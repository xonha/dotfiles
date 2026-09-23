local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

ls.add_snippets("javascript", {
  s("dfn", {
    t({ "/**@returns {" }),
    i(3, "return"),
    t({ "}", " */function " }),
    i(1, "name"),
    t({ "(" }),
    i(2, "params"),
    t({ ") {", "  " }),
    i(4, "// code here"),
    t({ "", "}" }),
  }),
})
