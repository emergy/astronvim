"""Проверка настоящего клавиатурного ввода в отдельном процессе Neovim."""
import fcntl
import json
import os
from pathlib import Path
import pty
import select
import struct
import subprocess
import tempfile
import termios
import time

base = Path(os.environ.get('TMPDIR', str(Path.cwd() / '.tmp')))
base.mkdir(parents=True, exist_ok=True)
artifacts = Path(tempfile.mkdtemp(prefix='nvim-key-test-', dir=base))
for index in range(1, 4):
    (artifacts / f'file-{index}.txt').write_text(f'file {index}\n')
state_file = artifacts / 'state.json'
key_file = artifacts / 'hint.txt'
(artifacts / 'terminal.py').write_text(
    "import os, tty\nfrom pathlib import Path\ntty.setraw(0)\n"
    "base=Path(__file__).parent\n(base/'terminal-ready').touch()\n"
    "while True:\n with (base/'terminal-input.bin').open('ab', buffering=0) as output: output.write(os.read(0, 1024))\n"
)
lua = r'''
vim.defer_fn(function()
  local base = BASE
  local files = {}
  for i=1,3 do
    files[i]=vim.fn.bufadd(base..'/file-'..i..'.txt')
    vim.fn.bufload(files[i]); vim.bo[files[i]].buflisted=true
  end
  local editor=vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(editor,files[1])
  local hints=require('hop.hint')
  local create=hints.create_hints
  hints.create_hints=function(...)
    local result=create(...)
    local state=require('neo-tree.sources.manager').get_state('buffers')
    for _,hint in ipairs(result) do
      local node=state.tree:get_node(hint.jump_target.cursor.row)
      if node and node.extra and node.extra.bufnr==files[2] then
        vim.fn.writefile({hint.label},base..'/hint.txt')
      end
    end
    return result
  end
  local timer=vim.uv.new_timer()
  local second
  timer:start(0,50,vim.schedule_wrap(function()
    local terms=package.loaded['toggleterm.terminal']
    local all=terms and terms.get_all() or {}
    if #all==1 and all[1]:is_open() and not second then
      second=terms.Terminal:new({direction='vertical',cmd='python3 '..vim.fn.shellescape(base..'/terminal.py')});second:spawn()
    end
    local active
    for _,term in ipairs(all) do
      if term:is_open() and term.window==vim.api.nvim_get_current_win() then active=term.id end
    end
    local trees=0
    for _,win in ipairs(vim.api.nvim_list_wins()) do
      if vim.bo[vim.api.nvim_win_get_buf(win)].filetype=='neo-tree' then trees=trees+1 end
    end
    local zen=package.loaded['snacks.zen']
    local state={mode=vim.api.nvim_get_mode().mode,ft=vim.bo.filetype,
      file=vim.api.nvim_buf_get_name(0),window=vim.api.nvim_get_current_win(),
      windows=#vim.api.nvim_list_wins(),trees=trees,active=active,
      zoom=zen and zen.win and zen.win:valid() or false}
    vim.fn.writefile({vim.json.encode(state)},base..'/state.json')
  end))
  vim.api.nvim_create_autocmd('VimLeavePre',{once=true,callback=function()timer:stop();timer:close()end})
end,1500)
'''.replace('BASE', json.dumps(str(artifacts)))
script = artifacts / 'case.lua'
script.write_text(lua)
master, slave = pty.openpty()
fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 42, 120, 0, 0))
process = subprocess.Popen(['nvim', '-i', 'NONE', '+luafile ' + str(script)], cwd=artifacts,
                           stdin=slave, stdout=slave, stderr=slave,
                           env={**os.environ, 'TERM': 'xterm-256color'})
os.close(slave)
output = bytearray()

def drain():
    if select.select([master], [], [], 0.05)[0]:
        try:
            output.extend(os.read(master, 65536))
        except OSError:
            pass

def wait_for(predicate, message, timeout=12):
    end = time.monotonic() + timeout
    state = {}
    while time.monotonic() < end and process.poll() is None:
        drain()
        try:
            state = json.loads(state_file.read_text())
            if predicate(state):
                return state
        except (FileNotFoundError, json.JSONDecodeError):
            pass
    raise AssertionError(message + ': ' + repr(state))

