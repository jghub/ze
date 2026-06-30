#!/usr/bin/env bash
zexdir=$(dirname -- "$(command -v -- "$0")") || exit 1
# shellcheck source=/dev/null  ## to silence shellcheck while avoiding to run it twice on ze.sh
. "$zexdir/ze.sh"
if [[ $1 == '--record' ]]; then
    _ze_record "$2"
else
    _ze "$@"
fi
