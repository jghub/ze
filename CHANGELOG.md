# ze.sh: Changelog

## 1.2.0, WIP (2026-06-15)
* **db auto-pruning**: db is pruned at source time by removing lowest scoring
entries if db size exceeds a hardcoded threshold (1024 entries). The threshold is
very conservative and ensures that ze.sh will keep several years of cd history.

* **symlink resolution**: the default now is to _not_ resolve symlinks to physical
paths, see README for further details.

* **remove -x option**: the use case for this options seems narrow (even more so
in ze.sh than in z.sh): deletion of ancient entries with high visit count jumping
to top of stack of single inadvertent new visit and otherwise not desirable, since
it easily can be issued inadvertently (mistyping -x when intending -c, e.g.).

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
