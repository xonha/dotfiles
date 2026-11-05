# LG PL5 for Omarchy

A small bar widget for the paired LG PL5 speaker. It reads the battery level
already provided by BlueZ every ten seconds through a bundled `busctl` helper.
The speaker icon uses the bar's normal foreground color and disappears when
the speaker or its battery interface disconnects. Click it to see the battery
level. No LG-specific protocol is needed.

The widget is installed from this repository by `omarchy/plugins.sh` and placed
next to Omacore by `omarchy/shell.json`. Its Bluetooth address is set in
`Panel.qml`; change it there if the speaker is replaced.
