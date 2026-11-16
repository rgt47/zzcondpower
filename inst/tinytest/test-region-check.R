# Regression tests for the region design check. check_region() used to
# compare only the row count and, when present, the recorded alpha, so
# an attribute-stripped region was accepted silently at any alpha and a
# region with extra columns or a mismatched recorded n passed unchecked.

library(tinytest)

n <- 60
reg05 <- fisher_rejection_region(n, alpha = 0.05)
plain <- matrix(as.vector(reg05), n + 1L, n + 1L)

expect_warning(
  exact_conditional_power(n, 2, 5, 0.03, 0.12, alpha = 0.01,
                          region = plain),
  pattern = "does not record n, alpha",
  info = "region defect: attribute-stripped region warns"
)

expect_error(
  exact_conditional_power(n, 2, 5, 0.03, 0.12,
                          region = cbind(reg05, FALSE)),
  pattern = "61 x 61",
  info = "region defect: extra column is a dimension error"
)

narrow <- reg05[, -1]
attr(narrow, "n") <- n
attr(narrow, "alpha") <- 0.05
expect_error(
  exact_conditional_power(n, 2, 5, 0.03, 0.12, region = narrow),
  pattern = "61 x 61",
  info = "region defect: missing column is a clear dimension error"
)

expect_error(
  exact_conditional_power(n, 2, 5, 0.03, 0.12,
                          region = as.vector(reg05)),
  pattern = "must be an \\(n \\+ 1\\) x \\(n \\+ 1\\) matrix",
  info = "region defect: non-matrix region is a clear error"
)

relabeled <- reg05
attr(relabeled, "n") <- 70
expect_error(
  exact_conditional_power(n, 2, 5, 0.03, 0.12, region = relabeled),
  pattern = "n = 70",
  info = "region defect: recorded n differing from the call is an error"
)

expect_error(
  exact_conditional_power(n, 2, 5, 0.03, 0.12, alpha = 0.01,
                          region = reg05),
  pattern = "alpha = 0.05",
  info = "region defect: recorded alpha mismatch is still an error"
)

expect_silent(
  exact_conditional_power(n, 2, 5, 0.03, 0.12, region = reg05),
  info = "region defect: matching region is accepted without warning"
)

## An unchecked region is used as given: same answer as the attributed
## region at the alpha it was actually built with.
expect_equal(
  suppressWarnings(
    exact_conditional_power(n, 2, 5, 0.03, 0.12, region = plain)
  ),
  exact_conditional_power(n, 2, 5, 0.03, 0.12, region = reg05),
  info = "region defect: unchecked region is used as given"
)

## monitored_size() passes the region through conditional_power_grid()
## and one monitored_operating_characteristics() call per rate; the
## missing-attribute warning must appear once, not once per nested call.
bare50 <- matrix(as.vector(fisher_rejection_region(50, 0.05)), 51, 51)
warnings_seen <- 0L
bare_size <- withCallingHandlers(
  monitored_size(50, 20, 0.1, c(0.05, 0.10, 0.15), region = bare50),
  warning = function(w) {
    warnings_seen <<- warnings_seen + 1L
    invokeRestart("muffleWarning")
  }
)
expect_equal(warnings_seen, 1L,
             info = "region defect: stripped region warns exactly once")
expect_equal(
  bare_size,
  monitored_size(50, 20, 0.1, c(0.05, 0.10, 0.15)),
  tolerance = 1e-12,
  info = "region defect: stripped region gives the recomputed answer"
)

## A numeric 0/1 region was used as positional indices by mass[region]
## in exact_conditional_power_pb(), giving a silently wrong answer.
numeric_region <- reg05 * 1
attr(numeric_region, "n") <- n
attr(numeric_region, "alpha") <- 0.05
expect_error(
  exact_conditional_power(n, 2, 5, 0.03, 0.12, region = numeric_region),
  pattern = "must be a logical matrix",
  info = "region defect: numeric 0/1 region is an error"
)

## The asymptotic driver of conditional_power_grid() returned before the
## region check ran, so a mismatched region was accepted silently.
expect_error(
  conditional_power_grid(50, 20, alpha = 0.01, driver = "asymptotic",
                         region = fisher_rejection_region(50, 0.05)),
  pattern = "alpha = 0.05",
  info = "region defect: asymptotic grid validates a supplied region"
)
expect_silent(
  conditional_power_grid(50, 20, alpha = 0.05, driver = "asymptotic",
                         region = fisher_rejection_region(50, 0.05)),
  info = "region defect: asymptotic grid accepts a matching region"
)
