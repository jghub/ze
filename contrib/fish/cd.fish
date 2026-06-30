function cd
    if test "$argv" = "-"
        set argv $_ZE_OLDPWD
    end
    set -l prev $PWD
    builtin cd $argv
    or return $status
    if test $PWD != $prev
        set -g _ZE_OLDPWD $prev
        zex.sh --record $PWD &
    end
end
