from pathlib import Path
import os,pty,struct,fcntl,termios,subprocess,time,select,json,tempfile
root=Path(__file__).resolve().parents[1];scratch=Path(os.environ.get('TMPDIR',str(root/'.tmp')));scratch.mkdir(parents=True,exist_ok=True);base=Path(tempfile.mkdtemp(prefix='buffer-middle-',dir=scratch));sock=str(base/'nvim.sock')
for name in ('alpha','bravo','charlie','delta'):(base/(name+'.txt')).write_text(name+'\n')
script=base/'setup.lua'
script.write_text('''
vim.cmd.cd(BASE)
vim.opt.mouse='a'
vim.opt.showtabline=2
for _,name in ipairs({'alpha','bravo','charlie','delta'}) do vim.cmd.edit(BASE..'/'..name..'.txt') end
vim.cmd.edit(BASE..'/alpha.txt')
require('neo-tree.command').execute({source='buffers',position='left',action='show'})
vim.cmd.wincmd('l')
_G.middle_state=function()
 local state=require('neo-tree.sources.manager').get_state('buffers')
 local rows={}
 if state.tree and state.winid and vim.api.nvim_win_is_valid(state.winid) then
  local info=vim.fn.getwininfo(state.winid)[1]
  for row=1,vim.api.nvim_buf_line_count(state.bufnr) do
   local node=state.tree:get_node(row)
   if node and node.extra and node.extra.bufnr then rows[vim.fn.fnamemodify(vim.api.nvim_buf_get_name(node.extra.bufnr),':t')]={x=info.wincol+5,y=vim.fn.screenpos(state.winid,row,1).row} end
  end
 end
 local bufs={}
 for _,b in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[b].buflisted then bufs[vim.fn.fnamemodify(vim.api.nvim_buf_get_name(b),':t')]={id=b,modified=vim.bo[b].modified} end end
 return vim.json.encode({rows=rows,bufs=bufs,current=vim.fn.expand('%:t'),tab=vim.api.nvim_eval_statusline(vim.o.tabline,{use_tabline=true,maxwidth=160}).str})
end
'''.replace('BASE',json.dumps(str(base))))
m,s=pty.openpty();fcntl.ioctl(s,termios.TIOCSWINSZ,struct.pack('HHHH',45,160,0,0))
p=subprocess.Popen(['nvim','--listen',sock,'-i','NONE','+luafile '+str(script)],stdin=s,stdout=s,stderr=s,env={**os.environ,'TERM':'xterm-256color','NVIM_UNIVERSAL_TEST':'1'});os.close(s)
def pump(sec):
 end=time.monotonic()+sec
 while time.monotonic()<end:
  if select.select([m],[],[],.03)[0]:
   try:os.read(m,65536)
   except OSError:return
def rpc(expr):
 return subprocess.check_output(['nvim','--headless','-u','NONE','-i','NONE','--server',sock,'--remote-expr',expr],stderr=subprocess.STDOUT).decode().strip()
def lua(code):return rpc('luaeval('+json.dumps(code,ensure_ascii=False)+')')
def state():return json.loads(lua('_G.middle_state()'))
def click(x,y,button=1):
 os.write(m,f'\x1b[<{button};{x};{y}M\x1b[<{button};{x};{y}m'.encode());pump(.45)
def tabclick(name,button=1):
 st=state();prefix=st['tab'].split(name)[0];assert name in st['tab'],st
 x=int(lua('vim.fn.strdisplaywidth('+json.dumps(prefix,ensure_ascii=False)+')'))+2
 click(x,1,button)
try:
 pump(2);st=state()
 deadline=time.monotonic()+20
 while ('bravo.txt' not in st['rows']) and time.monotonic()<deadline:
  pump(.2);st=state()
 assert 'bravo.txt' in st['rows'],st
 row=st['rows']['bravo.txt'];click(**row);st=state()
 assert 'bravo.txt' not in st['bufs'] and st['current']=='alpha.txt',st
 print('PASS inactive Bufs pointed buffer close, editor retained')
 tabclick('charlie.txt');st=state();assert 'charlie.txt' not in st['bufs'] and st['current']=='alpha.txt',st
 print('PASS tabbar middle closes background buffer')
 tabclick('delta.txt',0);st=state();assert st['current']=='delta.txt',st
 print('PASS tabbar left click selects')
 lua("(function() vim.api.nvim_buf_set_lines(0,0,-1,false,{'unsaved'}); _G.confirm_count=0; vim.fn.confirm=function() _G.confirm_count=_G.confirm_count+1; return 3 end end)()")
 tabclick('delta.txt');st=state();assert st['bufs']['delta.txt']['modified'] and int(lua('_G.confirm_count'))==1,st
 print('PASS modified buffer Cancel retains edits')
 lua('(function() vim.fn.confirm=function() return 2 end end)()');tabclick('delta.txt');st=state();assert 'delta.txt' not in st['bufs'],st
 print('PASS modified buffer explicit Discard closes')
 lua('''(function()
  _G.panel_first=require('terminal_sessions').new()
  _G.panel_second=require('terminal_sessions').new()
  require('snacks').zen.zoom({zoom={win={height=0}}})
 end)()''');pump(.5)
 tabclick('alpha.txt',0);st=state();assert st['current']=='alpha.txt',st
 assert lua('vim.api.nvim_win_get_buf(panel_second.window)==panel_second.bufnr')=='true'
 print('PASS actual tabbar file click from terminal zoom keeps the terminal panel')
 lua('''(function()
  require('terminal_sessions').activate(panel_second)
 end)()''');pump(.5)
 def terminal_state():
  return json.loads(lua('''vim.json.encode({buf=vim.api.nvim_get_current_buf(),
    first=panel_first.bufnr,second=panel_second.bufnr,zoom=require('terminal_zoom').active(),
    x=vim.fn.getwininfo(vim.api.nvim_get_current_win())[1].wincol+2,
    y=vim.fn.screenpos(0,vim.fn.line('w0'),1).row-1,
    offset=vim.fn.strdisplaywidth(require('terminal_sessions').label(panel_first,true))+1,
    splits=#vim.tbl_filter(function(w)return vim.api.nvim_win_get_config(w).relative=='' end,vim.api.nvim_list_wins())})'''))
 st=terminal_state();click(st['x'],st['y'],0);after=terminal_state()
 assert after['buf']==st['first'] and not after['zoom'] and after['splits']==st['splits'],(st,after)
 click(after['x'],after['y'],0);again=terminal_state()
 assert again['buf']==st['first'] and again['splits']==st['splits'] and not again['zoom'],again
 click(again['x']+again['offset'],again['y'],0);after=terminal_state()
 assert after['buf']==st['second'] and not after['zoom'] and after['splits']==st['splits'],after
 print('PASS actual Winbar clicks switch/reselect sessions in one terminal panel')
finally:
 try:lua('vim.schedule(function() vim.cmd("qa!") end)')
 except Exception:pass
 pump(.2)
 if p.poll() is None:p.terminate()
 p.wait(timeout=5);os.close(m)
