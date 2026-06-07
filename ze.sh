#!/usr/bin/env bash
# Copyright (c) 2009 rupa deadwyler. Licensed under the WTFPL license, Version 2
# =====================================================================================
# Modified by Joerg van den Hoff [2026]: exponential scoring, cd-event tracking only.
#
# changes:
#
# 1. replace original scoring model by smooth exponential weight decay (time
# series convolution with monoexponential kernel).
#
# 2. original z relies on zsh and bash hooks that in effect trigger score
# changes for any command in resident directory (including the final cd to a
# different directory). it seems preferable for a directory jumper to only
# monitor cd activity and increase score of the target directory, rather than
# that of the source directory of the cd action. this version removes the hooks;
# only cd actions trigger database updates.
#
# 3. usage: since hooks are gone, builtin cd will not trigger inclusion of new
# directories into the database. instead now simply use 'ze /path/to/directory'
# for that purpose or define
#
#    alias cd=_ze_cd
#
# =====================================================================================
# maintains a jump-list of the directories you actually use
#
# INSTALL:
#     * put something like this in your .bashrc/.zshrc:
#         . /path/to/ze.sh
#     * cd around with 'ze /path/to/directory' for a while to build up the db
#     * PROFIT!!
#     * optionally:
#         set $_ZE_CMD in .bashrc/.zshrc to change the command (default ze).
#         set $_ZE_DIR in shell rc file to change the datafile *directory* (default ~/.ze).
#         set $_ZE_LAMBDA to desired exponential decay rate (default 4e-6/sec, half-life=ln(2)/lambda ~ 170000s ~ 2d).
#         set $_ZE_NO_RESOLVE_SYMLINKS to prevent symlink resolution.
#         set $_ZE_NO_PROMPT_COMMAND if you're handling PROMPT_COMMAND yourself.  ** not honoured by this version **
#         set $_ZE_EXCLUDE_DIRS to an array of directories to exclude.
#         set $_ZE_OWNER to your username if you want use ze while sudo with $HOME kept
#
# USE:
#     * ze foo     # cd to most frecent dir matching foo
#     * ze foo bar # cd to most frecent dir matching foo and bar
#     * ze -r foo  # cd to highest ranked dir matching foo
#     * ze -t foo  # cd to most recently accessed dir matching foo
#     * ze -l foo  # list matches instead of cd
#     * ze -e foo  # emit the best match, don't cd
#     * ze -c foo  # restrict matches to subdirs of $PWD
#     * ze -x      # remove the current directory from the datafile
#     * ze -h      # show a brief help message
#
# DATA FORMAT: path|rank|timestamp|score
#     rank      = visit count (integer, preserved for -r mode)
#     timestamp = unix epoch of last visit (preserved for -t mode)
#     score     = exponential frecency score: running sum of decayed visit weights

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
    elif [[ ! -f "$datafile" ]]; then
        touch "$datafile" || { printf '%s\n' "ze: failed to create $datafile" >&2; return 1; }
    fi
    if [[ ! -O "$datafile" ]]; then
        printf '%s\n' "ze: $datafile not owned by current user" >&2
        return 1
    fi

    # address the old z.sh bug of not dealing with non-GNU OS regarding 'ze -x'.
    # detect which sed we are using and act on it accordingly:
    if sed --version 2>/dev/null | grep -q GNU; then
        _ZE_SED_IFLAG=(-i)
    else
        _ZE_SED_IFLAG=(-i '')
    fi
}

_ZE_DIR=${_ZE_DIR:-$HOME/.ze}
if ! _ze_init; then
    unset -f _ze_init
    return 1
fi
unset -f _ze_init

function _ze_dirs {
    typeset datafile="${_ZE_DIR}/ze.db"
    [[ -f "$datafile" ]] || return
    typeset line
    while IFS= read -r line; do
        # only count directories
        [[ -d "${line%%\|*}" ]] && printf '%s\n' "$line"
    done < "$datafile"
    return 0
}

function _ze_cd {
    if command cd "$@"; then
        if [[ "$_ZE_NO_RESOLVE_SYMLINKS" ]]; then
            (_ze --add "$PWD" &)
        else
            # shellcheck disable=SC2086 # not applicable
            (_ze --add "$(command pwd $_ZE_RESOLVE_SYMLINKS 2>/dev/null)" &)
        fi
        return 0
    else
        return $?
    fi
}

