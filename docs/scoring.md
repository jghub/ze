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
S_i := S_i(t_{\max}) = \sum_{n \in E_i} e^{-\lambda (t_{\max}-n)}, 
$$

where $E_i\subseteq\{1,\dots,t_{\max}\}$ is the set of $I_i$ ticks at which an
event attributed to item $i$ occurred. $\lambda>0$ denotes the score decay
constant (default: $\lambda=0.008$/tick). The query-time score is the quantity
used for ranking and reported by `ze -l`.

### Reduction to a minimal stored state

Eq. (1) seems to suggest that computation of $S_i$ requires to keep a log of the
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
s_i\, e^{-\lambda (t_{\max}-t_i)}, \qquad
s_i = \sum_{n \in E_i} e^{-\lambda (t_i-n)}. \tag{2}
$$

Here $s_i$ is the score of $i$ as computed at its own last event tick $t_i$. This
value does not change as $t_{\max}$ advances. Knowledge of $(s_i,t_i)$ therefore
suffices to derive $S_i$ for any $t_{\max}$. Consequently, for score computation
the database needs to hold only these two numbers per item while the last tick is
derived from $t_{\max}=\max_i t_i$.

### Update rule

When the next event, at tick $t_{\max}+1$, is attributed to item $k$, only the
last-visit timestamp and corresponding stored score of entry $k$ has to be updated
in the database:

$$
t_k' = t_{\max}' = t_{\max}+1,\qquad s_k' = e^{-\lambda (t_k'-t_k)}\, s_k+1 \tag{3}
$$

where the decay factor accounts for the score decay since $k$'s most recent
previous event. A new item enters the database with $s_k'=1$ (since formally its
previous score is $s_k=0$). For all $i\ne k$, the stored values are unchanged.

### Effect on the query-time scores

Let $S_i'$ denote the resulting query-time score after the new event, i.e.
evaluated at $t_{\max}'=t_{\max}+1$.

For $i\ne k$, according to Eq. (2), the unchanged stored values $(t_i, s_i)$ lead
to $S_i'=s_i\,e^{-\lambda(t_{\max}+1-t_i)}=e^{-\lambda}S_i$.
For the just updated item $k$, $t_k'=t_{\max}'$, so the query time score equals the stored
score:
$S_k'=s_k'=s_k\,e^{-\lambda(t_{\max}+1-t_k)}+1=e^{-\lambda}S_k+1$. Both cases are
summarized by

$$
S_i' = e^{-\lambda} S_i + \delta_{ik}, \tag{4}
$$

where $\delta_{ik}=1$ if $i=k$, and $0$ otherwise. Eq. (4) states that all
query-time scores decay by a factor $e^{-\lambda}$ per event, while the item
receiving the event additionally gains $+1$.

For an item $i\ne k$ the fractional loss per event is
$(S_i-S_i')/S_i=1-e^{-\lambda}\approx\lambda$ for $\lambda\ll1$. An item that
receives no further events has its score halved after $N_{1/2}=\ln 2/\lambda$
events. For the default $\lambda=0.008$ this gives $N_{1/2}\approx 87$, which
allows estimating the equivalent wall-clock period (e.g. 30--40 events/day
correspond to a half-life of about 2--3 days).

## 2. Total score

The EMS scores have another interesting property. Summing over all items gives

$$
S = \sum_i S_i = \sum_i s_i\, e^{-\lambda (t_{\max}-t_i)} =
\sum_{n=1}^{t_{\max}} e^{-\lambda (t_{\max}-n)},
$$

where the last equality holds because the sets $E_i$ partition
$\{1,\dots,t_{\max}\}$: each tick carries exactly one event, attributed to exactly
one item. Substituting $j=t_{\max}-n$ and recognizing the sum as a finite
geometric series one arrives at

$$
S = \sum_{j=0}^{t_{\max}-1} e^{-\lambda j} = \frac{1 - e^{-\lambda t_{\max}}}{1 - e^{-\lambda}}. \tag{5}
$$

For a sufficiently long history (where $\lambda t_{\max} \gg 1$ is fulfilled) the
sum approaches a maximum limit of

$$
S_\infty = \frac{1}{1 - e^{-\lambda}} \approx \frac{1}{\lambda}+\frac{1}{2} \qquad (\lambda \ll 1). \tag{6}
$$

E.g., for $\lambda=0.008$, $S_\infty\approx125.50$. (the sum over the scores
reported by `ze -l` may be somewhat smaller because the report excludes entries
whose paths do presently no longer exist). Summing the recurrence
$S_i'=e^{-\lambda}S_i+\delta_{ik}$ over all items gives $S'=e^{-\lambda}S+1$,
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
suffices to deduce its query-time score according to Eq. (1). There is no need
to retain the full event history.

## 4. Comparison with `zoxide's` frecency-based ranking

There are important differences between `ze's` EMS scoring and the "frecency"
approach used by `zoxide` and its ancestors where the score is computed as
$F_i=I_i \times R_i(\Delta T_i)$. Here, $R_i$ is a certain monotonically
decreasing function of wall-clock time difference $\Delta T_i$ between query time
and time of most recent (last) event for the considered item. (To be precise, the
$I_i$ are not necessarily identical to actual event frequency since they can
undergo additional periodic downscaling by some constant factor in those tools,
but for the current considerations this is of secondary import only.) The
typically used $R_i$ functions strongly penalize age, and wall-clock usage then
implies substantial score decay during extended inactivity periods (e.g.
holidays) which can lead to surprising ranking changes after taking up work again.

But the more fundamental issue is the fact that this "frecency" approach does
score _all_ $I_i$ events equally (assigning to each single event a weight $R_i$
that is determined solely by the very last event attributed to item $i$).
Therefore, ancient events contribute the same weight $R_i$ to the query-time score
as events that just happened, and $R_i$ will abruptly increase by a large factor
if a single revisit happens after a long time, boosting the query time score
accordingly.

The EMS scoring by contrast assigns a different age-dependent weight to each
individual event as per Eq. (1) which effectively avoids disproportionate score
jumps (a single new visit after a sufficiently long interval will always result in a
score very close to 1, independent of the number of ancient previous visits).

## 5. Database pruning

To limit database size, `ze` removes the lowest-scoring entries when the number
of entries exceeds a threshold $L$, retaining the top $K$ entries (defaults:
$L=640$, $K=620$).

Pruning does not change the scores or relative ranking of the retained entries:
each item's score depends only on its own event history. It does discard the
residual score of removed entries, however, so a subsequently revisited entry
will start again at score $1$.

With the default parameters, pruned entries typically will have not been visited
for several thousand events (which translates into many months of real time for
typical usage patterns) and will carry extremely small scores. Only for
nonsensical choices of the relevant parameters (extremely small or zero $\lambda$
which drives the scoring towards pure frequency scoring) or a too small pruning
limit $L$ one can construe a situation where a newly created entry (first-time
visit) incidentally triggers the pruning threshold and is immediately
evicted/pruned. As a conservative rule of thumb: it should be ensured that
$\lambda L \gtrsim 1$ (the default settings correspond to $\lambda L \approx 5$).
