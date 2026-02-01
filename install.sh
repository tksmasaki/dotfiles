#!/bin/zsh
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

# === aliases ===
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
# === end aliases ===
