#!/usr/bin/env bash
# ze.sh -- a frecency-based directory jumper
# fork of z.sh (https://github.com/rupa/z)
# Repository: https://github.com/jghub/ze
# Copyright (c) 2009 rupa deadwyler. Licensed under the WTFPL license, Version 2
# Modified by Joerg van den Hoff [2026]. See README.md for details.

function _ze_init {
    typeset  datafile="${_ZE_DIR}/ze.db"
    if [[ -e $_ZE_DIR && ! -d $_ZE_DIR ]]; then
        printf '%s\n' "ze: $_ZE_DIR exists and is not a directory" >&2
        return 1
    elif [[ ! -d $_ZE_DIR ]]; then
        mkdir -p "$_ZE_DIR" || { printf '%s\n' "ze: failed to create $_ZE_DIR" >&2; return 1; }
    fi
    if [[ -e "$datafile" && ! -f "$datafile" ]]; then
        printf '%s\n' "ze: $datafile exists and is not a regular file" >&2
        return 1
    elif [[ ! -f $datafile ]]; then
        touch "$datafile" || { printf '%s\n' "ze: failed to create $datafile" >&2; return 1; }
    fi
    if [[ -z $_ZE_OWNER && ! -O $datafile ]]; then
        printf '%s\n' "ze: $datafile not owned by current user" >&2
        return 1
    fi

    typeset -i dbmax=1024 dbfrac=32 dbsize 
    dbsize=$(wc -l < "$datafile")
    ((dbsize <= dbmax)) && return  # or ...
    # ... auto-prune db by removing lowest scoring entries
    typeset tempfile prunefile result lambda=${_ZE_LAMBDA:-4e-6}
    typeset -i margin nprune
    tempfile=$(mktemp "${datafile}.XXXXXX") || return 1
    prunefile=$(mktemp "${datafile}.XXXXXX") || { \rm -f "$tempfile"; return 1; }
    ((margin = dbmax/dbfrac))
    ((nprune = dbsize - dbmax + margin))
    result=$(_ze_dirs 0 | \awk -v t="$(date +%s)" -v lambda="$lambda" -F'|' '
        BEGIN { OFS = FS } 
        {
            $5 = $4 * exp(-lambda * (t - $3))
            print | "LC_ALL=C sort -t\\| -k5,5g -k1,1"
        }' |
        \awk -F'|' -v nprune="$nprune" 'BEGIN {OFS = FS} NR <= nprune { print $1, $2, $3, $4 }'
    )
    # process substitution does not work for mksh, otherwise we just could use:
    #_ze_dirs 0 | \grep -F -x -v -f <(printf '%s\n' "$result") >| "$tempfile"
    printf '%s\n' "$result" >| "$prunefile" && _ze_dirs 0 | \grep -Fxv -f "$prunefile" >| "$tempfile"
    # shellcheck disable=SC2181 # irrelevant
    if (( $? )) && [[ -f $datafile ]]; then
        \rm -f "$tempfile"
    else
        [[ $_ZE_OWNER ]] && chown "$_ZE_OWNER":"$(id -ng "$_ZE_OWNER")" "$tempfile"
        \mv -f "$tempfile" "$datafile.pruned" || \rm -f "$tempfile"
    fi
    \rm -f "$prunefile"
}

