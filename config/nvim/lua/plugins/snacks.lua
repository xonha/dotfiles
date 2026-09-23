return {
  "folke/snacks.nvim",
  opts = {
    notifier = {
      top_down = false
    },
    picker = {
      sources = {
        -- mostra dotfiles por padrao (<a-h> alterna, <a-i> alterna gitignored)
        files = { hidden = true },
        smart = { hidden = true },
        grep = { hidden = true },
        grep_word = { hidden = true },
        explorer = { hidden = true },
      },
    },
  }
}
