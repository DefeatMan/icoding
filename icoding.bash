#!/usr/bin/bash

function _flist_comp() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    [[ $COMP_CWORD == 1 ]] && COMPREPLY=($(compgen -W "add pop vim commit reset rm ls diff clean help" -- $cur)) || COMPREPLY=()
}

function flist_init() {
    script_shell="$(readlink /proc/$$/exe | sed "s/.*\///")"
    complete -F _flist_comp -o default flist
    [[ -z ${FLIST+x} ]] && export FLIST=~/.icoding
    [[ -z ${FLIST_BACKUP+x} ]] && export FLIST_BACKUP=$FLIST/backup
    export FLIST_TXT=$FLIST/to_be_ready_open.txt
    FLIST_BACKUP_S=${FLIST_BACKUP//\//\\\/}
    ! [[ -d $FLIST ]] && mkdir -p "$FLIST"
    ! [[ -d $FLIST_BACKUP ]] && mkdir "$FLIST_BACKUP"
    ! [[ -f $FLIST_TXT ]] && touch "$FLIST_TXT"
}

function _flist_help() {
  echo "Usage: flist {pattern} {FILES}/{NUMBER,}
   add      Add FILES into to_be_ready_open list
   pop      Remove FILES by rowid from to_be_ready_open list
   vim      Open FILES with VIM editor which in to_be_ready_open list
commit      Commit FILES to backup dir
 reset      Reset FILES from backup dir
    rm      Remove FILES in backup dir
    ls      List FILES in backup dir
  diff      Compare FILES between files from backup to workspace
 clean      Clean ALL FILES in backup dir
  help      Display this help and exit
            Default output to_be_ready_open list"
}

function _flist_clean() {
    [[ "$script_shell" == "zsh" ]] && setopt localoptions rmstarsilent && setopt no_nomatch
    [[ -n `realpath -q "$FLIST_BACKUP"/*` ]] && rm -rf "$FLIST_BACKUP"/*
    true > "$FLIST_TXT"
}

function _flist_append() {
    [[ $1 == "${1%[[:space:]]*}" ]] && echo $1 >> "$FLIST_TXT" || echo \"$1\" >> "$FLIST_TXT"
}

function _flist_add() {
    local v=${1//\//\\\/}
    cat "$FLIST_TXT" | [[ -n `sed -n "/^$v$/p"` ]] || _flist_append $1
    echo "add <<" $1
}

function _flist_commit() {
    mkdir -p "${FLIST_BACKUP}$(dirname $1)"
    cp -v "$1" "${FLIST_BACKUP}$1"
}

function _flist_reset() {
    mkdir -p "$(dirname $1)"
    cp -v "${FLIST_BACKUP}$1" "$1"
}

function _flist_rm() {
    local v=$(dirname ${FLIST_BACKUP}$1)
    [[ -n ${FLIST_BACKUP}$1 ]] && rm -f "${FLIST_BACKUP}$1"
    [[ -d $v ]] && rmdir --ignore-fail-on-non-empty -p $(dirname ${FLIST_BACKUP}$1)
}

function _flist_diff() {
    local s=`echo $1 | sed -n "s/^$FLIST_BACKUP_S//gp"`
    if [[ -n `diff -q $1 $s` ]];
    then
      echo -e "\e[30;103m@@diff:\e[39;49m $1 \e[93m$s\e[39m"
      diff "$1" "$s"
      echo ""
    fi
}

function _flist_pop() {
    local filelist=""
    for v in "$@"
    do
        echo $v | [[ -n "`sed -n '/^[0-9],*[0-9]*$/p'`" ]] && filelist=$filelist$v"d;"
    done
    sed -i "$filelist" "$FLIST_TXT"
    cat -n "$FLIST_TXT"
}

function _flist_ls() {
    if [[ $# == 1 || $@ == "" ]];
    then
      find "$FLIST_BACKUP$(realpath ${1:-/})" -type f | sed "s/^$FLIST_BACKUP_S//g"
    else
        for v in "$@"
        do
            [[ $v != $1 ]] && echo ""
            local s=$(realpath $v) 
            echo -e "\e[30;103m$s:\e[39;49m"
            find "$FLIST_BACKUP$s" -type f | sed "s/^$FLIST_BACKUP_S//g"
        done
    fi
}

function _flist_ctrl() {
    [[ "${script_shell}" == "zsh" ]] && setopt no_nomatch
    for v in ${@:2}
    do
        local filename=$(realpath $v)
        for vv in $filename
        do
            if [[ -d $vv ]];
            then
                [[ -n `realpath -q "$vv"/*` ]] && [[ $(ls -A $vv) ]] && _flist_ctrl $1 "${vv}"/*
            else
                $1 "$vv"
            fi
        done
    done
}

function flist() {
    flist_init
    case $1 in
      add)
        _flist_ctrl _flist_add ${@:2}
        ;;
      pop)
        _flist_pop ${@:2}
        ;;
      vim)
        [[ -f $FLIST_TXT ]] && cat "$FLIST_TXT" | xargs -o vim
        ;;
      commit)
        _flist_ctrl _flist_commit ${@:2}
        ;;
      reset)
        _flist_ctrl _flist_reset ${@:2}
        ;;
      rm)
        _flist_ctrl _flist_rm ${@:2}
        ;;
      ls)
        _flist_ls ${@:2}
        ;;
      diff)
        if [[ ${@:2} == "" ]]; then
            _flist_ctrl _flist_diff "$FLIST_BACKUP"/
        else
            local _real_path=()
            for v in ${@:2}
            do
                _real_path+=($FLIST_BACKUP$(realpath $v))
            done
            _flist_ctrl _flist_diff ${_real_path[@]}
        fi
        ;;
      clean)
        _flist_clean
        ;;
      help)
        _flist_help
        ;;
      cd)
        [[ $2 == "" ]] && cd $FLIST_BACKUP || cd "$FLIST_BACKUP$(realpath $2)"
        ;;
      *)
        [[ $@ == "" ]] && cat -n "$FLIST_TXT" || echo "unknown params, use help for help"
        ;;
    esac
}
