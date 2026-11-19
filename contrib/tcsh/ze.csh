# include these aliases in your .cshrc. 'ze' and 'cd' might then be used interchangeably
# for pathname and pattern based navigation. zex.sh and ze.sh need to reside in a common
# directory that is on your search path.
alias ze 'setenv OLDPWD "$owd"; set _ze_prev="$cwd"; set _ze_res=`zex.sh \!*`; if ($status == 0 && "$_ze_res" != "") chdir "$_ze_res"; if ("$cwd" != "$_ze_prev") zex.sh --record "$cwd" "$_ze_prev"'
alias cd ze
# support for file tracking:
alias ze-o 'zex.sh --open -o \!*'
alias ze-p 'zex.sh --open -p \!*'
# reporting options:
alias ze-e 'zex.sh -e'
alias ze-h 'zex.sh -h'
alias ze-l 'zex.sh -l'
alias ze-lo 'zex.sh -ol'
alias ze-V 'zex.sh -V'
