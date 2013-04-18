if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

function parse_git_branch {
    ref=$(/usr/lib/git-core/git-symbolic-ref HEAD 2> /dev/null) || return
    echo " ("${ref#refs/heads/}")"
}

export EDITOR='/usr/bin/vim'
PS1="\[\033[1;34m\]\u@\[\033[1;30m\]\h\[\033[1;34m\][\[\033[0;32m\]\w\[\033[1;34m\]]\$(parse_git_branch)\n\[\033[0m\]>"
PATH=~/bin:$PATH

p=`pwd`
for i in `ls ~/.virtualenvs/*/.project`
do
  choice=`cat $i`
  if [[ "`dirname $p`" = `dirname $choice`* ]]; then
    d=`echo $i|rev | cut -c 10- | rev`
    source $d/bin/activate
  fi
done

if [ -f .bashrc_local ]; then
    . .bashrc_local
fi
