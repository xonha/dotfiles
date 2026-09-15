-- BEGIN hyprmoncfg wake settings
-- Shared with Omarchy while hyprmoncfg manages displays.
hl.monitor({ output = "eDP-1", mode = "preferred", position = "-1x-1", scale = 1 })
-- END hyprmoncfg wake settings
local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })
