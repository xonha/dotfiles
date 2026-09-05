#!/usr/bin/env bash
# Manage the default browser profile used by HTTP/HTTPS links.

set -Eeuo pipefail

# id|desktop file|label
PROFILES=(
  "maistodos|brave-maistodos.desktop|MaisTodos"
  "devbot|brave-devbot.desktop|Devbot"
  "pessoal|brave-browser.desktop|Main"
)

MIMES=(
  x-scheme-handler/http
  x-scheme-handler/https
  x-scheme-handler/about
  x-scheme-handler/unknown
  text/html
)

field() {
  cut -d'|' -f"$2" <<<"${PROFILES[$1]}"
}

current_index() {
  local current index
  current=$(xdg-mime query default x-scheme-handler/https 2>/dev/null || true)
  for index in "${!PROFILES[@]}"; do
    [[ "$(field "$index" 2)" == "$current" ]] && {
      printf '%s\n' "$index"
      return
    }
  done
  return 1
}

apply_profile() {
  local index=$1 desktop
  desktop=$(field "$index" 2)
  xdg-mime default "$desktop" "${MIMES[@]}"
}

cycle_profile() {
  local index
  index=$(current_index) || {
    apply_profile 0
    return
  }
  apply_profile "$(((index + 1) % ${#PROFILES[@]}))"
}

set_profile() {
  local wanted=$1 index
  for index in "${!PROFILES[@]}"; do
    [[ "$(field "$index" 1)" == "$wanted" ]] && {
      apply_profile "$index"
      return
    }
  done
  echo "perfil desconhecido: $wanted" >&2
  exit 1
}

case "${1:---status}" in
--cycle) cycle_profile ;;
--set) set_profile "${2:?informe o perfil}" ;;
--status)
  index=$(current_index) || {
    printf 'Outro\n'
    exit
  }
  field "$index" 3
  ;;
--list)
  for index in "${!PROFILES[@]}"; do
    printf '%s\t%s\n' "$(field "$index" 1)" "$(field "$index" 3)"
  done
  ;;
*)
  echo "uso: $0 [--status|--cycle|--set perfil|--list]" >&2
  exit 1
  ;;
esac
