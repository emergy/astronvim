---@type LazySpec
return {
  "rebelot/heirline.nvim",
  opts = function(_, opts)
    -- AstroUI создаёт элементы буферов во время init, поэтому меняем их до рендера.
    local buffers = opts.tabline[2]
    local init = buffers.init
    buffers.init = function(self)
      init(self)
      require("buffer_mouse").patch_tabline(self)
    end
  end,
}
