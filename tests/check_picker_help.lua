-- nvim --headless -u NONE -i NONE -l tests/check_picker_help.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.opt.rtp:append(vim.fn.stdpath "data" .. "/lazy/snacks.nvim")
vim.o.lines, vim.o.columns = 45, 140
local spec = dofile "lua/plugins/snacks.lua"
local opts = { filter = function(mapping) return mapping.desc ~= "prior filter" end }
dofile("lua/plugins/which-key.lua").opts(nil, opts)
assert(opts.filter { lhs = "x", desc = "English" })
assert(not opts.filter { lhs = "д" })
assert(not opts.filter { lhs = "x", desc = "ASCII LM (translated)" })
assert(not opts.filter { lhs = "x", desc = "prior filter" }, "previous which-key filter lost")
require("snacks").setup(spec.opts)
local picker = Snacks.picker { items = { { text = "example" } }, show_delay = 0 }
assert(vim.wait(1000, function() return picker.list.win:valid() and picker.input.win:valid() end, 10))
local function help_window()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "snacks_win_help" then return win end
  end
end
for _, part in ipairs { "input", "list" } do
  local buf = picker[part].win.buf
  vim.keymap.set("n", "<F6>", function() end, { buffer = buf, desc = "English shortcut" })
  vim.keymap.set("n", "д", function() end, { buffer = buf, desc = "Russian duplicate" })
  vim.keymap.set("n", "<F7>", function() end, { buffer = buf, desc = "ASCII duplicate LM (translated)" })
  local before = vim.api.nvim_buf_get_keymap(buf, "n")
  picker:action("toggle_help_" .. part)
  local win = assert(help_window(), "help did not open")
  local text = {}
  for _, mark in
    ipairs(
      vim.api.nvim_buf_get_extmarks(
        vim.api.nvim_win_get_buf(win),
        vim.api.nvim_create_namespace "user.keymap_help",
        0,
        -1,
        { details = true }
      )
    )
  do
    for _, chunk in ipairs(mark[4].virt_text or {}) do
      text[#text + 1] = chunk[1]
    end
  end
  text = table.concat(text)
  assert(text:find("English shortcut", 1, true), "English mapping hidden")
  assert(text:find("toggle_hidden", 1, true), "native actions hidden")
  assert(vim.fn.match(text, "[А-Яа-яЁё]") == -1 and not text:find("LM (", 1, true), "duplicates visible")
  assert(vim.deep_equal(before, vim.api.nvim_buf_get_keymap(buf, "n")), "source mappings changed")
  picker:action("toggle_help_" .. part)
  assert(not help_window(), "help did not toggle closed")
end
picker:action "toggle_help_input"
picker:close()
assert(vim.wait(500, function() return not help_window() end, 10), "help survived picker close")
print "PASS: actual picker input/list help, English actions retained, Russian/LM duplicates hidden, maps unchanged, close lifecycle"
