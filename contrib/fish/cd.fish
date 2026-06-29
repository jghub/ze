function cd
    set -l prev $PWD
    builtin cd $argv
    and test $PWD != $prev
    and zex.sh --add $PWD &
end
