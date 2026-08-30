# ze.sh: Changelog

## v3.3.2 (2026-08-30)
* **`_ze_open`: honour `_ZE_RESOLVE_SYMLINKS`**: path resolution in file-open
  mode now follows the same symlink policy as directory-jump mode: logical
  paths are preserved by default, physical paths are used only when
  `_ZE_RESOLVE_SYMLINKS` is set.

* **remove `_ZE_EXCLUDE_DIRS` and `_ZE_EXCLUDE_FILES`**: these configuration
  variables served no defensible purpose in ze.sh. The EMS scoring model
  eliminates the score-jump problems that presumably motivated exclusion lists in
  z.sh, and the user controls what gets recorded through the choice of command
  (`ze` vs builtin `cd` for directories; `ze -o` vs `$EDITOR` for files).

## v3.3.1 (2026-08-28)
* **regression fix**: `ze -d` (dirs-mode dig) reported "no match" unconditionally.

* **regression fix**: bare `ze -c` failed to list when run from a directory
  whose path contains characters like `.`.

* **file safety**: binary-file detection no longer misclassifies some valid
  text files (e.g. shell rc files) as binary.

* **FS in pathname**: ze.sh uses `|` as its field separator, so pathnames
  containing a literal `|` corrupt db parsing. This release blocks new such
  entries and cleans up existing ones over time; if you have such a path in your
  history, expect a brief window before it's fully purged. A cleaner fix
  (pathname as last field, removing the delimiter conflict entirely) is deferred.

## v3.3.0 (2026-08-25)
* **file tracking**: added optional file tracking with a separate `zef.db`
database. The new `-o` option opens and records selected text files, with
`-f`/`-d` supporting ranked and filesystem-based file selection.

* **file safety**: added filtering of common binary file types during filesystem
search and checks to prevent non-text files from being opened in the editor.

* **zsh compatibility**: fixed use of `cd` under zsh without requiring
`set -o POSIX_BUILTINS`.

* **robustness**: generalized database initialization, pruning, filtering, and
commit handling to support both directory and file databases, including
additional safeguards against misuse of internal functions.

## v3.2.1 (2026-08-15)
* **`set -u` compatibility**: fixed sourcing and operation under shells using
`nounset`, including unset optional variables, positional arguments, and
exclusion-directory arrays.

* **documentation**: clarified command-line options, updated the default database
size to 640 entries, and documented the shell functions defined by `ze.sh`.

## v3.2.0 (2026-07-15)
* **directory discovery (`-d`)**: added an explicit filesystem discovery mode
using `fd` and `fzf`. The selected directory is immediately added to the ze
database, making it available for subsequent pattern-based jumps.

## v3.1.5 (2026-07-10)
* **dash support**: alias definitions and a `ze()` function provided in
`contrib/dash/ze.dash`. POSIX-compatible except for a single use of `local`
(a `dash` extension), which may be removed for strict compliance.

## v3.1.4 (2026-07-09)
* **backend driver**: `zex.sh` now does pathname resolution first in case the
wrapper does not (or cannot) do this anyway. This especially enables tcsh
support. It remains preferable, however, to let the wrapper handle this where
possible, in which case this new code is not triggered.

* **fzf interface**: the fzf window now provides a terse 'ls' preview.

* **tcsh support**: alias definitions provided in `contrib/tcsh/ze.csh`.

## v3.1.3 (2026-07-04)
* **fish wrapper**: major simplification and improvement of `ze.fish`.
`_ze_record` now accepts an optional second argument specifying the previous
working directory. This allows the wrapper to specify the correct `OLDPWD` value
explicitly. `zex.sh` and `_ze_cd.fish` adjusted accordingly. The wrapper now
delegates option handling to `ze.sh` as far as possible. There remains a single
corner case where `ze.fish` behaves different from native `ze.sh`: the call `ze -t
brandnewdir` where `brandnewdir` is not yet in the db will cd to that dir in
native use while in fish it will be a no-op (handled as failed db lookup). This
really only concerns calls with an additional option, `ze brandnewdir` will always
succeed.

* **fzf interface**: fix infinite recursion corner case (added missing
end-of-option indicator). `_ze_fzf` now prints the selection and delegates
execution of cd to caller.

* **option parser**: simplify parsing logic. Behavioural change: unrecognized
options are now silently stripped from options string prior to command execution.
A call like `ze -s` no longer treats `-s` as pattern but executes as bare `ze`
(which jumps to $HOME). To enforce pattern interpretation, use `ze -- -s`.

## v3.1.2 (2026-07-02)
* **fish wrapper**: `ze -` toggle implemented via `$_ZE_OLDPWD`, matching bash/ksh
semantics.

