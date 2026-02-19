# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

bindkey -v
setopt auto_cd
setopt auto_pushd
setopt hist_ignore_dups
setopt ignoreeof
setopt noclobber
setopt pushd_ignore_dups
setopt share_history
HISTFILE=~/.zsh_history
HISTORY_IGNORE="(l[sla]|lla|pwd|history|ps)"
HISTSIZE=10000
SAVEHIST=10000

export EDITOR="nvim"
export PAGER=less
export LESS='-giXRMS'

# ============================== version manager
# https://mise.jdx.dev
eval "$(mise activate zsh)"
# search tools in https://mise-versions.jdx.dev
# ============================== End version manager

# ============================== Plugin manager
# https://sheldon.cli.rs
eval "$(sheldon source)"
# ============================== End Plugin manager

# ============================== Shell Prompt
# https://github.com/romkatv/powerlevel10k
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
# ============================== End Shell Prompt

# ============================== aliases
alias ls='ls -F --color=auto'
alias ll='ls -lF --color=auto'
alias la='ls -AF --color=auto'
alias lla='ls -lAF --color=auto'
alias cp='cp -i'
alias cpr='cp -ir'
alias mv='mv -i'
alias rm='rm -i'
alias ln='ln -i'
alias mkdir='mkdir -p'
alias grep='grep --color=auto'
alias sudo='sudo '
alias vim='nvim'
alias sz='source ~/.zshrc'
alias vz='nvim ~/.zshrc'
alias cz='code ~/.zshrc'
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
alias galias='git config --get-regexp ^alias'
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
# devcontainer
alias dcz='devcontainer exec --remote-env TERM=xterm-256color zsh'
# ============================== End aliases

# Load ~/local/.zshrc if it exists
[[ -f ~/local/.zshrc ]] && source ~/local/.zshrc
