#!/usr/bin/env bash
# fast-track a single literal pathname argument, bypassing the database lookup.
# a leading '--' is accepted before the pathname (e.g. 'ze -- -foo'). If the
# pathname does not exist, leave the arguments unchanged for native ze. wrappers
# must export _ZE_OLDPWD or resolve '-' themselves.
(($# == 0)) || [[ $# == 1 && ( $1 == -- || -z $1 ) ]] && set -- "$HOME"
case $1 in
    --record|--record-file|--open);;
    *)  fastarg=''
        if (($# == 1)) && [[ $1 != -* || $1 == - ]]; then
            fastarg=$1
        elif (($# == 2)) && [[ $1 == -- ]]; then
            fastarg=$2
        fi
        [[ $fastarg == "-" ]] && { printf '%s\n' "${_ZE_OLDPWD:-$HOME}"; exit; }
        [[ -d $fastarg ]] && { printf '%s\n' "$fastarg"; exit; }
    ;;
esac
zexpath=$(command -v "$0") || exit 1
zexdir=${zexpath%/*}            # 'command -v' on a script file always yields a pathname containing '/'
# shellcheck source=/dev/null   ## silence shellcheck instead of running it twice on ze.sh
. "$zexdir/ze.sh" || exit
if [[ $1 == "--record" ]]; then
    shift
    _ze_record "$@"
elif [[ $1 == "--record-file" ]]; then
    shift
    _ze_record "$@" "" files
elif [[ $1 == "--open" ]]; then
    shift
    _ze "$@"
else
    _ze -e "$@"
fi
