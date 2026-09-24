function ze
    if test (count $argv) -eq 0
        _ze_cd
        return
    end
    set -l orig_argv $argv

    # let zex.sh take care completely of all flags/calls that don't require
    # parent shell 'cd' (either [-o|-p] or pure reporting [-e|-h|-l|-V]).
    argparse --ignore-unknown e h l V o p -- $argv
    if set -q _flag_o; or set -q _flag_p
        zex.sh --open $orig_argv
        return
    else if set -q _flag_e; or set -q _flag_h; or set -q _flag_l; or set -q _flag_V
        zex.sh $orig_argv
        return
    end

    # directory navigation requires parent shell builtin 'cd'
    set -l res (zex.sh $orig_argv)
    or return $status

    if test (count $res) -eq 1; and test -d "$res"
        _ze_cd "$res"
    else
        printf '%s\n' $res
    end
end
