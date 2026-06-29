#!/usr/bin/env bash
. ze.sh
if [[ $1 == '--add' ]]; then
    _ze_add "$2"
else
    _ze "$@"
fi
