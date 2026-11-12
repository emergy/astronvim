"""PTY: автозапуск новой сессии, возврат в Bash и исключение вложенных запусков."""
from pathlib import Path
import os
import pty
import shutil
import subprocess
import tempfile

if '/com.termux/' in os.environ.get('PREFIX', ''):
    subprocess._USE_VFORK = False

root = Path(__file__).resolve().parents[1]
bash = shutil.which('bash')
assert bash
base = Path(tempfile.mkdtemp(prefix='nterm-autostart-', dir=os.environ.get('TMPDIR', str(root / '.tmp'))))
(base / 'bin').mkdir()
program = base / 'bin/nterm'
program.write_text('#!' + bash + '\nprintf "called\\n" >> "$TEST_CALLS"\nexit "${TEST_EXIT:-0}"\n')
program.chmod(0o700)
env = {**os.environ, 'PATH': str(base / 'bin') + ':' + os.environ['PATH'],
       'TEST_HOOK': str(root / 'terminal/autostart.bash'), 'TEST_CALLS': str(base / 'calls')}
for name in ('NTERM_ACTIVE', 'NTERM_AUTOSTART_SEEN', 'NTERM_TOKEN', '__nterm_token', 'NTERM_AUTOSTART',
             'NVIM', 'TMUX', 'STY', 'SSH_CONNECTION', 'SSH_CLIENT', 'SSH_TTY', 'BASH_ENV', 'ENV', 'SHELLOPTS', 'BASHOPTS'):
    env.pop(name, None)
script = '. "$TEST_HOOK"; . "$TEST_HOOK"; bash --noprofile --norc -ic \' . "$TEST_HOOK" \'; printf "FALLBACK_OK\\n"'


def check(label, override=None, expected=0, interactive=True, tty=True, code=script):
    case_env = {**env, **(override or {})}
    calls = base / ('calls-' + label)
    case_env['TEST_CALLS'] = str(calls)
    args = [bash, '--noprofile', '--norc', '-ic' if interactive else '-c', code]
    if tty:
        master, slave = pty.openpty()
        process = subprocess.Popen(args, stdin=slave, stdout=slave, stderr=slave, env=case_env)
        os.close(slave)
        # Вывода мало: PTY не заполняется, ожидаем завершения и читаем до EOF.
        process.wait(timeout=10)
        output = bytearray()
        while True:
            try:
                chunk = os.read(master, 4096)
            except OSError:
                break
            if not chunk:
                break
            output.extend(chunk)
        os.close(master)
        assert process.returncode == 0, (label, output)
        text = output.decode(errors='replace')
    else:
        result = subprocess.run(args, env=case_env, capture_output=True, text=True, timeout=10, check=True)
        text = result.stdout + result.stderr
    count = len(calls.read_text().splitlines()) if calls.exists() else 0
    assert count == expected, (label, count, text)
    assert 'FALLBACK_OK' in text, (label, text)
    return text


check('new-session', expected=1)
check('second-new-session', expected=1)
assert 'завершился с ошибкой' in check('failed-launch', {'TEST_EXIT': '23'}, expected=1)
for name in ('NTERM_ACTIVE', 'NTERM_AUTOSTART_SEEN', 'NTERM_TOKEN', '__nterm_token',
             'NVIM', 'TMUX', 'STY', 'SSH_CONNECTION', 'SSH_CLIENT', 'SSH_TTY'):
    check(name, {name: 'present'})
check('disabled', {'NTERM_AUTOSTART': '0'})
check('noninteractive', interactive=False,
      code='. "$TEST_HOOK"; printf "FALLBACK_OK\\n"')
check('no-tty', tty=False)
check('missing-program', {'PATH': '/nonexistent'},
      code='. "$TEST_HOOK"; printf "FALLBACK_OK\\n"')
print('PASS: each new session; once per process tree; exit/error fallback; SSH/Nvim/Nterm/tmux/screen guards; opt-out; noninteractive; no TTY; absent command')
