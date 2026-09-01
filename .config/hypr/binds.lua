-- Keybinds.
-- Era o hyprbinds.conf.

local apps = require("apps")

local A = apps.apps
local S = apps.scripts
local K = apps.keys
local focus = apps.focus
local noct = "noctalia msg "

-- 1. Midia e teclas de funcao

hl.bind(K.F16, hl.dsp.exec_cmd("playerctl previous"), { description = "Faixa anterior" })
hl.bind(K.F17, hl.dsp.exec_cmd("playerctl play-pause"), { description = "Reproduzir ou pausar" })
hl.bind(K.F18, hl.dsp.exec_cmd("playerctl next"), { description = "Proxima faixa" })

-- 2. Aplicativos

hl.bind("SUPER+G", hl.dsp.exec_cmd(focus(A.explorer)), { description = "Arquivos" })
hl.bind("SUPER+W", hl.dsp.exec_cmd(focus(A.whatsapp)), { description = "WhatsApp" })
hl.bind("SUPER+E", hl.dsp.exec_cmd(focus(A.todoist)), { description = "Todoist" })
hl.bind("SUPER+R", hl.dsp.exec_cmd(focus(A.ytmusic)), { description = "YouTube Music" })
hl.bind("SUPER+S", hl.dsp.exec_cmd(focus(A.devbot)), { description = "Devbot" })
hl.bind("SUPER+D", hl.dsp.exec_cmd(focus(A.maistodos)), { description = "Mais Todos" })

hl.bind("SUPER+X", hl.dsp.exec_cmd(focus(A.devbot_ssh, "emptyn")), { description = "Devbot SSH em workspace vazio" })
hl.bind(
	"SUPER+C",
	hl.dsp.exec_cmd(focus(A.maistodos_ssh, "emptyn")),
	{ description = "Mais Todos SSH em workspace vazio" }
)
hl.bind("SUPER+V", hl.dsp.exec_cmd(focus(A.term, "emptyn")), { description = "Terminal em workspace vazio" })

hl.bind("SUPER+F", hl.dsp.exec_cmd(focus(A.brave, "workspace:1")), { description = "Brave no workspace 1" })

hl.bind("SUPER+A", hl.dsp.exec_cmd(focus(A.code, "emptyn")), { description = "Editor em workspace vazio" })

-- 3. Noctalia e sistema

hl.bind("SUPER+Backspace", hl.dsp.exec_cmd(noct .. "panel-toggle session"), { description = "Menu de sessao" })
hl.bind("SUPER+Space", hl.dsp.exec_cmd(noct .. "panel-toggle launcher"), { description = "Abrir launcher" })
hl.bind(
	"SUPER+Delete",
	hl.dsp.exec_cmd(noct .. "panel-toggle launcher"),
	{ description = "Abrir launcher alternativo" }
)
hl.bind("SUPER+U", hl.dsp.exec_cmd(noct .. "panel-toggle yuuto/calculator:panel"), { description = "Calculadora" })
hl.bind("SUPER+I", hl.dsp.exec_cmd(noct .. "panel-toggle icefish/phone-operate:main"), { description = "Phone Operate" })
hl.bind("SUPER+Y", hl.dsp.exec_cmd("hyprctl kill"), { description = "Encerrar janela ao clicar" })
hl.bind("SUPER+" .. K.C1, hl.dsp.exec_cmd(noct .. "session lock"), { description = "Bloquear sessao" })
hl.bind("SUPER+P", hl.dsp.exec_cmd("hyprpicker " .. "-" .. "-autocopy " .. "-" .. "-notify"), { description = "Selecionar cor da tela" })
hl.bind("SUPER+T", hl.dsp.exec_cmd(S.mic_mute), { description = "Ativar ou silenciar microfone" })
hl.bind("SUPER+" .. K.SEMI, hl.dsp.exec_cmd(S.keyd .. " " .. "-" .. "-toggle"), { description = "Alternar remapeamento do teclado" })
hl.bind("SUPER+N", hl.dsp.exec_cmd(S.denoise .. " toggle"), { description = "Alternar reducao de ruido" })
hl.bind(
	"SUPER+J",
	hl.dsp.exec_cmd(noct .. "panel-toggle kenn/keybind-cheatsheet:cheatsheet"),
	{ description = "Mostrar atalhos" }
)
hl.bind("SUPER+O", hl.dsp.exec_cmd(noct .. "panel-toggle raycursive/github-prs:panel"), { description = "GitHub Pull Requests" })
hl.bind("SUPER+M", hl.dsp.exec_cmd(noct .. "panel-toggle icefish/phone-operate:main"), { description = "Phone Operate" })
hl.bind("SUPER+K", hl.dsp.exec_cmd(noct .. "panel-toggle noctalia/notes:panel"), { description = "Notas" })
hl.bind("SUPER+Z", hl.dsp.exec_cmd(noct .. "screenshot-region"), { description = "Capturar regiao da tela" })
hl.bind("SUPER+ALT+C", hl.dsp.exec_cmd(noct .. "panel-toggle control-center"), { description = "Central de controle" })
hl.bind("SUPER+ALT+Z", hl.dsp.exec_cmd(noct .. "settings-toggle"), { description = "Configuracoes do Noctalia" })

