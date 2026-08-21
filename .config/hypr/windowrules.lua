-- Regras de janela.
-- Era o hyprwindowrule.conf.

local apps = require("apps")

-- Os apps "de canto" (PWAs e os perfis de trabalho do Brave) abrem numa
-- workspace vazia do monitor secundario.
for _, name in ipairs({ "devbot", "maistodos", "ytmusic", "todoist", "whatsapp" }) do
    hl.window_rule({
        name      = "side-" .. name,
        match     = { class = apps.apps[name].class },
        workspace = "emptyn",
        monitor   = apps.monitors.secondary,
    })
end

hl.window_rule({
    name  = "float-wlctl",
    match = { class = "wlctl" },
    float = true,
    size  = "900 800",
})

hl.window_rule({
    name  = "float-bluetui",
    match = { class = "bluetui" },
    float = true,
    size  = "700 500",
})
