#!/bin/bash

#--------------------------------------BUILTIN------------------------------------------------------
alias bashrc='vim ~/.bashrc; . ~/.bashrc'
#did you know aliases can use other aliases? watch out for that
#make aliases work with sudo
alias sudo='sudo '
#use sudo -i to become root and keep your bashrc & vimrc
alias -- -i='-E bash --rcfile $HOME/.bashrc'

if [[ "$__enterprise" != "nasdaq" ]]; then #nasdaq doesn't do X11 b/c we're lame.
    alias ssh='ssh -XY' #allows X11 forwarding, which I use for clipboards. now copy-paste might actually work.
fi

# auto completion for ssh and scp
_complete_ssh_hosts ()
{
        COMPREPLY=()
        cur="${COMP_WORDS[COMP_CWORD]}"
        comp_ssh_hosts=`cat ~/.ssh/known_hosts | \
                        cut -f 1 -d ' ' | \
                        sed -e 's/,.*//g' | \
                        grep -v ^# | \
                        uniq | \
                        grep -v "\[" ;
                cat ~/.ssh/config | \
                        grep "^Host " | \
                        awk '{print $2}'
                `
        COMPREPLY=( $(compgen -W "${comp_ssh_hosts}" -- $cur))
        return 0
}
complete -F _complete_ssh_hosts ssh
complete -F _complete_ssh_hosts ssh-copy-id
complete -F _complete_ssh_hosts share

#--auto sudo-
alias apt-get='sudo apt-get'
alias systemctl='sudo systemctl'
alias firewall='sudo firewall-cmd'
alias yum='sudo yum'
alias yumy='sudo yum install -y'
#alias ugh = sudo !!
alias ugh='sudo $(history -p !!)'

#--colors--
#tries to force color: (G):BSD; (--color):GNU, adds / after dirs, * after execs, etc (F);
#and human readable sizes (h)
# BSD ls colors
export CLICOLOR=1
export LSCOLORS=ExGxFxFxCxegedCHChEhEH
# lowercase is normal, uppercase is bold, x is "default"
# a - black, b - red, c - green, d - brown/yellow?, e - blue, f - magenta, g - cyan, h - grey, i - white
# dir: Ex, symlink: Gx, Socket/Pipe: Fx, executable: Cx, block special (/dev/): eg, char special (?): eg, 
# exe setuid: CH, exesetguid: Ch, all writable dir (sticky - no delete): Eh, 
# all writable dir (no sticky - everyone delete anything): EH
# GNU ls colors
# export LS_COLORS=
[[ -f "$(dircolors $bashfiles/dircolors.txt)" ]] && eval "$(dircolors $bashfiles/dircolors.txt)"
# Don't parse ls. especially because this ls will have raw output like $'\E[01;34mtesting-tools\E[0m/' since colors
alias ls='ls --color -GFh'
alias la='ls --color -GFhla'
#I want colors! 'always' might be better, but could bite you (auto doesn't color if you're piping)
if alias | grep 'alias grep' &>/dev/null; then unalias grep; fi #seems like the linux machines have this aliased by default why?
grep() {
    command grep --color=auto "$@"
}

viewargs() {  # view word splitting for double-check
  echo $#
  a=("$@")
  declare -p a
}

#tail, but highlight any words you want to
tailhl() { # 1: filename. 2: string to highlight. [3+]: more strings to highlight
    local file=$1
    shift
    local args='xqxz'
    for ele in "$@"; do
        args+="\|$ele"
    done
    echo $args
    tail -f "$file" | sed -e "s/\($args\)/\o033[1;31;43m\1\o033[0m/g"
}

hl() {
    # arbitrary first sting we'll never find
    local args='zxq'
    for ele in "$@"; do
        args+="\|$ele"
    done
    sed -e  "s/\($args\)/\o033[38;5;255;48;5;52m\1\o033[0m/I"
}

#--searching--
# don't use grep, use ripgrep
alias f.='find . -name'
alias fr.='find . -regextype grep -regex'
findsed() {  # $1. search value. $2. replacement value. stdin (optional): list of files.
  # if stdin is the terminal, then we didn't pipe anything
  if [[ -t 0 ]]; then
    find . -type f -not -path "*.git*" -exec sed -i -e "s:$1:$2:g" {} \+;
  else
    xargs sed -i -e "s:$1:$2:g"
  fi
}
alias s.='findsed'
# -a: dotfiles. -I: not those dotfiles. -C: color.
alias tr33='tree -a -C -I ".git|.vim|.idea|.DS_Store|*cache*" -L 3'
alias tree='tree -a -C -I ".git|.vim|.idea|.DS_Store|*cache*"'

