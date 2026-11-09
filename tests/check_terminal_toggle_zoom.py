"""Проверка переключения терминала и Termux auto-zoom настоящими клавишами."""
from pathlib import Path
import fcntl, json, os, pty, select, struct, subprocess, tempfile, termios, time

root = Path(__file__).resolve().parents[1]
scratch = Path(os.environ.get('TMPDIR', str(root / '.tmp')))
scratch.mkdir(parents=True, exist_ok=True)
base = Path(tempfile.mkdtemp(prefix='term-zoom-', dir=scratch))
sock = str(base / 'nvim.sock')
script = base / 'setup.lua'
script.write_text('''
vim.cmd.vnew()
_G.initial_layout=vim.inspect(vim.fn.winlayout())
vim.ui.select=function(items, _, callback) callback(items[_G.choose or 1]) end
_G.state=function()
 local zen=package.loaded['snacks.zen']
 local terms=package.loaded['toggleterm.terminal']
 local all=terms and terms.get_all() or {}
 local open, alive=0,0
 local detail={}
 for _,term in ipairs(all) do
  detail[#detail+1]={id=term.id,win=term.window,buf=term.bufnr,open=term:is_open(),hidden=term.hidden,number=vim.b[term.bufnr].toggle_number}
  if term:is_open() then open=open+1 end
  if term.job_id and vim.fn.jobwait({term.job_id},0)[1]==-1 then alive=alive+1 end
 end
 return vim.json.encode({zoom=zen and zen.win and zen.win:valid() or false,
   mode=vim.api.nvim_get_mode().mode,open=open,count=#all,alive=alive,detail=detail,err=vim.v.errmsg,
   current=vim.api.nvim_get_current_win(),buf=vim.api.nvim_get_current_buf(),buftype=vim.bo.buftype,
   zoomwin=zen and zen.win and zen.win.win,zoombuf=zen and zen.win and zen.win.buf,
   layout=vim.inspect(vim.fn.winlayout()),initial=initial_layout})
end
''')
master, slave = pty.openpty()
fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 42, 120, 0, 0))
process = subprocess.Popen(['nvim', '-i', 'NONE', '--listen', sock, '+luafile ' + str(script)],
                           stdin=slave, stdout=slave, stderr=slave,
                           env={**os.environ, 'TERM': 'xterm-256color', 'NVIM_UNIVERSAL_TEST': '1'})
os.close(slave)

def pump(seconds=.25):
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        if select.select([master], [], [], .02)[0]:
            try: os.read(master, 65536)
            except OSError: return

def lua(code):
    return subprocess.check_output(['nvim', '--headless', '-u', 'NONE', '-i', 'NONE', '--server', sock,
                                    '--remote-expr', 'luaeval(' + json.dumps(code) + ')'],
                                   stderr=subprocess.STDOUT, timeout=10).decode().strip()

def state(): return json.loads(lua('_G.state()'))
def key(data): os.write(master, data); pump(.4)
def opened(zoom, normal=False):
    value = state()
    assert value['zoom'] == zoom and value['open'] == 1 and (value['mode'] in ('n','nt') if normal else value['mode']=='t'), value
    return value

def closed():
    value = state()
    assert not value['zoom'] and value['open'] == 0 and value['layout'] == value['initial'], value

try:
    pump(1.5)
    termux = lua('require("user_platform").mobile') == 'true'
    assert lua('vim.fn.maparg("<Space>t","n")') == ''
    assert lua('vim.fn.maparg("<Space>tt","n") ~= ""') == 'true'
    assert lua('vim.fn.maparg("<Space>Tf","n") ~= ""') == 'true'
    key(b' tt'); opened(termux)
    for _ in range(3):
        key(b'\x1b[18~'); closed()
        key(b'\x1b[18~'); value=opened(termux)
        assert value['count'] == 1 and value['alive'] == 1, value
    print('PASS Space tt opens; F7 hides/reopens, restores layout and preserves one session')
    key(b'\x1b[1;6D'); key(b' tt'); closed()
    key(b' tt'); opened(termux, normal=not termux)
    if not termux: key(b'i')
    print('PASS Space tt also hides from terminal Normal mode')
    if termux:
        key(b'\x1b[1;6A'); opened(False)
        key(b'\x1b[18~'); closed()
        key(b'\x1b[18~'); opened(True)
        print('PASS manual unzoom works; reopening zooms again')
    lua('(function() _G.choose=2; vim.ui.select=function(items,_,callback) callback(items[_G.choose or 1]) end; require("toggleterm.terminal").Terminal:new({direction="horizontal",cmd="cat"}):spawn() end)()')
    key(b'\x1b[19~'); value=opened(termux)
    assert value['count']==2 and value['alive']==2, value
    key(b'\x1b[19~'); opened(termux)
    key(b'\x1b[18~'); closed()
    key(b'\x1b[18~'); value=opened(termux)
    assert value['count']==2 and value['open']==1, value
    print('PASS F8 switches/reselects with zoom and without extra splits or sessions')
    for sequence, expected in ((b' 1',1),(b' t]',2),(b' t]',1),(b' t[',2),(b' tT',2)):
        key(b'\x1b[1;6D'+sequence)
        try:value=opened(termux)
        except AssertionError as error:raise AssertionError(repr(sequence)+': '+str(error)) from error
        target=next(term for term in value['detail'] if term['id']==expected)
        assert value['buf']==target['buf'] and value['count']==2,value
    print('PASS Space 1, t[/t] cycle, tT menu alias with real keys')
    for suffix, count, opened_count in ((b'h',3,2),(b'v',4,3),(b'n',5,3)):
        key(b'\x1b[1;6D t'+suffix)
        value=state()
        assert value['count']==count and value['open']==opened_count and value['alive']==count,value
    key(b'\x1b[1;6D tc');value=state()
    assert value['count']==4 and value['open']==3 and value['alive']==4,value
    key(b'\x1b[1;6D tC');value=opened(termux,normal=True)
    assert value['count']==1 and value['alive']==1,value
    key(b'\x1b[1;6D tq');closed();value=state()
    assert value['count']==0 and value['alive']==0,value
    print('PASS Space th/tv/tn/tc/tC/tq with real key input; all editor windows retained')
    print('PASS profile:', 'mobile auto-zoom' if termux else 'Linux split unchanged')
finally:
    try: lua('vim.schedule(function() vim.cmd("qa!") end)')
    except Exception: pass
    pump()
    if process.poll() is None: process.terminate()
    process.wait(timeout=5)
    os.close(master)
