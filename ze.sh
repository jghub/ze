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
    typeset -i dbsize dbmax=${_ZE_DBMAX:-512}
    dbsize=$(wc -l < "$datafile")
    ((dbsize <= dbmax)) && return

    typeset -i margin nprune dbfrac=32
    typeset tempfile lambda=${_ZE_LAMBDA:-8e-3}
    tempfile=$(mktemp "${datafile}.XXXXXX") || return 1
    ((margin = dbmax/dbfrac))
    ((nprune = dbsize - dbmax + margin))
    (   set -o pipefail  # sub-process avoids overriding user settings
        awk -F'|' -v lambda="$lambda" '
            BEGIN { OFS = FS; OFMT = "%.17g" }
            {
                lines[NR] = $0
                if ($3 > tmax) tmax = $3
            }
            END {
                for (i = 1; i <= NR; i++) {
                    split(lines[i], f)
                    print f[1], f[2], f[3], f[4], f[4] * exp(-lambda * (tmax - f[3]))
                } 
            }' "$datafile" | LC_ALL=C sort -t'|' -k5,5g -k1,1 | awk -F'|' -v nprune="$nprune" '
                    BEGIN { OFS = FS; OFMT = "%.17g" } NR > nprune { print $1, $2, $3, $4 }' >| "$tempfile"
    )
    _ze_commit $? "$tempfile" "$datafile"
}

function _ze_commit {  ## rc tempfile datafile
    # do our best to avoid clobbering the datafile in a race condition.
    # shellcheck disable=SC2181 # irrelevant
    typeset rc=$1 tempfile=$2 datafile=$3
    if ((rc == 0)); then
        [[ $_ZE_OWNER ]] && chown "$_ZE_OWNER":"$(id -ng "$_ZE_OWNER")" "$tempfile"
        \mv -f "$tempfile" "$datafile" || \rm -f "$tempfile"
    else
        \rm -f "$tempfile"
    fi
}

if ! _ze_init; then
    unset -f _ze_commit _ze_init
    return 1
fi
unset -f _ze_init

