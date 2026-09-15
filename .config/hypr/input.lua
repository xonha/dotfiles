-- Keep only your personal input overrides here. Uncommented settings below
-- replace Omarchy's defaults.

-- Keyboard layout and options.
-- See https://wiki.hypr.land/Configuring/Basics/Variables/#input
-- Omarchy's default makes Caps Lock the compose key (compose:caps). No
-- compose key at all here: Right Alt is needed as AltGr by the br(abnt2)
-- layout (e.g. AltGr+W -> "?"), so it can't take over that role either.
hl.config({
  input = {
    kb_options = "",
  },
})

-- Swap Esc <-> Caps Lock, but only on the internal ThinkPad keyboard, so it
-- doesn't affect the Corne (which has its own layers) even when both are
-- connected at once. Device name from `hyprctl devices`.
hl.device({
  name = "at-translated-set-2-keyboard",
  kb_options = "caps:swapescape",
})
