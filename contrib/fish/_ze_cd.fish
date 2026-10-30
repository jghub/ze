function _ze_cd
    if test "$argv" = "-"
        set argv $_ZE_OLDPWD
    end
    set -l prev $PWD
    set -lx CDPATH ''
    builtin cd $argv
    or return $status
    set -l cur $PWD
    if test -n "$_ZE_RESOLVE_SYMLINKS"
        set cur (command pwd -P)
    end
    zex.sh --record $cur $prev &
    set -gx _ZE_OLDPWD $prev
end
