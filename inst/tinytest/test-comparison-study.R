# Validate the exact sample-size search and the numerical
# comparison grid on a fast scenario.

library(tinytest)

## The sample-size search returns the minimal n.
n_min <- exact_sample_size(0.10, 0.20, alpha = 0.05, power = 0.8,
                           n_max = 400)
expect_true(
  exact_fisher_power(n_min, 0.10, 0.20) >= 0.8,
  info = "returned n reaches target power"
)
expect_true(
  exact_fisher_power(n_min - 1, 0.10, 0.20) < 0.8,
  info = "n - 1 falls short, so the returned n is minimal"
)

## Consistency with the worked example's Haseman sample size.
expect_equal(
  exact_sample_size(0.05, 0.10, n_max = 600), 371,
  info = "search reproduces the Haseman sample size of 371"
)

## The comparison grid has the documented structure and signs.
grid <- conditional_power_comparison(
  0.20, info_fractions = c(0.25, 0.50), n_max = 400
)
expect_equal(nrow(grid), 2, info = "one row per fraction")
expect_true(all(grid$n == n_min),
            info = "grid uses the minimal sample size")
expect_true(all(grid$attained_size < 0.05),
            info = "attained size below nominal alpha")
expect_true(all(grid$difference > 0),
            info = "asymptotic value optimistic in all rows")
expect_true(all(grid$cp_exact > 0 & grid$cp_exact < 1),
            info = "exact values are interior probabilities")

## --- Regressions from the 2026-09 code review -------------------------

## Past entry_period + follow_up every subject has completed follow-up,
## so there is no future exposure to partition. The arithmetic used to
## return a negative p2_hat, which propagated as a negative event
## probability into the conditional power functions.
expect_error(
  estimate_partitioned_rates(10, 40, 60, t = 48,
                             entry_period = 24, follow_up = 12)
)

## At exactly t == entry_period + follow_up the exposure fraction is 1,
## so p2_hat is zero. In floating point it landed a few ulp below zero
## and was then rejected by the `gamma >= 0` guard downstream.
e_bnd <- estimate_partitioned_rates(10, 40, 60, t = 36,
                                    entry_period = 24, follow_up = 12)
expect_true(e_bnd$p2_hat >= 0)
expect_equal(e_bnd$p2_hat, 0)
expect_silent_ok <- exact_conditional_power(
  50, 2, 5, e_bnd$p2_hat / (1 - e_bnd$p1_hat), 0.10)
expect_true(is.numeric(expect_silent_ok))

## Interior times are unaffected by the clamp.
e_mid <- estimate_partitioned_rates(10, 40, 60, t = 12,
                                    entry_period = 24, follow_up = 12)
expect_true(e_mid$p2_hat > 0)
