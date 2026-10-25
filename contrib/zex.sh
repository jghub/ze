#!/usr/bin/env bash
# fast-track a single literal pathname argument, bypassing the database lookup.
# '-' resolves to the previous directory. wrappers must either export _ZE_OLDPWD
# or resolve '-' themselves.
(($# == 0)) && set -- "$HOME"
if (($# == 1)); then
    [[ $1 == "-" ]] && { printf '%s\n' "${_ZE_OLDPWD:-$HOME}"; exit; }
    [[ -d $1 ]] && { printf '%s\n' "$1"; exit; }
fi
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
