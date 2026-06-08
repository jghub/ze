# ze.sh

ze.sh is a frecency-based directory jumper for bash, zsh, ksh93, and mksh (e.g.
Termux/Android), forked from [z.sh](https://github.com/rupa/z), with a refined
scoring model and several behavioral fixes, see changes below.

## Installation

Source from your shell rc:

```sh
source /path/to/ze.sh
```

Requires awk and a POSIX-compatible date command.

## Usage

```
ze [options] [pattern|path]
ze [-cehlrtx] [args]
```

| Invocation      | Behavior                                  |
|-----------------|-------------------------------------------|
| `ze`            | cd to $HOME                               |
| `ze -`          | cd to previous directory                  |
| `ze path`       | cd to path directly (real path wins)      |
| `ze pattern`    | cd to best frecency match for pattern     |
| `ze -l pattern` | list matches with scores                  |
| `ze -x`         | remove current directory from database    |
| `ze -c pattern` | restrict matches to subdirs of $PWD       |
| `ze -e pattern` | print match instead of cd                 |
| `ze -r pattern` | rank by visit count                       |
| `ze -t pattern` | rank by recency                           |

## Changes from z.sh

| Area             | z.sh                                          | ze.sh                                          |
|------------------|-----------------------------------------------|------------------------------------------------|
| Tracking         | precommand hook fires on every command        | tracks only cd navigation via the `ze` command |
| Path dispatch    | pattern matching may override real paths      | real paths always take precedence              |
| Bare `ze`        | lists database                                | cd to $HOME                                    |
| `ze -`           | not handled, silently goes home               | cd to previous directory                       |
| Unknown flags    | silently cd to $HOME                          | treated as pattern                             |
| Scoring          | frecency heuristic with common-prefix override| exponential moving average, no common-prefix override |
| Shell compat     | bash/zsh only                                 | bash, zsh, ksh93, mksh                         |
| Init             | minimal, no safety checks                     | validates db path, ownership, file vs directory|
| Database         | single flat file `~/.z`                       | directory `~/.ze/`, database `~/.ze/ze.db`     |
| Stale db entries | pruned on next cd action                      | retained in db, filtered during matching       |

Ze.sh retains database entries for directories on transiently unavailable
filesystems (USB drives, NFS mounts). They are ignored during matching but
reactivate when the filesystem is remounted. Z.sh permanently prunes such
entries on the next cd action.

## Configuration

| Variable                  | Default  | Meaning                                  |
|---------------------------|----------|------------------------------------------|
| `_ZE_CMD`                  | `ze`     | command name                             |
| `_ZE_DIR`                  | `~/.ze`  | database directory                       |
| `_ZE_LAMBDA`               | `4e-6`   | decay rate (per second)                  |
| `_ZE_OWNER`                | unset    | allow use on shared db                   |
| `_ZE_NO_RESOLVE_SYMLINKS`  | unset    | do not resolve symlinks on cd            |
| `_ZE_EXCLUDE_DIRS`         | unset    | array of directory trees to exclude      |

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

Note that ze.sh only tracks directories navigated via the `ze` command itself, so
the imported history will only grow if you use `ze` for navigation to directories
not yet in the ze.sh database rather than the `cd` builtin.

## Related tools

[SD](https://github.com/jghub/sd-switchdir) — ksh93/bash/zsh, single-file,
explicit event log with exponential kernel scoring, cycling through matches. More
fully featured than ze.sh in several respects; the explicit event log allows
rescoring with different parameters without data loss.

[zoxide](https://github.com/ajeetdsouza/zoxide) — compiled Rust binary inspired by z.sh,
frecency-based scoring, wider shell support including fish and nushell, widely adopted.

ze.sh occupies a specific niche: minimal, shell-native, single-file, ksh93-compatible,
tracking only intentional navigation rather than all shell activity. Scoring is
equivalent to SD for a fixed decay parameter but the aggregate-state
database does not support retrospective rescoring.

## License

WTFPL — see LICENSE.