function _ze {
    typeset datafile="${_ZE_DIR}/ze.db"
    typeset lambda="${_ZE_LAMBDA:-4e-6}"

    # add entries
    if [[ "$1" == "--add" ]]; then
        shift

        # $HOME and / aren't worth matching
        [[ "$*" == "$HOME" || "$*" == '/' ]] && return
        # don't track excluded directory trees
        if (( ${#_ZE_EXCLUDE_DIRS[@]} > 0 )); then
            typeset exclude
            for exclude in "${_ZE_EXCLUDE_DIRS[@]}"; do
                case "$*" in "$exclude"*) return;; esac
            done
        fi

        # maintain the data file
        typeset tempfile="$datafile.$RANDOM"

        _ze_dirs | path="$*" \awk -v now="$(\date +%s)" -v lambda="$lambda" -F"|" '
            BEGIN { path = ENVIRON["path"] }
            {
                if( $1 == path ) {
                    hit = 1
                    rank = $2 + 1
                    time = now
                    score = $4 * exp(-lambda * (now - $3)) + 1
                } else {
                    rank = $2
                    time = $3
                    score = $4
                }
                print $1 "|" rank "|" time "|" score
            }
            END {
                if (!hit) print path "|" 1 "|" now "|" 1
            }
        ' 2>/dev/null >| "$tempfile"
        # do our best to avoid clobbering the datafile in a race condition.
        # shellcheck disable=SC2181 # irrelevant
        if (( $? != 0 )) && [[ -f "$datafile" ]]; then
            \env rm -f "$tempfile"
        else
            [[ "$_ZE_OWNER" ]] && chown "$_ZE_OWNER":"$(id -ng "$_ZE_OWNER")" "$tempfile"
            \env mv -f "$tempfile" "$datafile" || \env rm -f "$tempfile"
        fi

    # tab completion
    elif [[ "$1" == "--complete" ]] && [[ -s "$datafile" ]]; then
        _ze_dirs | candidate="$2" \awk -F"|" '
            BEGIN {
                q = ENVIRON["candidate"]
                q = substr(q, 3)
                if( q == tolower(q) ) imatch = 1
                gsub(/ /, ".*", q)
            }
            {
                if( imatch ) {
                    if( tolower($1) ~ q ) print $1
                } else if( $1 ~ q ) print $1
            }
        ' 2>/dev/null

    else
        # list/go
        typeset emit fnd opt typ
        typeset -i list=0
        while [[ "$1" ]]; do case "$1" in
            --) while [[ "$1" ]]; do shift; fnd="$fnd${fnd:+ }$1";done;;
             -) fnd="-";;
            -*) opt=${1:1}; while [[ "$opt" ]]; do case ${opt:0:1} in
                    c) fnd="^$PWD $fnd";;
                    e) emit=1;;
                    h) printf '%s\n' "${_ZE_CMD:-ze} [-cehlrtx] args" >&2; return;;
                    l) list=1;;
                    r) typ="rank";;
                    t) typ="recent";;
                    x) \sed "${_ZE_SED_IFLAG[@]}" -e "\:^${PWD}|.*:d" "$datafile"; return;;
                    *) fnd="$fnd${fnd:+ }$1"; opt='';;

                esac; opt=${opt:1}; done;;
             *) fnd="$fnd${fnd:+ }$1";;
        esac; (( $# > 0 )) && shift; done

        # if bare -c with no args, just list
        [[ "$fnd" == "^$PWD " ]] && list=1
        #  skip pattern matching if real path, empty (go to $HOME), or "-":
        ((!list)) && [[ -d "${fnd:-$HOME}" || "$fnd" == "-" ]] && { _ze_cd "${fnd:-$HOME}"; return; }


        typeset bestmatch
        bestmatch="$(_ze_dirs | fnd="$fnd" \awk -v t="$(\date +%s)" -v list="$list" -v typ="$typ" -v lambda="$lambda" -F"|" '
            function frecent(score, time) {
                # dampen stored score exponentially until t="now" to yield time-weighted current score (or "rank" as z.sh calls it)
                return score * exp(-lambda * (t - time))
            }
            function output(matches, best_match) {
                # list or return the desired directory
                if( list ) {
                    cmd = "sort -g >&2"
                    for( x in matches ) {
                        if( matches[x] ) {
                            printf "%-12s %s\n", matches[x], x | cmd
                        }
                    }
                } else {
                    print best_match
                }
            }
            BEGIN {
                q = ENVIRON["fnd"]
                gsub(" ", ".*", q)
                hi_rank = ihi_rank = -9999999999
            }
            {
                if( typ == "rank" ) {
                    rank = $2
                } else if( typ == "recent" ) {
                    rank = $3 - t
                } else rank = frecent($4, $3)
                if( $1 ~ q ) {
                    matches[$1] = rank
                } else if( tolower($1) ~ tolower(q) ) imatches[$1] = rank
                if( matches[$1] && matches[$1] > hi_rank ) {
                    best_match = $1
                    hi_rank = matches[$1]
                } else if( imatches[$1] && imatches[$1] > ihi_rank ) {
                    ibest_match = $1
                    ihi_rank = imatches[$1]
                }
            }
            END {
                # prefer case sensitive
                if( best_match ) {
                    output(matches, best_match)
                    exit
                } else if( ibest_match ) {
                    output(imatches, ibest_match)
                    exit
                }
                exit(1)
            }
        ')"

        # shellcheck disable=SC2181 # irrelevant
        if (( $? == 0 )); then
          if [[ "$bestmatch" ]]; then
            if [[ "$emit" ]]; then printf '%s\n' "$bestmatch"; else _ze_cd "$bestmatch"; fi
          fi
        else
          return $?
        fi
    fi
}

# shellcheck disable=SC2086,SC2139 # false alarm
alias ${_ZE_CMD:-ze}='_ze 2>&1'

[[ "$_ZE_NO_RESOLVE_SYMLINKS" ]] || _ZE_RESOLVE_SYMLINKS="-P"

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
