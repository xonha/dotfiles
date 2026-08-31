-- Keybinds.
-- Era o hyprbinds.conf.

local apps  = require("apps")

local A     = apps.apps
local S     = apps.scripts
local K     = apps.keys
local focus = apps.focus
local noct  = "noctalia msg "

-- -- Playerctl --------------------------------------------------------------

hl.bind(K.F16, hl.dsp.exec_cmd("playerctl previous"))
hl.bind(K.F17, hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind(K.F18, hl.dsp.exec_cmd("playerctl next"))

-- -- Apps -------------------------------------------------------------------

hl.bind("SUPER+G", hl.dsp.exec_cmd(focus(A.explorer)))
hl.bind("SUPER+W", hl.dsp.exec_cmd(focus(A.whatsapp)))
hl.bind("SUPER+E", hl.dsp.exec_cmd(focus(A.todoist)))
hl.bind("SUPER+R", hl.dsp.exec_cmd(focus(A.ytmusic)))
hl.bind("SUPER+S", hl.dsp.exec_cmd(focus(A.devbot)))
hl.bind("SUPER+D", hl.dsp.exec_cmd(focus(A.maistodos)))

hl.bind("SUPER+X",       hl.dsp.exec_cmd(focus(A.devbot_ssh, "emptyn")))
hl.bind("SUPER+SHIFT+X", hl.dsp.exec_cmd(focus(A.devbot_ssh, "current", true)))
hl.bind("SUPER+C",       hl.dsp.exec_cmd(focus(A.maistodos_ssh, "emptyn")))
hl.bind("SUPER+SHIFT+C", hl.dsp.exec_cmd(focus(A.maistodos_ssh, "current", true)))
hl.bind("SUPER+V",       hl.dsp.exec_cmd(focus(A.term, "emptyn")))
hl.bind("SUPER+SHIFT+V", hl.dsp.exec_cmd(focus(A.term, "current", true)))

hl.bind("SUPER+F",       hl.dsp.exec_cmd(focus(A.brave, "workspace:1")))
hl.bind("SUPER+SHIFT+F", hl.dsp.exec_cmd(focus(A.brave, "current", true)))

hl.bind("SUPER+A",       hl.dsp.exec_cmd(focus(A.code, "emptyn")))
hl.bind("SUPER+SHIFT+A", hl.dsp.exec_cmd(focus(A.code_new, "current", true)))

-- -- Misc -------------------------------------------------------------------

hl.bind("SUPER+Backspace", hl.dsp.exec_cmd(noct .. "panel-toggle session"))
hl.bind("SUPER+Space",     hl.dsp.exec_cmd(noct .. "panel-toggle launcher"))
hl.bind("SUPER+Delete",    hl.dsp.exec_cmd(noct .. "panel-toggle launcher"))
hl.bind("SUPER+" .. K.C1,  hl.dsp.exec_cmd(noct .. "session lock"))
hl.bind("SUPER+P",         hl.dsp.exec_cmd("hyprpicker --autocopy --notify"))
hl.bind("SUPER+T",         hl.dsp.exec_cmd(S.mic_mute))
hl.bind("SUPER+K",         hl.dsp.exec_cmd(S.keyd .. " --toggle"))
hl.bind("SUPER+N",         hl.dsp.exec_cmd(S.denoise .. " toggle"))
hl.bind("SUPER+J",         hl.dsp.exec_cmd("hyprctl kill"))
hl.bind("SUPER+Z",         hl.dsp.exec_cmd(noct .. "screenshot-region"))
hl.bind("SUPER+ALT+C",     hl.dsp.exec_cmd(noct .. "panel-toggle control-center"))
hl.bind("SUPER+ALT+Z",     hl.dsp.exec_cmd(noct .. "settings-toggle"))

-- -- Teclas de funcao -------------------------------------------------------

hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(noct .. "brightness-up"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(noct .. "brightness-down"), { locked = true, repeating = true })
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd(noct .. "volume-up"),       { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd(noct .. "volume-down"),     { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd(noct .. "volume-mute"),     { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd(S.mic_mute),                 { locked = true })
hl.bind("XF86AudioNext",         hl.dsp.exec_cmd(noct .. "media next"),      { locked = true })
hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd(noct .. "media previous"),  { locked = true })
hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd(S.media),                    { locked = true })
hl.bind("XF86AudioPause",        hl.dsp.exec_cmd(S.media),                    { locked = true })
hl.bind("XF86AudioStop",         hl.dsp.exec_cmd("playerctl stop"),          { locked = true })

-- -- Hyprland ---------------------------------------------------------------

hl.bind("SUPER+Q", hl.dsp.window.close())
hl.bind("SUPER+B", hl.dsp.window.move({ workspace = "empty" }))

-- Duas acoes na mesma tecla, como no .conf: flutua e depois centraliza.
hl.bind("SUPER+SHIFT+B", hl.dsp.window.float())
hl.bind("SUPER+SHIFT+B", hl.dsp.window.center())

hl.bind("SUPER+SHIFT+T", hl.dsp.exec_cmd("hyprctl reload"))

-- Foco
hl.bind("SUPER+left",  hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER+right", hl.dsp.focus({ direction = "right" }))
hl.bind("SUPER+up",    hl.dsp.focus({ direction = "up" }))
hl.bind("SUPER+down",  hl.dsp.focus({ direction = "down" }))
hl.bind("SUPER+H",     hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER+L",     hl.dsp.focus({ direction = "right" }))

-- Mover a janela no tile
hl.bind("SUPER+ALT+left",  hl.dsp.window.move({ direction = "left" }))
hl.bind("SUPER+ALT+right", hl.dsp.window.move({ direction = "right" }))
hl.bind("SUPER+ALT+up",    hl.dsp.window.move({ direction = "up" }))
hl.bind("SUPER+ALT+down",  hl.dsp.window.move({ direction = "down" }))
hl.bind("SUPER+ALT+H",     hl.dsp.window.move({ direction = "left" }))
hl.bind("SUPER+ALT+L",     hl.dsp.window.move({ direction = "right" }))

-- Redimensionar
hl.bind("SUPER+SHIFT+left",  hl.dsp.window.resize({ x = -20, y = 0, relative = true }), { repeating = true })
hl.bind("SUPER+SHIFT+right", hl.dsp.window.resize({ x = 20,  y = 0, relative = true }), { repeating = true })
hl.bind("SUPER+SHIFT+up",    hl.dsp.window.resize({ x = 0, y = -20, relative = true }), { repeating = true })
hl.bind("SUPER+SHIFT+down",  hl.dsp.window.resize({ x = 0, y = 20,  relative = true }), { repeating = true })
hl.bind("SUPER+SHIFT+H",     hl.dsp.window.resize({ x = -20, y = 0, relative = true }), { repeating = true })
hl.bind("SUPER+SHIFT+L",     hl.dsp.window.resize({ x = 20,  y = 0, relative = true }), { repeating = true })
hl.bind("SUPER+SHIFT+Return", hl.dsp.window.fullscreen(), { repeating = true })

-- Fake fullscreen: a janela segue no tile, o app pensa que esta fullscreen.
hl.bind("SUPER+ALT+B", hl.dsp.window.fullscreen_state({ internal = 0, client = 2 }))

-- Fullscreen real
hl.bind("SUPER+SHIFT+ALT+B", hl.dsp.window.fullscreen())

-- Mover a janela flutuante (as mesmas teclas do movewindow acima: uma acao
-- pega janela em tile, a outra pega flutuante).
hl.bind("SUPER+ALT+left",  hl.dsp.window.move({ x = -20, y = 0, relative = true }), { repeating = true })
hl.bind("SUPER+ALT+right", hl.dsp.window.move({ x = 20,  y = 0, relative = true }), { repeating = true })
hl.bind("SUPER+ALT+up",    hl.dsp.window.move({ x = 0, y = -20, relative = true }), { repeating = true })
hl.bind("SUPER+ALT+down",  hl.dsp.window.move({ x = 0, y = 20,  relative = true }), { repeating = true })

-- -- Workspaces -------------------------------------------------------------

for i = 1, 9 do
    hl.bind("SUPER+" .. i,        hl.dsp.focus({ workspace = i }))
    hl.bind("SUPER+CTRL+" .. i,   hl.dsp.window.move({ workspace = i }))
end

-- -- Tampa, pin, swap -------------------------------------------------------

hl.bind("switch:Lid Switch", hl.dsp.exec_cmd(noct .. "session lock"), { locked = true })

hl.bind("SUPER+ALT+P", hl.dsp.window.pin())
hl.bind("SUPER+ALT+P", hl.dsp.exec_cmd(apps.notify .. " 'Toggled Pin'"))

hl.bind("SUPER+ALT+S", hl.dsp.window.swap({ next = true }))

-- -- Mouse ------------------------------------------------------------------

hl.bind("SUPER+mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind("SUPER+mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind("SUPER+mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER+mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
