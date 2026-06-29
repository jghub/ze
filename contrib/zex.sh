#!/usr/bin/env bash
# shellcheck source=/dev/null  ## to silence shellcheck while avoiding to run it twice on ze.sh
. ze.sh
if [[ $1 == '--record' ]]; then
    _ze_record "$2"
else
    _ze "$@"
fi
