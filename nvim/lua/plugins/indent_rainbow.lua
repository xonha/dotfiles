return {
  "lukas-reineke/indent-blankline.nvim",
  main = "ibl",
  commit = "29be0919b91fb59eca9e90690d76014233392bef",
  dependencies = {
    "TheGLander/indent-rainbowline.nvim",
  },
  opts = function(_, opts)
    -- Other blankline configuration here
    return require("indent-rainbowline").make_opts(opts)
  end,
}
