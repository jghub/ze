# ze.sh: Changelog

## 1.2.0, WIP (2026-06-14)
* **db auto-pruning**: db is pruned at source time by removing lowest scoring
entries if db size exceeds the hardcoded threshold of 2^10 entries. The threshold
is very conservative and should make ze.sh remember several years of activity. 

* **symlink resolution**: the default now is to _not_ resolve symlinks to physical
paths, see README for further details.

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
