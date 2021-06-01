#!/bin/bash

# Provides `pd` and `vd`, which are used to remember previous directories and files, respectively.
# Both additionally accept nicknames when first resolving the resource, which can be used as an additional access
# method.

#------------------------------------------ENVIRONMENT-------------------------------
# maximum number of items to keep in the history.
# there's there's a TUI, infinite is unwieldy.
__maxhist=40

__cdfile="$PWD/pd_store/recent_dirs.txt"
__tempcdfile="$PWD/pd_store/temp_dirs.txt"
__vimfile="$PWD/pd_store/recent_files.txt"

touch $__cdfile $__tempcdfile $__vimfile

#we use printf because we're adults now.
[[ ! -f "$__cdfile" ]] && printf "%s%b" "$HOME" "\t" >> "$__cdfile"
[[ ! -f "$__vimfile" ]] && printf "%s%b" "$HOME/.bashrc" "\t" >> "$__vimfile"


# View the history files - mainly for debugging purposes.
alias pdh='vim $__cdfile'
alias vdh='vim $__vimfile'

#--------------------------------------PD-----------------------------------------------------------
__pdrc="$PWD/pd.sh"
# shellcheck disable=SC2139
alias pdrc="vim $__pdrc; . $__pdrc"


expandtilde() {
    #I only care about 2 cases: ~(/...) and ~user(/...)
    #add more if you want to be more of an adult.
    case "$1" in
        (\~)        echo "$HOME";;
        (\~/*)      echo "$HOME/${1#\~/}";;
        (\~[^/]*)   local user=${1%%/*}
                    user=$(getent passwd | grep "^${user:1}:" | cut -f6 -d:)
                    echo "$user/${1#*/}";;
        (*)         echo "$1";;
    esac
}


