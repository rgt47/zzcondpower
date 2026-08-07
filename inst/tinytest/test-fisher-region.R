# Validate the rejection region against fisher.test and check the
# design-stage operating characteristics of the worked example.

library(tinytest)

n <- 8
alpha <- 0.05
region <- fisher_rejection_region(n, alpha)

for (x in 0:n) {
  for (y in 0:n) {
    tab <- matrix(c(x, n - x, y, n - y), nrow = 2)
    p <- stats::fisher.test(tab, alternative = "less")$p.value
    expect_equal(
      region[x + 1, y + 1], p <= alpha,
      info = sprintf(
        "region membership matches fisher.test at (%d, %d)", x, y
      )
    )
  }
}

expect_true(
  exact_fisher_power(50, 0.05, 0.05, alpha = 0.05) <= 0.05,
  info = "attained size does not exceed nominal alpha (n = 50)"
)

expect_equal(
  exact_fisher_power(371, 0.05, 0.10, alpha = 0.05), 0.80004,
  tolerance = 1e-5,
  info = "Haseman sample size of 371 gives 80% exact power"
)

expect_true(
  exact_fisher_power(370, 0.05, 0.10, alpha = 0.05) < 0.80,
  info = "n = 370 falls short of 80% power, so 371 is minimal"
)
