# Validate the monitored-procedure operating-characteristics
# computation: degenerate thresholds, deflation/inflation
# directions, and regression pins on the worked-example design.

library(tinytest)

n <- 173
m <- 86
region <- fisher_rejection_region(n, 0.05)
cpg <- conditional_power_grid(n, m, driver = "exact",
                              region = region)

## tau = 0 never stops: fixed-design power and size recovered.
oc0 <- monitored_operating_characteristics(
  n, m, tau = 0, 0.10, 0.20, region = region, cp_grid = cpg
)
expect_equal(oc0$reject, exact_fisher_power(n, 0.10, 0.20),
             tolerance = 1e-12,
             info = "tau = 0 recovers fixed-design power")
expect_equal(oc0$stop, 0, info = "tau = 0 never stops")
expect_equal(oc0$ess, 2 * n, tolerance = 1e-12,
             info = "tau = 0 uses the full sample size")

## tau > 1 always stops.
oc1 <- monitored_operating_characteristics(
  n, m, tau = 1.01, 0.10, 0.20, region = region, cp_grid = cpg
)
expect_equal(oc1$stop, 1, info = "tau > 1 always stops")
expect_equal(oc1$reject, 0,
             info = "always stopping precludes rejection")

## Monotone consequences of futility stopping.
oc <- monitored_operating_characteristics(
  n, m, tau = 0.2, 0.10, 0.20, region = region, cp_grid = cpg
)
expect_true(oc$reject < oc0$reject,
            info = "futility stopping costs power")
sz <- monitored_size(n, m, tau = 0.2,
                     null_rates = c(0.10, 0.15, 0.20),
                     region = region, cp_grid = cpg)
expect_true(
  all(sz <= vapply(c(0.10, 0.15, 0.20), function(p) {
    exact_fisher_power(n, p, p)
  }, numeric(1))),
  info = "monitored size deflated below fixed attained size"
)

## The asymptotic driver stops less often than the exact driver
## (its conditional power is optimistic).
cpa <- conditional_power_grid(n, m, driver = "asymptotic")
oca <- monitored_operating_characteristics(
  n, m, tau = 0.2, 0.10, 0.20, region = region, cp_grid = cpa
)
expect_true(oca$stop < oc$stop,
            info = "asymptotic driver stops less often")

## Regression pins on the worked-example design (n = 371,
## f = 0.5, tau = 0.2, exact driver).
n2 <- 371
m2 <- 186
region2 <- fisher_rejection_region(n2, 0.05)
cpg2 <- conditional_power_grid(n2, m2, driver = "exact",
                               region = region2)
oc2 <- monitored_operating_characteristics(
  n2, m2, tau = 0.2, 0.05, 0.10, region = region2,
  cp_grid = cpg2
)
expect_equal(oc2$reject, 0.7432, tolerance = 5e-4,
             info = "worked-example monitored power")
expect_equal(oc2$stop, 0.1518, tolerance = 5e-4,
             info = "worked-example stopping probability")