function _ze_dirs {
    typeset datafile="${_ZE_DIR}/ze.db"
    typeset -a lines
    typeset line
    while IFS= read -r line; do
        [[ -d ${line%%\|*} ]] && lines+=("$line")
    done < "$datafile"
    (( ${#lines[@]} )) && printf '%s\n' "${lines[@]}"
}

function _ze_cd {
    if command cd "$@"; then
        # ksh93 may emit job-control notifications for the backgrounded helper despite wrapping it in
        # a subshell (this happens not in all terminal emulators, but in most). this makes
        # redirection of stderr to /dev/null necessary (and the subshell might thus go away, actually).
        if [[ $_ZE_RESOLVE_SYMLINKS ]]; then
            (_ze_record "$(command pwd -P 2>/dev/null)" &) 2>/dev/null
        else
            (_ze_record "$PWD" &) 2>/dev/null
        fi
    else
        return $?
    fi
}

function _ze_fzf { ## pattern typ
    typeset opt
    if [[ $2 == 'visits' ]]; then opt='-r'; elif [[ $2 == 'recent' ]]; then opt='-t'; fi
    _ze -l $opt -- "$1" |
        awk -F'\t' '{ buf[NR] = $NF } END { offs = NR+1; while (NR) print offs-NR FS buf[NR--] }' |
            fzf -e --no-sort | cut -f2
}

function _ze_record { ## pathname [oldpwd]  #2nd arg allows to drive recording from wrappers managing oldpwd themselves
    typeset pathname=$1 oldpwd=${2:-$OLDPWD}
    typeset datafile="${_ZE_DIR}/ze.db"
    typeset lambda=${_ZE_LAMBDA:-8e-3}

    # navigation to $HOME, $oldpwd, or "/" aren't worth recording, 
    [[ $pathname == "$HOME" || $pathname == "$oldpwd" || $pathname == "/" ]] && return

    typeset exclude
    for exclude in "${_ZE_EXCLUDE_DIRS[@]}"; do [[ $pathname == "$exclude"* ]] && return; done

    typeset tempfile
    tempfile=$(mktemp "${datafile}.XXXXXX") || return 1

    pathname=$pathname awk -v lambda="$lambda" -F"|" '
        BEGIN { pathname = ENVIRON["pathname"]; OFS = FS; OFMT = "%.17g" }
        {
            if ($1 == pathname) {
                hit = 1
                visits = $2
                ticks = $3
                score = $4
            } else print
            if ($3 > tmax) tmax = $3
        }
        END {
            now = tmax + 1    # advance global event clock
            if (hit) {
                visits = visits + 1
                score = score * exp(-lambda * (now - ticks)) + 1
                print pathname, visits, now, score
            } else print pathname, 1, now, 1
        }
    ' "$datafile" 2>/dev/null >| "$tempfile"
    _ze_commit $? "$tempfile" "$datafile"
}

function _ze_complete {  ## candidate
    typeset datafile="${_ZE_DIR}/ze.db"

    [[ -s $datafile ]] || return

    _ze_dirs | candidate=$1 awk -F"|" '
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
}

function _ze {
    typeset lambda=${_ZE_LAMBDA:-8e-3}

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
                *) ;;   # silently ignore unrecognized options
            esac; opt=${opt:1}; done;;
         *) fnd="$fnd${fnd:+ }$1";;
    esac; (($#)) && shift; done

    ((finder)) && {
        fnd=$(_ze_fzf "$fnd" "$typ")
        [[ $fnd ]] || return
        ((emit)) && { printf '%s\n' "$fnd"; return; }
    }

    [[ $fnd == "^$PWD " ]] && list=1  # if bare -c with no args, just list

    # in cd mode, delegate to _ze_cd immediately if fnd is a real path, empty, or "-":
    ((!(list || emit))) && [[ -d ${fnd:-$HOME} || $fnd == "-" ]] && { _ze_cd "${fnd:-$HOME}"; return; }

    typeset result
    result=$(_ze_dirs | fnd=$fnd awk -v list="$list" -v typ="$typ" -v lambda="$lambda" -F"|" '
        BEGIN {
            q = ENVIRON["fnd"]
            gsub(" ", ".*", q)
            lq = tolower(q)
            case_sensitive = (q != lq)
            if (!case_sensitive) q = lq
            hi_score = -1e300
        }
        {
           lines[NR] = $0
           if ($3 > tmax) tmax = $3
        }
        END {
            for (i = 1; i <= NR; i++) {
                split(lines[i], f)
                candidate = case_sensitive ? f[1] : tolower(f[1])
                if (candidate ~ q) {
                    if (typ == "visits") {
                        weight = f[2]
                    } else if (typ == "recent") {
                        weight = f[3]
                    } else weight = f[4] * exp(-lambda * (tmax - f[3]))
                    matches[f[1]] = weight
                    if (weight > hi_score) {
                        best_match = f[1]
                        hi_score = weight
                    }
                }
            }
            if (list)
                for (x in matches) printf "%-12s\t%s\n", matches[x], x | "LC_ALL=C sort -k1,1g -k2,2"
            else if (best_match)
                print best_match
            else exit(1)
        }
    ')
    typeset -i rc=$?; ((rc)) && { printf 'no match\n' >&2; return $rc; }
    [[ $result ]] || return

    if ((list || emit)); then
        printf '%s\n' "$result"
    else
        _ze_cd "$result"
    fi
}

if type compctl >/dev/null 2>&1; then
    # zsh completion
    function _ze_zsh_tab_completion {
        typeset compl
        # shellcheck disable=SC2162 # false alarm
        read -l compl
        # shellcheck disable=SC2034,SC2206,SC2296 # false alarm
        reply=(${(f)"$(_ze_complete "$compl")"})
    }
    compctl -U -K _ze_zsh_tab_completion "${_ZE_CMD:-ze}"
elif type complete >/dev/null 2>&1; then
    # bash completion
    # shellcheck disable=SC2016 # false alarm
    complete -o filenames -C '_ze_complete "$COMP_LINE"' "${_ZE_CMD:-ze}"
fi

# shellcheck disable=SC2086,SC2139 # false alarm
alias ${_ZE_CMD:-ze}='_ze'
