-- App shortcuts
local four_zones = require("hypr.four_zones")
local brave_flags = "--max-unused-resource-memory-usage-mb=128 --disk-cache-size=67108864"
local function brave_app(id)
  return ("brave-origin --profile-directory=Default --app-id=%s %s"):format(id, brave_flags)
end
local function browser_profile(browser, class_name)
  return ("%s --profile-directory=Default --class=%s"):format(browser, class_name)
end
local function match_classes(...)
  local classes = {}
  for _, class in ipairs({ ... }) do classes[class] = true end
  return function(window) return classes[window.class] == true end
end
local function grid_app(classes, command, default_zone)
  return function()
    four_zones.launch_or_focus(classes, o.launch(command), default_zone)
  end
end
hl.unbind("SUPER + V")
hl.unbind("SUPER + F")
hl.unbind("SUPER + Q")
hl.unbind("SUPER + W")
hl.unbind("SUPER + G")
hl.unbind("SUPER + S")
o.bind("SUPER + V", "Foot + tmux",
  grid_app(match_classes("foot-local"), "foot --app-id=foot-local -e tmux new-session -A -s main"))
o.bind("SUPER + F", "Brave Origin", grid_app(match_classes("brave-origin"), "brave-origin"))
o.bind("SUPER + Q", "Close window", hl.dsp.window.close())
o.bind("SUPER + W", "WhatsApp",
  grid_app(match_classes("brave-web.whatsapp.com__-Default"),
    "brave-origin --profile-directory=Default --app=https://web.whatsapp.com/"))
o.bind("SUPER + G", "Files", grid_app(match_classes("org.gnome.Nautilus"), "omarchy-launch-nautilus"))
o.bind("SUPER + E", "Todoist",
  grid_app(match_classes("brave-dlgohinmglaoopaiplliaecdpmnepmga-Default"), brave_app("dlgohinmglaoopaiplliaecdpmnepmga")))
o.bind("SUPER + R", "YouTube Music",
  grid_app(match_classes("brave-cinhimbnkkaeohfgghhklpknlkffjgod-Default"), brave_app("cinhimbnkkaeohfgghhklpknlkffjgod"), 3))
o.bind("SUPER + D", "Mais Todos",
  grid_app(match_classes("google-chrome-maistodos", "google-chrome"),
    browser_profile("google-chrome-stable", "google-chrome-maistodos")))
o.bind("SUPER + S", "Devbot",
  grid_app(match_classes("microsoft-edge-devbot"), browser_profile("microsoft-edge-stable", "microsoft-edge-devbot")))