#------------------------------------------PD----------------------------------------
pd() {
    #pd [path [nickname]]. Let's pretend it's short for persistent directory
    #pd stores your $__maxhist most recent directories (that you visited with pd) in a file
    #to go to a new location, simply use `pd /path/to/directory/`
    #to go to a previously visited directory, `pd direc` or any other partial completion
    #will work! you can add nicknames as well, via `pd /path/2/directory/ mydirnick`
    #nicknames are truncated to the first 6 characters when displayed (but not in search)
    #matching is done by completion, first on nicknames, then on last dir in path,
    #then on the entire path. multiple matches will return the highest numbered option
    #pd without arguments will give you a list of previously visited directories.
    #you can select from these using the full path, partial word searching, or number.
    #fails if directory names use tabs/newlines. You deserve failure in that case.
    #TODO: add pd rm option which removes something that matches your arg
    local choice
    local dest
    local nickname
    local num
    nickname=$2
    if [[ $# -ge 1 ]]; then
        choice="$1"
        if [[ "$choice" == "-" ]]; then
            pd "$OLDPWD"
            return
        fi
        if [[ "$choice" == "--remove" ]]; then
            #things about removing matches
            :;
        fi
        #I don't want to store $HOME in my file, because it's 1 char to type.
        # ~ in cmd line args already expands.
        if [[ "$choice" == "$HOME" ]]; then
            cd ~
            return
        fi
        num=$(cat "$__cdfile" | wc -l)
    else
        #note: in general, `mapfile`, `PS3` and `select` is best practice
        #does not work here b/c this is more complicated
        num=0
        while IFS=$'\t' read -r -u 9 saved_dest saved_nickname; do
            #make prettier version with only basic ~ compression:
            #printf: %: var. -: left-justify. num: that many padded spaces. 
            #.num:truncate to that width. s:string
            (( ++num )) #++i so bash -e doesn't throw on (( 0 )) 
            printf '%-8.8s %-2s %-39s %-s\n' "$saved_nickname" "$num" "${saved_dest/#$HOME/'~'}"
        done 9< "$__cdfile"
        #if you chose nothing, ask again
        # ~ here does not expand by default
        read -e -p "        ? " choice nickname
    fi
    #if you chose nothing again, ditch.
    if [[ -z "$choice" ]]; then
        return
    fi
    #if the choice is not a number that we have stored
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( $choice >= $num )); then
        #make sure $choice isn't in ~ form
        choice=$(expandtilde "$choice")
        #expand choice from ../relative/path /to/absolute/path:
        dest=$(readlink -e "$choice")
        #this won't work if you have tabs/newlines in your directory names
        #you deserve it to fail if that's true. jesus.
        if [[ -d "$dest" && ! $(grep "$__cdfile" -e "^$dest	") ]]; then
            #if it's a real place but we've never seen it
            #first, add to file
            printf "$dest\t$nickname\n" > "$__tempcdfile"
            cat "$__cdfile" >> "$__tempcdfile"
            #delete from file until under the line cap
            local linecount
            linecount=$(wc -l < "$__cdfile")
            if (( linecount > __maxhist )); then
                (( linecount -= __maxhist ))
                #we delete with truncation:
                #https://stackoverflow.com/a/48717431/5889131 
                truncate -s -$(tail -$linecount "$__tempcdfile" | wc -c) "$__tempcdfile"
            fi
            #then move
            mv "$__tempcdfile" "$__cdfile"
            cd "$choice"
            return
        elif [[ -z "$dest" ]]; then
            #if it's not meant to be a real place, so let's search
            #first the nickname, then the final directory name, then full path:
            dest=$(grep "$__cdfile" -e "	$choice$" || \
                   grep "$__cdfile" -e "	$choice.*$" || \
                   grep "$__cdfile" -e "	.*$choice.*$" || \
                   grep "$__cdfile" -e "$choice/*	" || \
                   grep "$__cdfile" -e "$choice[^/]*/*	" || \
                   grep "$__cdfile" -e "$choice")
            dest=$(echo "$dest" | tail -n 1 | cut -f1) #default delimiter is \t
            #if we still don't have a destination, sudoku
            [[ -z "$dest" ]] && return 1
        fi
        if [[ -f "$dest" ]]; then
            echo "$dest is not a directory"
            return 1
        fi
        #else: it is a real place and we've seen it, so $dest is valid either way:
        #the regex matches all lines that contain it.
        #-s: silent (no TUI, faster); -n: no undo buffer (swap file)
        #g: global range, re: the regex, m0: move to line0, x: write-quit
        vim -n -e -s -c "g:^$dest\t:m0|x" "$__cdfile"
        # vim -c "g:^$dest\t:m0|x" "$__cdfile"
        cd "$dest" || { \
            local line && \
            line="$(head -n 1 $__cdfile)" && \
            sed -i '1d' "$__cdfile" && \
            local args && \
            read -p "dir doesn't exist. Edit path: " -i "$line" -e args && \
            declare -p args && \
            pd $args && \
            return; } #specifically not quoting to expand arguments. 
    else
        #get destination by line number
        dest=$(sed "${choice}q;d" "$__cdfile" | cut -f1) #cut removes tabs
        #move it to the top
        vim -n -e -s -c "g:^$dest\t:m0|x" "$__cdfile"
        cd "$dest" || { \
            line=$(head -n 1 "$__cdfile") && \
            sed -i '1d' "$__cdfile" && \
            local args && \
            read -p "dir doesn't exist. Edit path: " -i "$line" -e args && \
            declare -p args && \
            pd $args && \
            return; } #specifically not quoting to expand arguments.
    fi
    #if we have a nickname to give the directory, do so
    if [[ -n "$nickname" ]]; then
        vim -n -e -s -c "0s/\t/\t$nickname/|x" "$__cdfile"
        # sed -i -e "1s;\t.*$;\t$nickname;" "$__cdfile"
    fi
}


#------------------------------------------VD----------------------------------------
vd() {
    #let's pretend it's short for vim destinations.
    #basically the same as pd, but for files instead of directories. read pd first.
    #to make a new file (i.e., couldn't ls that file before), you need an absolute or relative
    #path, like `vd ~/newfile.txt` or `vd ./newfile.txt` b/c otherwise vd can't tell
    #if you're trying to search through your previous file lists or not. 
    #tl;dr: non-existent files need ./ in front of their name with vd to avoid ambiguity.
    #vd doesn't know how to fix broken paths. vd will not receive more support.
    local choice
    local target
    local nickname=$2
    if [[ $# -ge 1 ]]; then
        choice="$1"
        local num=$(cat "$__vimfile" | wc -l)
    else
        #make prettier version with only basic ~ compression:
        local num=0
        while IFS=$'\t' read -r -u 9 saved_target saved_nickname; do
            #make prettier version with only basic ~ compression:
            ((++num)) #++i so bash -e doesn't throw on (( 0 )) 
            #quotes required on mac, unsure if they affect linux
            printf '%-6.6s %-2s %-39s %-s\n' "$saved_nickname" "$num" "${saved_target/#$HOME/'~'}"
        done 9< "$__vimfile"
        # while IFS= read -r -u 9 line || [[ -n $line ]]; do
            # printf '%-2s %s\n' "$num" "${line/#$HOME/~}"
            # ((++num)) #++i so bash -e doesn't throw on (( 0 ))
        # done 9< "$__vimfile"
        #if you chose nothing, ask again
        read -e -p "       ? " choice nickname
    fi
    #if you chose nothing again, ditch.
    if [[ -z "$choice" ]]; then
        return
    fi
    #if the choice is not a number in our file
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice >= num )); then
        #make sure $choice isn't in ~ form
        choice=$(expandtilde "$choice")
        #expand choice from ../relative ./path form:
        if [[ "$choice" =~ ^[/~.] ]]; then
            target=$(readlink -f "$choice")
        else
            target=$(readlink -e "$choice")
        fi
        #if we found a directory, ignore it
        if [[ -d "$target" ]]; then
            target=
        fi
        #this won't work if you have tabs/newlines in your directory/file-names
        #you deserve it to fail if that's true. jesus.
        echo "$target"
        if [[ -n "$target" && ! $(grep "$__vimfile" -e "^$target	") ]]; then
            #if it's a real place (or could be) but we've never seen it
            #can't test with -f because we might be making a new file here
            #first, add to target
            sed -i "1s;^;$target\t$nickname\n;" "$__vimfile"
            #delete from target until under the line cap
            while (( $(cat "$__vimfile" | wc -l) > $__maxhist )); do
                sed -i '$ d' "$__vimfile" #inefficient for v large $__maxhist
            done
            #then move
            vim "$choice"
            return
        elif [[ -z "$target" ]]; then
            #if it's not a real place, so let's search
            #first the nickname, then the final directory name, then full path:
            target=$(grep "$__vimfile" -e "	$choice$" || \
                   grep "$__vimfile" -e "	$choice.*$" || \
                   grep "$__vimfile" -e "	.*$choice.*$" || \
                   grep "$__vimfile" -e "$choice/*	" || \
                   grep "$__vimfile" -e "$choice[^/]*/*	" || \
                   grep "$__vimfile" -e "$choice")
            target=$(echo "$target" | tail -n 1 | cut -f1)
            #if still no target, the only possible option is that it's a new file
            #in a permission denied location. 
            #we can test that assuming we have sudo privileges.
            #comment out the next if block (the -z $target block; keep the -n $target)
            #if you don't.
            if [[ -z "$target" ]]; then
                if [[ "$choice" =~ ^[/~.] ]]; then
                    target=$(sudo readlink -f "$choice")
                else
                    target=$(sudo readlink -e "$choice")
                fi
                sed -i "1s;^;$target\t$nickname\n;" "$__vimfile"
                #delete from target until under the line cap
                while (( $(cat "$__vimfile" | wc -l) > $__maxhist )); do
                    sed -i '$ d' "$__vimfile" #inefficient for large targets
                done
                vim "$target"
                return
            fi
        fi
        #else: it is a real place and we've seen it, so $target is valid either way:
        #except if the file has been moved.
        vim -c "g:^$target\t:m0" -cwq "$__vimfile"
        vim "$target"
    else
        #get destination by line number
        target=$(sed "${choice}q;d" "$__vimfile" | cut -f1) #cut removes tabs
        #move it to the top
        vim -c "g:^$target\t:m0" -cwq "$__vimfile"
        vim "$target"
    fi
    #if we have a nickname to give the directory, do so
    if [[ -n "$nickname" ]]; then
        sed -i -e "1s;\t.*$;\t$nickname;" "$__vimfile"
    fi
}


