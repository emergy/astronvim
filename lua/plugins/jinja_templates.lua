return {
  {
    "AstroNvim/astrocore",
    opts = {
      filetypes = {
        pattern = {
          [".*%.ya?ml%.j2"] = "yaml.jinja2",
          [".*%.hcl%.j2"] = "hcl.jinja2",
        },
      },
    },
  },
  {
    "pearofducks/ansible-vim",
    ft = { "yaml.ansible", "jinja2", "yaml.jinja2", "hcl.jinja2" },
    init = function()
      -- Детектор ansible-vim запускается также при повторном чтении файла.
      vim.g.ansible_template_syntaxes = vim.tbl_extend(
        "force",
        vim.g.ansible_template_syntaxes or {},
        { [".*\\.ya?ml\\.j2$"] = "yaml", [".*\\.hcl\\.j2$"] = "hcl" }
      )
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.highlight = opts.highlight or {}
      local previous = opts.highlight.disable
      -- Парсеры базовых языков не понимают управляющие блоки Jinja.
      -- Здесь используем составной Vim syntax базового языка и Jinja.
      opts.highlight.disable = function(lang, buf)
        local ft = vim.bo[buf].filetype
        if ft == "yaml.jinja2" or ft == "hcl.jinja2" then return true end
        if type(previous) == "function" then return previous(lang, buf) end
        return previous == true or (type(previous) == "table" and vim.tbl_contains(previous, lang)) or false
      end
    end,
  },
}
