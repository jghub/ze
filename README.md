# ze.sh

ze.sh is a frecency-based directory jumper for bash, zsh, ksh93, and mksh (e.g.
Termux/Android), forked from [z.sh](https://github.com/rupa/z), with exponential
moving sum (EMS) scoring model as well as several behavioral fixes and
adjustments, see [list of changes](#changes-from-zsh).

## Installation

Source from your shell rc file:

```sh
source /path/to/ze.sh
```

**Important**: Unlike z.sh, ze.sh only tracks navigation performed through the
`ze` command itself. To also track ordinary `cd` commands, add

```sh
alias cd=_ze_cd
```

to your shell rc file. If you do not install this alias, directories reached via
ordinary cd commands are not recorded in the database.

## Design

ze.sh departs from z.sh in two fundamental ways:

**Scoring**: z.sh's scoring heuristic multiplies a cumulative visit count by a
recency factor derived from the most recent visit timestamp. This can produce
undesirable ranking — a long-unvisited directory with a large historical visit
count can jump near or to the top on first revisit. ze.sh replaces this with a
monoexponential decay kernel: the score is the sum of individual, exponentially
decayed unit impulses at each visit time, representing an exponential moving
sum (mathematically equivalent to the Unix load-average computation, but applied
to a binary directory-visit event stream). The decay rate is controlled by
`_ZE_LAMBDA` (default `4e-6`/sec, half-life `ln(2)/lambda` ≈ 48 hours).

**Tracking**: z.sh uses shell precommand hooks (`PROMPT_COMMAND` in bash, `precmd`
in zsh) that fire on every command, updating the score of whichever directory the
shell is currently in. This means any command executed in a directory increases
that directory's score, regardless of whether a cd action occurred. ze.sh removes
these hooks entirely. Only explicit `ze` invocations (or bare `cd` if aliased to
`_ze_cd`) trigger database updates, and only the target directory's score is
updated.

For broader shell compatibility, ze.sh uses `typeset` instead of `local` and
`[[`/`(())` instead of `[`/`test` throughout. The latter is not a compatibility
requirement — all target shells support `[` — but `[[` is a shell keyword with
cleaner semantics: no word splitting on unquoted variables, unambiguous `&&`/`||`
operators, and pattern matching support. In ze.sh, the `function f { ... }`
definition style is used throughout instead of POSIX-style `f() { ... }` — in
ksh93 and mksh, `typeset` variables are only locally scoped inside functions
defined with the `function` keyword, whereas POSIX style functions do not provide
local scoping in these shells. For historical POSIX sh compatibility, z.sh used
`[` and `f() { }` but was never actually POSIX-compatible due to its use of
arrays, process substitution, and shell-specific completion builtins — ze.sh drops
the pretense and uses the cleaner syntax consistently.

## Database format

The database at `~/.ze/ze.db` is a plain text file with one entry per line:

```
path|visits|timestamp|score
```

| Field | Meaning |
|-------|---------|
| `path` | absolute directory path |
| `visits` | cumulative visit count, incremented on each visit |
| `timestamp` | Unix epoch of last visit, used for score computation at query time and `-t` (recent) mode |
| `score` | exponentially decayed cumulative visit score as of the last visit timestamp |

ze.sh retains entries for directories that no longer exist (e.g. unmounted
filesystems) and filters them at match time rather than pruning them on update.

## Usage

```
ze [options] [pattern|path|-]
ze [-cefhlrt] [args]
```

| Invocation      | Behavior                                |
|-----------------|-----------------------------------------|
| `ze`            | cd to $HOME                             |
| `ze -`          | cd to previous directory                |
| `ze path`       | cd to path directly (real path wins)    |
| `ze pattern`    | cd to highest scoring match for pattern |
| `ze -c pattern` | restrict matches to subdirs of $PWD     |
| `ze -e pattern` | print match instead of cd               |
| `ze -f pattern` | use fzf for interactive selection       |
| `ze -l pattern` | list matches according to current score |
| `ze -r pattern` | sort by visit count                     |
| `ze -t pattern` | sort by recency of last visit           |

## Changes from z.sh

| Area             | z.sh                                          | ze.sh                                          |
|------------------|-----------------------------------------------|------------------------------------------------|
| Tracking         | precommand hook fires on every command        | tracks explicit cd navigation (`ze`, optionally aliased `cd`)|
| Scoring          | frecency heuristic with common-prefix override *(1)* | exponential moving sum, no common-prefix override |
| Path dispatch    | no pathname check, categorical pattern matching *(2)* | real paths take precedence over pattern matching |
| Bare call        | lists database                                | follows builtin cd semantics: cd to $HOME      |
| `-` argument     | not handled, lists database                   | follows builtin cd semantics: cd to previous directory |
| Stale db entries | pruned on next cd action                      | retained in db, filtered at match time *(3)*         |
| `-x` option      | deletes current dir from database             | removed; edit ~/.ze/ze.db directly to remove entries |
| `-l` option      | output to stderr, not pipeable                | output to stdout, pipeable to pager etc.       |
| Database         | single flat file `~/.z`                       | directory `~/.ze/`, database `~/.ze/ze.db`     |
| Shell compat     | bash/zsh only                                 | bash, zsh, ksh93, mksh                         |
| Init             | minimal, no safety checks                     | validates db path, ownership, file type        |
| Concurrency      | tempfile-name collisions and subsequent db corruption possible | `mktemp(1)` eliminates tempfile-name collisions, concurrent updates remain "last writer wins" |
| `-f` option      | not available                                 | interactive fzf selector (if fzf installed)    |
| Pattern matching | case-sensitive with case-insensitive fallback | smartcase: case-insensitive except when pattern contains uppercase |
| Symlinks         | resolved to physical paths by default         | logical paths are honoured by default *(4)*  |
| Unknown options  | not handled, lists database                   | treated as pattern                             |

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
reactivate when the filesystem is remounted. z.sh permanently prunes such entries
on the next cd action.

*(4)*: The legacy behaviour to resolve all symlinks to physical paths for storage
in the db seems not optimal for a directory navigation tool where logical names
probably are the intuitively expected paradigm for most users. Consequently,
ze.sh honours the logical paths by default. To revert to legacy behaviour you now
have to explicitly set the variable `_ZE_RESOLVE_SYMLINKS` to any non-empty value.

## Configuration

| Variable                  | Default  | Meaning                              |
|---------------------------|----------|--------------------------------------|
| `_ZE_CMD`                  | `ze`     | command name                        |
| `_ZE_DIR`                  | `~/.ze`  | database directory                  |
| `_ZE_LAMBDA`               | `4e-6`   | decay rate (per second)             |
| `_ZE_OWNER`                | unset    | allow use on shared db              |
| `_ZE_RESOLVE_SYMLINKS`     | unset    | resolve symlinks on cd              |
| `_ZE_EXCLUDE_DIRS`         | unset    | array of directory trees to exclude |

## fzf integration

If [fzf](https://github.com/junegunn/fzf) is installed, `ze -f [pattern]` opens
an interactive selector showing all matching directories ranked by frecency score,
best match at top. Select by pathname pattern or by entry number.

```sh
ze -f        # interactive selection from all tracked directories
ze -f foo    # interactive selection from directories matching foo
```

## Migrating from z.sh

If you have an existing `~/.z` database, you can convert it for use with ze.sh
by issuing:

```sh
mkdir -p ~/.ze
# Only run the following if ~/.ze/ze.db does not already exist:
awk -F'|' -v now="$(date +%s)" \
    'BEGIN{OFS="|"; lambda=4e-6}
    {print $1, $2, $3, $2 * exp(-lambda * (now - $3))}' ~/.z > ~/.ze/ze.db
```

This maps z.sh's three-column format to ze.sh's four-column format, computing an
initial frecency score proxy from the existing visit count and last-visit
timestamp. Directories not visited recently will start with correspondingly lower
initial scores.

## Related tools

[SD](https://github.com/jghub/sd-switchdir) — ksh93/bash/zsh, shell-native,
single-file, explicit event log with configurable kernel scoring (default:
exponential), cycling through matches. More fully featured than ze.sh in several
respects. SD stores the full visit history as an event log. Scores can therefore
be recomputed from scratch if the decay parameter or scoring model is changed.

[zoxide](https://github.com/ajeetdsouza/zoxide) — compiled Rust binary inspired by
z.sh, wider shell support including fish and nushell, widely adopted. Like z.sh,
frecency scoring multiplies cumulative visit count by a recency factor based on
the most recent visit which can produce undesirable ranking — a long-unvisited
directory with a large historical visit count can acquire a disproportionately
high rank on first revisit if its historical visit count is large.

ze.sh occupies a specific niche: minimal, shell-native, single-file, ksh93- and
mksh-compatible, tracking only intentional navigation rather than all shell
activity. The exponential moving sum scoring is comparable to SD's approach for a
fixed decay parameter but the aggregate-state database does not support
retrospective rescoring.

## License

WTFPL — see LICENSE.