---@type LazySpec
return {
  "folke/which-key.nvim",
  opts = function(_, opts)
    local previous = opts.filter
    opts.filter = function(mapping)
      if previous and not previous(mapping) then return false end
      -- Скрываем русские дубликаты и служебные привязки langmapper только в справке.
      return vim.fn.match(mapping.lhs or "", "[А-Яа-яЁё]") == -1
        and not (mapping.desc or ""):find("LM (", 1, true)
    end
  end,
}
