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
  return ("brave-origin --profile-directory=Default --app-id=%s %s"):format(id, brave_flags)
end
local function brave_profile(profile)
  return ("brave-origin --profile-directory=brave-origin-%s --class=brave-origin-%s --user-data-dir=.brave-origin-%s %s"):format(profile, profile, profile, brave_flags)
end

-- Replace Omarchy's default SUPER+G (window grouping) with the old file
-- explorer shortcut, using Omarchy's native Nautilus launcher.
hl.unbind("SUPER + G")
o.bind("SUPER + G", "Files", { launch = "omarchy-launch-nautilus", focus = "^org\\.gnome\\.Nautilus$" })

-- Note: brave-origin's --app-id mode ignores --class and always reports a
-- bare "brave-<app-id>-<profile>" window class, even on this brave-origin
-- binary. Verified by launching each app and checking `hyprctl clients`.
o.bind("SUPER + E", "Todoist", { launch = brave_app("dlgohinmglaoopaiplliaecdpmnepmga"), focus = "^brave-dlgohinmglaoopaiplliaecdpmnepmga-Default$" })
o.bind("SUPER + R", "YouTube Music", { launch = brave_app("cinhimbnkkaeohfgghhklpknlkffjgod"), focus = "^brave-cinhimbnkkaeohfgghhklpknlkffjgod-Default$" })
o.bind("SUPER + D", "Mais Todos", { launch = brave_profile("maistodos"), focus = "^brave-origin-maistodos$" })
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
o.bind("SUPER + DELETE", "Omarchy menu", "omarchy-menu toggle root")

-- Replace Omarchy's terminal shortcut with the apps menu.
hl.unbind("SUPER + RETURN")
o.bind("SUPER + RETURN", "Apps menu", "omarchy-menu toggle apps")

-- Move the theme menu from Omarchy's default SUPER+SHIFT+CTRL+SPACE shortcut.
hl.unbind("SUPER + SHIFT + CTRL + SPACE")
o.bind("SUPER + SHIFT + K", "Theme menu", "omarchy-menu toggle theme")

-- Keyd-generated function keys from the old setup (not used by Omarchy).
o.bind("code:194", "Previous track", "playerctl previous")
o.bind("code:195", "Play/pause", "playerctl play-pause")
o.bind("code:196", "Next track", "playerctl next")
o.bind("SUPER + code:47", "Lock screen", "omarchy system lock")
o.bind("SUPER + code:61", "Toggle key remapping", "~/.config/scripts/keyd.sh --toggle")

-- Restore the old Devbot / SSH shortcuts (workspace vazio), reusing the
-- legacy focus.sh helper which still supports the "emptyn" launch mode.
hl.unbind("SUPER + S")
o.bind("SUPER + S", "Devbot", { launch = brave_profile("devbot"), focus = "^brave-origin-devbot$" })

hl.unbind("SUPER + X")
o.bind("SUPER + X", "Devbot SSH (workspace vazio)", "~/.config/scripts/focus.sh \"kitty --class kitty-devbot-ssh -e ssh devbot -t 'tmux new-session -A -s main'\" kitty-devbot-ssh emptyn")

hl.unbind("SUPER + C")
o.bind("SUPER + C", "Mais Todos SSH (workspace vazio)", "~/.config/scripts/focus.sh \"kitty --class kitty-maistodos-ssh -e ssh maistodos -t 'tmux new-session -A -s main'\" kitty-maistodos-ssh emptyn")

-- Move Omarchy's universal clipboard shortcuts off C/V (reused above, and by
-- the terminal shortcut earlier in this file) onto SUPER+SHIFT+C/V. This
-- reimplements the logic from default/hypr/bindings/clipboard.lua, since its
-- helpers are local to that file. Note: overrides the default SUPER+SHIFT+C
-- "Calendar" webapp shortcut.
local function send_shortcut_once(mods, key)
  return function()
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))

    hl.timer(function()
      hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
    end, { timeout = 50, type = "oneshot" })
  end
end

local function active_window_is_terminal()
  local window = hl.get_active_window()
  if not window then
    return false
  end

  for _, tag in ipairs(window.tags or {}) do
    if tag:gsub("%*$", "") == "terminal" then
      return true
    end
  end

  return false
end

local function universal_clipboard_shortcut(default_mods, default_key, terminal_mods, terminal_key)
  return function()
    if active_window_is_terminal() then
      send_shortcut_once(terminal_mods, terminal_key)()
    else
      send_shortcut_once(default_mods, default_key)()
    end
  end
end

hl.unbind("SUPER + SHIFT + C")
o.bind("SUPER + SHIFT + C", "Universal copy", universal_clipboard_shortcut("CTRL", "C", "CTRL", "Insert"))
o.bind("SUPER + SHIFT + V", "Universal paste", universal_clipboard_shortcut("CTRL", "V", "SHIFT", "Insert"))

-- Old session menu, color picker and mic mute shortcuts.
hl.unbind("SUPER + BACKSPACE")
o.bind("SUPER + BACKSPACE", "Menu de sessão", "omarchy-menu toggle system")

hl.unbind("SUPER + P")
o.bind("SUPER + P", "Selecionar cor da tela", "hyprpicker --autocopy --notify")

hl.unbind("SUPER + T")
o.bind("SUPER + T", "Ativar/silenciar microfone", "~/.config/scripts/mic-mute.sh")

-- Emergency recovery for the internal display, kept from the old setup.
hl.unbind("SUPER + SHIFT + M")
o.bind("SUPER + SHIFT + M", "Reativar tela interna", [[hyprctl eval 'hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1, disabled = false })']])

-- Float then center the window on the same keypress, like the old setup.
hl.unbind("SUPER + SHIFT + B")
o.bind("SUPER + SHIFT + B", "Toggle window floating", hl.dsp.window.float())
o.bind("SUPER + SHIFT + B", "Center window", hl.dsp.window.center())

hl.unbind("SUPER + SHIFT + RETURN")
o.bind("SUPER + SHIFT + RETURN", "Toggle fullscreen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))

hl.unbind("SUPER + L")
o.bind("SUPER + L", "Focus right", hl.dsp.focus({ direction = "r" }))

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
