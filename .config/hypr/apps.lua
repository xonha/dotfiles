-- Programas, monitores, scripts e teclas remapeadas.
-- Era o hyprvariables.conf (as $variaveis do hyprlang).

local M = {}

M.monitors = {
    main      = "desc:SUE SFP2412FHD 000000000000",
    secondary = "desc:Shenzhen KTC Technology Group SFPCCB24180 000000000000",
}

M.scripts = {
    backlight = "~/.config/scripts/brightness.sh",
    volume    = "~/.config/scripts/volume.sh",
    focus     = "~/.config/scripts/focus.sh",
    keyd      = "~/.config/scripts/keyd.sh",
    powermenu = "~/.config/scripts/powermenu.sh",
    denoise   = "~/.config/scripts/denoise.sh",
}

M.notify = "notify-send -h string:x-canonical-private-synchronous:hypr-cfg -u low"

-- Teclas que o keyd produz (/etc/keyd/default.conf). Keycodes crus porque
-- nao tem keysym estavel pra elas.
M.keys = {
    C1   = "code:47",  -- Ç
    C2   = "code:108",
    F13  = "code:191",
    F14  = "code:192",
    F15  = "code:193",
    F16  = "code:194",
    F17  = "code:195",
    F18  = "code:196",
    SEMI = "code:61",
}

local brave_flags = "--max-unused-resource-memory-usage-mb=128 --disk-cache-size=67108864"

local function brave_profile(profile)
    return ("brave --profile-directory=brave-%s --class=brave-%s --user-data-dir=.brave-%s %s"):format(profile, profile,
        profile, brave_flags)
end

local function brave_app(id)
    return ("brave --profile-directory=Default --app-id=%s %s"):format(id, brave_flags)
end

-- cmd   = linha de comando que o focus.sh lanca
-- class = classe da janela usada pro focus.sh achar uma instancia existente
M.apps = {
    brave = {
        cmd   = "brave --profile-directory=Default " .. brave_flags,
        class = "brave-browser",
    },
    devbot = {
        cmd   = brave_profile("devbot"),
        class = "brave-devbot",
    },
    maistodos = {
        cmd   = brave_profile("maistodos"),
        class = "brave-maistodos",
    },
    ytmusic = {
        cmd   = brave_app("cinhimbnkkaeohfgghhklpknlkffjgod"),
        class = "brave-cinhimbnkkaeohfgghhklpknlkffjgod-Default",
    },
    whatsapp = {
        cmd   = brave_app("hnpfjngllnobngcgfapefoaidbinmjnm"),
        class = "brave-hnpfjngllnobngcgfapefoaidbinmjnm-Default",
    },
    todoist = {
        cmd   = brave_app("dlgohinmglaoopaiplliaecdpmnepmga"),
        class = "brave-dlgohinmglaoopaiplliaecdpmnepmga-Default",
    },

    explorer = { cmd = "nemo ~/Downloads", class = "nemo" },

    devbox = {
        cmd   = "kitty --class kitty-devbox -e ssh devbox -t 'tmux new-session -A -s main'",
        class = "kitty-devbox",
    },
    maistodos_ssh = {
        cmd   = "kitty --class kitty-maistodos -e ssh maistodos -t 'tmux new-session -A -s main'",
        class = "kitty-maistodos",
    },
    term = {
        cmd   = "kitty -e tmux new-session -A -s main",
        class = "kitty",
    },

    code     = { cmd = "code", class = "code" },
    code_new = { cmd = "code -n", class = "code" },
}

-- Monta a chamada do focus.sh: focus.sh "<cmd>" <class> [modo] [forca]
-- modo: "current" (default no script), "emptyn" ou "workspace:N"
function M.focus(app, mode, force)
    local parts = { M.scripts.focus, '"' .. app.cmd .. '"', app.class }
    if mode then
        parts[#parts + 1] = mode
    end
    if force then
        parts[#parts + 1] = "1"
    end
    return table.concat(parts, " ")
end

return M
