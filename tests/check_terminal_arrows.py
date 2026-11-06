import os,pty,fcntl,termios,struct,subprocess,time,select,json,tempfile
from pathlib import Path
base=Path(tempfile.mkdtemp(dir=Path(__file__).resolve().parents[1]/'.tmp',prefix='terminal-normal-'));sock=str(base/'nvim.sock');script=base/'setup.lua'
worker=base/'worker.py'
worker.write_text("import os,tty\nfrom pathlib import Path\ntty.setraw(0)\nos.write(1,b'history line\\r\\n'*80)\nwhile True:\n with (Path(__file__).parent/'input').open('ab',buffering=0) as f: f.write(os.read(0,1024))\n")
script.write_text("""
_G.editor=vim.api.nvim_get_current_win()
vim.cmd.split()
vim.api.nvim_win_set_buf(0,vim.api.nvim_create_buf(true,false))
_G.job=vim.fn.termopen({'python3',WORKER})
local hints=require('hop.hint')
local create=hints.create_hints
hints.create_hints=function(...)
 local result=create(...)
 if result[1] then vim.fn.writefile({vim.json.encode({label=result[1].label,row=result[1].jump_target.cursor.row})},HINT) end
 return result
end
vim.cmd.startinsert()
""".replace('WORKER',json.dumps(str(worker))).replace('HINT',json.dumps(str(base/'hint'))))

m,s=pty.openpty();fcntl.ioctl(s,termios.TIOCSWINSZ,struct.pack('HHHH',40,120,0,0))
p=subprocess.Popen(['nvim','-i','NONE','--listen',sock,'+luafile '+str(script)],stdin=s,stdout=s,stderr=s,env={**os.environ,'TERM':'xterm-256color','NVIM_UNIVERSAL_TEST':'1'});os.close(s)
def pump(sec=.3):
 end=time.monotonic()+sec
 while time.monotonic()<end:
  if select.select([m],[],[],.02)[0]:
   try:os.read(m,65536)
   except OSError:return
def lua(code):
 return subprocess.check_output(['nvim','--headless','-u','NONE','-i','NONE','--server',sock,'--remote-expr','luaeval('+json.dumps(code)+')'],stderr=subprocess.STDOUT).decode(errors='replace').strip()
def key(data):os.write(m,data);pump()
def normal():return lua('vim.api.nvim_get_mode().mode') in ('n','nt')
try:
 pump(1.5);assert lua('vim.api.nvim_get_mode().mode')=='t'
 for _ in range(2):
  key(b'\x1b[1;6D');assert normal()
  key(b'\x1b[1;6D');assert normal()
  key(b'\x1b[1;6C');assert lua('vim.api.nvim_get_mode().mode')=='t'
  key(b'\x1b[1;6C');assert lua('vim.api.nvim_get_mode().mode')=='t'
 print('PASS Ctrl+Shift+Left normal, Ctrl+Shift+Right terminal, repeated presses safe')
 for startmode in ('t','n'):
  if startmode=='n':key(b'\x1b[1;6D')
  hint=base/'hint'
  if hint.exists():hint.unlink()
  key(b'\x1b[1;6B');assert hint.exists(),'Hop hints were not generated'
  target=json.loads(hint.read_text());key(target['label'].encode())
  assert normal()
  assert int(lua('vim.api.nvim_win_get_cursor(0)[1]'))==target['row'],target
  print('PASS Ctrl+Shift+Down real Hop line selection from',startmode)
 assert not (base/'input').exists() or (base/'input').read_bytes()==b''
 assert lua('vim.fn.jobwait({job},0)[1]')=='-1'
 for arrow in ('Left','Right','Down'):
  assert lua('vim.fn.maparg("<C-'+arrow+'>","n",false,true).desc')=='Resize split '+arrow.lower()
  assert lua('vim.fn.maparg("<C-'+arrow+'>","t",false,true).buffer or 0')=='0'
 print('PASS unshifted Ctrl+arrows keep original terminal and resize behavior')
 key(b'\x1b[1;6C');key(b'probe');assert (base/'input').read_bytes()==b'probe'
 print('PASS control keys are not sent to process; regular input restored')
 lua('(function() vim.cmd.stopinsert(); vim.api.nvim_set_current_win(editor) end)()');pump()
 assert lua('vim.fn.maparg("<C-Left>","n",false,true).desc')=='Resize split left'
 assert lua('vim.fn.maparg("<C-Right>","n",false,true).desc')=='Resize split right'
 assert lua('vim.fn.maparg("<C-Down>","n",false,true).desc')=='Resize split down'
 print('PASS ordinary editor retains resize mappings')
finally:
 try:lua('vim.schedule(function() vim.cmd("qa!") end)')
 except Exception:pass
 pump()
 if p.poll() is None:p.terminate()
 p.wait(timeout=5);os.close(m)
