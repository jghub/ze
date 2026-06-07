# ze.sh

A fork of [z.sh](https://github.com/rupa/z) — a frecency-based directory jumper for bash, zsh, and ksh93.

ze.sh refines z.sh's scoring model and fixes several behavioral issues. It is not a drop-in replacement; see changes below.

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
| Tracking         | precommand hook fires on every command        | tracks only explicit `ze` invocations          |
| Path dispatch    | pattern matching may override real paths      | real paths always take precedence              |
| Bare `ze`        | lists database                                | cd to $HOME                                    |
| `ze -`           | not handled, silently goes home               | cd to previous directory                       |
| Unknown flags    | silently cd to $HOME                          | treated as pattern                             |
| Scoring          | frecency heuristic with common-prefix override| exponential moving average, no common-prefix override |
| Shell compat     | bash/zsh only                                 | bash, zsh, ksh93                               |
| Init             | minimal, no safety checks                     | validates db path, ownership, file vs directory|
| Database         | single flat file `~/.z`                       | directory `~/.ze/`, database `~/.ze/ze.db`     |

## Configuration

| Variable                  | Default  | Meaning                                  |
|---------------------------|----------|------------------------------------------|
| `_Z_CMD`                  | `ze`     | command name                             |
| `_Z_DIR`                  | `~/.ze`  | database directory                       |
| `_Z_LAMBDA`               | `4e-6`   | decay rate (per second)                  |
| `_Z_OWNER`                | unset    | allow use on shared db                   |
| `_Z_NO_RESOLVE_SYMLINKS`  | unset    | do not resolve symlinks on cd            |
| `_Z_EXCLUDE_DIRS`         | unset    | array of directory trees to exclude      |

## Related tools

[zoxide](https://github.com/ajeetdsouza/zoxide) — compiled Rust binary, same concept, wider shell support including fish and nushell, actively maintained, the de facto standard for new installations.

[sd-switchdir](https://github.com/jghub/sd-switchdir) — ksh93/bash/zsh, single-file, more sophisticated scoring (explicit event log rather than aggregate state), cycling through matches, recently released. Closer in spirit to ze.sh than zoxide.

ze.sh occupies a specific niche: minimal, single-file, ksh93-compatible, tracks only intentional navigation rather than all shell activity.

## License

WTFPL — see LICENSE.