-- 4. Midia e teclas de funcao

hl.bind(
	"XF86MonBrightnessUp",
	hl.dsp.exec_cmd(noct .. "brightness-up"),
	{ locked = true, repeating = true, description = "Aumentar brilho" }
)
hl.bind(
	"XF86MonBrightnessDown",
	hl.dsp.exec_cmd(noct .. "brightness-down"),
	{ locked = true, repeating = true, description = "Diminuir brilho" }
)
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd(noct .. "volume-up"),
	{ locked = true, repeating = true, description = "Aumentar volume" }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd(noct .. "volume-down"),
	{ locked = true, repeating = true, description = "Diminuir volume" }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd(noct .. "volume-mute"),
	{ locked = true, description = "Ativar ou silenciar audio" }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd(S.mic_mute),
	{ locked = true, description = "Silenciar microfone pela tecla de funcao" }
)
hl.bind("XF86AudioNext", hl.dsp.exec_cmd(noct .. "media next"), { locked = true, description = "Proxima faixa" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd(noct .. "media previous"), { locked = true, description = "Faixa anterior" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd(S.media), { locked = true, description = "Reproduzir midia" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(S.media), { locked = true, description = "Pausar midia" })
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"), { locked = true, description = "Parar midia" })

-- 5. Janelas

hl.bind("SUPER+Q", hl.dsp.window.close(), { description = "Fechar janela" })
hl.bind("SUPER+B", hl.dsp.window.move({ workspace = "empty" }), { description = "Mover janela para workspace vazio" })

-- Duas acoes na mesma tecla, como no .conf: flutua e depois centraliza.
hl.bind("SUPER+SHIFT+B", hl.dsp.window.float(), { description = "Alternar janela flutuante" })
hl.bind("SUPER+SHIFT+B", hl.dsp.window.center(), { description = "Centralizar janela" })

hl.bind("SUPER+SHIFT+T", hl.dsp.exec_cmd("hyprctl reload"), { description = "Recarregar Hyprland" })
hl.bind("SUPER+SHIFT+Return", hl.dsp.window.fullscreen(), { repeating = true, description = "Alternar tela cheia" })
hl.bind(
	"SUPER+ALT+B",
	hl.dsp.window.fullscreen_state({ internal = 0, client = 2 }),
	{ description = "Alternar tela cheia simulada" }
)

-- 6. Navegacao com H e L
hl.bind("SUPER+H", hl.dsp.focus({ direction = "left" }), { description = "Focar a esquerda" })
hl.bind("SUPER+L", hl.dsp.focus({ direction = "right" }), { description = "Focar a direita" })

hl.bind("SUPER+ALT+H", hl.dsp.window.move({ direction = "left" }), { description = "Mover janela para esquerda" })
hl.bind("SUPER+ALT+L", hl.dsp.window.move({ direction = "right" }), { description = "Mover janela para direita" })

hl.bind(
	"SUPER+SHIFT+H",
	hl.dsp.window.resize({ x = -20, y = 0, relative = true }),
	{ repeating = true, description = "Reduzir largura" }
)
hl.bind(
	"SUPER+SHIFT+L",
	hl.dsp.window.resize({ x = 20, y = 0, relative = true }),
	{ repeating = true, description = "Aumentar largura" }
)

-- 7. Mouse

hl.bind("SUPER+mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Arrastar janela" })
hl.bind("SUPER+mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Redimensionar janela" })
