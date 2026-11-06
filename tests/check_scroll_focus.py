from pathlib import Path
import os, pty, struct, fcntl, termios, subprocess, time, select, json, tempfile
root=Path(__file__).resolve().parents[1];scratch=Path(os.environ.get('TMPDIR',str(root/'.tmp')));scratch.mkdir(parents=True,exist_ok=True);base=Path(tempfile.mkdtemp(prefix='scroll-focus-',dir=scratch));sock=str(base/'nvim.sock')
script=base/'setup.lua'
script.write_text('''
vim.opt.rtp:prepend(CONFIG)
vim.opt.mouse='a'
require('neotree_mouse').setup()
local lines={}
for i=1,300 do lines[i]=('line %03d '):format(i)..string.rep('x',160) end
vim.api.nvim_buf_set_lines(0,0,-1,false,lines)
_G.left=vim.api.nvim_get_current_win()
vim.cmd.vnew()
vim.api.nvim_buf_set_lines(0,0,-1,false,lines)
_G.right=vim.api.nvim_get_current_win()
_G.snap=function()
 local out={win=vim.api.nvim_get_current_win(),mode=vim.api.nvim_get_mode().mode}
 for _,name in ipairs({'left','right'}) do
  local win=_G[name]
  local info=vim.fn.getwininfo(win)[1]
  out[name]={win=win,x=info.wincol+4,y=info.winrow+8,top=info.topline}
 end
 return vim.json.encode(out)
end
'''.replace('CONFIG',json.dumps(str(root))))
m,s=pty.openpty();fcntl.ioctl(s,termios.TIOCSWINSZ,struct.pack('HHHH',40,120,0,0))
p=subprocess.Popen(['nvim','-u','NONE','-i','NONE','--listen',sock,'+luafile '+str(script)],stdin=s,stdout=s,stderr=s,env={**os.environ,'TERM':'xterm-256color'});os.close(s)
def pump(sec=.25):
 end=time.monotonic()+sec
 while time.monotonic()<end:
  if select.select([m],[],[],.02)[0]:
   try:os.read(m,65536)
   except OSError:return
def lua(code):
 return subprocess.check_output(['nvim','--headless','-u','NONE','-i','NONE','--server',sock,'--remote-expr','luaeval('+json.dumps(code)+')'],stderr=subprocess.STDOUT).decode().strip()
def snap():return json.loads(lua('_G.snap()'))
def wheel(target,button=65):
 st=snap()[target];os.write(m,f'\x1b[<{button};{st["x"]};{st["y"]}M'.encode());pump()
def run(code):lua('(function() '+code+' end)()');pump()
try:
 pump(.6)
 for mode,keys in [('n',b''),('i',b'i'),('v',b'v')]:
  run('vim.api.nvim_set_current_win(right)')
  os.write(m,keys);pump();wheel('left')
  st=snap();assert st['win']==st['left']['win'] and st['mode']=='n',st
  print('PASS editor focus from '+mode)
 before=snap()['left']['top'];wheel('left');assert snap()['left']['top']>before
 print('PASS native scrolling in active window')
 for button in (64,65,66,67):
  run('vim.api.nvim_set_current_win(right)');wheel('left',button);assert snap()['win']==snap()['left']['win']
 print('PASS all four wheel directions focus target')
 run("vim.api.nvim_set_current_win(right); vim.cmd.enew(); _G.job=vim.fn.termopen({'cat'}); vim.cmd.startinsert()")
 assert snap()['mode']=='t',snap()
 wheel('left');st=snap();assert st['mode']=='n' and st['win']==st['left']['win'],st
 assert lua('vim.fn.jobwait({job},0)[1]')=='-1'
 wheel('right');assert snap()['win']==snap()['right']['win']
 print('PASS switching from/to terminal keeps process running')
 run("_G.float=vim.api.nvim_open_win(vim.api.nvim_create_buf(false,true),true,{relative='editor',row=2,col=40,width=25,height=8,style='minimal'})")
 wheel('left');assert snap()['win']==snap()['left']['win']
 os.write(m,b'\x1b[<65;45;5M');pump();assert int(lua('vim.api.nvim_get_current_win()'))==int(lua('float'))
 print('PASS switching from/to floating window')
finally:
 try:lua('vim.schedule(function() vim.cmd("qa!") end)')
 except Exception:pass
 pump()
 if p.poll() is None:p.terminate()
 p.wait(timeout=5);os.close(m)
