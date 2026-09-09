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
