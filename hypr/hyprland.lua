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

local function monitor_connected(description)
  for _, monitor in ipairs(hl.get_monitors()) do
    if monitor.description == description then return true end
  end
  return false
end

-- Keep the former multi-monitor routing only while those outputs are connected.
-- On the Samsung, shortcut-managed apps stay on the visible tiled workspace.
local left_monitor = "Shenzhen KTC Technology Group SFPCCB24180 000000000000"
if monitor_connected(left_monitor) then
  o.window("^(brave-(origin-.+|.+-Default)|google-chrome(-maistodos)?|microsoft-edge-devbot)$", {
    monitor = "desc:" .. left_monitor,
    workspace = "emptym",
  })
end

local right_monitor = "SUE SFP2412FHD 000000000000"
if monitor_connected(right_monitor) then
  o.window("^brave-origin$", {
    monitor = "desc:" .. right_monitor,
    workspace = "empty",
  })
end

-- Disable Omarchy's default window transparency (see default/hypr/windows.lua).
o.window(".*", { tag = "-default-opacity", opacity = "1 1" })

-- Added by hyprmoncfg: its generated monitor rules load last, so nothing before this can override the applied layout.
do local path = (os.getenv("XDG_CONFIG_HOME") or os.getenv("HOME") .. "/.config") .. "/hypr/hyprmoncfg-monitors.lua"; local file = io.open(path, "r"); if file then file:close(); dofile(path) end end
