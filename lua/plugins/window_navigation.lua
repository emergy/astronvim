---@type LazySpec
return {
  "AstroNvim/astrocore",
  opts = function(_, opts)
    -- Ctrl+J совпадает с переводом строки: оставляем его терминальному приложению.
    for _, mode in ipairs { "n", "t" } do
      local maps = opts.mappings[mode]
      for key, arrow in pairs { H = "Left", J = "Down", K = "Up", L = "Right" } do
        maps["<C-S-" .. key .. ">"] = maps["<C-" .. key .. ">"]
        maps["<M-" .. arrow .. ">"] = maps["<C-" .. key .. ">"]
        maps["<C-" .. key .. ">"] = false
      end
    end
    opts.mappings.t["<C-Space>"] = {
      [[<C-\><C-N>]],
      desc = "Перейти из терминального ввода в Normal mode",
    }
    opts.mappings.t["<C-K>"] = {
      function() require("terminal_history").clear() end,
      desc = "Очистить историю терминала",
    }
  end,
}
