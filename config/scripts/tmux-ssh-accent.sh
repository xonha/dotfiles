#!/usr/bin/env bash

# Print the accent colour for a tmux pane based on its SSH destination.
# tmux itself remains local while an SSH client runs inside the pane, so the
# tmux server hostname cannot be used for this decision.

root_pid=${1:?pane PID is required}

ssh_accent() {
    local pid=$1 child args

    args=$(ps -o args= -p "$pid" 2>/dev/null || true)
    if [[ $args == *'ssh maistodos'* || $args == *'ssh maistodos '* ]]; then
        printf '#cba6f7'
        return 0
    fi
    if [[ $args == *'ssh lab'* || $args == *'ssh lab '* ]]; then
        printf '#a6e3a1'
        return 0
    fi

    while read -r child; do
        [[ -n $child ]] && ssh_accent "$child" && return 0
    done < <(pgrep -P "$pid" 2>/dev/null || true)

    return 1
}

ssh_accent "$root_pid" || printf '#f38ba8'