o.bind("SUPER + A", "Editor", grid_app(match_classes("code"), "code"))
-- Windows
o.bind("SUPER + B", "Move window to empty workspace", hl.dsp.window.move({ workspace = "empty" }))
o.bind("SUPER + H", "Focus left", hl.dsp.focus({ direction = "l" }))
o.bind("SUPER + ALT + H", "Move window left", hl.dsp.window.move({ direction = "l" }))
o.bind("SUPER + ALT + L", "Move window right", hl.dsp.window.move({ direction = "r" }))
o.bind("SUPER + SHIFT + H", "Resize left", hl.dsp.window.resize({ x = -20, y = 0, relative = true }))
o.bind("SUPER + SHIFT + L", "Resize right", hl.dsp.window.resize({ x = 20, y = 0, relative = true }))
o.bind("SUPER + ALT + B", "Toggle simulated fullscreen", hl.dsp.window.fullscreen_state({ internal = 0, client = 2 }))
-- Omarchy menus
hl.unbind("SUPER + RETURN")
hl.unbind("SUPER + SHIFT + CTRL + SPACE")
hl.unbind("SUPER + SHIFT + K")
hl.unbind("SUPER + SHIFT + ALT + SPACE")
o.bind("SUPER + U", "Calculator", "omacalc")
o.bind("SUPER + I", "Phone Operate", "omarchy-menu toggle")
hl.unbind("SUPER + Y")
hl.unbind("SUPER + H")
hl.unbind("SUPER + M")
hl.unbind("SUPER + J")
hl.unbind("SUPER + K")
hl.unbind("SUPER + O")
hl.unbind("SUPER + N")
o.bind("SUPER + H", "Focus left", hl.dsp.focus({ direction = "l" }))
o.bind("SUPER + Y", "Reload state", "~/.config/scripts/reload-orchestrator.sh")
o.bind("SUPER + M", "Keybindings", "omarchy-menu-keybindings")
o.bind("SUPER + N", "Theme menu", "omarchy-menu toggle theme")
o.bind("SUPER + Z", "Screenshot region", "omarchy capture screenshot region")
o.bind("SUPER + ALT + Z", "Settings", "omarchy-menu toggle")
o.bind("SUPER + DELETE", "Omarchy menu", "omarchy-menu toggle root")
o.bind("SUPER + RETURN", "Apps menu", "omarchy-menu toggle apps")
-- Media and lock screen
o.bind("code:194", "Previous track", "playerctl previous")
o.bind("code:195", "Play/pause", "playerctl play-pause")
o.bind("code:196", "Next track", "playerctl next")
o.bind("SUPER + code:47", "Lock screen", "omarchy system lock")
-- Remote shortcuts
hl.unbind("SUPER + X")
hl.unbind("SUPER + C")
o.bind("SUPER + X", "Lab SSH",
  grid_app(match_classes("foot-lab-ssh"),
    "foot --app-id=foot-lab-ssh -e ssh lab -t 'tmux new-session -A -s main \\; set-option -t main @accent \"#89b4fa\"'"))
o.bind("SUPER + C", "Mais Todos SSH",
  grid_app(match_classes("foot-maistodos-ssh"),
    "foot --app-id=foot-maistodos-ssh -e ssh maistodos -t 'tmux -u new-session -A -s main \\; set-option -t main @accent \"#cba6f7\"'"))
-- Clipboard
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
-- System shortcuts
hl.unbind("SUPER + BACKSPACE")
hl.unbind("SUPER + P")
hl.unbind("SUPER + T")
hl.unbind("SUPER + SHIFT + M")
hl.unbind("SUPER + SHIFT + B")
hl.unbind("SUPER + SHIFT + W") -- Omarchy default: Omawrite
hl.unbind("SUPER + SHIFT + RETURN")
hl.unbind("SUPER + L")
hl.unbind("SUPER + J")
hl.unbind("SUPER + K")
o.bind("SUPER + BACKSPACE", "Menu de sessão", "omarchy-menu toggle system")
o.bind("SUPER + P", "Selecionar cor da tela", "hyprpicker --autocopy --notify")
o.bind("SUPER + T", "Ativar microfone Bluetooth com RNNoise", "~/.config/scripts/toggle-bt-rnnoise.sh")
o.bind("SUPER + SHIFT + M", "Reativar tela interna",
  [[hyprctl eval 'hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1, disabled = false })']])
