"""Проверка общего tmux-конфига на отдельном сокете без рабочих сессий."""
from pathlib import Path
import json
import shlex
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
config = root / "tmux/tmux.conf"
(root / ".tmp").mkdir(exist_ok=True)
scratch = Path(tempfile.mkdtemp(prefix="tmux-config-", dir=root / ".tmp"))
base = ["tmux", "-S", str(scratch / "server.sock")]

def call(*args):
    return subprocess.check_output([*base, *args], text=True, stderr=subprocess.STDOUT, timeout=10).strip()

try:
    call("-f", str(config), "new-session", "-d", "-s", "config-test", "sleep 60")
    assert call("show-options", "-gv", "prefix") == "C-a"
    assert call("show-options", "-gv", "mouse") == "off"
    bindings = {}
    for line in call("list-keys", "-T", "prefix").splitlines():
        parts = shlex.split(line)
        index = parts.index("-T")
        bindings[parts[index + 2]] = " ".join(parts[index + 3:])
    for key, command in {"Tab": "select-pane", "Left": "select-pane -L", "Right": "select-pane -R",
                         "Up": "select-pane -U", "Down": "select-pane -D", "y": "synchronize-panes",
                         "m": "mouse", "r": "source-file"}.items():
        assert command in bindings.get(key, ""), (key, command)
    call("set-window-option", "synchronize-panes")
    assert call("show-window-options", "-v", "synchronize-panes") == "on"
    call("set-window-option", "synchronize-panes")
    assert call("show-window-options", "-v", "synchronize-panes") == "off"
    call("set-option", "-g", "mouse")
    assert call("show-options", "-gv", "mouse") == "on"
    call("set-option", "-g", "mouse")
    call("source-file", str(config))
    assert call("show-options", "-gv", "prefix") == "C-a"
    print(json.dumps({"result": "PASS", "version": subprocess.check_output(["tmux", "-V"], text=True).strip(),
                      "checks": ["config load/reload", "prefix/key bindings", "sync toggle", "mouse toggle"],
                      "artifacts": str(scratch)}))
finally:
    subprocess.run([*base, "kill-server"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
