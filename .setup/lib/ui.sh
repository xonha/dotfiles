#!/usr/bin/env bash
# Shared helpers for setup steps

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { printf "${BLUE}  =>${RESET} %s\n" "$*"; }
success() { printf "${GREEN}  [ok]${RESET} %s\n" "$*"; }
warn()    { printf "${YELLOW}  [!]${RESET} %s\n" "$*"; }
error()   { printf "${RED}  [err]${RESET} %s\n" "$*" >&2; }
header()  { printf "\n${BOLD}${BLUE}=== %s ===${RESET}\n\n" "$*"; }

# Ask the user to confirm a step before running it.
# Usage: confirm_step "Step title" "Description"
# Returns 0 if confirmed, 1 if skipped.
confirm_step() {
  local title="$1"
  local desc="${2:-}"

  printf "\n${BOLD}Step: %s${RESET}\n" "$title"
  [[ -n "$desc" ]] && printf "  %s\n" "$desc"
  printf "  Run this step? [Y/n] "

  local answer
  read -r answer
  answer="${answer:-Y}"

  case "$answer" in
    [Yy]*) return 0 ;;
    *)
      warn "Skipped: $title"
      return 1
      ;;
  esac
}