o.bind("SUPER + SHIFT + B", "Toggle maximized window", hl.dsp.window.fullscreen({ mode = "maximized" }))
o.bind("SUPER + SHIFT + W", "Toggle window floating", hl.dsp.window.float())
o.bind("SUPER + SHIFT + W", "Center window", hl.dsp.window.center())
o.bind("SUPER + SHIFT + RETURN", "Toggle fullscreen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
o.bind("SUPER + L", "Focus right", hl.dsp.focus({ direction = "r" }))

-- Previous SUPER + SHIFT actions replaced by the 4K zones.
-- Change the key and uncomment a line to restore an action elsewhere.
-- o.bind("SUPER + SHIFT + E", "Email", { webapp = "https://app.hey.com" }) -- Omarchy default
-- o.bind("SUPER + SHIFT + R", "Set reminder", "omarchy-menu toggle reminder-set")
-- o.bind("SUPER + SHIFT + F", "Full screen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
-- o.bind("SUPER + SHIFT + D", "Docker", { tui = "omarchy-launch-docker-tui" }) -- Omarchy default
-- Omarchy's older SUPER + SHIFT + C action was Calendar (https://app.hey.com/calendar/weeks/).

-- SUPER + SHIFT + T previously reloaded Hyprland.
hl.unbind("SUPER + SHIFT + T")
o.bind("SUPER + SHIFT + T", "Toggle 4K row width", function()
  four_zones.toggle_row_wide()
end)
hl.unbind("SUPER + SHIFT + G") -- Omarchy default: Signal
o.bind("SUPER + SHIFT + G", "Toggle 4K half-row cell", function()
  four_zones.toggle_half_cell()
end)

-- Keep universal copy and paste on SUPER + SHIFT + C/V.
hl.unbind("SUPER + SHIFT + C")
o.bind("SUPER + SHIFT + C", "Universal copy", universal_clipboard_shortcut("CTRL", "C", "CTRL", "Insert"))
o.bind("SUPER + SHIFT + V", "Universal paste", universal_clipboard_shortcut("CTRL", "V", "SHIFT", "Insert"))

-- Restore the SUPER + ALT actions replaced by the former zone shortcuts.
hl.unbind("SUPER + ALT + E")
hl.unbind("SUPER + ALT + R")
hl.unbind("SUPER + ALT + F")
hl.unbind("SUPER + ALT + D")
hl.unbind("SUPER + ALT + C")
o.bind("SUPER + ALT + E", "Emojis", "omarchy-shell shell toggle omarchy.emojis")
o.bind("SUPER + ALT + R", "Show reminders", "omarchy-reminder show")
o.bind("SUPER + ALT + D", "Display", "omarchy-shell shell toggle omarchy.monitor")
o.bind("SUPER + ALT + C", "Control center", "omarchy-menu toggle system")
local window_zone_shortcuts_4k = {
  { key = "E", zone = 1, name = "upper left" },
  { key = "R", zone = 2, name = "upper right" },
  { key = "D", zone = 3, name = "lower left" },
  { key = "F", zone = 4, name = "lower right" },
}

for _, shortcut in ipairs(window_zone_shortcuts_4k) do
  local key = "SUPER + SHIFT + " .. shortcut.key
  hl.unbind(key)
  o.bind(key, "4K zone " .. shortcut.name, function()
    four_zones.move_active(shortcut.zone)
  end)
end
-- Ctrl-free Omarchy remapping.
-- Applications
hl.unbind("SUPER + CTRL + X")
hl.unbind("SUPER + CTRL + RETURN")
hl.unbind("SUPER + CTRL + V")
hl.unbind("SUPER + ALT + X")
o.bind("SUPER + SHIFT + ALT + RETURN", "Herdr", { omarchy = "terminal-herdr" })
o.bind("SUPER + SHIFT + ALT + V", "Clipboard manager", "omarchy-shell shell toggle omarchy.clipboard")
-- Windows
hl.unbind("SUPER + CTRL + F")
hl.unbind("SUPER + SHIFT + ALT + F")
hl.unbind("SUPER + CTRL + TAB")
hl.unbind("SUPER + SHIFT + ALT + TAB")
hl.unbind("SUPER + CTRL + LEFT")
hl.unbind("SUPER + CTRL + RIGHT")
hl.unbind("SUPER + ALT + TAB")
hl.unbind("SUPER + CTRL + code:20")
hl.unbind("SUPER + CTRL + code:21")
hl.unbind("SUPER + CTRL + SHIFT + code:20")
hl.unbind("SUPER + CTRL + SHIFT + code:21")
hl.unbind("SUPER + ALT + code:20")
hl.unbind("SUPER + ALT + code:21")
hl.unbind("SUPER + SHIFT + ALT + code:20")
hl.unbind("SUPER + SHIFT + ALT + code:21")
o.bind("SUPER + SHIFT + ALT + F", "Tiled full screen", "omarchy-hyprland-window-tiled-fullscreen-toggle")
o.bind("SUPER + SHIFT + ALT + N", "File manager (cwd)", { omarchy = "nautilus-cwd" })
o.bind("SUPER + SHIFT + ALT + TAB", "Former workspace", hl.dsp.focus({ workspace = "previous" }))
o.bind("SUPER + ALT + PAGE_DOWN", "Next window in group", hl.dsp.group.next())
o.bind("SUPER + ALT + PAGE_UP", "Previous window in group", hl.dsp.group.prev())
o.bind("SUPER + SHIFT + ALT + code:20", "Expand window left a lot",
  hl.dsp.window.resize({ x = -300, y = 0, relative = true }))
o.bind("SUPER + SHIFT + ALT + code:21", "Shrink window left a lot",
  hl.dsp.window.resize({ x = 300, y = 0, relative = true }))
o.bind("SUPER + ALT + code:20", "Shrink window up a lot", hl.dsp.window.resize({ x = 0, y = -300, relative = true }))
o.bind("SUPER + ALT + code:21", "Expand window down a lot", hl.dsp.window.resize({ x = 0, y = 300, relative = true }))
-- Global controls
hl.unbind("CTRL + ALT + DELETE")
hl.unbind("CTRL + ALT + TAB")
hl.unbind("CTRL + ALT + SHIFT + TAB")
hl.unbind("SUPER + CTRL + ALT + Delete")

o.bind("SUPER + SHIFT + ALT + Delete", "Close all windows", "omarchy-hyprland-window-close-all")
o.bind("SUPER + ALT + TAB", "Focus on next monitor", hl.dsp.focus({ monitor = "+1" }))
o.bind("SUPER + SHIFT + ALT + PAGE_UP", "Focus on previous monitor", hl.dsp.focus({ monitor = "-1" }))

-- Utilities
hl.unbind("SUPER + CTRL + E")
hl.unbind("SUPER + CTRL + C")
hl.unbind("SUPER + CTRL + O")
hl.unbind("SUPER + CTRL + H")
hl.unbind("SUPER + CTRL + K")
hl.unbind("SUPER + CTRL + Q")
hl.unbind("SUPER + CTRL + SPACE")
hl.unbind("SUPER + ALT + SPACE")
hl.unbind("SUPER + SHIFT + CTRL + SPACE")
hl.unbind("SUPER + CTRL + BACKSPACE")
hl.unbind("SUPER + CTRL + comma")
hl.unbind("SUPER + CTRL + I")
hl.unbind("SUPER + CTRL + N")
hl.unbind("SUPER + CTRL + Delete")
hl.unbind("SUPER + CTRL + PRINT")
hl.unbind("SUPER + CTRL + S")
hl.unbind("SUPER + CTRL + PERIOD")
hl.unbind("SUPER + CTRL + R")
hl.unbind("SUPER + CTRL + ALT + R")
hl.unbind("SUPER + SHIFT + CTRL + R")
hl.unbind("SUPER + CTRL + ALT + T")
hl.unbind("SUPER + CTRL + ALT + B")
hl.unbind("SUPER + SHIFT + ALT + B")
hl.unbind("SUPER + CTRL + ALT + W")
hl.unbind("SUPER + SHIFT + CTRL + A")
hl.unbind("SUPER + SHIFT + ALT + A")
hl.unbind("SUPER + CTRL + A")
hl.unbind("SUPER + CTRL + B")
hl.unbind("SUPER + CTRL + D")
hl.unbind("SUPER + CTRL + ALT + D")
hl.unbind("SUPER + CTRL + W")
hl.unbind("SUPER + CTRL + P")
hl.unbind("SUPER + CTRL + T")
o.bind("SUPER + SHIFT + ALT + C", "Capture menu", "omarchy-menu toggle capture")
o.bind("SUPER + ALT + O", "Toggle menu", "omarchy-menu toggle toggle")
o.bind("SUPER + SHIFT + ALT + H", "Hardware menu", "omarchy-menu toggle hardware")
o.bind("SUPER + SHIFT + ALT + K", "Herdr keybindings", "omarchy-menu-herdr-keybindings")
o.bind("SUPER + ALT + Q", "Calculator", "omacalc")
o.bind("SUPER + ALT + SPACE", "Background switcher", "omarchy-menu toggle background")
o.bind("SUPER + ALT + BACKSPACE", "Toggle single-window square aspect",
  "omarchy-hyprland-window-single-square-aspect-toggle")
o.bind_toggle("SUPER + ALT + comma", "Toggle silencing notifications", "notification-silencing")
o.bind_toggle("SUPER + ALT + I", "Toggle locking on idle", "idle")
o.bind_toggle("SUPER + ALT + N", "Toggle nightlight", "nightlight")
o.bind("SUPER + ALT + Delete", "Toggle laptop display", "omarchy-hyprland-monitor-internal toggle")
o.bind("SUPER + ALT + 0", "Toggle laptop display mirroring",
  "omarchy-hyprland-monitor-internal-mirror toggle")
o.bind("SUPER + ALT + PRINT", "Extract text (OCR) from screenshot", "omarchy-capture-text")
o.bind("SUPER + SHIFT + ALT + S", "Share", "omarchy-menu toggle share")
o.bind("SUPER + ALT + PERIOD", "Transcode", "omarchy-transcode")
o.bind("SUPER + SHIFT + ALT + R", "Clear reminders", "omarchy-reminder clear")
o.bind("SUPER + SHIFT + ALT + T", "Show time", "omarchy-notification-time")
o.bind("SUPER + SHIFT + ALT + B", "Show battery remaining", "omarchy-notification-battery")
o.bind("SUPER + SHIFT + ALT + W", "Toggle weather", "omarchy-notification-weather")
o.bind("SUPER + SHIFT + ALT + A", "Agent", "omarchy-agent --pick")
o.bind("SUPER + ALT + A", "Audio", "omarchy-shell shell toggle omarchy.audio")
o.bind("SUPER + SHIFT + ALT + Y", "Bluetooth", "omarchy-shell shell toggle omarchy.bluetooth")
o.bind("SUPER + SHIFT + ALT + D", "Calendar", "omarchy-shell shell toggle omarchy.clock")
o.bind("SUPER + ALT + W", "Network", "omarchy-shell shell toggle omarchy.network")
o.bind("SUPER + ALT + P", "Power", "omarchy-shell shell toggle omarchy.power")
o.bind("SUPER + ALT + T", "Activity", { tui = "btop" })

-- Bar panels
for panel = 1, 9 do
  hl.unbind("SUPER + CTRL + code:" .. tostring(panel + 9))
  hl.unbind("SUPER + SHIFT + ALT + code:" .. tostring(panel + 9))
end

for panel = 1, 9 do
  o.bind(
    "SUPER + SHIFT + ALT + code:" .. tostring(panel + 9),
    "Bar panel " .. panel,
    "omarchy-shell -q shell togglePanelAt right " .. panel
  )
end
-- Zoom and lock
hl.unbind("SUPER + CTRL + Z")
hl.unbind("SUPER + CTRL + ALT + Z")
hl.unbind("SUPER + CTRL + L")
o.bind("SUPER + SHIFT + ALT + Z", "Zoom in", function()
  local zoom = hl.get_config("cursor.zoom_factor") or 1
  hl.config({ cursor = { zoom_factor = zoom + 1 } })
end)
o.bind("SUPER + SHIFT + ALT + 0", "Reset zoom", function()
  hl.config({ cursor = { zoom_factor = 1 } })
end)
o.bind("SUPER + ALT + L", "Lock system", "omarchy-system-lock")
