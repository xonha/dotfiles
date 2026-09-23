-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

map("n", "<C-q>", "<cmd>qa<cr>", { noremap = true, silent = true })

-- Move line up/down. Overrides LazyVim's default <C-j>/<C-k> window navigation,
-- which we don't use; freed up because Alt+j/k are now captured by tmux for window switching.
map("n", "<C-j>", "<cmd>execute 'move .+' . v:count1<cr>==", { desc = "Move Down" })
map("n", "<C-k>", "<cmd>execute 'move .-' . (v:count1 + 1)<cr>==", { desc = "Move Up" })
map("i", "<C-j>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move Down" })
map("i", "<C-k>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move Up" })
map("v", "<C-j>", ":<C-u>execute \"'<,'>move '>+\" . v:count1<cr>gv=gv", { desc = "Move Down" })
map("v", "<C-k>", ":<C-u>execute \"'<,'>move '<-\" . (v:count1 + 1)<cr>gv=gv", { desc = "Move Up" })
map("n", "ç", "<cmd>Telescope buffers sort_mru=true sort_lastused=true<cr>", { noremap = true, silent = true })
map("i", "<S-Tab>", "<Tab>", { noremap = true, silent = true })
map("n", "<leader>ce", ":EditCodeBlock<CR>:LspRestart<CR>", { noremap = true, silent = true, desc = "Edit Code Block" })

map("n", "<leader>gd", function()
  Snacks.terminal.open({ "lazydocker" }, { win = { keys = { term_normal = false } } })
end, { desc = "Lazydocker" })

map("i", "jf", function()
  return vim.fn["codeium#Accept"]()
end, { expr = true, silent = true })

map("n", "q", function()
  if #vim.api.nvim_list_bufs() > 1 then
    vim.cmd("bd")
  else
    vim.cmd("qa") -- Quit all if it's the last buffer
  end
end, { noremap = true, silent = true, desc = "Close buffer or quit Neovim" })
