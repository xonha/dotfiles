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
makepkg
sudo pacman -U libfprint-git-[0-9]*.pkg.tar.zst
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
Chipsailing reader (for example, right index on both and right thumb on the
dongle). `pam_fprintd` then prefers Chipsailing while both are connected and
uses Synaptics when the dongle is absent. Its choice is made at the start of
each authentication attempt; a disconnect during a scan does not switch
readers mid-attempt.

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
