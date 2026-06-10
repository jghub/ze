# ze.sh

ze.sh is a frecency-based directory jumper for bash, zsh, ksh93, and mksh (e.g.
Termux/Android), forked from [z.sh](https://github.com/rupa/z), with a refined
scoring model and several behavioral fixes, see changes below.

## Installation

Source from your shell rc file:

```sh
source /path/to/ze.sh
```

By default, only navigation via the `ze` command itself is tracked. To also track
bare `cd` invocations, add to your shell rc file:

```sh
alias cd=_ze_cd
```

If you do not install this alias, directories reached via ordinary cd commands are
not added to the database.

## Design

ze.sh departs from z.sh in two fundamental ways:

**Scoring**: z.sh's scoring heuristic multiplies a cumulative visit count by a
recency factor derived from the most recent visit timestamp. This can produce
undesirable ranking — a long-unvisited directory with a large historical visit
count can jump near or to the top on first revisit. ze.sh replaces this with a
monoexponential decay kernel: the score is the sum of individual, exponentially
decayed, unit impulses at each visit time, representing an exponential moving sum
(mathematically equivalent to the Unix load average computation on a binary
visit/no-visit signal). The decay rate is controlled by `_ZE_LAMBDA` (default
`4e-6`/sec, half-life `ln(2)/lambda` ≈ 48 hours).

**Tracking**: z.sh uses shell precommand hooks (`PROMPT_COMMAND` in bash, `precmd`
in zsh) that fire on every command, updating the score of whichever directory the
shell is currently in. This means any command executed in a directory increases
that directory's score, regardless of whether a cd action occurred. ze.sh removes
these hooks entirely. Only explicit `ze` invocations (or bare `cd` if aliased to
`_ze_cd`) trigger database updates, and only the target directory's score is
updated.

## Database format

The database at `~/.ze/ze.db` is a plain text file with one entry per line:

```
path|rank|timestamp|score
```

| Field | Meaning |
|-------|---------|
| `path` | absolute directory path |
| `rank` | visit count, incremented on each visit |
| `timestamp` | Unix epoch of last visit, used for score computation at query time and `-t` (recent) mode |
| `score` | score: cumulative sum of exponentially decayed visit weights until time of last visit of the path |

Use `ze -x` to remove the current directory, or delete entries manually. Such
cleanup is rarely necessary in practice.

ze.sh retains entries for directories that no longer exist (e.g. unmounted
filesystems) and filters them at match time rather than pruning them on update.

## Usage

```
ze [options] [pattern|path|-]
ze [-cehlrtx] [args]
```

| Invocation      | Behavior                                  |
|-----------------|-------------------------------------------|
| `ze`            | cd to $HOME                               |
| `ze -`          | cd to previous directory                  |
| `ze path`       | cd to path directly (real path wins)      |
| `ze pattern`    | cd to highest scoring match for pattern   |
| `ze -l pattern` | list matches with scores at query time    |
| `ze -x`         | remove current directory from database    |
| `ze -c pattern` | restrict matches to subdirs of $PWD       |
| `ze -e pattern` | print match instead of cd                 |
| `ze -r pattern` | rank by visit count                       |
| `ze -t pattern` | rank by recency                           |

## Changes from z.sh

| Area             | z.sh                                          | ze.sh                                          |
|------------------|-----------------------------------------------|------------------------------------------------|
| Tracking         | precommand hook fires on every command        | tracks explicit cd navigation (`ze`, optionally aliased `cd`)|
| Scoring          | frecency heuristic with common-prefix override| exponential moving average, no common-prefix override |
| Path dispatch    | no pathname check, categorical pattern matching *(1)* | real paths take precedence over pattern matching |
| Bare call        | lists database                                | follows builtin cd semantics: cd to $HOME      |
| `-` argument     | not handled, lists database                   | follows builtin cd semantics: cd to previous directory |
| `-x` option      | deletes current dir, falls through to pattern matching | deletes current dir and returns immediately |
| `-l` option      | output to stderr, not pipeable                | output to stdout, pipeable to pager etc.       |
| `-f` option      | not available                                 | interactive fzf selector (if fzf installed)    |
| Unknown options  | not handled, lists database                   | treated as pattern                             |
| Database         | single flat file `~/.z`                       | directory `~/.ze/`, database `~/.ze/ze.db`     |
| Init             | minimal, no safety checks                     | validates db path, ownership, file type        |
| Stale db entries | pruned on next cd action                      | retained in db, filtered at match time *(2)*         |
| Shell compat     | bash/zsh only                                 | bash, zsh, ksh93, mksh                         |

*(1)*: Absolute pathnames are recognized only if given as the last argument - a
side effect of tab completion handling. Argument order matters: `z foo /path` cds
directly while `z /path foo` pattern-matches. Relative pathnames are never
recognized and always treated as pattern.

*(2)*: ze.sh retains database entries for directories on transiently unavailable
filesystems (USB drives, NFS mounts). They are ignored during matching but
reactivate when the filesystem is remounted. Z.sh permanently prunes such entries
on the next cd action.

## Configuration

| Variable                  | Default  | Meaning                                  |
|---------------------------|----------|------------------------------------------|
| `_ZE_CMD`                  | `ze`     | command name                             |
| `_ZE_DIR`                  | `~/.ze`  | database directory                       |
| `_ZE_LAMBDA`               | `4e-6`   | decay rate (per second)                  |
| `_ZE_OWNER`                | unset    | allow use on shared db                   |
| `_ZE_NO_RESOLVE_SYMLINKS`  | unset    | do not resolve symlinks on cd            |
| `_ZE_EXCLUDE_DIRS`         | unset    | array of directory trees to exclude      |

## fzf integration

If [fzf](https://github.com/junegunn/fzf) is installed, `ze -f [pattern]` opens
an interactive selector showing all matching directories ranked by frecency score,
best match at top. Select by pathname pattern or by entry number.

```sh
ze -f        # interactive selection from all tracked directories
ze -f foo    # interactive selection from directories matching foo
```

## Migrating from z.sh

If you have an existing `~/.z` database, you might convert it for use with ze.sh 
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
timestamp. Directories not visited recently will start with appropriately lower
scores.

By default, ze.sh only tracks directories navigated via the `ze` command itself.
If you prefer to track ordinary `cd` activity as well, add alias `cd=_ze_cd` to
your shell rc file as described above.

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
directory with a large historical visit count can jump to the very top on first
revisit.

ze.sh occupies a specific niche: minimal, shell-native, single-file, ksh93- and
mksh-compatible, tracking only intentional navigation rather than all shell
activity. The smooth exponential moving average scoring is comparable to SD's
approach for a fixed decay parameter but the aggregate-state database does not
support retrospective rescoring.

## License

WTFPL — see LICENSE.