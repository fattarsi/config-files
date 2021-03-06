if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

# kubectl autocomplete
source <(kubectl completion bash)
alias kpo="kubectl get po --all-namespaces"
alias k="kubectl"
complete -o default -F __start_kubectl k

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

# virtualenvwrapper non-lazy load doesn't seem to work
# do this if not in a venv to load workon tab completion
if [ -z "$VIRTUAL_ENV" ]; then
    workon > /dev/null
fi


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

alias cd="current_directory"
alias sl="sl -Fal"

p=`pwd`
for i in `ls ~/.virtualenvs/*/.project`
do
  choice=`cat $i`
  if [[ "$p" = "$choice"* ]]; then
    d=`echo $i|rev | cut -c 10- | rev`
    source $d/bin/activate
  fi
done

set_title
if [ -f ~/.bashrc_local ]; then
    . ~/.bashrc_local
fi

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"
