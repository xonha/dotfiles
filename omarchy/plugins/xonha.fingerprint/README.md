# Fingerprint Readers widget

This local adaptation of [zimixin/omarchy-fingerprint](https://github.com/zimixin/omarchy-fingerprint)
keeps the bar/popup concept but uses the system `fprintd` instead of the
FPC 9201-only `fingerprint-ocv` session daemon. It shows the internal Synaptics
and external Chipsailing readers separately, with per-reader enrollment and
verification. The bar glyph is ``.

`omarchy/plugins.sh` installs `xonha.fingerprint` and copies the shared
`setup/fingerprint/fingerprint_device.py` helper into its `bin` directory.
Do not install the upstream plugin's PAM bridge or `fprintd-list` shadow:
Omarchy's native PAM setup already talks to the correct system daemon.

PAM selects the connected reader with the most enrolled prints. To prefer the
dongle when it is present and use Synaptics after unplugging it, enroll one
finger on Synaptics and two different fingers on Chipsailing. The widget
suggests the next unenrolled finger on the selected reader. Authentication
selection happens at the start of each PAM attempt, not mid-scan. Always keep
password authentication available.
