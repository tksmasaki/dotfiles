# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

bindkey -e
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
export ABBR_QUIETER=1

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

# ============================== fzf
# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)
# ============================== End fzf

# ============================== zoxide
eval "$(zoxide init zsh)"
# ============================== End zoxide

# ============================== aliases
abbr -S -f ls='ls -F --color=auto'
abbr -S -f cp='cp -i'
abbr -S -f mv='mv -i'
abbr -S -f rm='rm -i'
abbr -S -f ln='ln -i'
abbr -S -f mkdir='mkdir -p'
abbr -S -f grep='grep --color=auto'
abbr -S -f sudo='sudo '
abbr -S -f vim='nvim'
abbr -S ll='ls -lF --color=auto'
abbr -S la='ls -AF --color=auto'
abbr -S lla='ls -lAF --color=auto'
abbr -S cpr='cp -ir'
abbr -S sz='source ~/.zshrc'
abbr -S vz='nvim ~/.zshrc'
abbr -S cz='code ~/.zshrc'
# git
abbr -S -f g='git'
abbr -S gb='git branch -vv'
abbr -S gbd='git branch -D'
abbr -S gco='git checkout'
abbr -S gcfl='git config -l'
abbr -S glgo='git log --graph --oneline'
abbr -S glog='git log'
abbr -S glogg='git log -G'
abbr -S glogs='git log -S'
abbr -S glogdeletefile='git log --diff-filter=D --name-status --'
abbr -S gpulr='git pull --rebase'
abbr -S gpulrmain='git pull --rebase origin main'
abbr -S gpulrmaster='git pull --rebase origin master'
abbr -S gpusf='git push --force-with-lease'
abbr -S gs='git status'
abbr -S gsw='git switch'
abbr -S gswc='git switch -c'
abbr -S galias='git config --get-regexp ^alias'
# ruby
abbr -S gemclean='gem uninstall -I -a -x --user-install --force'
abbr -S be='bundle exec'
abbr -S bi='bundle install'
# act
abbr -S aj='act -j'
abbr -S al='act --list'
# docker
abbr -S dit='docker exec -it'
# VSCode: https://code.visualstudio.com/docs/setup/mac#_launching-from-the-command-line
abbr -S -f c='code'
abbr -S cn='code -n'
abbr -S cr='code -r'
# devcontainer
abbr -S dcz='devcontainer exec --remote-env TERM=xterm-256color zsh'
# ============================== End aliases

# Load ~/local/.zshrc if it exists
[[ -f ~/local/.zshrc ]] && source ~/local/.zshrc
