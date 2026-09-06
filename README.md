# zzcondpower

Exact conditional power for two-arm trials with binary outcomes.

Exact stochastic curtailment calculations for interim monitoring of
two-arm randomized clinical trials whose final analysis is the
one-sided Fisher exact test. The package computes the exact rejection
region and its conditional power by enumeration, rather than relying
on a normal approximation, and extends that calculation to staggered
entry, censored time-to-event follow-up, the discrete-visit log-rank
statistic, and a conditional Poisson final test.

## Installation

```r
# install.packages("pak")
pak::pak("rgt47/zzcondpower")
```

## Usage

Conditional power under simultaneous entry, given interim event
counts:

```r
library(zzcondpower)

exact_conditional_power(371, x1 = 2, y1 = 5,
                        gamma = 0.0331, beta = 0.0837)
#> [1] 0.9382867
```

The normal-approximation calculation in the Halperin tradition is
provided for comparison:

```r
halperin_conditional_power(371, 48.8, 2 / 48.8, 5 / 48.8)
#> [1] 0.9570119
```

`thomas1991_example()` reproduces a worked example, returning the
estimates alongside the homogeneous, stratified, and Halperin
conditional powers:

```r
str(thomas1991_example(), max.level = 1)
#> List of 5
#>  $ estimates     :List of 4
#>  $ m_effective   : num 48.8
#>  $ cp_homogeneous: num 0.939
#>  $ cp_stratified : num 0.949
#>  $ cp_halperin   : num 0.957
```

## What is covered

| Setting | Functions |
|:--------|:----------|
| Fisher exact, simultaneous entry | `exact_conditional_power()`, `fisher_rejection_region()`, `exact_fisher_power()` |
| Normal approximation | `halperin_conditional_power()` |
| Staggered entry, censored follow-up | `exact_conditional_power_pb()`, `pois_binom_pmf()` |
| Rate and follow-up estimators | `estimate_partitioned_rates()`, `follow_up_durations()`, `conditional_event_prob()`, `exponential_survival()`, `rate_from_risk()` |
| Discrete-visit log-rank | `logrank_exact_conditional_power()`, `logrank_moment_conditional_power()`, `logrank_atrisk_dist()`, `logrank_visit_increment()` |
| Conditional Poisson final test | `count_conditional_power_poisson()`, `count_conditional_power_nb()`, `nb_predictive_pmf()`, `convolve_pmf_list()` |
| Design utilities | `exact_sample_size()`, `conditional_power_comparison()`, `conditional_power_grid()`, `monitored_operating_characteristics()`, `monitored_size()` |

## License

GPL-3
