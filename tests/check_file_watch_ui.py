"""Внешняя запись файлов при активном терминальном вводе полной конфигурации."""
from pathlib import Path
import fcntl
import json
import os
import pty
import select
import struct
import subprocess
import tempfile
import termios
import time

root = Path(__file__).resolve().parents[1]
scratch = Path(os.environ.get("TMPDIR", str(root / ".tmp")))
scratch.mkdir(parents=True, exist_ok=True)
base = Path(tempfile.mkdtemp(prefix="file-watch-ui-", dir=scratch))
one, two, three = base / "one.txt", base / "two.txt", base / "created.txt"
one.write_text("one\n")
two.write_text("two\n")
sock = str(base / "nvim.sock")
script = base / "setup.lua"
script.write_text("""
vim.opt.rtp:prepend(ROOT)
require('file_watch').setup()
vim.cmd.edit(ONE)
_G.watched_editor=vim.api.nvim_get_current_win()
_G.watched_one=vim.api.nvim_get_current_buf()
_G.watched_two=vim.fn.bufadd(TWO)
vim.fn.bufload(watched_two)
_G.watched_three=vim.fn.bufadd(THREE)
vim.fn.bufload(watched_three)
require('lazy').load({plugins={'toggleterm.nvim'}})
require('terminal_sessions').new({cmd='cat'})
_G.watch_state=function()
 return vim.json.encode({
  current=vim.api.nvim_get_current_win(),buf=vim.api.nvim_get_current_buf(),mode=vim.api.nvim_get_mode().mode,
  one=vim.api.nvim_buf_get_lines(watched_one,0,-1,false),two=vim.api.nvim_buf_get_lines(watched_two,0,-1,false),
  three=vim.api.nvim_buf_get_lines(watched_three,0,-1,false),
  modified=vim.bo[watched_two].modified,layout=vim.inspect(vim.fn.winlayout()),
  ready=not require('user_platform').mobile or require('terminal_zoom').active(),
  checks=require('file_watch').stats().checks})
end
""".replace("ROOT", json.dumps(str(root))).replace("ONE", json.dumps(str(one))).replace("TWO", json.dumps(str(two))).replace("THREE", json.dumps(str(three))))
master, slave = pty.openpty()
fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 42, 120, 0, 0))
process = subprocess.Popen(["nvim", "-i", "NONE", "--listen", sock, "+luafile " + str(script)],
                           stdin=slave, stdout=slave, stderr=slave,
                           env={**os.environ, "TERM": "xterm-256color", "NVIM_UNIVERSAL_TEST": "1"})
os.close(slave)
output = bytearray()


def pump(seconds=.05):
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        if select.select([master], [], [], .01)[0]:
            try:
                output.extend(os.read(master, 65536))
            except OSError:
                return


def lua(code):
    return subprocess.check_output(["nvim", "--headless", "-u", "NONE", "-i", "NONE", "--server", sock,
                                    "--remote-expr", "luaeval(" + json.dumps(code) + ")"],
                                   stderr=subprocess.STDOUT, timeout=10).decode().strip()


def wait_for(predicate):
    end = time.monotonic() + 10
    state = {}
    while time.monotonic() < end and process.poll() is None:
        pump()
        try:
            state = json.loads(lua("_G.watch_state()"))
        except (subprocess.CalledProcessError, json.JSONDecodeError):
            continue
        if predicate(state):
            return state
    raise AssertionError(state)


try:
    initial = wait_for(lambda value: value["mode"] == "t" and value["ready"])
    one.write_text("agent changed visible editor\n")
    state = wait_for(lambda value: value["one"] == ["agent changed visible editor"])
    two.write_text("agent changed hidden buffer\n")
    state = wait_for(lambda value: value["two"] == ["agent changed hidden buffer"])
    temp = base / "replacement"
    temp.write_text("atomic agent save\n")
    temp.replace(two)
    state = wait_for(lambda value: value["two"] == ["atomic agent save"])
    three.write_text("created by agent\n")
    state = wait_for(lambda value: value["three"] == ["created by agent"])
    assert state["current"] == initial["current"] and state["mode"] == "t" and state["layout"] == initial["layout"], state
    lua("vim.api.nvim_buf_set_lines(watched_two,0,-1,false,{'unsaved user edit'})")
    two.write_text("conflicting agent change\n")
    pump(.3)
    state = json.loads(lua("_G.watch_state()"))
    assert state["two"] == ["unsaved user edit"] and state["modified"] and state["mode"] == "t", state
    assert state["current"] == initial["current"] and state["layout"] == initial["layout"], state
    checks = state["checks"]
    pump(.3)
    assert json.loads(lua("_G.watch_state()"))["checks"] == checks, "idle checks detected"
    print("PASS: full config, real terminal input, visible/hidden reload, atomic replace, conflicts, focus/layout retained, no idle polling")
finally:
    (base / "screen.log").write_bytes(output)
    try:
        lua("vim.schedule(function() vim.cmd('qa!') end)")
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
        pass
    pump(.2)
    if process.poll() is None:
        process.terminate()
    process.wait(timeout=5)
    os.close(master)
