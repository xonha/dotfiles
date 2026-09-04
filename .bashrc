# Omarchy environment (OMARCHY_PATH + PATH), needed even for non-interactive shells
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap

# If not running interactively, don't do anything else (leave this above the rc source)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source "$OMARCHY_PATH/default/bash/rc"

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
  yay --noconfirm --removemake || return
  local orphans
  orphans=$(pacman -Qdtq 2>/dev/null) || return 0
  [[ -n $orphans ]] && sudo pacman -Rns --noconfirm $orphans
}
