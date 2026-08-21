#!/bin/bash

# mako-click.sh
# Called by mako's on-button-left binding with the notification ID in $id.
# Invokes the default notification action and focuses the sending application.

NOTIF_ID="${id}"

# Invoke the default action so the app knows it was clicked
makoctl invoke -n "$NOTIF_ID" default 2>/dev/null

# Get the app name (Desktop entry first, fallback to app-name)
APP_INFO=$(makoctl list 2>/dev/null | grep -A 5 "Notification ${NOTIF_ID}:")
DESKTOP_ENTRY=$(echo "$APP_INFO" | awk '/Desktop entry:/ { print $NF }')
APP_NAME=$(echo "$APP_INFO" | awk '/App name:/ { $1=$2=""; print $0 }' | xargs)

FOCUS_CLASS="${DESKTOP_ENTRY:-$APP_NAME}"

if [ -n "$FOCUS_CLASS" ]; then
    # Try case-insensitive match: exact class first, then lowercase
    WINDOW_ADDR=$(hyprctl clients -j | jq -r \
        ".[] | select(.class | ascii_downcase == (\"$FOCUS_CLASS\" | ascii_downcase)) | .address" \
        | head -n1)

    if [ -n "$WINDOW_ADDR" ]; then
        # Hyprland >= 0.55 com config em lua: dispatch recebe lua.
        hyprctl dispatch "hl.dsp.focus({ window = \"address:${WINDOW_ADDR}\" })"
    fi
fi

# Dismiss the notification
makoctl dismiss -n "$NOTIF_ID"
