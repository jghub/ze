function ze
    if test (count $argv) -eq 0
        _ze_cd
        return
    end

    # classify short options (including bundles) up to '--'; patterns/paths never start with '-'
    set -l open 0
    set -l report 0
    for a in $argv
        switch $a
            case --
                break
            case '--*'
                continue
            case '-?*'
                string match -qr -- '^-[^[:space:]]*[op]' "$a"; and set open 1
                string match -qr -- '^-[^[:space:]]*[ehlV]' "$a"; and set report 1
        end
    end
    if test $report -eq 1
        zex.sh $argv
        return
    else if test $open -eq 1
        zex.sh --open $argv
        return
    end

    # directory navigation requires parent shell builtin 'cd'
    set -l res (zex.sh $argv)
    or return $status
    test (count $res) -gt 0; or return
    if test (count $res) -eq 1; and test -d "$res"
        _ze_cd "$res"
    else
        printf '%s\n' $res    # e.g. bare -c yields a list
    end
end
