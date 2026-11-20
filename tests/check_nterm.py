"""Настоящий PTY: лёгкий профиль, Readline, вложенный Neovim и история."""
from pathlib import Path
import fcntl
import json
import os
import pty
import select
import shlex
import struct
import subprocess
import tempfile
import termios
import time

# Termux: vfork + exec-перехватчик повреждает память CPython при RPC-запусках.
# fork изолирует тестовый процесс; рабочий профиль Python не использует.
if "/com.termux/" in os.environ.get("PREFIX", ""):
    subprocess._USE_VFORK = False

root = Path(__file__).resolve().parents[1]
scratch = Path(os.environ.get("TMPDIR", str(root / ".tmp")))
scratch.mkdir(parents=True, exist_ok=True)
base = Path(tempfile.mkdtemp(prefix="nterm-test-", dir=scratch)).resolve()
(base / "tmp").mkdir()
(base / "config").mkdir()
(base / "config/nvim").symlink_to(root, target_is_directory=True)
rc = base / "bashrc"
rc.write_text("PS1='ROOT> '\nHISTCONTROL=\nHISTIGNORE=\nshopt -s histappend lithist\n"
              ". " + shlex.quote(str(root / 'terminal/autostart.bash')) + "\n"
              "fixture_func() { printf 'FUNCTION_OK\\n'; }\n"
              "fixture_prompt() { return $?; }\nPROMPT_COMMAND=(fixture_prompt)\nHISTFILE=" + shlex.quote(str(base / "bash_history")) + "\n")
sock = str(base / "nvim.sock")
env = {**os.environ, "TERM": "xterm-256color", "NTERM_CONFIG_DIR": str(root),
       "NTERM_USER_BASHRC": str(rc), "XDG_STATE_HOME": str(base / "state"),
       "XDG_CONFIG_HOME": str(base / "config"),
       "XDG_CACHE_HOME": str(base / "cache"), "TMPDIR": str(base / "tmp")}
env.pop("TMUX", None)
master, slave = pty.openpty()
fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 38, int(os.environ.get("NTERM_TEST_COLUMNS", "120")), 0, 0))
process = subprocess.Popen([str(root / "scripts/nterm"), "--listen", sock],
                           stdin=slave, stdout=slave, stderr=slave, env=env, cwd=root)
os.close(slave)
output = bytearray()


def pump(seconds=.05):
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        if select.select([master], [], [], .01)[0]:
            try: output.extend(os.read(master, 65536))
            except OSError: return


def lua(code, server=sock):
    return subprocess.check_output(["nvim", "--headless", "-u", "NONE", "-i", "NONE", "--server", server,
                                    "--remote-expr", "luaeval(" + json.dumps(code) + ")"],
                                   text=True, stderr=subprocess.STDOUT, timeout=8).strip()


def state():
    return json.loads(lua("""(function()
      local m=require('terminal_profile');local s=m.current();local a=_G.first_session or s
      return vim.json.encode({mode=vim.api.nvim_get_mode().mode,buf=vim.api.nvim_get_current_buf(),
       draft=vim.bo.buftype=='acwrite',lines=vim.api.nvim_buf_get_lines(0,0,-1,false),
       output=a and vim.api.nvim_buf_get_lines(a.buf,0,-1,false) or {},ready=a and a.ready or false,
       current_ready=s and s.ready or false,current_id=s and s.id,session_count=vim.tbl_count(m.sessions),
       tabs=#vim.api.nvim_list_tabpages(),tab=vim.api.nvim_tabpage_get_number(0),
       lazy=package.loaded.lazy~=nil,hop=package.loaded.hop~=nil,toggle=package.loaded.toggleterm~=nil}) end)()"""))


def wait_for(predicate, label, timeout=8):
    end = time.monotonic() + timeout
    value = {}
    while time.monotonic() < end and process.poll() is None:
        pump()
        try: value = state()
        except (subprocess.CalledProcessError, json.JSONDecodeError): continue
        if predicate(value): return value
    raise AssertionError(label + ": " + repr(value))


def send(data): os.write(master, data)
def command(text): send(text.encode() + b"\r")
def draft(text):
    lua("require('terminal_profile').edit_command(" + json.dumps(text) + ",_G.first_session)")
    return wait_for(lambda s: s["draft"] and s["mode"] == "n", "command editor")


