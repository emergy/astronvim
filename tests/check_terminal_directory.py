"""Каталог новых PTY: корень Neo-tree при старом lcd редактора и явный Th/Tv."""
from pathlib import Path
import fcntl, json, os, pty, select, struct, subprocess, tempfile, termios, time
root=Path(__file__).resolve().parents[1]
base=Path(tempfile.mkdtemp(prefix='terminal-directory-',dir=root/'.tmp'))
a,b=base/'project-a',base/'project-b'
for path in (a/'.devcontainer',b/'chosen'):
 path.mkdir(parents=True)
 (path/'file.txt').write_text('fixture\n')
sock=str(base/'nvim.sock');script=base/'setup.lua'
script.write_text('''
_G.editor=vim.api.nvim_get_current_win()
vim.api.nvim_win_call(editor,function()vim.cmd('lcd '..vim.fn.fnameescape(A..'/.devcontainer'))end)
require('neo-tree.command').execute({source='filesystem',action='focus',dir=B})
_G.dir_state=function()
 return vim.json.encode({buf=vim.api.nvim_get_current_buf(),ft=vim.bo.filetype,
  root=require('terminal_directory').root(),terms=vim.tbl_map(function(t)
   return {id=t.id,dir=t.dir,buf=t.bufnr,job=t.job_id,win=t.window,cwd=(vim.uv or vim.loop).fs_readlink('/proc/'..vim.fn.jobpid(t.job_id)..'/cwd')}
  end,require('toggleterm.terminal').get_all())})
end
vim.api.nvim_set_current_win(editor)
'''.replace('A',json.dumps(str(a))).replace('B',json.dumps(str(b))))
m,s=pty.openpty();fcntl.ioctl(s,termios.TIOCSWINSZ,struct.pack('HHHH',42,140,0,0))
p=subprocess.Popen(['nvim','--listen',sock,'-i','NONE','+luafile '+str(script)],stdin=s,stdout=s,stderr=s,env={**os.environ,'TERM':'xterm-256color','NVIM_UNIVERSAL_TEST':'1'});os.close(s)
def pump(sec=.35):
 end=time.monotonic()+sec
 while time.monotonic()<end:
  if select.select([m],[],[],.02)[0]:
   try:os.read(m,65536)
   except OSError:return
def lua(code):
 return subprocess.check_output(['nvim','--headless','-u','NONE','-i','NONE','--server',sock,'--remote-expr','luaeval('+json.dumps(code)+')'],stderr=subprocess.STDOUT,timeout=10).decode().strip()
def state():return json.loads(lua('_G.dir_state()'))
def key(value):os.write(m,value);pump(.5)
try:
 pump(1.8)
 key(b'\x1b[18~');st=state()
 assert st['terms'][0]['dir']==str(b) and st['terms'][0]['cwd']==str(b),st
 first_job=st['terms'][0]['job']
 print('PASS F7 ignores stale editor lcd and starts at Neo-tree root')
 lua('''(function()
  local state=require('neo-tree.sources.manager').get_state('filesystem')
  require('neo-tree.ui.renderer').focus_node(state,B..'/chosen',true)
  state.commands.set_root(state)
 end)()'''.replace('B',json.dumps(str(b))))
 pump(.4)
 lua("require('terminal_sessions').new({cmd='cat'})");pump(.4);st=state()
 assert st['terms'][1]['dir']==str(b/'chosen') and st['terms'][1]['cwd']==str(b/'chosen'),st
 assert st['terms'][0]['job']==first_job and st['terms'][0]['cwd']==str(b),st
 print('PASS set_root changes new-session cwd without changing an existing shell')
 lua('''(function()
  require('neo-tree.command').execute({source='filesystem',action='focus',dir=B})
 end)()'''.replace('B',json.dumps(str(b))))
 pump(.4)
 lua('''(function()
  local state=require('neo-tree.sources.manager').get_state('filesystem')
  require('neo-tree.ui.renderer').focus_node(state,B..'/chosen',true)
  state.commands.toggleterm_horizontal(state)
 end)()'''.replace('B',json.dumps(str(b))))
 pump(.4);st=state()
 assert st['terms'][2]['dir']==str(b/'chosen') and st['terms'][2]['cwd']==str(b/'chosen'),st
 print('PASS explicit Neo-tree terminal command uses selected directory instead of root')
 lua('''(function()
  vim.cmd.tabnew()
  vim.cmd('tcd '..vim.fn.fnameescape(A))
  vim.cmd('lcd '..vim.fn.fnameescape(A..'/.devcontainer'))
  require('terminal_sessions').new({cmd='cat'})
 end)()'''.replace('A',json.dumps(str(a))))
 pump(.4);st=state()
 assert st['terms'][3]['dir']==str(a) and st['terms'][3]['cwd']==str(a),st
 print('PASS new tab without Neo-tree uses its tab cwd instead of window lcd or another tab root')
finally:
 try:lua('vim.schedule(function()vim.cmd("qa!")end)')
 except Exception:pass
 pump(.2)
 if p.poll() is None:p.terminate()
 p.wait(timeout=5);os.close(m)
