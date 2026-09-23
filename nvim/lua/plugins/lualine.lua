return {
  "nvim-lualine/lualine.nvim",
  opts = function(_, opts)
    local palette = require("catppuccin.palettes").get_palette()
    local theme = require("catppuccin.utils.lualine")()

    local mode_colors = {
      normal = palette.green,
      insert = palette.yellow,
      visual = palette.sky,
      replace = palette.pink,
      command = palette.text,
      terminal = palette.text,
    }

    for mode, color in pairs(mode_colors) do
      theme[mode].a.bg = color
      theme[mode].a.fg = palette.base
      theme[mode].b.fg = color
    end

    theme.inactive.a.fg = palette.text
    opts.options.theme = theme
  end,
}
