# Browser routing for calendar links

Calendar events are opened in different browsers according to their calendar
source. Brave profiles are not used for this routing.

## Canonical browser mapping

The launcher is `.config/scripts/calendar-browser.sh`:

- `MaisTodos` → `google-chrome-stable --profile-directory=Default`
- `Devbot` → `microsoft-edge-stable --profile-directory=Default`
- `Personal` → `brave-origin --profile-directory=Default`

The `promaa.clock` plugin passes the calendar name as the second argument to
the launcher, which is used to select the browser.

## Plugin notes

Calendar-aware routing requires `promaa.clock` to pass the source calendar to
the launcher. A URL-only browser router cannot distinguish `MaisTodos` from
`Devbot` when both contain the same Meet or Teams domain.
