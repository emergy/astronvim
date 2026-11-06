local M = {}

function M.attach(buf)
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "terminal" then return end
  local function map(mode, key, action, desc)
    vim.keymap.set(mode, key, action, { buffer = buf, silent = true, desc = desc })
  end
  map("t", "<C-S-Left>", [[<C-\><C-n>]], "Перейти из терминального ввода в Normal mode")
  map("n", "<C-S-Left>", "<Nop>", "Оставаться в Normal mode терминала")
  map({ "n", "t" }, "<C-S-Right>", "<Cmd>startinsert<CR>", "Вернуться к вводу в терминал")
  map(
    "n",
    "<C-S-Down>",
    function() require("hop").hint_lines { multi_windows = false } end,
    "Выбрать строку по метке"
  )
  map(
    "t",
    "<C-S-Down>",
    [[<C-\><C-n><Cmd>lua require("hop").hint_lines({multi_windows=false})<CR>]],
    "Выбрать строку по метке"
  )
end

function M.setup()
  local group = vim.api.nvim_create_augroup("TerminalHistoryKeys", { clear = true })
  vim.api.nvim_create_autocmd("TermOpen", {
    group = group,
    callback = function(args) M.attach(args.buf) end,
  })
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    M.attach(buf)
  end
end

return M
