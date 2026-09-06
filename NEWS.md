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