try:
    initial = wait_for(lambda s: s["current_ready"] and s["mode"] == "t", "first Bash prompt", 15)
    assert initial["session_count"] == initial["tabs"] == 1 and not initial["lazy"] and not initial["toggle"] and not initial["hop"]
    assert 'invalid keymap name' not in '\n'.join(initial['output']), initial['output']
    command("""for nterm_map in emacs-standard vi-insert vi-command; do nterm_bindings=$(bind -m "$nterm_map" -X); if [[ $nterm_bindings == *__nterm_request_edit* && $nterm_bindings == *__nterm_load_command* ]]; then printf 'READLINE_MAP_OK=%s\\n' "$nterm_map"; fi; done""")
    wait_for(lambda s: s['ready'] and all('READLINE_MAP_OK=' + name in s['output']
             for name in ('emacs-standard', 'vi-insert', 'vi-command')), 'Readline maps installed')
    lua("(function() _G.first_session=require('terminal_profile').current() end)()")
    ipc = Path(lua("first_session.command_file")).parent
    command("export NT_KEEP=kept; cd " + shlex.quote(str(base)) + "; printf 'CONTEXT_OK\\n'")
    wait_for(lambda s: "CONTEXT_OK" in s["output"] and s["ready"], "shell context")
    edited = "fixture_func\nprintf 'edited_%s\\n' \"$NT_KEEP\""
    draft(edited.replace('edited_', 'ORIGINAL_'))
    command(':%s/ORIGINAL_/edited_/')
    wait_for(lambda s: s['draft'] and '\n'.join(s['lines']) == edited, 'edit command text')
    command(":wq")
    wait_for(lambda s: not s["draft"] and s["ready"] and "edited_kept" in s["output"] and "FUNCTION_OK" in s["output"], "wq executes in same Bash")
    history = base / "state/nvim/nterm/commands.jsonl"
    assert json.loads(history.read_text().splitlines()[0])["command"] == edited
    assert history.stat().st_mode & 0o777 == 0o600
    assert lua("first_session.cwd") == str(base)
    prompts = sum(line.startswith('ROOT>') for line in state()['output'])
    command('false')
    wait_for(lambda s: s['ready'] and sum(line.startswith('ROOT>') for line in s['output']) > prompts, 'failed command prompt')
    draft("printf 'AFTER_FAILURE=%s\\n' \"$?\"")
    command(':wq')
    wait_for(lambda s: s['ready'] and 'AFTER_FAILURE=1' in s['output'], 'previous exit status')
    cancelled = base / "must-not-run"
    draft("touch " + shlex.quote(str(cancelled)))
    command(':s/touch/wq/')
    wait_for(lambda s: s['draft'] and s['lines'][0].startswith('wq '), 'wq abbreviation changed substitution text')
    command(":q!")
    wait_for(lambda s: not s["draft"] and s["mode"] == "t", "cancel draft")
    assert not cancelled.exists() and len(history.read_text().splitlines()) == 2
    command("sleep 1.5")
    wait_for(lambda s: not s["ready"], "busy signal")
    draft("touch " + shlex.quote(str(cancelled)))
    command(":wq")
    pump(.2)
    assert state()["draft"] and not cancelled.exists(), "command injected into busy process"
    command(":q!")
    wait_for(lambda s: s["ready"] and not s["draft"], "prompt after busy job")
    send(b"printf 'READLINE_OK\\n'\x18\x05")
    value = wait_for(lambda s: s["draft"], "Readline editor request")
    assert "printf 'READLINE_OK\\n'" in "\n".join(value["lines"]), value
    command(":wq")
    wait_for(lambda s: s["ready"] and "READLINE_OK" in s["output"], "Readline edit and execute")

    worker, raw, ready = base / "raw.py", base / "raw.bin", base / "raw.ready"
    worker.write_text("import os,tty\nfrom pathlib import Path\ntty.setraw(0)\nPath(" + repr(str(ready)) + ").touch()\n"
                      "data=b''\nwhile len(data)<5:\n data+=os.read(0,64)\nPath(" + repr(str(raw)) + ").write_bytes(data)\n")
    command("python3 " + shlex.quote(str(worker)))
    deadline = time.monotonic() + 5
    while not ready.exists() and time.monotonic() < deadline: pump()
    assert ready.exists()
    send(b"\x1c\x0e\x1bz")
    pump(.1)
    assert state()["mode"] == "t", "outer consumed inner Vim escape"
    send(b"\0")
    wait_for(lambda s: s["mode"] in ("n", "nt"), "outer prefix")
    send(b"\0")
    wait_for(lambda s: s["mode"] == "t" and s["ready"], "double prefix passthrough")
    assert raw.read_bytes() == b"\x1c\x0e\x1bz\0", raw.read_bytes()

    inner = str(base / "inner.sock")
    command("nvim --clean -u NONE -i NONE --listen " + shlex.quote(inner))
    deadline = time.monotonic() + 8
    while not Path(inner).exists() and time.monotonic() < deadline: pump()
    assert Path(inner).exists()
    command(":terminal cat")
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        pump()
        if lua("vim.api.nvim_get_mode().mode", inner) == "t": break
    if lua("vim.api.nvim_get_mode().mode", inner) in ("n", "nt"):
        send(b"i")
        pump(.15)
    assert lua("vim.api.nvim_get_mode().mode", inner) == "t"
    send(b"\x1c\x0e")
    pump(.2)
    assert lua("vim.api.nvim_get_mode().mode", inner) in ("n", "nt") and state()["mode"] == "t"
    send(b"\0")
    wait_for(lambda s: s["mode"] in ("n", "nt"), "outer Normal over nested Vim")
    send(b"i")
    wait_for(lambda s: s["mode"] == "t", "resume nested Vim")
    command(":qa!")
    wait_for(lambda s: s["ready"], "nested Vim exit")

    command("printf 'printf SELECTED_OK\\n'")
    wait_for(lambda s: "printf SELECTED_OK" in s["output"] and s["ready"], "selection output")
    send(b"\0")
    wait_for(lambda s: s["mode"] in ("n", "nt"), "outer selection mode")
    lua("(function() for i,line in ipairs(vim.api.nvim_buf_get_lines(first_session.buf,0,-1,false)) do if line=='printf SELECTED_OK' then vim.api.nvim_win_set_cursor(0,{i,0});break end end end)()")
    send(b"V e")
    value = wait_for(lambda s: s["draft"], "visual region editor")
    assert value["lines"] == ["printf SELECTED_OK"], value
    command(":q!")
    wait_for(lambda s: not s["draft"] and s["mode"] == "t", "cancel visual editor")
    send(b"\0")
    wait_for(lambda s: s["mode"] in ("n", "nt"), "copy selection mode")
    highlighted = lua("""(function()
      _G.nterm_yank_marks = function()
        local count=0
        for _,mark in ipairs(vim.api.nvim_buf_get_extmarks(0,-1,0,-1,{details=true})) do
          if mark[4].hl_group=='IncSearch' then count=count+1 end
        end
        return count
      end
      vim.cmd('normal! yy')
      return nterm_yank_marks()
    end)()""")
    assert int(highlighted) > 0, "copied text was not highlighted"
    pump(.25)
    assert lua("nterm_yank_marks()") == "0", "copy highlight did not expire"
    assert b"\x1b]52;" in output, "OSC52 clipboard was not emitted"
    send(b" j")
    wait_for(lambda s: s["hop"], "Hop lazy load")
    send(b"\x1b")
    pump(.1)
    assert not state()["lazy"]
    send(b" tn")
    wait_for(lambda s: s["tabs"] == 2 and s["current_ready"] and s["mode"] == "t", "new tab")
    send(b"\0 tv")
    wait_for(lambda s: s["session_count"] == 3 and s["current_ready"], "terminal split")
    send(b"\0 tc")
    wait_for(lambda s: s["session_count"] == 2 and s["mode"] == "t", "close split")
    send(b"\0 t[")
    wait_for(lambda s: s["tab"] == 1 and s["current_id"] == 1 and s["mode"] == "t", "previous tab")
    send(b"\0:qa!\r")
    deadline = time.monotonic() + 5
    while process.poll() is None and time.monotonic() < deadline: pump()
    assert process.poll() == 0
    assert not ipc.exists(), "IPC directory leaked"
    assert "edited_%s" in (base / "bash_history").read_text(), "edited command missing from Bash history"
    print("PASS: minimal boot; same Bash/history; edit/cancel/busy guard; Readline Ctrl-X Ctrl-E; raw forwarding; nested Vim; selection; OSC52 and transient yank highlight; Hop; tabs/splits; cleanup")
finally:
    (base / "screen.log").write_bytes(output)
    if process.poll() is None:
        try: lua("vim.schedule(function() vim.cmd('qa!') end)")
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired): pass
        pump(.1)
        if process.poll() is None: process.terminate()
    process.wait(timeout=5)
    os.close(master)
