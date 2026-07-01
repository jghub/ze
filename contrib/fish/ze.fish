function ze
    # ---------------------------------------------------------------------------
    # ze -- fish wrapper for ze.sh / zex.sh
    #   -c   restrict to subdirs of $PWD
    #   -e   emit path to stdout
    #   -f   fzf interactive selector
    #   -h   help
    #   -l   list matches with scores
    #   -r   rank by visit count
    #   -t   rank by recency
    # ---------------------------------------------------------------------------
    argparse c e f h l r t -- $argv; or return 1
    set -l modifiers $_flag_c $_flag_r $_flag_t

    if set -q _flag_h
        echo "ze [-cefhlrt] [args]" >&2
        return 0
    end

    if set -q _flag_f
        set -l result (zex.sh -l $modifiers $argv |
            awk -F'\t' '{buf[NR]=$NF} END{offs=NR+1; while(NR) print offs-NR FS buf[NR--]}' |
            fzf -e --no-sort | cut -f2)
        test -n "$result"
        and _ze_cd $result
        return 0
    else if set -q _flag_l; or set -q _flag_e
        zex.sh $_flag_l $_flag_e $modifiers $argv
    else
        if not set -q argv[1]
            _ze_cd
        else if test (count $argv) -eq 1; and test "$argv[1]" = "-"
            _ze_cd -
        else if test (count $argv) -eq 1; and test -d "$argv[1]"
            _ze_cd $argv[1]
        else
            set -l result (zex.sh -e $modifiers $argv)
            if test -n "$result"
                _ze_cd $result
            else
                _ze_cd $argv
            end
        end
    end
end