* **fish wrapper**: `cd -` toggle implemented in `_ze_cd.fish`, matching bash/ksh
semantics.

* **fish wrapper**: valid pathname argument now takes priority over db pattern
matching, in line with native behavior.

* **fish wrapper**: `ze -r`/`-t`/`-c` with no pattern now correctly go to `$HOME`,
matching native behavior.

* **fish wrapper**: fzf abort no longer reported as error.

* **fish wrapper**: `cd.fish` renamed to `_ze_cd.fish`.

* **function rename**: `_ze_add` renamed to `_ze_record` throughout.

* **backend driver**: `zex.sh` `--add` flag renamed to `--record`.

* **backend driver**: `zex.sh` now locates `ze.sh` relative to its own path: both
must reside in the same directory.

## v3.1.1 (2026-06-29)
* **fix oversight**: shellcheck workflow on github now picks up zex.sh as well and
we need to tell shellcheck to ignore the sourcing of ze.sh in that file since it
already has seen it.

## v3.1.0 (2026-06-29)
* **add fish shell support**: wrapper functions (`ze.fish`, `cd.fish`) and a
backend driver (`zex.sh`) have been added. The native implementation remains
unchanged. fish communicates with it through the backend driver. The README has
been updated with fish installation and usage instructions.

* **ze -f now honours -r or -t**: when `-r` or `-t` are specified in addition to
`-l` or `-f`, sort order is adjusted accordingly.

## v3.0.2 (2026-06-23)
* **refactor of _ze**: the previous monolithic _ze function has been split into
three helpers _ze_add, _ze_complete, _ze_query. _ze performs dispatch only.

* **pruning logic**: database rewrite during pruning now uses %.17g formatting
for score serialization, matching the precision used in update logic.

## v3.0.1 (2026-06-23)
* **store scores with full floating point precision**: previously scores were
stored with awk's default OFMT of %.6g. Over large numbers of recurring updates
rounding errors then accumulate, though with no relevant practical impact on
ranking. The db now uses %.17g, guaranteeing lossless IEEE 754 double round-trip
serialisation.

## v3.0.0 (2026-06-20)
* **switch from wall clock to event clock**: this is a fundamental change from
legacy behaviour that immediately resolves all issues with inactivity periods.
The previously used heuristic timeline normalisation is now redundant and has been
removed. The switch to event clock constitutes a breaking change regarding db
semantics (rather than format): column 3 previously held wall-clock timestamps and
now holds the global cumulative cd event count at time of last visit. The z -> ze
migration recipe in the README has been updated accordingly. No further changes
to db layout and semantics anticipated for the future.

* **_ZE_LAMBDA default**: this variable now is expressed in different units
(previously: 1/s, now: 1/cd-action) and the numerical default value now is 8e-3
(half life: 87 cd actions).

## v2.0.0 (2026-06-18)
* **changed default for symlink resolution**: the default now is to _not_ resolve
symlinks to physical paths, see README for further details.

* **remove -x option**: the use case for this option has always been narrow, and
removal of a single database entry is hardly ever desirable given ze.sh's
exponential scoring model, where old infrequently-visited entries naturally decay
to low scores and are eventually removed once the database exceeds its size
limit.

* **timestamp normalisation**: if the inactivity gap since the most recent
recorded visit exceeds a _ZE_LAMBDA dependent tolerance at shell startup, all
timestamps in the database are shifted forward in sync such that the newest
timestamp coincides with the current time, closing the gap. This prevents massive
global score decay during extended periods of inactivity (for example holidays),
while preserving the relative ranking of directories. Stored timestamps do no
longer represent wall clock time but "elapsed activity time": the clock
effectively stops during inactive periods.

* **add db auto-pruning**: db is pruned at shell startup by removing lowest scoring
entries when its size exceeds a threshold (default: 512 entries). The default
threshold is conservative; for typical usage patterns the database is unlikely to
exceed it within the first year or two for typical interactive shell usage.

## v1.1.0 (2026-06-13)
* **smartcase pattern matching**: legacy z.sh implements a strict case-sensitive
pattern matching strategy with a fallback to case-insensitive matching in case no
case-sensitive match is found. ze.sh now uses smartcase matching
(case-insensitive except when pattern contains uppercase characters).

## v1.0.0 (2026-06-13)
Initial release of ze.sh, forked from [z.sh](https://github.com/rupa/z) v1.12.
Primary change: exponential moving sum scoring replacing z.sh's frecency
heuristic. See [Changes from z.sh](README.md#changes-from-zsh) in the README for
the full list.
