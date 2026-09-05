# Omarchy environment (OMARCHY_PATH + PATH), needed even for non-interactive shells
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap

# If not running interactively, don't do anything else (leave this above the rc source)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source "$OMARCHY_PATH/default/bash/rc"

# Omarchy loads its Readline bindings above.  Load ble.sh afterwards so its
# bind wrapper does not attempt to parse unsupported stock Readline functions.
[[ -r /usr/share/blesh/ble.sh ]] && source /usr/share/blesh/ble.sh --noattach

# ble.sh's builtin faces hardcode xterm 256-color indices (16-255), which the
# Catppuccin Mocha foot theme doesn't retheme (only ANSI 0-15 are remapped).
# Swap every hardcoded index for its nearest Catppuccin Mocha equivalent.
if [[ ${BLE_VERSION-} ]]; then
  ble-color-defface menu_filter_input        fg=233,bg=223
  ble-color-defface syntax_expr              fg=111
  ble-color-defface syntax_error             bg=211,fg=189
  ble-color-defface syntax_varname           fg=216
  ble-color-defface syntax_history_expansion bg=223,fg=189
  ble-color-defface syntax_function_name     fg=183,bold
  ble-color-defface syntax_comment           fg=241
  ble-color-defface syntax_glob              fg=218,bold
  ble-color-defface syntax_brace             fg=116,bold
  ble-color-defface syntax_document          fg=223
  ble-color-defface syntax_document_begin    fg=223,bold
  ble-color-defface command_function         fg=183
  ble-color-defface command_directory        fg=111,underline
  ble-color-defface filename_directory       underline,fg=111
  ble-color-defface filename_directory_sticky underline,fg=white,bg=111
  ble-color-defface filename_orphan          underline,fg=teal,bg=224
  ble-color-defface filename_setuid          underline,fg=black,bg=223
  ble-color-defface filename_setgid          underline,fg=black,bg=223
  ble-color-defface vbell_erase              bg=146
  ble-color-defface region                   bg=243,fg=white
  ble-color-defface region_target            bg=111,fg=black
  ble-color-defface region_match             bg=183,fg=white
  ble-color-defface disabled                 fg=241
  ble-color-defface overwrite_mode           fg=black,bg=116
  ble-color-defface menu_complete            fg=12,bg=146
  ble-color-defface auto_complete            bg=189,fg=237
  ble-color-defface cmdinfo_cd_cdpath        fg=111,bg=151
fi

# Personal environment migrated from the previous Zsh setup.
export OZONE_PLATFORM_HINT=wayland
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

# Keep the same command precedence as before.
export PATH="$HOME/.sst/bin:$HOME/go/bin:$HOME/.local/bin:$PATH"

# Persistent Bash history, including commands from concurrent shells.
HISTFILE="$HOME/.bash_history"
HISTSIZE=10000
HISTFILESIZE=10000
shopt -s histappend
PROMPT_COMMAND="history -a; history -n${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

# Readline equivalent of the old Zsh Ctrl-H binding.
bind -m emacs-standard '"\C-h": backward-kill-word'

# Node version manager supplied by Arch.
[[ -r /usr/share/nvm/init-nvm.sh ]] && source /usr/share/nvm/init-nvm.sh

v() {
  if [[ -d ${1:-} ]]; then
    builtin cd -- "$1" && nvim .
  elif [[ -f ${1:-} ]]; then
    nvim -- "$1"
  else
    nvim .
  fi
}

o() {
  if [[ -d ${1:-} ]]; then
    builtin cd -- "$1" && opencode .
  elif [[ -f ${1:-} ]]; then
    opencode "$1"
  else
    opencode .
  fi
}

dot() {
  local dir
  for dir in "$HOME/Dotfiles" "$HOME/dotfiles"; do
    if [[ -d $dir ]]; then
      builtin cd -- "$dir" && nvim .
      return
    fi
  done
  printf '%s\n' 'Dotfiles directory not found.' >&2
}

venv() { source .venv/bin/activate; }

alias l='ls -lh'
alias ll='ls -lah'
alias la='ls -A'
alias lm='ls -m'
alias lr='ls -R'
alias lg='ls -l --group-directories-first'
alias g='git'
alias gc='git checkout'
alias gcp='git cherry-pick'
alias del='yay -R --noconfirm'
alias add='yay --noconfirm --removemake'
alias dotfiles='dot'
alias maistodos='ssh maistodos'
alias bazzite='ssh bazzite'
alias laptop='ssh laptop'
alias devbot='ssh devbot'
alias lab='ssh lab'

up() {
  if [[ -n ${OMARCHY_PATH:-} ]] && command -v omarchy >/dev/null 2>&1; then
    omarchy update
    return
  fi

  yay --noconfirm --removemake || return
  local orphans
  orphans=$(pacman -Qdtq 2>/dev/null) || return 0
  [[ -n $orphans ]] && sudo pacman -Rns --noconfirm $orphans
}

eval "$(starship init bash)"

# ble-attach must come last so ble.sh wraps the final prompt/readline setup.
[[ ${BLE_VERSION-} ]] && ble-attach
