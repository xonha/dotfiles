# Overview

One Omarchy bar button for Chronica's date/time and the current or next calendar event. Its panel places the selected day's agenda on the left, the calendar with world clocks below it in the center, and notification history on the right.

The calendar is based on `promaa.clock` and keeps its calendar sync, editing, settings, and meeting links. Notifications are grouped by application; groups with multiple items start collapsed and expand on click. Each group has a **Limpar** action, while individual cards have a trash button and the section has **Limpar todas**. These actions use the enabled `xonha.notifications` service. Clicking a card focuses the sending application through the Dotfiles focus helper. Keep `xonha.notifications` enabled as a service even though its bar widget is removed.

World clocks appear as Elsewhen-style cards below the calendar, with city, time, date, and a day phase strip. The `cities` list comes from `shell.json`; times are calculated with the system timezone database.
