#!/usr/bin/env bash
# catch the pathname resolution cases in case the wrapper does not (or cannot) do this himself.
# Handling of 'ze -' depends on the wrapper exporting _ZE_OLDPWD into the environment before the
# zex.sh call.
(($# == 0)) && set -- "$HOME"
if (($# == 1)); then
    [[ $1 == "-" ]] && { printf '%s\n' "${_ZE_OLDPWD:-$HOME}"; exit; }
    [[ -d $1 ]] && { printf '%s\n' "$1"; exit; }
fi
zexpath=$(command -v "$0") || exit 1
zexdir=${zexpath%/*}  # safe since 'command -v' returns '/' containing pathname in the supported shells
# shellcheck source=/dev/null  ## silence shellcheck instead of running it twice on ze.sh
. "$zexdir/ze.sh"
if [[ $1 == "--record" ]]; then
    shift
    _ze_record "$@"
elif [[ $1 == "--record-file" ]]; then
    shift
    _ze_record "$@" "" files
else
    _ze -e "$@"
fi
