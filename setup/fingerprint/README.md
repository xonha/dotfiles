# ThinkPad T495 and CS9711 fingerprint readers

This local Arch package builds the CS9711 libfprint fork with both the
`synaptics` and `cs9711` drivers. The stock Omarchy package recognizes the
internal Synaptics reader but does not recognize the USB dongle. The generic
CS9711 installer builds only its driver and would hide the internal reader.

The package is pinned to a reviewed source commit and uses epoch 2 so a normal
pacman update does not silently replace it with Omarchy's CS9711-free package.
Rebuild and review this package when updating its source or OpenCV. The CS9711
driver's matching code is experimental; keep password authentication available.

Install build dependencies, build the package as the regular user, then install
the resulting package through pacman:

```sh
sudo pacman -S --needed base-devel git meson ninja glib2-devel libgusb \
  pixman cairo openssl opencv doctest gobject-introspection
cd setup/fingerprint
makepkg -Csi
sudo systemctl restart fprintd.service
```

Check that `GetDevices` returns two paths:

```sh
busctl --system call net.reactivated.Fprint \
  /net/reactivated/Fprint/Manager net.reactivated.Fprint.Manager GetDevices
```

Enroll and verify on a specific reader in a local terminal. Touch the named
sensor when prompted; never run these commands with sudo:

```sh
cd /home/henrique/Dotfiles
python3 setup/fingerprint/fingerprint_device.py list
python3 setup/fingerprint/fingerprint_device.py enroll --reader chipsailing
python3 setup/fingerprint/fingerprint_device.py verify --reader chipsailing
python3 setup/fingerprint/fingerprint_device.py enroll --reader synaptics
python3 setup/fingerprint/fingerprint_device.py verify --reader synaptics
```

The `xonha.fingerprint` Omarchy widget offers the same per-reader enrollment
and verification from the bar. It uses the `` glyph and the system `fprintd`,
not the original `fingerprint-ocv` daemon.

For automatic selection by whether the dongle is connected, register one
finger on the internal Synaptics reader and two different fingers on the
external CS9711 USB reader (for example, right index on both and right thumb on
the dongle). `pam_fprintd` then prefers the USB reader while both are connected and
uses Synaptics when the dongle is absent. Its choice is made at the start of
each authentication attempt; a disconnect during a scan does not switch
readers mid-attempt.

Omarchy skips PAM fingerprint authentication while the lid is closed. To keep
the external reader usable in that state while still avoiding a timeout when
only the internal reader is available, install the local PAM gate:

```sh
pkexec /home/henrique/Dotfiles/setup/fingerprint/install-pam.sh
```

The installer backs up and updates the Omarchy gate in `sudo` and `polkit-1`.
The replacement skips fingerprint authentication only when the lid is closed
and the CS9711 USB reader is absent. Password authentication remains
available in either case.

The installer also adds a udev rule that refreshes `fprintd` when the CS9711
reconnects and a system-sleep hook that refreshes it after resume. Either event
can otherwise leave stale reader entries in the running daemon and send `sudo`
straight to the password prompt. Re-run the installer to apply these recovery
hooks on an existing installation. To clear duplicate entries immediately, run
`sudo systemctl restart fprintd.service`.

If the CS9711 reports `enroll-disconnected`, check `journalctl -k` for a USB
disconnect and reconnect. Try the dongle directly in a ThinkPad USB port first;
it can be unstable behind unpowered hubs. A `Release` error after disconnect
is only a cleanup symptom, not the cause of the failed enrollment.

`fprintd-enroll` uses one default reader. This package makes both readers
available but does not add simultaneous verification or mid-attempt fallback.

To revert, reinstall Omarchy's package and restart fprintd:

```sh
sudo pacman -S omarchy/libfprint-git
sudo systemctl restart fprintd.service
```
