# Setup Notes

## Nemo sidebar / XDG folders

Applied by `.setup/nemo.sh` (run from `.install.sh`).

Two gotchas on a minimal Hyprland setup:

1. **`~/.config/user-dirs.dirs` is never generated.** There is no XDG autostart
   processor, so `xdg-user-dirs-update` never runs and every `XDG_*_DIR`
   resolves to `$HOME`. Fixed by running it once in `nemo.sh` and via
   `hl.exec_cmd("xdg-user-dirs-update")` in `hyprland.lua`.
2. **Nemo does not auto-list the XDG folders.** Unlike Nautilus, it only shows
   Home/Desktop/Filesystem/Trash plus whatever is in
   `~/.config/gtk-3.0/bookmarks`. So the standard folders must be seeded there.
   `sidebar-bookmark-breakpoint` (dconf) sets where the "My Computer" section
   ends and "Bookmarks" begins. Custom folder icons live in GIO metadata
   (`gio set … metadata::custom-icon-name`), which is per-machine, not a file
   that can be stowed.

## waybar-ycal (Google Calendar popup)

> Legacy: esta seção só se aplica à configuração antiga da branch `main`.
> Na branch `noctalia`, Waybar e waybar-ycal não são instalados nem ativados.

Installed by `.setup/desktop.sh` (`aur/waybar-ycal`); the user service is
enabled by `.setup/services.sh`. Three things the scripts cannot do for you.

### 1. Google OAuth credentials (manual, one-time)

1. Create a project at <https://console.cloud.google.com>
2. Enable the **Google Calendar API** and the **Google Tasks API**
3. Create an **OAuth2 Desktop** credential, download the JSON
4. Save it as `~/.config/waybar-ycal/credentials.json`
5. On the **Audience** page either add your Google account under **Test users**,
   or hit **Publish app**

Publishing is worth the extra click: in Testing mode Google expires the refresh
token every 7 days, so the login comes back weekly. Either way the consent
screen warns the app is unverified — Advanced → continue. Both scopes it asks
for (`calendar.readonly`, `tasks`) are *sensitive*, not *restricted*, so no
Google verification is required for personal use.

Then click the bar module and hit **Authenticate**. The token lands in
`~/.cache/waybar-ycal/token.json`. That path and `~/.config/waybar-ycal/` are
gitignored — the repo is public.

### 2. `BROWSER` in /etc/environment breaks the OAuth flow

`/etc/environment` ships `BROWSER=firefox` on this machine, and firefox is not
installed. The OAuth flow calls `webbrowser.open()`, which honours `$BROWSER`
before anything else, fails to exec `firefox`, and returns `False` without
raising — the button then sits on "Opening browser..." forever waiting for a
callback that never arrives.

`.config/systemd/user/waybar-ycal.service.d/override.conf` works around it with
`UnsetEnvironment=BROWSER`, which is enough for this service (without the
variable Python falls back to `xdg-open`). Note `systemctl --user
unset-environment BROWSER` does *not* work: the value is inherited from PAM and
sits outside the block the manager controls. The real cure is dropping the line
from `/etc/environment`, which needs root and a re-login.

### 3. The popup renders opaque under a themed GTK4

GTK4 adds the `.background` class to every window, and
`.themes/Catppuccin-Black/gtk-4.0/gtk.css` is loaded as
`~/.config/gtk-4.0/gtk.css` at `PRIORITY_USER` (800) — beating the app's own
`window { background: transparent }` at `PRIORITY_APPLICATION` (600). The
victim is `ClickShield`, a fullscreen layer-shell window that only exists to
catch clicks outside the popup: it paints `#151515` over the entire screen.

Fixed by a `.click-shield` override appended to both `gtk.css` and
`gtk-dark.css`. Keep the alpha at `0.01` rather than `transparent` — with alpha
0 the compositor stops delivering input to the surface and click-outside-to-close
silently dies.

Two smaller pieces, both stowed:

- `.config/omarchy/current/theme/colors.toml` — the app reads its palette from
  there; without it you get its built-in orange-on-navy defaults.
- `.config/scripts/ycal-popup.py` — launcher that anchors the popup to the top
  right. Upstream anchors `TOP` only (centred) and exposes no position setting,
  and `popup.py` calls `app.run()` at module level with no `__main__` guard, so
  it cannot be imported and patched afterwards. The launcher rewrites that one
  line in the source before exec'ing it, and aborts loudly if a package update
  moves it. `ExecStart=` in the drop-in points the service here.

## Wake from Suspend via Keyboard (ThinkPad)

By default, the ThinkPad only wakes from `systemctl suspend` via the power button.
This documents how to enable wakeup from the internal keyboard and an external USB keyboard.

### Why it happens

The internal keyboard (`i8042/serio0`) and USB devices have their `power/wakeup` attribute
set to `disabled` by default. The ACPI wakeup table (`/proc/acpi/wakeup`) may show `XHC0`/`XHC1`
as enabled, but that alone is not enough — the individual device nodes must also be enabled.

### Diagnose

Check current wakeup state:

```bash
# Internal keyboard
cat /sys/devices/platform/i8042/serio0/power/wakeup

# USB devices (find your keyboard)
for dev in /sys/bus/usb/devices/*/; do
  name=$(cat "$dev/product" 2>/dev/null || echo "N/A")
  wakeup=$(cat "$dev/power/wakeup" 2>/dev/null || echo "N/A")
  echo "$(basename $dev) | $name | wakeup=$wakeup"
done

# ACPI wakeup table
cat /proc/acpi/wakeup
```

### Test immediately (lost on reboot)

```bash
echo enabled | sudo tee /sys/devices/platform/i8042/serio0/power/wakeup

# Replace <port> with the port your keyboard is on (from the loop above, e.g. 1-3, 2-1)
echo enabled | sudo tee /sys/bus/usb/devices/<port>/power/wakeup
```

Then test with `systemctl suspend` and wake with a keypress.

### Make it persistent (udev rules)

Create `/etc/udev/rules.d/90-wakeup-keyboard.rules`:

```
# Internal ThinkPad keyboard (i8042)
KERNEL=="serio0", SUBSYSTEM=="serio", ATTR{power/wakeup}="enabled"

# External USB keyboard matched by vendor/product ID
# Replace idVendor and idProduct with your keyboard's values
# (check with: cat /sys/bus/usb/devices/<port>/idVendor)
# Using vendor/product ID is preferred over port number since the port can change between reboots.
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="1d50", ATTR{idProduct}=="615e", ATTR{power/wakeup}="enabled"
```

Reload udev rules without rebooting:

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### Optional: wake on lid open

The lid (`PNP0C0D`) is also disabled by default. To enable it:

```bash
# Test immediately
echo enabled | sudo tee /sys/devices/platform/PNP0C0D:00/power/wakeup

# Persistent (add to the udev rules file above)
ACTION=="add", SUBSYSTEM=="platform", KERNEL=="PNP0C0D:00", ATTR{power/wakeup}="enabled"
```
