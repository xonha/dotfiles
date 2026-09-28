# Notification Center

Personal fork of Omarchy's notification service, with a bell widget and a
notification center. Click the bell to choose the output, the toast position,
and browse archived notifications. The panel opens on the selected output.
Position choices are top/bottom combined with left/center/right. Changes take
effect immediately, with space reserved for the bar on its configured edge.
Use **Testar notificação** to preview the selected monitor and position. The
center closes to leave the preview unobstructed; the test is archived normally.
The button is disabled when the selected output is disconnected.

Only the selected monitor shows toasts. If it is disconnected, toasts stay
hidden; there is no automatic fallback to a potentially shared screen. The
center can still be opened on an available monitor to change the selection.

Notifications are archived when they expire, are dismissed, or acted on.
History survives shell restarts. The default limit is 100 entries; the panel
offers 25, 100, and 500. A lower limit is enforced on the next archival.
Notifications received during Do Not Disturb retain upstream behavior.

Preferences are saved in `~/.local/state/omarchy/notification-center.json`.
The existing history is reused from
`~/.local/state/omarchy/notifications/history/`.
The default output is DP-3, matching this machine's left monitor.

Open the center from a terminal:

```sh
omarchy-shell shell toggle xonha.notifications '{}'
```

`omarchy/plugins.sh` copies the versioned plugin into the installed plugin
directory. Restart the shell after changing service code because `keepLoaded`
services retain their old instance across plugin rescans.

Upstream code and notification protocol support come from
[Omarchy](https://github.com/basecamp/omarchy).
