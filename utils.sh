#!/bin/bash

#--------------------------------------BUILTIN------------------------------------------------------
alias bashrc='vim ~/.bashrc; . ~/.bashrc'
alias profilerc='vim ~/.bash_profile; . ~/.bash_profile'
#did you know aliases can use other aliases? watch out for that
#make aliases work with sudo
alias sudo='sudo '
#use sudo -i to become root and keep your bashrc & vimrc
alias -- -i='-E bash --rcfile $HOME/.bashrc'

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
    find . -type f -not -path "*.git*" -exec sed -i -e "s>$1>$2>g" {} \+;
  else
    xargs sed -i -e "s:$1:$2:g"
  fi
}
alias s.='findsed'
# -a: dotfiles. -I: not those dotfiles. -C: color.
alias tr33='tree -a -C -I ".git|.vim|.idea|.DS_Store|*cache*" -L 3'
alias tree='tree -a -C -I ".git|.vim|.idea|.DS_Store|*cache*"'

#--utils--
export et="TZ=\"America/New_York\""
export utc="TZ=\"Etc/UTC\""
export mt="TZ=\"America/Denver\""
alias et="TZ=\"America/New_York\""
alias utc="TZ=\"Etc/UTC\""
alias mt="TZ=\"America/Denver\""
alias at="TZ=\"Australia/Sydney\""
fromet() {  # $1 Military time in ET
  date -d "$et $1 today" +"%H%M %Z"
}
frommt() {  # $1 Military time in MT
  date -d "$mt $1 today" +"%H%M %Z"
}
fromutc() {  # $1 Military time in UTC
  date -d "$utc $1 today" +"%H%M %Z"
}
fromat() {  # $1 Military time in Australia
  date -d "$at $1 20220405" +"%y%m%d %H%M %Z"
}

hrbytes() {  # human readable bytes. numfmt is cool.
  local num;
  if [[ $# -lt 1 ]]; then
    read num;
  else
    num="$1"
  fi
  local from
  if [[ "$num" =~ [KMGTPEZY]i$ ]]; then
    from="--from=iec-i"
  elif [[ "$num" =~ [KMGTPEZY]$ ]]; then
    from="--from=si"
  fi
  # purposefully not quoting from to avoid empty string issues
  numfmt --to=iec-i --suffix=B --format="%.3f" $from "${num//,}"
}
alias hrb='hrbytes'
es() {  # epoch seconds
  date +%s
}
ems() {  # epoch ms
  date +%s%3N
}
hres() {  # human readable epoch seconds
  local d
  if [[ $# -lt 1 ]]; then
    read d;
  else
    d="$1"
  fi
  date -d @$d
}
hrems() {  # human readable epoch milliseconds
  local T
  if [[ $# -lt 1 ]]; then
    read T;
  else
    T="$1"
  fi
  date -d @$((T/1000))
}
hrs() {  # human readable seconds.
  local D T
  if [[ $# -lt 1 ]]; then
    read T;
  else
    T="$1"
  fi
  ((D=T/60/60/24)) && printf '%d days ' $D
  printf '%d:%d:%d\n' $((T/60/60%24)) $((T/60%60)) $((T%60))
}
hrms() {  # human readable seconds.
  local ms s
  if [[ $# -lt 1 ]]; then
    read ms;
  else
    ms="$1"
  fi
  s=$(( ms / 1000 ))
  hrs $s
}
hrnum() {  # human readable numbers (commas and SI format)
  # can read from files via pipe and from args
  # -c : comma format only (1234 -> 1,234)
  # -s : scientific notation (1234 -> 1.3K)
  # -b (default): both formats (1234 -> 1,234 aka 1.3K)
  local format=b
  local nums=''
  if [[ $# -gt 0 ]]; then
    for arg in "$@"; do
      if [[ $arg =~ ^-[a-z]$ ]]; then
        format=${arg##?}
      elif [[ $arg =~ ^[0-9.]+$ ]]; then
        nums+="$arg"$'\n'
      else
        echo "Dunno how to parse $arg, can only accept [0-9.]+, -c / -s / -b"
        return 1
      fi
    done
  fi
  if [[ -n "$nums" ]]; then
    # herestring would add another trailing newline
    echo -n "$nums" | hrnum -$format
  else
    while read -r num || [[ -n "$num" ]]; do
      if [[ $format == "b" ]]; then
        printf "%'.f aka " "$num"
        numfmt --to=si --format="%.1f" "$num"
      elif [[ $format == "s" ]]; then
        numfmt --to=si --format="%.1f" "$num"
      elif [[ $format == "c" ]]; then
        printf "%'f\n" "$num"
      fi
    done
  fi
}
bd() {  # bash floating point division
  # deletes comma and underscore separators
  echo "result = $(echo "$@" |tr -d ',_' | sed -e 's/[Ee]/*10^/g') ; scale=4; result / 1" | bc -l
}
sum() {
  if [[ $# -lt 1 ]]; then
    awk '{for(i=1;i<=NF;i++) sum+=$i}END{print sum}'
  else
    awk '{for(i=1;i<=NF;i++) sum+=$i}END{print sum}' <<< "$@"
  fi
}
average() {
  if [[ $# -lt 1 ]]; then
    # nested if prevents for loop from triggering and incrementing n on empty lines
    awk '{for(i=1;i<=NF;i++) {if (i<=NF) sum+=$i; n++ }} END {print sum / n}'
  else
    # nested if prevents for loop from triggering and incrementing n on empty lines
    awk '{for(i=1;i<=NF;i++) {if (i<=NF) sum+=$i; n++ }} END {print sum / n}' <<< "$@"
  fi
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
fix10() {  # calculate fix checksum from a message delimited by |
  local msg
  if [[ $# -lt 1 ]]; then
    read msg;
  else
    msg="$1"
  fi
  echo "$msg" | \
    sed -e 's/10=[0-9]\{3\}|\?$//' | \
    awk 'BEGIN{FS="";for(n=0;n<256;n++)ord[sprintf("%c",n)]=n;ord["|"]=1}{for(i=1;i<=NF;i++) a+=ord[$(i)]}END{print a%256}'
}
