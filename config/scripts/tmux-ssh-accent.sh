#!/usr/bin/env bash

# Print the accent colour for a tmux pane based on its SSH destination.
# tmux itself remains local while an SSH client runs inside the pane, so the
# tmux server hostname cannot be used for this decision.

root_pid=${1:?pane PID is required}

is_maistodos() {
    local pid=$1 child args

    args=$(ps -o args= -p "$pid" 2>/dev/null || true)
    if [[ $args == *'ssh maistodos'* || $args == *'ssh maistodos '* ]]; then
        return 0
    fi

    while read -r child; do
        [[ -n $child ]] && is_maistodos "$child" && return 0
    done < <(pgrep -P "$pid" 2>/dev/null || true)

    return 1
}

if is_maistodos "$root_pid"; then
    printf '#cba6f7'
else
    printf '#f38ba8'
fi
