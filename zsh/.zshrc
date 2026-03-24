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
abbr ls='ls -F --color=auto'
abbr ll='ls -lF --color=auto'
abbr la='ls -AF --color=auto'
abbr lla='ls -lAF --color=auto'
abbr cp='cp -i'
abbr cpr='cp -ir'
abbr mv='mv -i'
abbr rm='rm -i'
abbr ln='ln -i'
abbr mkdir='mkdir -p'
abbr grep='grep --color=auto'
abbr sudo='sudo '
abbr vim='nvim'
abbr sz='source ~/.zshrc'
abbr vz='nvim ~/.zshrc'
abbr cz='code ~/.zshrc'
# git
abbr g='git'
abbr gb='git branch -vv'
abbr gbd='git branch -D'
abbr gco='git checkout'
abbr gcfl='git config -l'
abbr glgo='git log --graph --oneline'
abbr glog='git log'
abbr glogg='git log -G'
abbr glogs='git log -S'
abbr glogdeletefile='git log --diff-filter=D --name-status --'
abbr gpulr='git pull --rebase'
abbr gpulrmain='git pull --rebase origin main'
abbr gpulrmaster='git pull --rebase origin master'
abbr gpusf='git push --force-with-lease'
abbr gs='git status'
abbr gsw='git switch'
abbr gswc='git switch -c'
abbr galias='git config --get-regexp ^alias'
# ruby
abbr gemclean='gem uninstall -I -a -x --user-install --force'
abbr be='bundle exec'
abbr bi='bundle install'
# act
abbr aj='act -j'
abbr al='act --list'
# docker
abbr dit='docker exec -it'
# VSCode: https://code.visualstudio.com/docs/setup/mac#_launching-from-the-command-line
abbr c='code'
abbr cn='code -n'
abbr cr='code -r'
# devcontainer
abbr dcz='devcontainer exec --remote-env TERM=xterm-256color zsh'
# ============================== End aliases

# Load ~/local/.zshrc if it exists
[[ -f ~/local/.zshrc ]] && source ~/local/.zshrc
