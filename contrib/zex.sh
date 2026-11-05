#!/usr/bin/env bash
# fast-track a single literal pathname argument, bypassing the database lookup. everything else is
# dispatched to `_ze -N`, which centralizes general literal-path priority, '--' handling, and pattern
# fallback, ensuring wrappers behave like native ze. '-' resolves to the previous directory. The
# environment seen by zex.sh must hold the caller's previous directory in OLDPWD (dash exports it,
# the tcsh alias sets it) or no OLDPWD at all (the fish wrapper clears any inherited value and
# exports _ZE_OLDPWD instead), because an inherited OLDPWD takes precedence over _ZE_OLDPWD.
(($# == 0)) && set -- "$HOME"
if (($# == 1)); then
    [[ $1 == "-" ]] && { printf '%s\n' "${OLDPWD:-${_ZE_OLDPWD:-$HOME}}"; exit; }
    [[ $1 != -* && -d $1 ]] && { printf '%s\n' "$1"; exit; }
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
    _ze -N "$@"
fi
