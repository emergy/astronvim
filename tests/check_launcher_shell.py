"""Изолированная проверка оболочки Launcher без облака и инфраструктуры."""
from pathlib import Path
import os
import shutil
import signal
import subprocess
import sys
import tempfile

source, profile = map(Path, sys.argv[1:3])
work = Path(tempfile.mkdtemp(prefix="launcher-shell-", dir=os.environ.get("TMPDIR", "/tmp")))
home = work / "home"
config = home / ".config/workstation"
config.mkdir(parents=True)
for name in ("interactive-shell.sh", "ssh-agent.sh"):
    shutil.copyfile(source / name, config / name)
(home / ".local/share/workstation").mkdir(parents=True)
(home / ".local/share/workstation/current").symlink_to(profile)
(home / ".ssh").mkdir()
subprocess.run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(home / ".ssh/id_test")], check=True)
(home / ".kube").mkdir()
for name in ("a.config", "b space.config", "ignored.bak"):
    (home / ".kube" / name).write_text("")
(home / ".bashrc").write_text("# isolated test\n")
(home / "storage").mkdir()
(home / "storage/downloads").write_text("preserve me\n")
mock = work / "bin"
mock.mkdir()
(mock / "rclone").write_text('#!/usr/bin/env bash\nprintf "%s\\n" "$@" > "$TEST_WORK/rclone-args"\ncat > "$TEST_WORK/archive"\n')
(mock / "rclone").chmod(0o700)
env = {**os.environ, "HOME": str(home), "TMPDIR": str(work), "TEST_WORK": str(work),
       "PATH": f"{mock}:{profile}/bin:" + os.environ["PATH"]}
for name in ("SSH_AUTH_SOCK", "SSH_AGENT_PID", "KUBECONFIG", "BASH_ENV"):
    env.pop(name, None)
script = r'''
. "$HOME/.config/workstation/interactive-shell.sh"
[[ $(alias gg) == "alias gg='lazygit'" ]] || exit 11
[[ $(alias vim) == "alias vim='nvim'" ]] || exit 12
[[ $KUBECONFIG == "$HOME/.kube/a.config:$HOME/.kube/b space.config" ]] || exit 13
[[ $KUBE_EDITOR == nvim ]] || exit 14
for command in kubectl k helm argocd codex; do complete -p "$command" >/dev/null || exit 15; done
ssh-add -l >/dev/null || exit 16
socket=$SSH_AUTH_SOCK
. "$HOME/.config/workstation/ssh-agent.sh"
[[ $SSH_AUTH_SOCK == "$socket" ]] || exit 17
printf '%s' "$socket" > "$TEST_WORK/socket"
git -C "$HOME" init -q -b prompt-check
cd "$HOME" || exit 18
[[ $(__git_ps1 ' (%s)') == *prompt-check* ]] || exit 19
[[ $PS1 == *'__git_ps1'* ]] || exit 20
# Алиас проверяется без обращения к облаку.
shopt -s expand_aliases
eval hsyncto </dev/null
grep -qx -- '--dry-run' "$TEST_WORK/rclone-args" || exit 21
grep -qx -- '--links' "$TEST_WORK/rclone-args" || exit 22
grep -qx 'dropbox:nix-launcher-home/' "$TEST_WORK/rclone-args" || exit 23
tbackup-home || exit 24
tar -tzf "$TEST_WORK/archive" | grep -q '^./.bashrc$' || exit 25
# Ошибка tar должна проходить через конвейер.
printf '#!/usr/bin/env bash\nexit 43\n' > "$TEST_WORK/bin/tar"
chmod +x "$TEST_WORK/bin/tar"
tbackup-root
[[ $? == 43 ]] || exit 26
'''
try:
    subprocess.run(["bash", "--noprofile", "--norc", "-c", script], env=env, check=True)
    override = {**env, "KUBECONFIG": "/chosen/config"}
    subprocess.run(["bash", "--noprofile", "--norc", "-c", '. "$HOME/.config/workstation/interactive-shell.sh"; [[ $KUBECONFIG == /chosen/config ]]'], env=override, check=True)
    subprocess.run(["bash", str(source / "setup-storage.sh")], env=env, check=True)
    assert (home / "storage/downloads").read_text() == "preserve me\n"
    assert (home / "storage/shared").is_symlink()
    print("PASS: aliases, completions, KUBECONFIG, shared agent/key loading, Git prompt, backup pipefail, dry-run sync and non-destructive storage")
finally:
    socket_file = work / "socket"
    if socket_file.exists():
        socket = socket_file.read_text()
        for line in subprocess.check_output(["ps", "-eo", "pid,args"], text=True).splitlines():
            words = line.split()
            if len(words) >= 4 and Path(words[1]).name == "ssh-agent" and words[2:4] == ["-a", socket]:
                os.kill(int(words[0]), signal.SIGTERM)
