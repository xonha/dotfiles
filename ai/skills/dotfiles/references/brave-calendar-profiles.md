# Brave profiles for calendar links

Use this procedure when calendar events must open links in different Brave
Origin accounts.

## Canonical profiles

Keep all profiles in the standard Brave Origin user-data directory:

```text
~/.config/BraveSoftware/Brave-Origin/
├── Default     # Personal
├── Profile 1   # MaisTodos
└── Profile 2   # Devbot
```

The display names are stored in `Local State` under `profile.info_cache`.
Change them only while Brave is closed, after making a backup. Do not create
separate `--user-data-dir` directories for these profiles: discovery tools
such as mclovin will not see them as profiles of the canonical installation.

## Calendar routing

The active calendar plugin is `promaa.clock`. It exposes the event calendar as
`modelData.calendar`; route links by that value:

```text
Personal  → --profile-directory=Default
MaisTodos → --profile-directory=Profile 1
Devbot    → --profile-directory=Profile 2
```

The launcher is `.config/scripts/calendar-browser.sh`. Hyprland bindings are
in `hypr/bindings.lua`; `Super+D` uses Profile 1 and `Super+S` uses
Profile 2. Reload Hyprland after changing bindings and restart the Omarchy
shell after changing the calendar plugin.

## Migrating an old profile

Close Brave completely before copying browser data. Old data may be found in
`.brave-origin-maistodos/brave-origin-maistodos` or a temporary
`Brave-Origin-MaisTodos/Default` tree. Back up the destination profile first,
then copy only the old profile contents into `Profile 1`. Never overwrite
`Local State` from the old user-data directory.

Keep the old source and backup until the new profile has been tested.

## Plugin notes

`mclovin` receives only a URL and cannot distinguish `MaisTodos` from `Devbot`
when both use Meet. Calendar-aware routing still needs the calendar plugin to
pass the source calendar to the launcher. mclovin may remain installed for
general browser/profile routing, but must not replace that calendar context.
