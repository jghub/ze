function ze
    # ---------------------------------------------------------------------------
    # ze -- fish wrapper for ze.sh / zex.sh
    # the wrapper detects the 'report only, do not cd' options and acts
    # accordingly:
    #   -e   emit path to stdout
    #   -h   help
    #   -l   list matches with scores
    # in order to use argparse we still need to provide list of +all+ ze options
    # although we do only act on -o in the wrapper (all other actions delegated
    # to ze.sh).
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
    argparse --ignore-unknown c d e f h l o r t -- $argv
    if set -q _flag_e; or set -q _flag_h; or set -q _flag_l
        printf '%s\n' $result
    else if set -q _flag_o
        if test (count $result) -eq 1; and test -f "$result"
            set -l editor $EDITOR
            test -n "$editor"; or set editor vi
            $editor "$result"
            zex.sh --record-file "$result" &
        else
            printf '%s\n' $result
        end
    else if test (count $result) -eq 1; and test -d "$result"
        _ze_cd "$result"
    else
        printf '%s\n' $result
    end
end
