return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    opts = {
      flavour = "mocha",
      color_overrides = {
        mocha = {
          base = "#151515",
          crust = "#0f0f0f",
          mantle = "#121212",
          overlay0 = "#3f3f3f",
          overlay1 = "#4f4f4f",
          overlay2 = "#5f5f5f",
          surface0 = "#1c1c1c",
          surface1 = "#232323",
          surface2 = "#2a2a2a",
        },
      },
      custom_highlights = {
        Normal = { bg = "#0f0f0f" },
        NormalNC = { bg = "#0f0f0f" },
        NeoTreeEndOfBuffer = { bg = "#121212" },
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-mocha",
    },
  },
}