def send(data):
    os.write(master, data)

try:
    wait_for(lambda s: s['file'].endswith('file-1.txt') and s['mode']=='n', 'editor ready')
    send(b' e')
    wait_for(lambda s: s['ft']=='neo-tree', 'Explorer focused before :edit')
    send(b':e '+str(artifacts/'file-1.txt').encode()+b'\r')
    wait_for(lambda s: s['file'].endswith('file-1.txt') and s['ft']!='neo-tree' and s['trees']==1,
             ':edit existing file from Neo-tree must not exit Neovim')
    send(b' e')
    wait_for(lambda s: s['trees']==0 and s['mode']=='n', 'Explorer closes after :edit regression')
    send(b'\x1b[18~')  # F7
    first=wait_for(lambda s: s.get('active')==1 and s['mode']=='t', 'F7 opens terminal')
    send(b'\x1b[19~')  # F8
    wait_for(lambda s: s['ft']=='snacks_picker_input', 'F8 picker from terminal mode')
    send(b'\x1b[B\r')
    second=wait_for(lambda s: s.get('active')==2 and s['mode']=='t', 'F8 switches session')
    assert first['window']==second['window'] and second['windows']==2, 'F8 must reuse split'
    send(b'\x1bz')
    wait_for(lambda s: s['zoom'] and s['mode']=='t', 'Alt-z zoom from terminal mode')
    send(b'\x1bz')
    wait_for(lambda s: not s['zoom'] and s.get('active')==2 and s['mode']=='t', 'Alt-z restores terminal')
    end=time.monotonic()+5
    while not (artifacts/'terminal-ready').exists() and time.monotonic()<end:
        drain()
    assert (artifacts/'terminal-ready').exists(), 'raw terminal ready'
    send(b'\x08\n\x0b\x0c')  # Ctrl-h/j/k/l, including the Ctrl+Enter newline
    end=time.monotonic()+5
    received=artifacts/'terminal-input.bin'
    while time.monotonic()<end:
        drain()
        if received.exists() and received.read_bytes()==b'\x08\n\x0b\x0c':
            break
    assert received.exists() and received.read_bytes()==b'\x08\n\x0b\x0c', 'original control keys must reach the terminal'
    send(b'\x1b[107;6u')  # Ctrl-Shift-k
    wait_for(lambda s: s['file'].endswith('file-1.txt') and s['mode']=='n', 'Ctrl-Shift-k returns to editor')
    send(b'\x1b[1;3B')  # Alt-Down from editor
    wait_for(lambda s: s.get('active')==2, 'Alt-Down returns to terminal')
    send(b'\x1b[1;3A')  # Alt-Up from terminal
    wait_for(lambda s: s['file'].endswith('file-1.txt') and s['mode']=='n', 'Alt-Up returns to editor')
    send(b'\x1b[106;6u')  # Ctrl-Shift-j from editor
    wait_for(lambda s: s.get('active')==2, 'Ctrl-Shift-j returns to terminal')
    send(b'\x1b[107;6u')
    wait_for(lambda s: s['file'].endswith('file-1.txt') and s['mode']=='n', 'Ctrl-Shift-k returns again')
    send(b' bb')
    end=time.monotonic()+8
    while not key_file.exists() and time.monotonic()<end:
        drain()
    assert key_file.exists(), 'Neo-tree Hop labels appear'
    send(key_file.read_text().strip().encode())
    wait_for(lambda s: s['file'].endswith('file-2.txt') and s['trees']==0, 'Space bb opens file and hides tree')
    send(b':qa!\r')
    end=time.monotonic()+5
    while process.poll() is None and time.monotonic()<end:
        drain()
    assert process.poll()==0, 'clean Neovim exit'
    print('PASS: :edit existing file from Neo-tree, real F7/F8 session switching, Alt-z from terminal, Ctrl-Shift-j/k, Alt-Up/Down, raw Ctrl-h/j/k/l passthrough, Space bb + Hop; '+str(artifacts))
finally:
    (artifacts/'screen.log').write_bytes(output)
    if process.poll() is None:
        process.terminate()
    process.wait(timeout=5)
    os.close(master)
