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
# shellcheck disable=SC2016  # awk/fzf scripts in single quotes must not expand
function _ze_init {
    typeset datadir=${_ZE_DIR:-$HOME/.ze}
    typeset datafile="$datadir/ze.db"
    if [[ -e $datadir && ! -d $datadir ]]; then
        printf '%s\n' "ze: $datadir exists and is not a directory" >&2
        return 1
    elif [[ ! -d $datadir ]]; then
        mkdir -p "$datadir" || { printf '%s\n' "ze: failed to create $datadir" >&2; return 1; }
    fi
    if [[ -e "$datafile" && ! -f "$datafile" ]]; then
        printf '%s\n' "ze: $datafile exists and is not a regular file" >&2
        return 1
    elif [[ ! -f $datafile ]]; then
        touch "$datafile" || { printf '%s\n' "ze: failed to create $datafile" >&2; return 1; }
    fi
    if [[ -z ${_ZE_OWNER:-} && ! -O $datafile ]]; then
        printf '%s\n' "ze: $datafile not owned by current user" >&2
        return 1
    fi
    typeset -i dbsize dbmax=${_ZE_DBMAX:-640}
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
    _ze_commit $? "$tempfile"
}

function _ze_commit {  ## rc tempfile
    (($# == 2)) || return 1                         # safeguard against manual misuse 
    typeset rc=$1 tempfile=$2
    typeset datafile="${_ZE_DIR:-$HOME/.ze}/ze.db"
    [[ $tempfile == "$datafile."* ]] || return 1    # safeguard against manual misuse
    # do our best to avoid clobbering the datafile in a race condition.
    if ((rc == 0)); then
        [[ ${_ZE_OWNER:-} ]] && chown "$_ZE_OWNER":"$(id -ng "$_ZE_OWNER")" "$tempfile"
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
    typeset datafile="${_ZE_DIR:-$HOME/.ze}/ze.db"
    typeset -a lines
    typeset pathname remains ifs='|'
    while IFS=$ifs read -r pathname remains; do
        [[ -d $pathname ]] && lines+=("$pathname$ifs$remains")
    done < "$datafile"
    (( ${#lines[@]} )) && printf '%s\n' "${lines[@]}"
}

function _ze_cd {
    if command cd "$@"; then
        # ksh93 may emit job-control notifications for the backgrounded helper despite wrapping it in
        # a subshell (this happens not in all terminal emulators, but in most). this makes
        # redirection of stderr to /dev/null necessary.
        if [[ ${_ZE_RESOLVE_SYMLINKS:-} ]]; then
            (_ze_record "$(command pwd -P 2>/dev/null)" &) 2>/dev/null
        else
            (_ze_record "$PWD" &) 2>/dev/null
        fi
    else
        return $?
    fi
}

function _ze_fzf { ## pattern typ
    command -v fzf >/dev/null || { printf '%s\n' "'fzf' not found" >&2; return 1; }
    typeset metric opt=''
    typeset -a fzfopts
    case $2 in
        visits) metric='visit count'; opt='-r';;
        recent) metric='recency'; opt='-t';;
        *)      metric='EMS score';;
    esac
    fzfopts=( -0 -e --no-sort --preview-window='top,19%' --header="dir stack (ranked by $metric)" --color='header:bright-red'
        --preview pathname='{2..}; LC_ALL=C ls -AC --color=always "$pathname"' )
    (set -o pipefail; _ze -l $opt -- "$1" |
        awk -F'\t' '{ buf[NR] = $NF } END { offs = NR+1; while (NR) print offs-NR FS buf[NR--] }' |
            fzf "${fzfopts[@]}" | cut -f2)
}

function _ze_dig { ## fdopts_and_args
    command -v fzf >/dev/null || { printf '%s\n' "'fzf' not found" >&2; return 1; }
    if command -v fd >/dev/null; then
        typeset fdex=fd
    elif command -v fdfind >/dev/null; then
        typeset fdex=fdfind
    else
        printf '%s\n' "'fd' not found" >&2; return 1
    fi
    typeset -a fdargs; fdargs=( -Ipa -td "$@")  # avoid 'typeset -a x=(...)' because of mksh
    # shellcheck disable=SC2124 # this scalar assignment ensures join by single space independent of IFS
    typeset argstring="${fdargs[@]}"
    typeset -a fzfopts
    fzfopts=( -0 -e --no-sort --preview-window='top,19%' --header="$fdex $argstring" --color='header:bright-red'
        --preview pathname='{2..}; LC_ALL=C ls -AC --color=always "$pathname"' )
    (set -o pipefail; $fdex "${fdargs[@]}" | LC_ALL=C sort | nl | fzf "${fzfopts[@]}" | cut -f2)
    (($? == 1)) && printf 'no match\n' >&2
}

function _ze_record { ## pathname [oldpwd]  #2nd arg allows to drive recording from wrappers managing oldpwd themselves
    typeset pathname=${1:-"/"} oldpwd=${2:-$OLDPWD}  # 'pathname default="/" safeguards against manual misuse
    typeset datafile="${_ZE_DIR:-$HOME/.ze}/ze.db"
    typeset lambda=${_ZE_LAMBDA:-8e-3}

    # navigation to $HOME, $oldpwd, or "/" aren't worth recording
    [[ $pathname == "$HOME" || $pathname == "$oldpwd" || $pathname == "/" ]] && return

    if [[ ${_ZE_EXCLUDE_DIRS[*]+x} ]]; then   # avoid unset-array expansion under 'set -u'
        typeset exclude
        for exclude in "${_ZE_EXCLUDE_DIRS[@]}"; do [[ $pathname == "$exclude"* ]] && return; done
    fi

    typeset tempfile
    tempfile=$(mktemp "${datafile}.XXXXXX") || return 1

    pathname=$pathname awk -v lambda="$lambda" -F"|" '
        BEGIN { pathname = ENVIRON["pathname"]; OFS = FS; OFMT = "%.17g" }
        {
            if ($1 == pathname) {
                visits = $2
                ticks = $3
                score = $4
            } else print
            if ($3 > tmax) tmax = $3
        }
        END { print pathname, visits + 1, tmax + 1, score * exp(-lambda * (tmax + 1 - ticks)) + 1 }
    ' "$datafile" 2>/dev/null >| "$tempfile"
    _ze_commit $? "$tempfile"
}

function _ze {
    typeset lambda=${_ZE_LAMBDA:-8e-3}

    typeset fnd='' opt='' typ=''
    typeset -i list=0 finder=0 digger=0 emit=0
    typeset -a fdargs
    while (($#)); do case "$1" in
        --) shift; while (($#)); do fnd+=${fnd:+ }$1; fdargs+=("$1"); shift; done;;
         -) fnd='-';;
        -*) opt=${1:1}; while [[ $opt ]]; do case ${opt:0:1} in
                c) fnd="^$PWD $fnd";;
                d) digger=1;;
                e) emit=1;;
                f) finder=1;;
                h) printf '%s\n' "${_ZE_CMD:-ze} [-cdefhlrt] args" >&2; return;;
                l) list=1;;
                r) typ="visits";;
                t) typ="recent";;
                *) ;;   # silently ignore unrecognized options
            esac; opt=${opt:1}; done;;
         *) fnd+=${fnd:+ }$1; fdargs+=("$1");;
    esac; (($#)) && shift; done

    if ((digger || finder)); then
        ((digger)) && fnd=$(_ze_dig "${fdargs[@]}")
        ((finder)) && fnd=$(_ze_fzf "$fnd" "$typ")
        [[ $fnd ]] || return
        ((emit)) && { printf '%s\n' "$fnd"; return; }
    fi

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
            if (!best_match) exit(1)
            if (list)
                for (x in matches) printf "%-12s\t%s\n", matches[x], x | "LC_ALL=C sort -k1,1g -k2,2"
            else print best_match
        }
    ')
    typeset -i rc=$?; ((rc)) && { printf 'no match\n' >&2; return $rc; }

    if ((list || emit)); then
        printf '%s\n' "$result"
    else
        _ze_cd "$result"
    fi
}

function _ze_complete {  ## candidate
    typeset datafile="${_ZE_DIR:-$HOME/.ze}/ze.db"

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
