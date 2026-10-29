---@type LazySpec
return {
  "AstroNvim/astrocore",
  opts = function(_, opts)
    -- Ctrl+J совпадает с переводом строки: оставляем его терминальному приложению.
    for _, mode in ipairs { "n", "t" } do
      local maps = opts.mappings[mode]
      for _, key in ipairs { "H", "J", "K", "L" } do
        maps["<C-S-" .. key .. ">"] = maps["<C-" .. key .. ">"]
        maps["<C-" .. key .. ">"] = false
      end
    end
  end,
}
