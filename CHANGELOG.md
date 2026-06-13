# ze.sh: Changelog

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
