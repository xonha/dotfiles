# Future desktop setup

## Base setup

When reinstalling the system, the intended setup is:

- **CachyOS** as the Arch-based distribution, using its graphical installer.
- **Hyprland** as the Wayland compositor and tiling window manager.
- **Noctalia** as the desktop shell, replacing most of the collection of independent desktop utilities currently needed around Hyprland.
- Keep the existing dotfiles approach for Hyprland keybindings, window rules, application focus logic and other workflow-specific behavior.

Noctalia should preferably handle the desktop-shell responsibilities such as the bar, launcher, control center, notifications, lock screen, wallpaper, audio/brightness controls and session UI. The greeter can also be replaced by the Noctalia greeter if desired.

## Monitor plan

The intended future monitor is a **32-inch 4K (3840×2160)** display, preferably used at **100% scaling** if the physical viewing distance makes that comfortable.

Do not model the display permanently as four virtual monitors. Treat the whole 3840×2160 panel as one Hyprland output and use flexible window layouts/zones instead.

Useful layouts to experiment with:

### Four FHD quadrants

```text
┌───────────────────┬───────────────────┐
│     1920×1080     │     1920×1080     │
├───────────────────┼───────────────────┤
│     1920×1080     │     1920×1080     │
└───────────────────┴───────────────────┘
```

### Two stacked ultrawide areas

```text
┌───────────────────────────────────────┐
│              3840×1080                │
├───────────────────────────────────────┤
│              3840×1080                │
└───────────────────────────────────────┘
```

### Center-focused layout

This is probably the most interesting layout for normal work. Keep the primary applications in two central FHD-sized regions and auxiliary applications in peripheral half-FHD regions.

```text
┌─────────┬───────────────────┬─────────┐
│         │                   │         │
│  aux    │   main 1920×1080 │   aux   │
│960×1080 │                   │960×1080 │
├─────────┼───────────────────┼─────────┤
│         │                   │         │
│  aux    │   main 1920×1080 │   aux   │
│960×1080 │                   │960×1080 │
└─────────┴───────────────────┴─────────┘
```

Examples of peripheral applications: Slack/chat, file manager, monitoring tools and other applications that should remain visible without occupying the main visual focus.

The important idea is to keep these as **logical zones rather than fake physical monitors**, so the entire 4K surface can still be used freely when another layout is more appropriate.

## Application-focused workflow

Keep the current workflow where `Super + key` focuses or launches a specific application through `focus.sh`.

Potential future extension: make `focus.sh` aware of logical zones, allowing an application to be focused/launched and optionally moved to a predefined region of the 4K display.

Conceptually:

```text
focus(app)
focus(app, zone)
```

Possible zones:

```text
top-left-aux
top-main
top-right-aux
bottom-left-aux
bottom-main
bottom-right-aux
```

Do not over-engineer this initially. Start with normal Hyprland tiling and add explicit zones only if they improve the workflow.

## Screen sharing

Avoid sharing the complete 3840×2160 display whenever possible. A full 4K share can result in very small UI/text for viewers and unnecessarily high capture resolution.

Preferred approaches, in order:

1. **Share a specific application window** when only one application needs to be presented.
2. **Share a 1920×1080 region** of the physical 4K display when multiple applications/content need to be presented together.
3. If those approaches are insufficient, create a dedicated **1920×1080 headless Hyprland output** for screen sharing.

Hyprland supports fake/headless outputs through `hyprctl`, e.g.:

```bash
hyprctl output create headless Share
```

A possible future workflow is a `Share` output configured at 1920×1080 and enabled only during meetings. This can later be automated with a script/keybinding if it proves useful.

Screen sharing on Wayland should use PipeWire/WirePlumber with `xdg-desktop-portal-hyprland`.

## General principle

The target setup should preserve the parts of Hyprland that are valuable — tiling, keybindings, window rules, scripting and the application-focused workflow — while delegating generic desktop-shell functionality to Noctalia.

For the 4K display, prefer **one large flexible canvas with logical zones** over permanently emulating multiple monitors.
