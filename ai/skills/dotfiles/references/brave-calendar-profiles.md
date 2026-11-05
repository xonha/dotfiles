# Browser routing for calendar links

Calendar events and meeting links from both Omarchy widgets open in Brave,
regardless of their calendar source.

## Browser launcher

The launcher is `.config/scripts/calendar-browser.sh`:

All calendars use `brave-origin --profile-directory=Default`.

The `promaa.clock` and `xonha.next-event` plugins pass the calendar name as
the second argument. The launcher accepts it for compatibility.

## Plugin notes

Both plugins use the same launcher for Meet, Teams, and calendar URLs.
