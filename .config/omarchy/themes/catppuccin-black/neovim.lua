return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      custom_highlights = {
        Normal = { bg = "#0f0f0f" },
        NormalNC = { bg = "#0f0f0f" },
        SignColumn = { bg = "#0f0f0f" },
        EndOfBuffer = { bg = "#0f0f0f" },
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-nvim",
    },
  },
}
