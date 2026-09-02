# Keep the instant prompt before anything that may request input.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export OZONE_PLATFORM_HINT=wayland
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

typeset -U path PATH
path=(
  "$HOME/.sst/bin"
  $path
  "$HOME/go/bin"
  "$HOME/.local/bin"
)

HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory

source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
source /usr/share/nvm/init-nvm.sh

autoload -Uz add-zsh-hook compinit
compinit
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

bindkey '^[[A' history-substring-search-up
bindkey '^[OA' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^[OB' history-substring-search-down
bindkey '^H' backward-kill-word

v() {
  if [[ -d $1 ]]; then
    cd -- "$1" && nvim .
  elif [[ -f $1 ]]; then
    nvim -- "$1"
  else
    nvim .
  fi
}

o() {
  if [[ -d $1 ]]; then
    cd -- "$1" && opencode .
  elif [[ -f $1 ]]; then
    opencode "$1"
  else
    opencode .
  fi
}

# Rehash only after Pacman changes its command cache.
zshcache_time="$(date +%s%N)"
rehash_precmd() {
  if [[ -a /var/cache/zsh/pacman ]]; then
    local paccache_time="$(date -r /var/cache/zsh/pacman +%s%N)"
    if (( zshcache_time < paccache_time )); then
      rehash
      zshcache_time="$paccache_time"
    fi
  fi
}
add-zsh-hook -Uz precmd rehash_precmd

alias venv='source .venv/bin/activate'

alias l='ls -lh'
alias ll='ls -lah'
alias la='ls -A'
alias lm='ls -m'
alias lr='ls -R'
alias lg='ls -l --group-directories-first'

alias g='git'
alias gc='git checkout'
alias gcp='git cherry-pick'

alias up='yay --noconfirm --removemake && sudo pacman -Rns $(pacman -Qdtq) --noconfirm'
alias del='yay -R --noconfirm'
alias add='yay --noconfirm --removemake'

dot() {
  local dir
  for dir in "$HOME/Dotfiles" "$HOME/dotfiles"; do
    if [[ -d $dir ]]; then
      cd -- "$dir" && nvim .
      return
    fi
  done
  print -u2 'Dotfiles directory not found.'
}

alias dotfiles=dot
alias maistodos='ssh maistodos'
alias bazzite='ssh bazzite'
alias laptop='ssh laptop'
alias devbot='ssh devbot'
alias lab='ssh lab'

[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"

# Must remain last so every widget is wrapped for highlighting.
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
