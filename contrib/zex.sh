#!/usr/bin/env bash
# shellcheck source=/dev/null  ## to silence shellcheck while avoiding to run it twice on ze.sh
. ze.sh
if [[ $1 == '--add' ]]; then
    _ze_add "$2"
else
    _ze "$@"
fi
