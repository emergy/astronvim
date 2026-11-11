return {
  {
    "zbirenbaum/copilot.lua",
    -- Insert-mode исключён из langmapper: русские дубли направляем в штатные карты.
    keys = {
      { "<M-л>", "<M-k>", mode = "i", remap = true, desc = "Copilot: принять подсказку" },
      { "<M-д>", "<M-l>", mode = "i", remap = true, desc = "Copilot: принять слово" },
    },
  },
}
