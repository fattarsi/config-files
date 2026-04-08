### zsh config
#source /usr/local/bin/virtualenvwrapper.sh
#source ./.local/bin/virtualenvwrapper.sh
export PATH=$HOME/.local/bin:/usr/local/go/bin:$HOME/go/bin:$PATH

# Directly source the Oh My Zsh plugins you use without enabling the full
# framework or its theme system.
export ZSH="$HOME/.oh-my-zsh"
if mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/oh-my-zsh/completions" 2>/dev/null; then
  export ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/oh-my-zsh"
else
  export ZSH_CACHE_DIR="/tmp/oh-my-zsh-$USER"
  mkdir -p "$ZSH_CACHE_DIR/completions"
fi
for plugin_file in \
  "$ZSH/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  "$ZSH/plugins/docker/docker.plugin.zsh" \
  "$ZSH/plugins/git/git.plugin.zsh" \
  "$ZSH/plugins/kubectl/kubectl.plugin.zsh" \
  "$ZSH/plugins/zoxide/zoxide.plugin.zsh" \
  "$ZSH/plugins/command-not-found/command-not-found.plugin.zsh"
do
  [ -r "$plugin_file" ] && source "$plugin_file"
done
unset plugin_file

NEWLINE=$'\n'
export PROMPT="%F{027}%n%F{007}@%F{008}%m[%F{034}%~%F{008}]${NEWLINE}%F{007}>"
export EDITOR="vim"

autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

#autoload -U add-zsh-hook
#add-zsh-hook -Uz chpwd (){
#  ls --color --group-directories-first -g --width=3 -h;
#}

HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
setopt appendhistory

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/rsa_id"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# tab completion to work more like bash
setopt noautomenu
setopt nomenucomplete

# ctrl+j to enter autocomplete menu
bindkey '^j' menu-complete
bindkey '^[[Z' autosuggest-accept

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

# Auto ls after change directory
function chpwd() {
    emulate -L zsh
    ls
}

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# opencode
export PATH=/home/fattarsi/.opencode/bin:$PATH

# Rig environment variables
[ -f ~/.config/rig/env.sh ] && source ~/.config/rig/env.sh

# yazi shell wrapper (enables directory changing with z, etc.)
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

# nav - fuzzy file browser (cd to final directory on exit)
function n() {
	local result dest
	result=$(nav)
	if [[ "$result" == *$'\n'* ]]; then
		local last_line="${result##*$'\n'}"
		local first_line="${result%%$'\n'*}"
		if [[ "$first_line" == OPEN:* ]]; then
			${EDITOR:-vim} "${first_line#OPEN:}"
			return
		fi
		dest="$last_line"
	else
		dest="$result"
	fi
	if [ -n "$dest" ] && [ "$dest" != "$PWD" ]; then
		builtin cd -- "$dest"
	fi
}

# Local config (not tracked by git)
[ -f ~/.zshrc.local ] && source ~/.zshrc.local

# bun completions
[ -s "/home/fattarsi/.bun/_bun" ] && source "/home/fattarsi/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
