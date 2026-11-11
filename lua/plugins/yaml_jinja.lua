return {
  {
    "AstroNvim/astrocore",
    opts = {
      filetypes = { pattern = { [".*%.ya?ml%.j2"] = "yaml.jinja2" } },
    },
  },
  {
    "pearofducks/ansible-vim",
    ft = { "yaml.ansible", "jinja2", "yaml.jinja2" },
    init = function()
      -- Детектор ansible-vim запускается также при повторном чтении файла.
      vim.g.ansible_template_syntaxes = vim.tbl_extend(
        "force",
        vim.g.ansible_template_syntaxes or {},
        { [".*\\.ya?ml\\.j2$"] = "yaml" }
      )
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.highlight = opts.highlight or {}
      local previous = opts.highlight.disable
      -- YAML-парсер не понимает управляющие блоки Jinja. Здесь используем
      -- составной Vim syntax: YAML вместе с уже установленным Jinja syntax.
      opts.highlight.disable = function(lang, buf)
        if vim.bo[buf].filetype == "yaml.jinja2" then return true end
        if type(previous) == "function" then return previous(lang, buf) end
        return previous == true or (type(previous) == "table" and vim.tbl_contains(previous, lang)) or false
      end
    end,
  },
}
