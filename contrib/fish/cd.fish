function cd
    set -l prev $PWD
    builtin cd $argv
    and test $PWD != $prev
    and zex.sh --record $PWD &
end
