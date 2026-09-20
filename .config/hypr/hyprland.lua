dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

require("default.hypr.omarchy")

require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

require("default.hypr.toggles")

-- Brave webapps (bindings.lua: WhatsApp, Todoist, YouTube Music, Mais Todos)
-- always open on an empty workspace on the left monitor. Excludes
-- the bare Brave Origin browser itself (class "brave-origin"), handled below.
o.window("^brave-(origin-.+|.+-Default)$", {
  monitor = "desc:Shenzhen KTC Technology Group SFPCCB24180 000000000000",
  workspace = "emptym",
})

-- The bare Brave Origin browser (SUPER+F) always opens on the right monitor.
o.window("^brave-origin$", {
  monitor = "desc:SUE SFP2412FHD 000000000000",
  workspace = "empty",
})

-- Disable Omarchy's default window transparency (see default/hypr/windows.lua).
o.window(".*", { tag = "-default-opacity", opacity = "1 1" })

-- Added by hyprmoncfg: its generated monitor rules load last, so nothing before this can override the applied layout.
do local path = os.getenv("HOME") .. "/.config/hypr/hyprmoncfg-monitors.lua"; local file = io.open(path, "r"); if file then file:close(); dofile(path) end end
