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
