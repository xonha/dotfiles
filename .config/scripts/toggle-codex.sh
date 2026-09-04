#!/bin/sh
# Toggle Codex right pane for tmux
# - If Codex pane is visible in current window: hide it
# - If Codex pane exists in another window: bring it back
# - If no Codex pane exists: create one

CURRENT_WINDOW="$(tmux display-message -p '#{window_id}')"
CURRENT_PATH="$(tmux display-message -p '#{pane_current_path}')"

# Find a pane running Codex across all windows in this session
CODEX_PANE="$(tmux list-panes -s -F '#{pane_id} #{pane_current_command} #{window_id}' \
  | grep ' codex ' | head -1)"

if [ -n "$CODEX_PANE" ]; then
  PANE_ID="$(echo "$CODEX_PANE" | awk '{print $1}')"
  WINDOW_ID="$(echo "$CODEX_PANE" | awk '{print $3}')"

  if [ "$WINDOW_ID" = "$CURRENT_WINDOW" ]; then
    # Codex is visible in this window — hide it
    tmux break-pane -d -s "$PANE_ID"
  else
    # Codex exists but is hidden — bring it back
    tmux join-pane -h -l 40% -s "$PANE_ID"
  fi
else
  # No Codex pane — create one
  tmux split-window -h -l 40% -c "$CURRENT_PATH" codex
fi
