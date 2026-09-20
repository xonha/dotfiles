return {
  {
    "3rd/image.nvim",
    build = false,
    opts = {
      backend = "sixel",
      processor = "magick_cli",

      integrations = {
        markdown = {
          enabled = true,
          only_render_image_at_cursor = false,
        },
        neorg = {
          enabled = true,
        },
      },

      -- Use the full editor viewport and let ImageMagick downscale oversized images.
      max_height_window_percentage = 100,
      max_width_window_percentage = 100,
      hijack_file_patterns = {
        "*.png",
        "*.jpg",
        "*.jpeg",
        "*.gif",
        "*.webp",
      },
    },
  },
}
