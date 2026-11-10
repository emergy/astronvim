"""Регрессия коллизии langmapper: точка меняет корень, слеш открывает Filter."""
from pathlib import Path
import os,pty,struct,fcntl,termios,subprocess,time,select,json,tempfile
root=Path.cwd();base=Path(tempfile.mkdtemp(prefix='neotree-root-',dir=root/'.tmp'));sock=str(base/'nvim.sock')
(base/'chosen').mkdir();(base/'chosen/file.txt').write_text('fixture\n')
script=base/'setup.lua'
script.write_text('''
require('neo-tree.command').execute({action='focus',source='filesystem',dir=BASE})
_G.root_state=function()
 local state=require('neo-tree.sources.manager').get_state('filesystem')
 return vim.json.encode({path=state.path,ft=vim.bo.filetype,mode=vim.api.nvim_get_mode().mode,
  dot=vim.api.nvim_win_call(state.winid,function()return vim.fn.maparg('.','n',false,true).desc end),
  slash=vim.api.nvim_win_call(state.winid,function()return vim.fn.maparg('/','n',false,true).desc end)})
end
_G.choose_root=function()
 local state=require('neo-tree.sources.manager').get_state('filesystem')
 require('neo-tree.ui.renderer').focus_node(state,BASE..'/chosen',true)
end
'''.replace('BASE',json.dumps(str(base))))
m,s=pty.openpty();fcntl.ioctl(s,termios.TIOCSWINSZ,struct.pack('HHHH',42,120,0,0))
p=subprocess.Popen(['nvim','--listen',sock,'-i','NONE','+luafile '+str(script)],stdin=s,stdout=s,stderr=s,env={**os.environ,'TERM':'xterm-256color','NVIM_UNIVERSAL_TEST':'1'});os.close(s)
def pump(sec=.3):
 end=time.monotonic()+sec
 while time.monotonic()<end:
  if select.select([m],[],[],.02)[0]:
   try:os.read(m,65536)
   except OSError:return
def lua(code):
 return subprocess.check_output(['nvim','--headless','-u','NONE','-i','NONE','--server',sock,'--remote-expr','luaeval('+json.dumps(code)+')'],stderr=subprocess.STDOUT,timeout=10).decode().strip()
def state():return json.loads(lua('_G.root_state()'))
def key(value):os.write(m,value);pump(.5)
try:
 pump(1.8);st=state();assert st['dot']=='set_root' and st['slash']=='fuzzy_finder',st
 lua('_G.choose_root()');key(b'.');st=state();assert st['path']==str(base/'chosen') and st['ft']=='neo-tree',st
 print('PASS dot changes root instead of opening Filter')
 key(b'\x7f');st=state();assert st['path']==str(base),st
 key(b'/');st=state();assert st['ft']=='neo-tree-popup',st
 key(b'\x1b');st=state();assert st['ft']=='neo-tree' and st['dot']=='set_root',st
 print('PASS slash still opens Filter; root mapping survives redraw')
 lua('_G.choose_root()');key('ю'.encode());st=state();assert st['path']==str(base/'chosen') and st['ft']=='neo-tree',st
 print('PASS Russian dot-key alias retains set_root')
finally:
 try:lua('vim.schedule(function()vim.cmd("qa!")end)')
 except Exception:pass
 pump(.2)
 if p.poll() is None:p.terminate()
 p.wait(timeout=5);os.close(m)
