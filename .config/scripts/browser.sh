#!/usr/bin/env bash
# ~/.config/scripts/browser.sh
# Cicla o navegador padrao entre os perfis do Brave e emite status pro Waybar.
#   browser.sh [--status|--cycle|--set <perfil>|--list]
# O default de verdade mora no mimeapps.list (via xdg-mime); esse script so
# escreve os handlers de http/https/html de uma vez so.

set -Eeuo pipefail

WAYBAR_SIGNAL=8
ICON=$'\uf0ac' # nf-fa-globe, escapado: glifo literal nao sobrevive a edicao

# perfil|arquivo .desktop|rotulo   -- a ordem aqui e a ordem do ciclo
PROFILES=(
  "maistodos|brave-maistodos.desktop|MaisTodos"
  "devbot|brave-devbot.desktop|Devbot"
  "pessoal|brave-browser.desktop|Pessoal"
)

# icone por perfil, mesma ordem: briefcase, robot, user
ICONS=($'\uf0b1' $'\U000f06a9' $'\uf007')

MIMES=(
  x-scheme-handler/http
  x-scheme-handler/https
  x-scheme-handler/about
  x-scheme-handler/unknown
  text/html
)

field() { cut -d'|' -f"$2" <<<"${PROFILES[$1]}"; }

current_index() {
  local now i
  now=$(xdg-mime query default x-scheme-handler/https 2>/dev/null || true)
  for i in "${!PROFILES[@]}"; do
    [ "$(field "$i" 2)" = "$now" ] && { printf '%s' "$i"; return 0; }
  done
  return 1
}

apply() {
  local i=$1 desktop
  desktop=$(field "$i" 2)
  # tudo numa chamada so: xdg-mime pega lock por invocacao e chamadas
  # em sequencia rapida chegam a perder a escrita
  xdg-mime default "$desktop" "${MIMES[@]}"
  notify-send -h string:x-canonical-private-synchronous:browser -u low \
    "Navegador padrao: $(field "$i" 3)" 2>/dev/null || true
  pkill -RTMIN+"$WAYBAR_SIGNAL" waybar 2>/dev/null || true
}

cycle() {
  local i
  # sem perfil conhecido, o ciclo comeca do primeiro
  i=$(current_index) || { apply 0; return; }
  apply $(((i + 1) % ${#PROFILES[@]}))
}

set_profile() {
  local want=$1 i
  for i in "${!PROFILES[@]}"; do
    [ "$(field "$i" 1)" = "$want" ] && { apply "$i"; return 0; }
  done
  echo "perfil desconhecido: $want (use --list)" >&2
  exit 1
}

emit_json() {
  local i tip
  if ! i=$(current_index); then
    printf '{"text":"%s  ?","class":"unknown","tooltip":"Navegador padrao fora do ciclo: %s"}\n' "$ICON" \
      "$(xdg-mime query default x-scheme-handler/https)"
    return
  fi
  tip="Navegador padrao: ${ICONS[$i]} $(field "$i" 3)\rClique para ciclar"
  printf '{"text":"%s  %s","alt":"%s","class":"%s","tooltip":"%s"}\n' \
    "$ICON" "$(field "$i" 3)" "$(field "$i" 1)" "$(field "$i" 1)" "$tip"
}

case "${1:-}" in
--cycle) cycle ;;
--set) set_profile "${2:?informe o perfil}" ;;
--list) for i in "${!PROFILES[@]}"; do printf '%s\t%s\n' "$(field "$i" 1)" "$(field "$i" 2)"; done ;;
--status | "") emit_json ;;
*)
  echo "uso: $0 [--status|--cycle|--set <perfil>|--list]" >&2
  exit 1
  ;;
esac
