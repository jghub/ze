# include these aliases in your .cshrc. 'ze' and 'cd' might then be used interchangeably
# for pathname and pattern based navigation. zex.sh and ze.sh need to reside in a common
# directory that is on your search path.
alias ze 'setenv _ZE_OLDPWD "$owd"; set _ze_prev="$cwd"; set _ze_res=`zex.sh \!*`; if ($status == 0 && "$_ze_res" != "") chdir "$_ze_res"; zex.sh --record "$cwd" "$_ze_prev"; endif'
alias cd ze
alias ze-l 'zex.sh -l'
# support for file tracking:
alias ze-o  'set _ze_res=`zex.sh -o \!*`; if ($status == 0) vi "$_ze_res"; zex.sh --record-file "$_ze_res"; endif'
alias ze-p  'set _ze_res=`zex.sh -p \!*`; if ($status == 0) less -NRS "$_ze_res"; zex.sh --record-file "$_ze_res"; endif'
alias ze-lo 'zex.sh -ol'
