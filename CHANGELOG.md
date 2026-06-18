# ze.sh: Changelog

## 2.0.0 (2026-06-18)
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

## 1.1.0 (2026-06-13)
* **smartcase pattern matching**: legacy z.sh implements a strict case-sensitive
pattern matching strategy with a fallback to case-insensitive matching in case no
case-sensitive match is found. ze.sh now uses smartcase matching
(case-insensitive except when pattern contains uppercase characters).

## 1.0.0 (2026-06-13)
Initial release of ze.sh, forked from [z.sh](https://github.com/rupa/z) v1.12.
Primary change: exponential moving sum scoring replacing z.sh's frecency
heuristic. See [Changes from z.sh](README.md#changes-from-zsh) in the README for
the full list.
