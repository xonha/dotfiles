#!/usr/bin/env bash
set -u

# Heuristic detector for browser-based meetings.
# It intentionally reports "unknown" when the browser window is not visible;
# an open Meet/Teams tab alone is not proof that a meeting is active.

meeting_status() {
  local title=""
  local app=""
  local browser=0
  local capture=0

  if command -v hyprctl >/dev/null 2>&1; then
    title="$(hyprctl activewindow -j 2>/dev/null | jq -r '.title // ""' 2>/dev/null || true)"
    app="$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // ""' 2>/dev/null || true)"
  fi

  if [[ "$app" =~ [Bb]rave ]] && [[ "$title" =~ [Mm]eet|[Tt]eams|[Zz]oom|[Ww]ebex|[Jj]itsi|[Dd]iscord ]]; then
    browser=1
  fi

  # Chromium-based browsers expose the capture stream as a Stream/Input/Audio
  # node (not necessarily Audio/Source). Match Brave's input stream as well as
  # common Chromium node names.
  if command -v pw-dump >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    if pw-dump 2>/dev/null | jq -e '
      .[]
      | select(.type == "PipeWire:Interface:Node")
      | .info.props as $p
      | (($p["application.name"] // "") + " " + ($p["node.name"] // "") + " " + ($p["media.name"] // "")) as $n
      | select($n | test("Brave|brave|Google Chrome|google-chrome|Chromium|chromium|Microsoft Edge|microsoft-edge|Edge|edge"))
      | select(($p["media.class"] // "") | test("Stream/Input/Audio|Audio/Source|Audio/Duplex"))
    ' >/dev/null; then
      capture=1
    fi
  fi

  local state="unknown"
  if (( capture == 1 )); then
    state="in_meeting"
  elif (( browser == 1 )); then
    state="meeting_tab_focused"
  elif (( capture == 1 )); then
    state="browser_capture_active"
  else
    state="not_detected"
  fi

  jq -cn --arg state "$state" --arg title "$title" \
    --argjson meeting_tab "$browser" --argjson capture "$capture" \
    '{state: $state, meeting_tab_focused: ($meeting_tab == 1), browser_capture_active: ($capture == 1), window_title: $title}'
}

browser_source_outputs() {
  pactl list source-outputs 2>/dev/null | awk '
    /^Source Output #[0-9]+/ { id=$3; sub("#", "", id); app="" }
    /application.name =/ { app=$0 }
    /^$/ {
      if (app ~ /Brave input|Google Chrome input|Chromium input|Microsoft Edge input|Edge input/) print id
      id=""; app=""
    }
  '
}

set_browser_mute() {
  local mute="$1"
  local found=0

  command -v pactl >/dev/null 2>&1 || {
    echo "pactl não encontrado" >&2
    return 1
  }

  while read -r output_id; do
    [[ -n "$output_id" ]] || continue
    pactl set-source-output-mute "$output_id" "$mute"
    found=1
  done < <(browser_source_outputs)

  if (( found == 0 )); then
    echo "Nenhum stream de microfone do Brave/Chrome/Chromium encontrado." >&2
    return 1
  fi
}

if [[ ${1:-} == "--watch" ]]; then
  while true; do
    meeting_status
    sleep "${2:-5}"
  done
elif [[ ${1:-} == "--mute" ]]; then
  set_browser_mute 1
elif [[ ${1:-} == "--unmute" ]]; then
  set_browser_mute 0
elif [[ ${1:-} == "--toggle" ]]; then
  while read -r output_id; do
    [[ -n "$output_id" ]] || continue
    current=$(pactl list source-outputs | awk -v id="$output_id" '
      $0 == "Source Output #" id { found=1 }
      found && /^\tMute:/ { print $2; exit }
    ')
    if [[ "$current" == "yes" ]]; then
      pactl set-source-output-mute "$output_id" 0
    else
      pactl set-source-output-mute "$output_id" 1
    fi
  done < <(browser_source_outputs)
else
  meeting_status
fi
