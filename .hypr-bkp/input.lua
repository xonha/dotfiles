-- Teclado, mouse, touchpad, cursor e gestos.
-- Era o hyprnavigation.conf.

hl.config({
    input = {
        kb_model   = "",
        kb_layout  = "br",
        kb_variant = "",
        kb_options = "",
        kb_rules   = "",
        kb_file    = "",

        numlock_by_default = true,
        repeat_rate        = 25,
        repeat_delay       = 600,

        sensitivity    = 0.5,
        accel_profile  = "adaptive",
        force_no_accel = false,
        left_handed    = false,

        scroll_method  = "2fg",
        scroll_button  = 0,
        natural_scroll = false,

        follow_mouse                = 1,
        float_switch_override_focus = 1,

        touchpad = {
            disable_while_typing    = true,
            natural_scroll          = true,
            scroll_factor           = 1.0,
            middle_button_emulation = false,
            clickfinger_behavior    = false,
            tap_to_click            = true, -- era "tap-to-click" no .conf
            drag_lock               = 0,    -- era false; virou int (0/1/2)
        },

        touchdevice = {
            transform = 0,
            output    = "",
        },
    },

    cursor = {
        inactive_timeout = 2,
    },

    -- Ajustes do swipe de workspace. O swipe em si agora precisa de um
    -- hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" }),
    -- que o .conf antigo tambem nao tinha (nunca ligou workspace_swipe).
    gestures = {
        workspace_swipe_distance           = 100,
        workspace_swipe_invert             = true,
        workspace_swipe_min_speed_to_force = 30,
        workspace_swipe_cancel_ratio       = 0.5,
        workspace_swipe_create_new         = false,
        workspace_swipe_forever            = false,
    },
})
