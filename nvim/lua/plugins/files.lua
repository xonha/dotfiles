return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    window = { position = "right" },
    filesystem = {
      -- dotfiles visiveis (em cinza) por padrao; H alterna
      filtered_items = { visible = true },
    },
    sort_function = function(a, b)
      if a.type ~= b.type then
        return a.type < b.type
      end
      local name_a = a.path:match("[^/]+$") or a.path
      local name_b = b.path:match("[^/]+$") or b.path
      local ext_a = name_a:match("%.([^%.]+)$") or ""
      local ext_b = name_b:match("%.([^%.]+)$") or ""
      if ext_a ~= ext_b then
        return ext_a < ext_b
      end
      return name_a < name_b
    end,
    sort_case_insensitive = true,
  },
}
