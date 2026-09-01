-- Config do Hyprland no formato Lua (Hyprland >= 0.55).
-- O formato .conf antigo sai na 0.57.
--
-- Docs: https://wiki.hypr.land/Configuring/Start/
-- Stubs pro LSP: /usr/share/hypr/stubs/hl.meta.lua
--
-- Noctalia fornece bar, launcher, notificacoes, lock screen, wallpaper,
-- controles de hardware e UI de sessao.

require("monitors")
require("workspaces")
require("looknfeel")
require("input")
require("misc")
require("windowrules")
require("binds")
require("autostart")
