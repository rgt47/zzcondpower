# zzcondpower 0.4.0.9000

## Correctness fixes

* **A precomputed `cp_grid` silently overrode `alpha` and the other
  design arguments.** `monitored_operating_characteristics()` and
  `monitored_size()` accept a conditional-power grid to avoid
  recomputation, but never checked it against the call. A grid built
  at `alpha = 0.05` used with `alpha = 0.01` (n = 50, m = 20,
  tau = 0.1, rates 0.05 and 0.10) returned a stopping probability of
  0.632 and rejection probability of 0.0291 rather than the correct
  0.723 and 0.0276, with no warning. A grid built for a different `n`
  or with a different `driver` was likewise accepted.
  `conditional_power_grid()` now records `n`, `m`, `alpha` and
  `driver` as attributes, and a new internal `check_cp_grid()`
  validates them at both entry points. A mismatch is an error. A grid
  of the wrong dimensions is now a clear error rather than
  "non-conformable arrays".
* Grids without these attributes (built by hand, or by 0.4.0 and
  earlier) are still accepted, with a single warning, because they
  cannot be checked. Rebuild such grids to enable the check.
* User-visible change: passing a grid built with
  `driver = "asymptotic"` now requires `driver = "asymptotic"` in the
  call as well; previously the `driver` argument was ignored whenever
  a grid was supplied.
* **A precomputed `region` was checked less strictly than `cp_grid`.**
  `check_region()` compared only the row count and, when present, the
  recorded `alpha`. A region whose `alpha` attribute had been dropped
  (for example by `matrix()` or subsetting) was accepted silently at
  any `alpha`: a 0.05 region stripped of attributes and used with
  `alpha = 0.01` in `exact_conditional_power(60, 2, 5, 0.03, 0.12)`
  returned 0.660 rather than 0.284. A region with the right number of
  rows but an extra column, or one whose recorded `n` disagreed with
  the call, was also accepted. `check_region()` now follows the same
  policy as `check_cp_grid()`: a region that is not an
  `(n + 1) x (n + 1)` matrix, or whose recorded `n` or `alpha`
  disagrees with the call, is an error; a region without these
  attributes draws a single warning and is used as given.
* User-visible change: hand-built or attribute-stripped regions now
  warn (once per top-level call), and non-square or non-matrix regions
  now fail with a clear message instead of "subscript out of bounds"
  or a silently wrong answer.
* **A numeric 0/1 region gave a silently wrong answer.**
  `exact_conditional_power_pb()` indexes the outcome mass by
  `mass[region]`, so a numeric region was read as positional indices
  rather than as a membership mask. `check_region()` now requires a
  logical matrix, as returned by `fisher_rejection_region()`; no
  example or test in the package builds a numeric region.
* **`conditional_power_grid(driver = "asymptotic")` skipped the region
  check.** The asymptotic branch returned before `check_region()` ran,
  so a region built at another `n` or `alpha` was accepted. That
  branch does not use the region, so the value was unaffected, but the
  mismatch went unreported. The region is now validated for both
  drivers.

# zzcondpower 0.4.0

## Correctness fixes

These were made under version 0.3.0 without a version bump, so 0.3.0
exists in two forms: the released one and the corrected one. Anyone
holding results from a 0.3.0 install should confirm which they have,
by behaviour rather than by version string, and regenerate if needed.
`exists("check_region")` in the package namespace distinguishes them.

* **A precomputed `region` silently overrode `alpha`.** Five exported
  functions accept a rejection region as a speed optimisation, but
  `alpha` was never consulted when one was supplied, so a region built
  at 0.05 used with `alpha = 0.01` returned the 0.05 answer, 0.454
  rather than 0.154. The region already recorded its own alpha in an
  attribute the code wrote and never read. A new internal
  `check_region()` validates `n` and `alpha` at all four entry points.

* **`conditional_power_grid(driver = "asymptotic")` fabricated a value
  at the all-events corner,** returning 0.0386 where the exact driver
  correctly gives 0. The cause was flooring the pooled variance at
  `.Machine$double.eps`, which turned a loud `NaN` into a plausible
  wrong number. Both degenerate corners now return 0, matching the
  exact driver, and the floor is gone so future misuse fails visibly.

* **`estimate_partitioned_rates()` accepted times past the horizon,**
  returning a negative event probability once `t` exceeded
  `entry_period + follow_up`, which propagated as a probability.
  Out-of-range times are now refused.

* **The same function broke at exactly the boundary.** At
  `t == entry_period + follow_up` the exposure fraction is 1 in real
  arithmetic, so the residual is 0, but in floating point it landed at
  -1.39e-17 and the downstream `gamma >= 0` guard rejected it.
  Rounding-scale negatives are now clamped; materially negative values
  still surface.

* **`halperin_conditional_power()` returned `NaN` for zero pooled
  variance,** which arises whenever both arms have all-or-nothing
  events. Zero events in both arms is the expected early state of a
  rare-event trial, so this was reachable in ordinary use; it is now
  refused explicitly.

## Documentation

* The package-level help records the significance-level convention: the
  Fisher family defaults to one-sided 0.05 and the log-rank and count
  families to 0.025, so results are not comparable across families
  unless `alpha` is set explicitly.

## Tests

* Suite grew from 150 assertions to 159, each new one naming the defect
  it guards.

# zzcondpower 0.3.0

First release. Exact stochastic curtailment calculations for interim
monitoring of two-arm randomized clinical trials.

## Fisher exact test, simultaneous entry

* `exact_conditional_power()` computes conditional power by
  enumeration for trials whose final analysis is the one-sided Fisher
  exact test.
* `fisher_rejection_region()` and `exact_fisher_power()` give the exact
  rejection region and its power.
* `halperin_conditional_power()` provides the normal-approximation
  conditional power in the Halperin tradition, for comparison.

## Staggered entry and censored follow-up

* `exact_conditional_power_pb()` and `pois_binom_pmf()` extend the
  calculation through an exact Poisson-binomial formulation with
  subject-specific event probabilities.
* Supporting estimators: `estimate_partitioned_rates()`,
  `follow_up_durations()`, `conditional_event_prob()`,
  `exponential_survival()`, `rate_from_risk()`.

## Discrete-visit log-rank

* `logrank_exact_conditional_power()` implements an exact
  forward recursion for the discrete-visit log-rank
  (Mantel-Haenszel) statistic, with `logrank_atrisk_dist()` and
  `logrank_visit_increment()` supplying the at-risk distribution and
  visit increments.
* `logrank_moment_conditional_power()` is a moment-matched normal
  approximation using the recursion's exact first two moments.

## Conditional Poisson final test

* `count_conditional_power_poisson()` and
  `count_conditional_power_nb()` give exact and frailty-conditioned
  conditional power for the conditional Poisson
  (Przyborowski-Wilenski) test under gamma-Poisson
  (negative-binomial) heterogeneity, supported by
  `nb_predictive_pmf()` and `convolve_pmf_list()`.

## Design utilities

* `exact_sample_size()`, `conditional_power_comparison()`,
  `conditional_power_grid()`, `monitored_operating_characteristics()`,
  `monitored_size()`.
* `thomas1991_example()` reproduces a worked example.
