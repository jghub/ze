# ze.sh: Changelog

## 2.0.0, WIP (2026-06-16)
* **changed default for symlink resolution**: the default now is to _not_ resolve
symlinks to physical paths, see README for further details.

* **remove -x option**: the use case for this options seems narrow: removal of a
single database entry is hardly ever desirable given ze.sh's exponential scoring
model, where old infrequently-visited entries naturally decay to low scores and
and are eventually removed once the database exceeds its size limit.

* **add db auto-pruning**: db is pruned at source time by removing lowest scoring
entries when its size exceeds a threshold (default: 512 entries). The default
threshold is conservative; for typical usage patterns the database is unlikely to
exceed it within the first year or two of use.

## 1.1.0 (2026-06-13)
* **smartcase pattern matching**: legacy z.sh implements a strict case-sensitive
pattern matching strategy with a fallback to case-insensitve matching in case no
case-sensitive match is found. ze.sh now uses smartcase matching
(case-insensitive except when pattern contains uppercase characters).

## 1.0.0 (2026-06-13)
Initial release of ze.sh, forked from [z.sh](https://github.com/rupa/z) v1.12.
Primary change: exponential moving sum scoring replacing z.sh's frecency
heuristic. See [Changes from z.sh](README.md#changes-from-zsh) in the README for
the full list.
