#!/usr/bin/env bash
zexpath=$(command -v "$0") || exit 1
# Parameter expansion is safe here -- command -v returns a pathname (absolute or
# relative) containing '/' in the supported shells (bash, zsh, ksh93, mksh):
zexdir=${zexpath%/*}
# shellcheck source=/dev/null  ## to silence shellcheck while avoiding to run it twice on ze.sh
. "$zexdir/ze.sh"
if [[ $1 == "--record" ]]; then
    shift
    _ze_record "$@"
else
    _ze -e "$@"
fi
