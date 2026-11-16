# Regression tests for the cp_grid design check. A precomputed grid
# used to be accepted regardless of the n, m, alpha and driver of the
# call, so a grid built at alpha = 0.05 silently returned the 0.05
# answer for an alpha = 0.01 call.

library(tinytest)

n <- 50
m <- 20
g05 <- conditional_power_grid(n, m, alpha = 0.05)

expect_equal(
  lapply(c("n", "m", "alpha", "driver"), function(a) {
    attr(g05, a, exact = TRUE)
  }),
  list(50, 20, 0.05, "exact"),
  info = "cp_grid defect: grid records n, m, alpha and driver"
)
expect_identical(
  attr(conditional_power_grid(n, m, driver = "asymptotic"), "driver"),
  "asymptotic",
  info = "cp_grid defect: asymptotic grid records its driver"
)

expect_error(
  monitored_operating_characteristics(n, m, 0.1, 0.05, 0.10,
                                      alpha = 0.01, cp_grid = g05),
  pattern = "alpha = 0.05",
  info = "cp_grid defect: alpha mismatch is an error in monitored OC"
)
expect_error(
  monitored_size(n, m, 0.1, c(0.05, 0.10), alpha = 0.01,
                 cp_grid = g05),
  pattern = "alpha = 0.05",
  info = "cp_grid defect: alpha mismatch is an error in monitored_size"
)
expect_error(
  monitored_operating_characteristics(
    n, m, 0.1, 0.05, 0.10, cp_grid = conditional_power_grid(60, m)
  ),
  pattern = "n = 60",
  info = "cp_grid defect: n mismatch is an error"
)
expect_error(
  monitored_operating_characteristics(
    n, m, 0.1, 0.05, 0.10,
    cp_grid = conditional_power_grid(n, m, driver = "asymptotic")
  ),
  pattern = "driver = asymptotic",
  info = "cp_grid defect: driver mismatch is an error"
)
expect_error(
  monitored_operating_characteristics(
    n, m, 0.1, 0.05, 0.10, cp_grid = conditional_power_grid(n, 25)
  ),
  pattern = "21 x 21",
  info = "cp_grid defect: wrong-dimension grid gets a clear error"
)

## A matching grid gives the same answer as recomputation, silently.
fresh <- monitored_operating_characteristics(n, m, 0.1, 0.05, 0.10,
                                             alpha = 0.01)
g01 <- conditional_power_grid(n, m, alpha = 0.01)
expect_silent(
  supplied <- monitored_operating_characteristics(
    n, m, 0.1, 0.05, 0.10, alpha = 0.01, cp_grid = g01
  ),
  info = "cp_grid defect: matching grid is accepted without warning"
)
expect_equal(supplied, fresh, tolerance = 1e-12,
             info = "cp_grid defect: matching grid equals recomputation")

## A grid without attributes cannot be checked: one warning, then the
## same answer as a matching grid.
bare <- matrix(as.vector(g05), m + 1L, m + 1L)
warnings_seen <- 0L
bare_size <- withCallingHandlers(
  monitored_size(n, m, 0.1, c(0.05, 0.10, 0.15), cp_grid = bare),
  warning = function(w) {
    warnings_seen <<- warnings_seen + 1L
    invokeRestart("muffleWarning")
  }
)
expect_equal(warnings_seen, 1L,
             info = "cp_grid defect: attribute-free grid warns exactly once")
expect_equal(
  bare_size,
  monitored_size(n, m, 0.1, c(0.05, 0.10, 0.15), cp_grid = g05),
  tolerance = 1e-12,
  info = "cp_grid defect: attribute-free grid is still used as given"
)
expect_warning(
  monitored_operating_characteristics(n, m, 0.1, 0.05, 0.10,
                                      cp_grid = bare),
  pattern = "does not record",
  info = "cp_grid defect: attribute-free grid warns in monitored OC"
)
