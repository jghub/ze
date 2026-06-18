# ze.sh -- a frecency-based directory jumper
# Originally derived from z.sh: https://github.com/rupa/z
# Repository: https://github.com/jghub/ze
#
# Copyright (c) 2009 rupa deadwyler
# Copyright (c) 2026 Joerg van den Hoff (jghub)
#
# ze.sh is a substantially modified fork of z.sh. Original z.sh was distributed
# under the WTFPL v2. ze.sh is distributed under the MIT License.
# -----------------------------------------------------------------------------
# shellcheck shell=ksh
function _ze_init {
    _ZE_DIR=${_ZE_DIR:-$HOME/.ze}
    typeset datafile="${_ZE_DIR}/ze.db"
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

    typeset -i now
    ((now = $(\date +%s)))
    typeset tempfile lambda=${_ZE_LAMBDA:-4e-6}
    tempfile=$(mktemp "${datafile}.XXXXXX") || return 1
    \awk -F'|' -v now="$now" -v lambda="$lambda" '
        BEGIN { OFS = FS }
        { lines[NR] = $0; if ($3 > tlast) tlast = $3 }
        END {
            tol = 0.5 * log(2)/lambda
            bump = now - tlast
            if (bump <= tol || NR == 0) exit(1)  # signal _ze_commit to tidy up
            for (i = 1; i <= NR; i++) {
                split(lines[i], f, FS)
                f[3] += bump
                print f[1], f[2], f[3], f[4]
            }
        }' "$datafile" >| "$tempfile"
    _ze_commit $? "$tempfile" "$datafile"

    typeset -i dbsize dbmax=${_ZE_DBMAX:-512}
    dbsize=$(wc -l < "$datafile")
    ((dbsize <= dbmax)) && return  # or ...
    # ... auto-prune db by removing lowest scoring entries:
    typeset -i margin nprune dbfrac=32
    tempfile=$(mktemp "${datafile}.XXXXXX") || return 1
    ((margin = dbmax/dbfrac))
    ((nprune = dbsize - dbmax + margin))
    (   set -o pipefail  # sub-process avoids overriding user settings (pipefail' unavailable in mksh: error in middle of chain would not be caught)
        _ze_dirs 0 | awk -v now="$now" -v lambda="$lambda" -F'|' '
            BEGIN { OFS = FS } { $5 = $4 * exp(-lambda * (now - $3)); print }' |
                LC_ALL=C sort -t'|' -k5,5g -k1,1 | awk -F'|' -v nprune="$nprune" '
                    BEGIN {OFS = FS} NR > nprune { print $1, $2, $3, $4 }' >| "$tempfile"
    )
    _ze_commit $? "$tempfile" "$datafile"
}

function _ze_commit {  ## rc tempfile datafile
    # do our best to avoid clobbering the datafile in a race condition.
    # shellcheck disable=SC2181 # irrelevant
    typeset rc=$1 tempfile=$2 datafile=$3
    if ((rc)); then
        \rm -f "$tempfile"
    else
        [[ $_ZE_OWNER ]] && chown "$_ZE_OWNER":"$(id -ng "$_ZE_OWNER")" "$tempfile"
        \mv -f "$tempfile" "$datafile" || \rm -f "$tempfile"
    fi
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
        _ze_dirs 0 | path="$1" awk -v now="$(date +%s)" -v lambda="$lambda" -F"|" '
            BEGIN { path = ENVIRON["path"]; OFS = FS }
            $1 == path {
                hit = 1
                $2 = $2 + 1
                $4 = $4 * exp(-lambda * (now - $3)) + 1
                $3 = now
            }
            # we specify fields explicitly rather than using simple "print" to
            # allow for minor db sanitation in case it was manually edited and
            # some trailing garbage left behind in the edited record(s):
            { print $1, $2, $3, $4 }
            END { if (!hit) print path, 1, now, 1 }
        ' 2>/dev/null >| "$tempfile"
        _ze_commit $? "$tempfile" "$datafile"

    # tab completion
    elif [[ $1 == "--complete" ]] && [[ -s $datafile ]]; then
        _ze_dirs 1 | candidate=$2 awk -F"|" '
            BEGIN {
                q = ENVIRON["candidate"]
                sub(/^[^ ]+[ ]+/, "", q)   # replace previous fixed-offset substring to account for possibility of non-default ZE_CMD value
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

        # in cd mode, delegate to _ze_cd immediately if fnd is a real path, empty, or "-":
        ((!(list || emit))) && [[ -d ${fnd:-$HOME} || $fnd == "-" ]] && { _ze_cd "${fnd:-$HOME}"; return; }

        typeset result
        result=$(_ze_dirs 1 | fnd=$fnd awk -v now="$(date +%s)" -v list="$list" -v typ="$typ" -v lambda="$lambda" -F"|" '
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
                    weight = $3 - now
                } else weight = $4 * exp(-lambda * (now - $3))  # exponential decay of recorded score until "now"

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
