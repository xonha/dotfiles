return {
  "nvim-telescope/telescope.nvim",
  opts = {
    pickers = {
      find_files = { hidden = true },
      buffers = {
        initial_mode = "normal",
        mappings = {
          n = {
            ["d"] = "delete_buffer",
            ["h"] = "delete_buffer",
            ["l"] = "select_default",
          },
        },
      },
    },
  },
}
