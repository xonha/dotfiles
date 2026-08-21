-- Aparencia do Hyprland: bordas, gaps, rounding e animacoes.
-- Era a parte final do hyprtoolkit.conf (o resto daquele arquivo continua
-- em .conf porque e config do hyprtoolkit, nao do Hyprland).

-- Catppuccin Black - so as cores que o Hyprland usa.
-- A paleta completa vive no hyprtoolkit.conf.
local colors = {
    red      = "rgb(f38ba8)",
    maroon   = "rgb(eba0ac)",
    subtext0 = "rgb(9e9e9e)",
}

hl.config({
    general = {
        border_size = 2,
        gaps_in     = 3,
        gaps_out    = 8,

        col = {
            active_border   = { colors = { colors.red, colors.maroon }, angle = 45 },
            inactive_border = { colors = { colors.subtext0, colors.subtext0 }, angle = 45 },
        },

        layout = "dwindle",
    },

    decoration = {
        rounding = 2,
    },

    animations = {
        enabled = true,
    },
})

hl.animation({ leaf = "windowsIn",   enabled = true, speed = 5,  bezier = "default", style = "popin 0%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 5,  bezier = "default", style = "popin" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5,  bezier = "default", style = "slide" })
hl.animation({ leaf = "fadeIn",      enabled = true, speed = 8,  bezier = "default" })
hl.animation({ leaf = "fadeOut",     enabled = true, speed = 8,  bezier = "default" })
hl.animation({ leaf = "fadeSwitch",  enabled = true, speed = 8,  bezier = "default" })
hl.animation({ leaf = "fadeShadow",  enabled = true, speed = 8,  bezier = "default" })
hl.animation({ leaf = "fadeDim",     enabled = true, speed = 8,  bezier = "default" })
hl.animation({ leaf = "border",      enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 5,  bezier = "default", style = "fade" })
