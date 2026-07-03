function _ze_cd
    if test "$argv" = "-"
        set argv $_ZE_OLDPWD
    end
    set -l prev $PWD
    builtin cd $argv
    or return $status
    zex.sh --record $PWD $prev &
    set -g _ZE_OLDPWD $prev
end