#--utils--
hrbytes() {  # human readable bytes. numfmt is cool.
  local num;
  if [[ $# -lt 1 ]]; then
    read num;
  else
    num="$1"
  fi
  numfmt --to=iec-i --suffix=B --format="%.3f" "$num"
}
alias hrb='hrbytes'
es() {  # epoch seconds
  date +%s
}
hres() {  # human readable epoch seconds
    local T=$1
    if [[ "$T" == "ms" ]]; then #ms since epoch
        T=$2
        date -d @$((T/1000))
    else
        date -d @$1
    fi
}
hrs() {  # human readable seconds. -h
    local D T=$1
    ((D=T/60/60/24)) && printf '%d days ' $D
    printf '%d:%d:%d\n' $((T/60/60%24)) $((T/60%60)) $((T%60))
}
bd() {  # bash floating point division
  echo "result = $@ ; scale=4; result / 1" | bc -l
}
baseconvert() {  # convert between bases
  if [[ $# -lt 3 ]]; then
    echo "Usage: baseconvert <number> <numberBase> <desiredBase>"
    return 1
  fi
  echo "obase=$3; ibase=$2; $1" | bc
}
alias convertbase='baseconvert'

alias dos2unix='sed -i -e "s/$//"'
alias unix2dos='sed -i -e "s/$//"'
stats() {  # get permissions, owner, datestamp on file.
    # %a: octal permissions. %U %G: owner's user & group. %n: filename. it only looks awful b/c quoting is awful in bash.
    stat -c "%n: 0%a '%U' '%G' \"$(hres $(date +%s -r $1))\"" $1
}
sortinplace() {
    sort -o "$1" "$1"
}
alias sorti='sortinplace'
#is it running? sometimes you need all the args (i.e., for java processes) to fully grep
psg() {
    echo "UID   PID  PPID   C STIME   TTY           TIME CMD"
    ps -ef | grep -v grep | grep "$@" -i --color=auto  || \
    ps -efww | grep -v grep | grep "$@" -i --color=auto
}
flatten() {  # make folder have maxdepth 1
    find $1 -mindepth 2 -type f -exec mv -i '{}' $1 ';'
}
bringup() {  # bring up contents of folder
    mv $1/* $(dirname $1)
}
alias datestamp="date +%Y%m%d"
alias timestamp="date +%Y%m%d-%H%M%S"
alias sec='echo $SECONDS'
# removes leading/lagging whitespace, compresses duplicate whitespace to single
alias smoosh="sed -e 's/\s\s*/ /g' -e 's/^\s*//' -e 's/\s*$//'"
numcols() {  # display numbers next to column names (one per line) for file or pipe.
  # 1: filename, or number of lines to numcols if reading from a pipe
  # 2: delimiter (defaults to ',')
  if [[ -s "$1" ]]; then
    head $1 -n 1 | sed "s/${2:-,}/\n/g" | awk '{printf("%d %s\n", NR-1, $0)}'
  else
    head -n $1 | sed "s/${1:-,}/\n/g" | awk '{printf("%d %s\n", NR-1, $0)}'
  fi
}

transpose() {  # takes in head arguments (aka filename and -n <numlines>). Works with pipes.
  # adapted from <https://stackoverflow.com/a/1729980/5889131>
  head "$@" | \
    awk '
    { 
        for (i=1; i<=NF; i++)  {
            a[NR,i] = $i
        }
    }
    NF>p { p = NF }
    END {    
        for(j=1; j<=p; j++) {
            str=a[1,j]
            for(i=2; i<=NR; i++){
                str=str" "a[i,j];
            }
            print str
        }
    }'
}

cols() {  # auto-spacing columns like ls does. works with pipes or a file.
  column -t -s ' ' "$@"
}


# find and grep combined because I use it so freaking much.
f() {
  local arg
  declare -a fargs
  declare -a gargs
  for arg; do
    if [[ $arg == "g" ]]; then
      shift
      break
    else
      fargs+=("$arg")
      shift
    fi
  done
  for arg; do
    gargs+=("$arg")
  done
  # find in the current directory any files matching what we specified in fargs
  # grep through those for things with specified in gargs, but always 
  # include color, exclude binary, and write the filename and line number.
  find '.' -type f -name "${fargs[@]}" -exec grep -nIH --color=auto "${gargs[@]}" {} \+
}

# Get man page for a bash builtin (because that's a pain otherwise)
bashman () {
  man bash | less -p "^       $1 "
}

#--eccentricities--
if [[ "$__os" == "mac" ]]; then
    alias rpmivh='sudo rpm --nodeps --ignoreos -ivh'
fi

up() {  # b/c cd ../../.. is a pain to type
  local count="${1:-1}"
  local path=$(printf '../%.0s' $(seq 1 $count))
  echo "cd $path"
  cd "$path"
}

# make cal always display next month as well, which I sometimes want and never don't want.
alias cal='cal -A1 -B1'

mkcd() {
  mkdir -p $1 && cd $1
}
cdl() {
  cd $1 && ls
}
