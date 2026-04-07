if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

export DOTNET_ROOT=$HOME/.dotnet

# kubectl autocomplete
if command -v kubectl &> /dev/null; then
    source <(kubectl completion bash)
    alias kpo="kubectl get po --all-namespaces"
    alias k="kubectl"
    complete -o default -F __start_kubectl k
fi

# dev container
alias dev="docker run -it dev"

# fix for some gtk based apps
export NO_AT_BRIDGE=1

function current_directory {
    cd "$@"; set_title; ls --color --group-directories-first -g --width=3 -h
}

function set_title {
    echo -ne "\033]0;${PWD}\007"
}
function vim {
    /usr/bin/vim "$@";set_title
}


function parse_git_branch {
    ref=$(/usr/lib/git-core/git-symbolic-ref HEAD 2> /dev/null) || return
    echo " ("${ref#refs/heads/}")"
}

export EDITOR='/usr/bin/vim'
PS1="\[\033[1;34m\]\u@\[\033[1;30m\]\h\[\033[1;34m\][\[\033[0;32m\]\w\[\033[1;34m\]]\$(parse_git_branch)\n\[\033[0m\]>"
PATH=~/projects/android-sdk-linux/tools:$PATH
PATH=~/bin:$PATH
PATH=/usr/local/go/bin:$PATH
PATH=$PATH:~/go/bin
PATH=$PATH:~/.pyenv/bin
PATH=$PATH:$HOME/.dotnet:$HOME/.dotnet/tools

alias cd="current_directory"
alias sl="sl -Fal"

set_title
if [ -f ~/.bashrc_local ]; then
    . ~/.bashrc_local
fi

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
