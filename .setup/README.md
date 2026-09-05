# Setup Notes

## Estrutura

O instalador usa etapas numeradas em `stages/` apenas para definir a ordem.
Módulos com responsabilidades concretas ficam fora delas:

- `desktop/`: pacotes e preferências da sessão gráfica;
- `lib/`: funções reutilizáveis sem efeitos colaterais;
- `docs/`: documentação operacional.

## Login shell safety

`.setup/stages/40-login-shell.sh` runs immediately after the server packages are installed. It
configures Zsh as the login shell only after confirming that `command -v zsh`
returns an executable and that the exact path is present in `/etc/shells`.
The step then verifies the resulting passwd entry. This prevents PAM's
`pam_shells.so` from rejecting login if a distribution-provided shell (such as
Fish) is later removed.

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
