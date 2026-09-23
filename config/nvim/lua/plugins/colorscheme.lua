local omarchy_theme = vim.fn.expand("~/.local/state/omarchy/current/theme/neovim.lua")

if vim.fn.filereadable(omarchy_theme) == 1 then
  local ok, spec = pcall(dofile, omarchy_theme)
  if ok and type(spec) == "table" then
    return spec
  end
end

-- Fallback for sessions where Omarchy has not generated a Neovim theme yet.
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
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-mocha",
    },
  },
}
