#!/bin/sh
# Toggle a command's right pane for tmux
# - If the pane is visible in current window: hide it
# - If the pane exists in another window: bring it back
# - If no pane exists: create one

CMD="${1:?uso: $0 <comando>}"

CURRENT_WINDOW="$(tmux display-message -p '#{window_id}')"
CURRENT_PATH="$(tmux display-message -p '#{pane_current_path}')"

# Find a pane running $CMD across all windows in this session
PANE="$(tmux list-panes -s -F '#{pane_id} #{pane_current_command} #{window_id}' \
  | grep " $CMD " | head -1)"

if [ -n "$PANE" ]; then
  PANE_ID="$(echo "$PANE" | awk '{print $1}')"
  WINDOW_ID="$(echo "$PANE" | awk '{print $3}')"

  if [ "$WINDOW_ID" = "$CURRENT_WINDOW" ]; then
    # Pane is visible in this window — hide it
    tmux break-pane -d -s "$PANE_ID"
  else
    # Pane exists but is hidden — bring it back
    tmux join-pane -h -l 40% -s "$PANE_ID"
  fi
else
  # No pane — create one
  tmux split-window -h -l 40% -c "$CURRENT_PATH" "$CMD"
fi
