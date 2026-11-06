# Overview

One Omarchy bar button for Chronica's date/time and the next calendar event. Its panel places the Chronica calendar and agenda on the left and recent notification history on the right.

The calendar is based on `promaa.clock` and keeps its calendar sync, editing, settings, and meeting links. `dashboard.py` reads the existing `xonha.notifications` history when the panel opens and every minute while open. Keep `xonha.notifications` enabled as a service even though its bar widget is removed. The notification list is read-only; notification settings and dismissal remain available through the notification center IPC.

The world clock is intentionally absent from this version of the panel. The `cities` setting remains in `shell.json` so it can be restored later.
