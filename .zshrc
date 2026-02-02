bindkey -e
setopt auto_pushd
setopt hist_ignore_dups
setopt ignoreeof
setopt noclobber
setopt pushd_ignore_dups
setopt share_history
HISTFILE=~/.zsh_history
HISTORY_IGNORE="(l[sla]|lla|pwd|history)"
HISTSIZE=10000
SAVEHIST=10000

export EDITOR="vim"
export PAGER=less
export LESS='-giXRMS'

# ============================== version manager
eval "$(mise activate zsh)"
# ============================== End version manager

# ============================== Zinit
# https://github.com/zdharma-continuum/zinit
### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
	zdharma-continuum/zinit-annex-as-monitor \
	zdharma-continuum/zinit-annex-bin-gem-node \
	zdharma-continuum/zinit-annex-patch-dl \
	zdharma-continuum/zinit-annex-rust

### End of Zinit's installer chunk
# Zinit plugins
zinit light-mode for \
	zsh-users/zsh-autosuggestions \
	zdharma-continuum/fast-syntax-highlighting \
	zdharma-continuum/history-search-multi-word
# ============================== End Zinit

# ============================== Theme
# https://github.com/romkatv/powerlevel10k
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
zinit ice depth=1; zinit light romkatv/powerlevel10k
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
# ============================== End Theme

# ============================== Carapace
# https://pixi.carapace.sh
autoload -U compinit && compinit
export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense' # optional
zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'
source <(carapace _carapace)
# ============================== End Carapace

# ============================== aliases
alias ls='ls -F --color=auto'
alias ll='ls -lF --color=auto'
alias la='ls -AF --color=auto'
alias lla='ls -lAF --color=auto'
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias mkdir='mkdir -p'
alias grep='grep --color=auto'
alias sudo='sudo '
alias sz='source ~/.zshrc'
alias viz='vi ~/.zshrc'
alias cz='code ~/.zshrc'
alias vigc='vi ~/.gitconfig'
alias cgc='code ~/.gitconfig'
# git
alias g='git'
alias gb='git branch -vv'
alias gbd='git branch -D'
alias gco='git checkout'
alias gcfl='git config -l'
alias glgo='git log --graph --oneline'
alias glog='git log'
alias glogg='git log -G'
alias glogs='git log -S'
alias glogdeletefile='git log --diff-filter=D --name-status --'
alias gpulr='git pull --rebase'
alias gpulrmain='git pull --rebase origin main'
alias gpulrmaster='git pull --rebase origin master'
alias gpusf='git push --force-with-lease'
alias gs='git status'
alias gsw='git switch'
alias gswc='git switch -c'
# ruby
alias gemclean='gem uninstall -I -a -x --user-install --force'
alias be='bundle exec'
alias bi='bundle install'
# act
alias aj='act -j'
alias al='act --list'
# docker
alias dit='docker exec -it'
# VSCode: https://code.visualstudio.com/docs/setup/mac#_launching-from-the-command-line
alias c='code'
alias cn='code -n'
alias cr='code -r'
# ============================== End aliases

# Load ~/local/.zshrc if it exists
[ -f ~/local/.zshrc ] && source ~/local/.zshrc
