return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "mocha",
      color_overrides = {
        mocha = {
          base = "#0f0f0f",
          crust = "#0f0f0f",
          mantle = "#0f0f0f",
          surface0 = "#1c1c1c",
          surface1 = "#232323",
          surface2 = "#2a2a2a",
          overlay0 = "#3f3f3f",
          overlay1 = "#4f4f4f",
          overlay2 = "#5f5f5f",
        },
      },
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
