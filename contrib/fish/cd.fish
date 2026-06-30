function cd
    set -l prev $PWD
    builtin cd $argv
    or return $status
    if test $PWD != $prev
        zex.sh --record $PWD &
    end
end
