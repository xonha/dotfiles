-- Fallback seguro para qualquer monitor conectado.
-- Perfis conhecidos podem sobrescrever esta regra por `desc:` sem depender
-- de nomes de conectores (DP-1, HDMI-A-1 etc.), que mudam entre docks.

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

-- Monitores conhecidos da mesa. As regras so sao aplicadas quando o monitor
-- correspondente esta conectado; monitores desconhecidos usam o fallback.
hl.monitor({
    output   = "desc:Shenzhen KTC Technology Group SFPCCB24180 000000000000",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

hl.monitor({
    output   = "desc:SUE SFP2412FHD 000000000000",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})
