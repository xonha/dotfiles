-- Keep tiled windows flush against each other and the monitor edges.
hl.config({
  general = {
    gaps_in = 0,
    gaps_out = 0,
  },
  decoration = {
    rounding = 0,
    -- Blur only matters for see-through surfaces. Windows stay opaque (see
    -- hyprland.lua), so in practice this blurs the layers opted in below.
    blur = {
      enabled = true,
      size = 6,
      passes = 3,
      new_optimizations = true,
      xray = false,
      brightness = 0.8,
      vibrancy = 0.3,
      popups = false,
      special = false,
    },
  },
})

-- Nexus, the TV panel (repos/app.nexus): frosted glass behind its
-- translucent panel. Its nearly clear scrim (alpha < 0.3) is not blurred.
hl.layer_rule({
  match = { namespace = "^nexus$" },
  blur = true,
  ignore_alpha = 0.3,
})

-- Opt another application in to Omarchy's standard transparency.
-- Find its class with: hyprctl clients
-- o.transparent_window("my-app")
-- o.transparent_window("my-app", "0.9 0.85") -- Custom active/inactive opacity.
