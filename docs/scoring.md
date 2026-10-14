# Mathematical notes on the exponential moving sum (EMS) scoring algorithm used by `ze.sh`

## 1. Algorithm

Time is measured by an event counter, starting from 1, which represents a clock
that advances by one tick per scored event. The last tick $t_{\max}$ is the tick
of the most recent event -- it equals the number of scored events so far and
serves as the algorithm's notion of "now".

Each event is attributed to exactly one item (in `ze`: a directory or, in
file tracking mode, a file).

### Query-time score

The query-time score of item $i$ is defined as

$$
S_i := S_i(t_{\max}) = \sum_{n \in E_i} e^{-\lambda (t_{\max}-n)}, \qquad (1)
$$

where $E_i\subseteq\lbrace 1,\dots,t_{\max} \rbrace$ is the set of $I_i$ ticks at which an
event attributed to item $i$ occurred. $\lambda>0$ denotes the score decay
constant (default: $\lambda=0.008$/tick). The query-time score is the quantity
used for ranking and reported by `ze -l`.

### Reduction to a minimal stored state

Eq. (1) seems to suggest that computation of $S_i$ requires keeping a log of the
full sequence of consecutive individual events. For the special case of the
exponential weighting function this is however not necessary because this function
obeys the identity $\exp(-a)\times\exp(-b)=\exp(-(a+b))$. From this fact it
follows that the whole score decay history of an item (the train of individually
decaying scores of the single events attributed to the item) can be condensed into
a single number. Formally:

Let $t_i=\max E_i$ be the tick of the most recent event attributed to $i$. Since
$t_{\max}-n=(t_{\max}-t_i)+(t_i-n)$, the factor depending on $t_{\max}$ can be
factored out of the sum in Eq. (1):

$$
S_i = e^{-\lambda (t_{\max}-t_i)} \sum_{n \in E_i} e^{-\lambda (t_i-n)} =
s_i\thinspace e^{-\lambda (t_{\max}-t_i)}, \qquad
s_i = \sum_{n \in E_i} e^{-\lambda (t_i-n)}. \qquad (2)
$$

Here $s_i$ is the score of $i$ as computed at its own last event tick $t_i$. This
value does not change as $t_{\max}$ advances. Knowledge of $(s_i,t_i)$ therefore
suffices to derive $S_i$ for any $t_{\max}$. Consequently, for score computation
the database needs to hold only these two numbers per item while the last tick is
derived from $t_{\max}=\max_i t_i$.

### Update rule

When the next event, at tick $t_{\max}+1$, is attributed to item $k$, only the
last-visit timestamp and corresponding stored score of entry $k$ have to be updated
in the database:

$$
t^*_k = t^*_{\max} = t_{\max}+1,\qquad s^*_k = e^{-\lambda (t^*_k-t_k)}\thinspace s_k+1 \qquad (3)
$$

where the decay factor accounts for the score decay since $k$'s most recent
previous event. A new item enters the database with $s^*_k=1$ (since formally its
previous score is $s_k=0$). For all $i\ne k$, the stored values are unchanged.

### Effect on the query-time scores

Let $S^*_i$ denote the resulting query-time score after the new event, i.e.
evaluated at $t^*_{\max}=t_{\max}+1$.

For $i\ne k$, according to Eq. (2), the unchanged stored values $(t_i, s_i)$ lead
to $S^*_i=s_i\thinspace e^{-\lambda(t_{\max}+1-t_i)}=e^{-\lambda}S_i$.
For the just updated item $k$, $t^*_k=t^*_{\max}$, so the query time score equals the stored
score:
$S^*_k=s^*_k=s_k\thinspace e^{-\lambda(t_{\max}+1-t_k)}+1=e^{-\lambda}S_k+1$. Both cases are
summarized by

$$
S^*_i = e^{-\lambda} S_i + \delta_{ik}, \qquad (4)
$$

where $\delta_{ik}=1$ if $i=k$, and $0$ otherwise. Eq. (4) states that all
query-time scores decay by a factor $e^{-\lambda}$ per event, while the item
receiving the event additionally gains $+1$.

For an item $i\ne k$ the fractional loss per event is
$(S_i-S^*_i)/S_i=1-e^{-\lambda}\approx\lambda$ for $\lambda\ll1$. An item that
receives no further events has its score halved after $N_{1/2}=\ln 2/\lambda$
events. For the default $\lambda=0.008$ this gives $N_{1/2}\approx 87$, which
allows estimating the equivalent wall-clock period (e.g. 30--40 events/day
correspond to a half-life of about 2--3 days).

## 2. Total score

The EMS scores have another interesting property. Summing over all items gives

$$
S = \sum_i S_i = \sum_i s_i\thinspace e^{-\lambda (t_{\max}-t_i)} =
\sum_{n=1}^{t_{\max}} e^{-\lambda (t_{\max}-n)},
$$

where the last equality holds because the sets $E_i$ partition
$\lbrace 1,\dots,t_{\max} \rbrace$: each tick carries exactly one event, attributed to exactly
one item. Substituting $j=t_{\max}-n$ and recognizing the sum as a finite
geometric series one arrives at

$$
S = \sum_{j=0}^{t_{\max}-1} e^{-\lambda j} = \frac{1 - e^{-\lambda t_{\max}}}{1 - e^{-\lambda}}. \qquad (5)
$$

For a sufficiently long history (where $\lambda t_{\max} \gg 1$ is fulfilled) the
sum approaches a maximum limit of

