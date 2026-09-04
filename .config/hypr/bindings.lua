-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Terminal shortcut from the previous setup, adapted to Omarchy's Foot.
hl.unbind("SUPER + V")
o.bind("SUPER + V", "Foot + tmux", { launch = "foot -e tmux new-session -A -s main", focus = "^(foot|org\\.codeberg\\.dnkl\\.foot)$" })

-- Move Omarchy's fullscreen shortcut to SUPER+SHIFT+F and restore the old
-- SUPER+F launcher, using the Brave Origin class installed on this system.
hl.unbind("SUPER + F")
hl.unbind("SUPER + SHIFT + F")
o.bind("SUPER + F", "Brave Origin", { launch = "brave-origin", focus = "^brave-origin$" })
o.bind("SUPER + SHIFT + F", "Full screen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))

-- Restore the old close-window shortcut.
hl.unbind("SUPER + Q")
o.bind("SUPER + Q", "Close window", hl.dsp.window.close())

-- Replace Omarchy's default SUPER+W (close window, now on SUPER+Q above)
-- with the old WhatsApp shortcut.
hl.unbind("SUPER + W")
o.bind("SUPER + W", "WhatsApp", { webapp = "https://web.whatsapp.com/", focus = true })

-- Other old bindings whose keys are not used by Omarchy. Use its native
-- launch-or-focus helper instead of the legacy focus.sh wrapper.

local brave_flags = "--max-unused-resource-memory-usage-mb=128 --disk-cache-size=67108864"
local function brave_app(id)
  return ("brave --profile-directory=Default --app-id=%s %s"):format(id, brave_flags)
end
local function brave_profile(profile)
  return ("brave --profile-directory=brave-%s --class=brave-%s --user-data-dir=.brave-%s %s"):format(profile, profile, profile, brave_flags)
end

o.bind("SUPER + E", "Todoist", { launch = brave_app("dlgohinmglaoopaiplliaecdpmnepmga"), focus = "^brave-dlgohinmglaoopaiplliaecdpmnepmga-Default$" })
o.bind("SUPER + R", "YouTube Music", { launch = brave_app("cinhimbnkkaeohfgghhklpknlkffjgod"), focus = "^brave-cinhimbnkkaeohfgghhklpknlkffjgod-Default$" })
o.bind("SUPER + D", "Mais Todos", { launch = brave_profile("maistodos"), focus = "^brave-maistodos$" })
o.bind("SUPER + A", "Editor", { launch = "code", focus = "^code$" })

o.bind("SUPER + B", "Move window to empty workspace", hl.dsp.window.move({ workspace = "empty" }))
o.bind("SUPER + H", "Focus left", hl.dsp.focus({ direction = "l" }))
o.bind("SUPER + ALT + H", "Move window left", hl.dsp.window.move({ direction = "l" }))
o.bind("SUPER + ALT + L", "Move window right", hl.dsp.window.move({ direction = "r" }))
o.bind("SUPER + SHIFT + H", "Resize left", hl.dsp.window.resize({ x = -20, y = 0, relative = true }))
o.bind("SUPER + SHIFT + L", "Resize right", hl.dsp.window.resize({ x = 20, y = 0, relative = true }))
o.bind("SUPER + ALT + B", "Toggle simulated fullscreen", hl.dsp.window.fullscreen_state({ internal = 0, client = 2 }))
o.bind("SUPER + SHIFT + T", "Reload Hyprland", "hyprctl reload")

o.bind("SUPER + U", "Calculator", "omacalc")
o.bind("SUPER + I", "Phone Operate", "omarchy-menu toggle")
o.bind("SUPER + Y", "Close active window", "hyprctl kill")
o.bind("SUPER + N", "Toggle noise reduction", "~/.config/scripts/denoise.sh toggle")
o.bind("SUPER + M", "Phone Operate", "omarchy-menu toggle")
o.bind("SUPER + Z", "Screenshot region", "omarchy capture screenshot region")
o.bind("SUPER + ALT + C", "Control center", "omarchy-menu toggle system")
o.bind("SUPER + ALT + Z", "Settings", "omarchy-menu toggle")
o.bind("SUPER + DELETE", "Apps menu", "omarchy-menu toggle apps")

-- Replace Omarchy's terminal shortcut with the root menu.
hl.unbind("SUPER + RETURN")
o.bind("SUPER + RETURN", "Omarchy menu", "omarchy-menu toggle root")

-- Move the theme menu from Omarchy's default SUPER+SHIFT+CTRL+SPACE shortcut.
hl.unbind("SUPER + SHIFT + CTRL + SPACE")
o.bind("SUPER + SHIFT + K", "Theme menu", "omarchy-menu toggle theme")

-- Keyd-generated function keys from the old setup (not used by Omarchy).
o.bind("code:194", "Previous track", "playerctl previous")
o.bind("code:195", "Play/pause", "playerctl play-pause")
o.bind("code:196", "Next track", "playerctl next")
o.bind("SUPER + code:47", "Lock screen", "omarchy system lock")
o.bind("SUPER + code:61", "Toggle key remapping", "~/.config/scripts/keyd.sh --toggle")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")
