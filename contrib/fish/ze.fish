function ze
    # ---------------------------------------------------------------------------
    # ze -- fish wrapper for ze.sh / zex.sh
    # the wrapper detects the 'report only, do not cd' options and acts
    # accordingly:
    #   -e   emit path to stdout
    #   -h   help
    #   -l   list matches with scores
    #   -o   open file in editor
    #   -p   open file in pager
    # in order to use argparse we need to provide a list of +all+ ze options
    # although we do only act on [-o|-p] in the wrapper (all other actions
    # delegated to ze.sh).
    # ---------------------------------------------------------------------------
    if not set -q argv
        _ze_cd
        return
    else if test (count $argv) -eq 1
        if test "$argv[1]" = -
            _ze_cd -
            return
        else if test -d "$argv[1]"
            _ze_cd "$argv[1]"
            return
        end
    end
    set -l result (zex.sh $argv)
    test -n "$result"; or return
    argparse --ignore-unknown c d e f h l o p r t V -- $argv
    if set -q _flag_e; or set -q _flag_h; or set -q _flag_l
        printf '%s\n' $result
        return
    end
    if set -q _flag_o; or set -q _flag_p
        if test (count $result) -ne 1; or not test -f "$result"
            printf '%s\n' $result
            return
        end
        set -l opcmd
        set -l lastchoice
        if set -q _flag_o
            if set -q _ZE_OPEN; and test -n "$_ZE_OPEN"
                set opcmd $_ZE_OPEN
            else if set -q VISUAL; and test -n "$VISUAL"
                set opcmd $VISUAL
            else if set -q EDITOR; and test -n "$EDITOR"
                set opcmd $EDITOR
            else
                set opcmd nano
            end
            set lastchoice vi
        else
            if set -q _ZE_PAGER; and test -n "$_ZE_PAGER"
                set opcmd $_ZE_PAGER
            else if set -q PAGER; and test -n "$PAGER"
                set opcmd $PAGER
            else
                set opcmd less -NRS
            end
            set lastchoice more
        end
        command -q $opcmd[1]; or set opcmd $lastchoice
        $opcmd "$result"
        zex.sh --record-file "$result" &
        return
    end
    if test (count $result) -eq 1; and test -d "$result"
        _ze_cd "$result"
    else
        printf '%s\n' $result
    end
end