$$
S_\infty = \frac{1}{1 - e^{-\lambda}} \approx \frac{1}{\lambda}+\frac{1}{2} \qquad (\lambda \ll 1). \qquad (6)
$$

E.g., for $\lambda=0.008$, $S_\infty\approx125.50$ (the sum over the scores
reported by `ze -l` may be somewhat smaller because entries
whose paths no longer exist are skipped). Summing the recurrence
$S^*_i=e^{-\lambda}S_i+\delta_{ik}$ over all items gives $S^*=e^{-\lambda}S+1$,
whose fixed point is $S_\infty=1/(1-e^{-\lambda})$. Therefore, asymptotically the
combined decay loss of all items, $(1-e^{-\lambda})S_\infty=1$, exactly
compensates the $+1$ increment of the item receiving the event: in the asymptotic
regime a new event causes a redistribution of the constant score sum $S_\infty$
over the given items.

## 3. Summary of properties

- **Event-count time:** Score decay depends on the number of events, not
wall-clock time.

- **Implicit global decay:** Each new event reduces every item's query-time score
by a factor $e^{-\lambda}$, while the event-receiving item additionally gains a $+1$
score increment according to Eq. (4). Only the database entry for the event-receiving
item needs to be updated according to Eq. (3). The decay until query time is
deduced using the stored individual last-visit ticks $t_i$ via Eq. (2).

- **Bounded total score:** With one event per tick and no loss of score mass, the
total sum of scores approaches $1/(1-e^{-\lambda})$ and further events only
determine how this mass is distributed among items.

- **Persistent state:** The pair of values $(s_i,t_i)$ stored for each item
suffices to deduce its query-time score according to Eq. (2). There is no need
to retain the full event history.

## 4. Database pruning

To limit database size, `ze` removes the lowest-scoring entries at shell
initialization when the number of entries exceeds a threshold $L$, retaining the
top $K$ entries (defaults: $L=640$, $K=L-L/32=620$).

Pruning does not change the scores or relative ranking of the retained entries:
each item's score depends only on its own event history. It does discard the
residual score of removed entries, however, so a subsequently revisited entry will
start again at score $1$. With the default parameters, pruned entries are, by the
bound derived below, at least about 500 events old, usually much older.

Only for extreme choices of the relevant parameters ( $\lambda$ very close or
equal to zero, which drives the scoring towards pure frequency scoring) or a too
low pruning threshold $L$ one can construe a situation where a newly created, once
visited entry is promptly evicted again when pruning incidentally triggers
immediately after the event. If this were to happen, it would not cause serious
problems but it would constitute failure to properly retain the new entry (and
also imply loss of the increment of $t_{\max}$). Preferably, the
immediate-eviction corner case should just be avoided by observing the condition
on $\lambda$ and $L$ derived below.

A fresh entry has score exactly $1$ right after its event. Its rank is at most
one plus the number of entries with score $>1$. Each of those contributes more
than $1$ to the total score mass, which is at most $S_\infty$, so it is guaranteed
that there always are fewer than $S_\infty-1$ of such entries. The new entry can
therefore be pruned only if $S_\infty>K+1$. Therefore, a new entry is safe from
pruning as long as

$$
\frac{1}{1-e^{-\lambda}} \le K+1 \quad \Longleftrightarrow \quad
\lambda \ge \ln \left( 1+\frac 1 K \right) \approx \frac 1 K, \textrm{ or } \lambda K \gtrsim 1,
$$

which is comfortably satisfied for the defaults ($\lambda K\approx5$). More
generally, only entries whose last event is older than about $K-S_\infty$
events ($\approx500$ for the defaults) can possibly be pruned. For practical
usage patterns pruned entries typically are in fact much older than that.

## 5. Comparison with frecency-based ranking

Frecency-based jumpers such as `zoxide` (and its ancestor `z`) rank items by
$F_i=I_i \times R(\Delta T_i)$. Here $I_i$ is an access count (periodically
downscaled by a common factor to bound the database, which leaves the ranking
unchanged) and $R$ is a decreasing function of the wall-clock time $\Delta T_i$
since the most recent event of item $i$ (a step function in `zoxide`, a hyperbolic
function in `z`). Two consequences follow.

First, all scores decay with wall-clock time, so after an extended inactive period
(e.g. holidays) every score is small and the ranking approaches that of the raw
counts.

Second, the recency factor is determined solely by the last event and multiplies
the *entire* accumulated count, so all $I_i$ past events carry the same weight,
however old. A single revisit after a long dormancy therefore changes $F_i$ by
the factor $\frac{R(0)}{R(\Delta T_k)}$ (for `zoxide` up to 16-fold) and
reactivates the item's full history score at once. The revisited item can then
outrank items with intense recent activity but smaller raw counts, i.e. those on
which current work takes place.

EMS scoring instead weights each event by its own age (Eq. (1)). Each event adds
a bounded increment: Eq. (4) gives $S_k^*-S_k=1-(1-e^{-\lambda})S_k\le1$. The
old history of a dormant item has already decayed, so a revisit lifts its score
only to $1+e^{-\lambda\Delta}s_k$, which is close to 1 once $\Delta$ is large
compared with $\ln(s_k)/\lambda$, essentially independent of how often the item
was visited long ago. Because the clock advances only with events, inactive
periods do not change scores at all, and established items with score well above 1
remain ranked above the revisited one. In short, EMS updates are additive (+1 on
top of pre-decayed score), whereas frecency updates are multiplicative, rescaling
the whole accumulated count by a recency factor.