function _ze_dirs { ## 1/0 (1 (default): skip stale entries, 0: keep stale entries)
    typeset datafile="${_ZE_DIR}/ze.db"
    typeset -a lines
    typeset line
    if (( ${1:-1} )); then
        while IFS= read -r line; do
            [[ -d ${line%%\|*} ]] && lines+=("$line")
        done < "$datafile"
    else
        while IFS= read -r line; do lines+=("$line"); done < "$datafile"
    fi
    (( ${#lines[@]} )) && printf '%s\n' "${lines[@]}"
}

function _ze_cd {
    if command cd "$@"; then
        if [[ $_ZE_RESOLVE_SYMLINKS ]]; then
            (_ze --add "$(command pwd -P 2>/dev/null)" &)
        else
            (_ze --add "$PWD" &)
        fi
    else
        return $?
    fi
}

function _ze_fzf { ## pattern
    typeset selection
    selection=$(_ze -l "$1" |
        awk -F'\t' '{ buf[NR] = $NF } END { offs = NR+1; while (NR) print offs-NR FS buf[NR--] }' |
        fzf -e --no-sort | cut -f2) && [[ $selection ]] && _ze_cd "$selection"
}

function _ze {
    typeset datafile="${_ZE_DIR}/ze.db"
    typeset lambda=${_ZE_LAMBDA:-4e-6}

    # add entries
    if [[ $1 == "--add" ]]; then
        shift

        # $HOME and / aren't worth matching, neither is $OLDPWD
        [[ $1 == "$HOME" || $1 == "$OLDPWD" || $1 == "/" ]] && return

        typeset exclude
        for exclude in "${_ZE_EXCLUDE_DIRS[@]}"; do [[ $1 == "$exclude"* ]] && return; done

        typeset tempfile
        tempfile=$(mktemp "${datafile}.XXXXXX") || return 1

        # _ze_dirs 1/0: do/don't ignore stale db entries
        _ze_dirs 0 | path="$1" \awk -v now="$(date +%s)" -v lambda="$lambda" -F"|" '
            BEGIN { path = ENVIRON["path"]; OFS = FS }
            $1 == path {
                hit = 1
                $2 = $2 + 1
                $4 = $4 * exp(-lambda * (now - $3)) + 1
                $3 = now
            }
            # we specify fields explictly rather than using simple "print" to
            # allow for minor db sanitation in case it was manually edited and
            # some trailing garbage left behind in the edited record(s):
            { print $1, $2, $3, $4 }
            END { if (!hit) print path, 1, now, 1 }
        ' 2>/dev/null >| "$tempfile"
        # do our best to avoid clobbering the datafile in a race condition.
        # shellcheck disable=SC2181 # irrelevant
        if (( $? )) && [[ -f $datafile ]]; then
            \rm -f "$tempfile"
        else
            [[ $_ZE_OWNER ]] && chown "$_ZE_OWNER":"$(id -ng "$_ZE_OWNER")" "$tempfile"
            \mv -f "$tempfile" "$datafile" || \rm -f "$tempfile"
        fi

    # tab completion
    elif [[ $1 == "--complete" ]] && [[ -s $datafile ]]; then
        _ze_dirs 1 | candidate=$2 \awk -F"|" '
            BEGIN {
                q = ENVIRON["candidate"]
                q = substr(q, 3)
                lq = tolower(q)
                case_sensitive = (q != lq)
                if (!case_sensitive) q = lq
                gsub(/ /, ".*", q)
            }
            {
                candidate = case_sensitive ? $1 : tolower($1)
                if (candidate ~ q) print $1
            }
        ' 2>/dev/null

    # list/go
    else
        typeset fnd opt typ
        typeset -i list=0 finder=0 emit=0
        while [[ $1 ]]; do case "$1" in
            --) while [[ $1 ]]; do shift; fnd=$fnd${fnd:+ }$1; done;;
             -) fnd='-';;
            -*) opt=${1:1}; while [[ $opt ]]; do case ${opt:0:1} in
                    c) fnd="^$PWD $fnd";;
                    e) emit=1;;
                    f) finder=1;;
                    h) printf '%s\n' "${_ZE_CMD:-ze} [-cefhlrt] args" >&2; return;;
                    l) list=1;;
                    r) typ="visits";;
                    t) typ="recent";;
                    *) fnd="$fnd${fnd:+ }$1"; opt='';;

                esac; opt=${opt:1}; done;;
             *) fnd="$fnd${fnd:+ }$1";;
        esac; (($#)) && shift; done

        ((finder)) && { _ze_fzf "$fnd"; return; }

        [[ $fnd == "^$PWD " ]] && list=1  # if bare -c with no args, just list

        # delegate to _ze_cd immediately if fnd is a real path, empty, or "-":
        ((!list)) && [[ -d ${fnd:-$HOME} || $fnd == "-" ]] && { _ze_cd "${fnd:-$HOME}"; return; }

        typeset result
        result=$(_ze_dirs 1 | fnd=$fnd \awk -v t="$(date +%s)" -v list="$list" -v typ="$typ" -v lambda="$lambda" -F"|" '
            function output(matches, best_match, list,   x) {
                if (list) {
                    for( x in matches ) printf "%-12s\t%s\n", matches[x], x | "LC_ALL=C sort -k1,1g -k2,2"
                } else print best_match
            }
            BEGIN {
                q = ENVIRON["fnd"]
                gsub(" ", ".*", q)
                lq = tolower(q)
                case_sensitive = (q != lq)
                if (!case_sensitive) q = lq
                hi_score = -1e300
            }
            {
                if (typ == "visits") {
                    weight = $2
                } else if( typ == "recent") {
                    weight = $3 - t
                } else weight = $4 * exp(-lambda * (t - $3))  # exponential decay of recorded score until time t ("now")

                candidate = case_sensitive ? $1 : tolower($1)
                if (candidate ~ q) {
                    matches[$1] = weight
                    if (weight > hi_score) {
                        best_match = $1
                        hi_score = weight
                    }
                }
            }
            END {
                if (!best_match) exit(1)
                output(matches, best_match, list)
            }
        ')
        typeset -i rc=$?; ((rc)) && return $rc
        [[ $result ]] || return

        if ((list || emit)); then
            printf '%s\n' "$result"
        else
            _ze_cd "$result"
        fi
    fi
}

_ZE_DIR=${_ZE_DIR:-$HOME/.ze}
if ! _ze_init; then
    unset -f _ze _ze_cd _ze_dirs _ze_fzf _ze_init 
    return 1
fi
unset -f _ze_init

if type compctl >/dev/null 2>&1; then
    # zsh completion
    function _ze_zsh_tab_completion {
        typeset compl
        # shellcheck disable=SC2162 # false alarm
        read -l compl
        # shellcheck disable=SC2034,SC2206,SC2296 # false alarm
        reply=(${(f)"$(_ze --complete "$compl")"})
    }
    compctl -U -K _ze_zsh_tab_completion "${_ZE_CMD:-ze}"
elif type complete >/dev/null 2>&1; then
    # bash completion
    # shellcheck disable=SC2016 # false alarm
    complete -o filenames -C '_ze --complete "$COMP_LINE"' "${_ZE_CMD:-ze}"
fi

# shellcheck disable=SC2086,SC2139 # false alarm
alias ${_ZE_CMD:-ze}='_ze'
