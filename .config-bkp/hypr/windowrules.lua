-- Regras de janela.
-- Era o hyprwindowrule.conf.

local apps = require("apps")

-- Satty (anotador de screenshot) deve abrir flutuante.
hl.window_rule({
	name = "float-satty",
	match = { class = "^org.satty.satty$" },
	float = true,
})

-- Os apps "de canto" (PWAs e os perfis de trabalho do Brave) abrem numa
-- workspace vazia do monitor secundario.
for _, name in ipairs({ "devbot", "maistodos", "ytmusic", "todoist", "whatsapp" }) do
	hl.window_rule({
		name = "side-" .. name,
		match = { class = apps.apps[name].class },
		workspace = "emptyn",
		monitor = apps.monitors.secondary,
	})
end
