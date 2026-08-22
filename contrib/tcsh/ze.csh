# include these aliases in your .cshrc. 'ze' and 'cd' might then be used interchangeably
# for pathname and pattern based navigation. zex.sh and ze.sh need to reside in a common
# directory that is on your search path.
alias ze 'setenv _ZE_OLDPWD "$owd"; set _ze_res=`zex.sh \!*`; if ($status == 0) chdir "$_ze_res"; zex.sh --record "$cwd" "$owd"; endif'
alias zd 'ze -d --'
alias zf 'ze -f'
alias zl 'zex.sh -l'
alias cd ze
# support for file tracking:
alias zo  'set _ze_res=`zex.sh -o \!*`; if ($status == 0) vile "$_ze_res"; zex.sh --record-file "$_ze_res"; endif'
alias zod 'set _ze_res=`zex.sh -od -- \!*`; if ($status == 0) vile "$_ze_res"; zex.sh --record-file "$_ze_res"; endif'
alias zof 'set _ze_res=`zex.sh -of \!*`; if ($status == 0) vile "$_ze_res"; zex.sh --record-file "$_ze_res"; endif'
alias zol 'zex.sh -ol'
