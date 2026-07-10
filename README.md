# ze.sh

ze.sh is a shell-native directory jumper for `bash`, `zsh`, `ksh93`, and `mksh` (e.g.
Termux/Android). ze.sh originated as a fork of [z.sh](https://github.com/rupa/z)
but has been substantially rewritten. The interface and the cd-driven database
update model remain z.sh-like while the scoring model, internal structure, and
shell compatibility approach are independent reimplementations. ze.sh replaces
z.sh's frecency heuristic with an exponential moving sum (EMS) scoring model and
includes numerous behavioral improvements (see [list of changes](#changes-from-zsh)).
`fish` is supported via a lightweight wrapper around the native implementation.

## Installation

For native use with `bash`, `zsh`, `ksh`, and `mksh`, source from your shell rc file:

```sh
source /path/to/ze.sh
```

**Important**: ze.sh is designed to use `ze` for all navigation, including
pathname-based directory changes. Ordinary `cd` commands are not tracked by
default. To also track `cd`, add

```sh
alias cd=_ze_cd
```

to your shell rc file. This triggers database updates on every `cd` while
retaining native `cd` semantics. To additionally enable pattern-based navigation
on every `cd` invocation, use `_ZE_CMD=cd` (see Configuration).

For `fish`, install ze.sh, zex.sh, and the wrapper functions:

    cp ze.sh zex.sh ~/bin   # or any directory on $PATH. 
    chmod +x ~/bin/zex.sh
    cp contrib/fish/ze.fish contrib/fish/_ze_cd.fish ~/.config/fish/functions/

`zex.sh` is the generic backend driver used by all wrappers, defaulting to `bash`
for execution. Changing the shebang to `ksh` (`#!/usr/bin/env ksh`) reduces
latency by about 40% if available, though latency remains imperceptible in
interactive use either way.

`tcsh` users may include the alias definitions in `contrib/tcsh/ze.csh` in their
.cshrc file to use `ze.sh` from `tcsh`.

A POSIX-compatible wrapper for `dash` and similar minimal shells is provided in
`contrib/dash/ze.dash`. Source it from your `.profile`. It uses the `local`
keyword (supported by `dash` as an extension) which may be removed for strict
POSIX compliance.

## Design

ze.sh departs from z.sh in three fundamental ways:

**Event clock**: z.sh couples score decay to wall-clock time. This causes a
well-known failure mode: after any extended period of inactivity, all scores decay
toward zero, and the first directories visited on return immediately dominate the
ranking regardless of prior history. The underlying issue is that elapsed
wall-clock time during shell inactivity carries no information about directory
relevance. ze.sh replaces wall-clock time with an event clock: each cd action
advances the clock by one tick. The clock stands still during inactive periods
and no score decay occurs during such periods.

**Scoring**: z.sh's scoring heuristic multiplies a cumulative visit count by a
recency factor derived from the most recent visit timestamp. This can produce
undesirable ranking — a long-unvisited directory with a large historical visit
count can jump near or to the top on first revisit. ze.sh replaces this with a
monoexponential decay kernel: the score is the sum of individual, exponentially
decayed unit impulses at each visit time, representing an exponential moving
sum (mathematically equivalent to the Unix load-average computation, but applied
to a binary directory-visit event stream). The decay rate is controlled by
`_ZE_LAMBDA` (default `8e-3`/cd-action, half-life `ln(2)/lambda` ≈ 87 cd actions
(about 2 days at 40 cd/day)).

**Tracking**: z.sh requires shell precommand hooks (`PROMPT_COMMAND` in bash,
`precmd` in zsh) that fire on every command, updating the score of whichever
directory the shell is currently in. This means _any_ command executed in
directory A increases that directory's score. For a directory jumper, using
command activity _within_ a directory as a measure of how often a user might want
to _reach_ that directory (so that it should be scored highly) seems inferior to
monitoring only cd activity. Therefore, ze.sh removes the hooks entirely. Only
explicit `ze`-based directory changes (or bare `cd` if aliased to `_ze_cd`)
trigger database updates.

For broader shell compatibility, ze.sh furthermore uses `typeset` instead of
`local` and `[[`/`(())` instead of `[`/`test` throughout. The latter is not a
compatibility requirement — all target shells support `[` — but `[[` is a shell
keyword with cleaner semantics: no word splitting on unquoted variables,
unambiguous `&&`/`||` operators, and pattern matching support. In ze.sh, the
`function f { ... }` definition style is used throughout instead of POSIX-style
`f() { ... }` — in ksh93 and mksh, `typeset` variables are only locally scoped
inside functions defined with the `function` keyword, whereas POSIX style
functions do not provide local scoping in these shells. For historical reasons,
z.sh used `[` and `f() { }` but was never actually POSIX-compatible
due to its use of arrays, process substitution, and shell-specific completion
builtins — ze.sh drops the pretense and uses the cleaner syntax consistently.

## Database format

The database at `~/.ze/ze.db` is a plain text file with one entry per line:

```
path|visits|ticks|score
```

| Field | Meaning |
|-------|---------|
| `path` | absolute directory path *(1)* |
| `visits` | cumulative visit count for this entry, incremented on each visit |
| `ticks` | global cumulative cd event count at time of last visit, used for score computation at query time and `-t` (recent) mode |
| `score` | exponentially decayed cumulative visit score as of the last visit |

*(1)*: ze.sh retains entries for directories that no longer exist (e.g. unmounted
filesystems) and filters them at match time rather than pruning them on update.

## Usage

```
ze [-cdefhlrt] [pattern|path|-]
```

| Invocation      | Behavior                                |
|-----------------|-----------------------------------------|
| `ze`            | cd to $HOME                             |
| `ze -`          | cd to previous directory                |
| `ze path`       | cd to path directly (real path wins)    |
| `ze pattern`    | cd to highest scoring match for pattern |
| `ze -c pattern` | restrict matches to subdirs of $PWD     |
| `ze -d [fdargs]`| discover and jump via fd+fzf, register in database |
| `ze -e pattern` | print match instead of cd               |
| `ze -f pattern` | use fzf for interactive selection       |
| `ze -l pattern` | list matches according to current score |
| `ze -r pattern` | sort by visit count                     |
| `ze -t pattern` | sort by recency of last visit           |

## Changes from z.sh

| Area             | z.sh                                          | ze.sh                                          |
|------------------|-----------------------------------------------|------------------------------------------------|
| Tracking         | precommand hook fires on every command        | tracks explicit cd navigation (`ze`, optionally aliased `cd`)|
| Scoring          | frecency heuristic with common-prefix override *(1)* | exponential moving sum on event clock, no common-prefix override |
| Path dispatch    | no pathname check, categorical pattern matching *(2)* | real paths take precedence over pattern matching |
| Bare call        | lists database                                | follows builtin cd semantics: cd to $HOME      |
| `-` argument     | not handled, lists database                   | follows builtin cd semantics: cd to previous directory |
| Stale db entries | pruned on next cd action                      | retained in db, filtered at match time *(3)*         |
| `-x` option      | deletes current dir from database             | removed *(4)* |
| `-l` option      | output to stderr, not pipeable                | output to stdout, pipeable to pager etc.       |
| Database         | single flat file `~/.z`                       | directory `~/.ze/`, database `~/.ze/ze.db`     |
| Shell compat     | bash/zsh only                                 | bash/zsh/ksh93/mksh (native), fish (wrapper)   |
| Init             | minimal, no safety checks                     | validates db path, ownership, file type        |
| Concurrency      | tempfile-name collisions may cause db corruption | `mktemp(1)` eliminates tempfile-name collisions, concurrent updates remain "last writer wins" |
| `-f` option      | not available                                 | interactive fzf selector (if fzf installed)    |
| `-d [fdargs]`    | not available                                 | discover and jump to directory via `fd`+`fzf`, registering it in the database (*5*) |
| Pattern matching | case-sensitive with case-insensitive fallback | smartcase: case-insensitive except when pattern contains uppercase |
| Symlinks         | resolved to physical paths by default         | logical paths are honoured by default *(6)*  |
| Unknown options  | not handled, lists database                   | silently stripped from option string before execution |

*(1)*: The common-prefix heuristic of z.sh overrides the highest-scoring match in
favor of a shorter path when all matches share a common prefix. With a
well-calibrated scoring model this is counterproductive — the highest-scoring
match is the statistically most likely intended destination. For cases where
manual selection is still needed, `ze -f` provides an interactive fallback.

*(2)*: Absolute pathnames are recognized by z.sh only if given as the last
argument - a side effect of tab completion handling. Argument order matters: `z
foo /path` cds directly while `z /path foo` pattern-matches. Relative pathnames
are never recognized and always treated as pattern.

*(3)*: ze.sh retains database entries for directories on transiently unavailable
filesystems (USB drives, NFS mounts). They are ignored during matching but
reactivate when the filesystem is remounted. z.sh prunes such entries immediately
on the next cd action. In ze.sh, score-based pruning takes place when the db
exceeds a configurable size limit (default: 512 entries), which eventually removes
lowest scoring entries including never-again-used stale entries.

*(4)*: The -x option in z.sh serves mainly to remove entries that have accumulated
high scores and dominate the stack inappropriately. ze.sh's exponential scoring
model largely prevents this problem - scores decay naturally and directories do
not become permanently entrenched. In the rare case that an entry must be removed
(for privacy reasons, e.g.), the database at ~/.ze/ze.db can be edited directly.

*(5)*: The -d option provides directory discovery via fd and fzf, similar to the
ALT-C binding installed by fzf's shell integration, but working across all
supported shells and - more importantly - immediately registering the selected
directory in ze's database so it becomes available for future pattern-based
jumping.

*(6)*: The legacy behaviour to resolve all symlinks to physical paths for storage
in the db seems not optimal for a directory navigation tool where logical paths
are usually the expected paradigm. Consequently, ze.sh honours the logical paths
by default. To revert to legacy behaviour, set `_ZE_RESOLVE_SYMLINKS` to any
non-empty value.

## Configuration

| Variable                   | Default  | Meaning                             |
|----------------------------|----------|-------------------------------------|
| `_ZE_CMD`                  | `ze`     | command name *(1)*                  |
| `_ZE_DIR`                  | `~/.ze`  | database directory                  |
| `_ZE_LAMBDA`               | `8e-3`   | decay constant (units: 1/cd-action) |
| `_ZE_DBMAX`                | `512`    | db size limit (pruning threshold)   |
| `_ZE_OWNER`                | unset    | allow use on shared db              |
| `_ZE_RESOLVE_SYMLINKS`     | unset    | resolve symlinks on cd              |
| `_ZE_EXCLUDE_DIRS`         | unset    | array of directory trees to exclude |


*(1)*: Must be set before sourcing ze.sh so that tab completion is registered
under the chosen name. For example, `_ZE_CMD=myze` makes `myze` the command name
with working tab completion - `alias myze=ze` alone would not register completion.
Setting `_ZE_CMD=cd` shadows the builtin `cd` with full `ze` behaviour including
pattern navigation. Note that this changes `cd` semantics: unrecognized pathnames
are tried as patterns against the database rather than producing an error.

## fzf integration

If [fzf](https://github.com/junegunn/fzf) is installed, `ze -f [pattern]` opens
an interactive selector showing all matching directories ranked by score,
best match at top. Select by pathname pattern or by entry number.

```sh
ze -f        # interactive selection from all tracked directories
ze -f foo    # interactive selection from directories matching foo
```

## fish users

A fish wrapper is provided in `contrib/fish/`. It exposes the same user interface
as the native implementation, including `ze -f` integration with `fzf`.

Unlike the native shells, `fish` does not source `ze.sh` directly. Instead,
`ze.fish` invokes the `zex.sh` backend, while `_ze_cd.fish` wraps fish's builtin
`cd` to record directory changes in the ze database.

`_ZE_CMD` is not used under `fish`. The three configuration cases from the native
shells map to `fish` as follows. Add the relevant line to
`~/.config/fish/config.fish`:

```sh
alias myze ze          # rename ze to arbitrary different command name
alias cd   _ze_cd      # track cd, retain native cd semantics
alias cd   ze          # track cd, enable pattern navigation on every cd
```

## Migrating from z.sh

If you have an existing `~/.z` database, you can convert it for use with ze.sh
by issuing:

```sh
mkdir -p ~/.ze
# Only run the following if ~/.ze/ze.db does not already exist:
now=$(awk -F'|' '{ now += $2 } END { print now }' ~/.z)
sort -t'|' -k3,3n ~/.z | awk -F'|' -v now="$now" '
    BEGIN { OFS = FS; lambda = 8e-3 }
    {
        visits = $2
        ticks += visits
        if (visits == 1) {
            score = 1
        } else {
            step = ticks/visits
            decay_step = exp(-lambda * step)
            decay_full = exp(-lambda * ticks)
            score = (1 - decay_full)/(1 - decay_step)
        }
        print $1, visits, ticks, score
    }' > ~/.ze/ze.db
```
This maps z.sh's three-column format to ze.sh's four-column format. Entries are
sorted by their original timestamp and assigned global cumulative visit counts as
tick values accordingly. The score approximation assumes all visits were
uniformly distributed over time. Most initial scores after migration will be low,
frequently well below 1, with only frequently visited recent directories
exhibiting distinctly higher scores. This means the stack might initially exhibit
abrupt reordering similar to z.sh when any directory is visited, since a single
new visit adds a score increment of 1 which dominates most existing scores. Note
that this is an artifact of the migration approximation, not a property of ze.sh's
algorithm. After a few days of normal use, scores will adjust to levels where the
exponential model's smooth ranking behavior becomes apparent and the stack
stabilizes meaningfully.

## Related tools

[SD](https://github.com/jghub/sd-switchdir) — ksh93/bash/zsh, shell-native,
single-file, explicit event log with configurable kernel scoring (default:
exponential), cycling through matches. More fully featured than ze.sh in several
respects. SD stores the full visit history as an event log. Scores can therefore
be recomputed from scratch if the decay parameter or scoring model is changed.

[zoxide](https://github.com/ajeetdsouza/zoxide) — compiled Rust binary inspired by
z.sh, wider shell support including powershell and nushell, widely adopted. Like
z.sh, frecency scoring multiplies cumulative visit count by a recency factor based
on the most recent visit which can produce undesirable ranking — a long-unvisited
directory with a large historical visit count can acquire a disproportionately
high rank on first revisit if its historical visit count is large.

ze.sh occupies a specific niche: minimal (≈220 LOC), single file, shell-native
support of `bash/zsh/ksh93/mksh`, with optional wrappers for `fish`, `tcsh`,
and `dash` in `contrib/`. The exponential moving sum scoring on an event clock
is comparable to SD's approach for a fixed decay parameter. However, only SD
provides the ability to modify the decay parameter at any time and to fully
reconstruct the corresponding scores from scratch.

## License

MIT — see LICENSE.
