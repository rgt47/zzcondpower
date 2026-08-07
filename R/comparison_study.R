#' Minimal sample size for the one-sided Fisher exact test
#'
#' Finds, by bisection on the exact power function
#' [exact_fisher_power()], the smallest per-arm sample size whose
#' exact power reaches `power` at the specified one-sided level.
#'
#' @param p_treatment Numeric. Treatment-arm event probability
#'   under the alternative.
#' @param p_control Numeric. Control-arm event probability.
#' @param alpha Numeric. One-sided significance level.
#' @param power Numeric. Target power.
#' @param n_max Integer. Upper bound for the search.
#'
#' @return The minimal per-arm sample size, a single integer.
#'
#' @examples
#' \donttest{
#' exact_sample_size(0.05, 0.10)
#' }
#'
#' @export
exact_sample_size <- function(p_treatment, p_control,
                              alpha = 0.05, power = 0.8,
                              n_max = 5000) {
  stopifnot(p_treatment < p_control)
  lo <- 2L
  hi <- n_max
  if (exact_fisher_power(hi, p_treatment, p_control,
                         alpha) < power) {
    stop("target power not reached by n_max subjects per arm")
  }
  while (hi - lo > 1L) {
    mid <- (lo + hi) %/% 2L
    if (exact_fisher_power(mid, p_treatment, p_control,
                           alpha) >= power) {
      hi <- mid
    } else {
      lo <- mid
    }
  }
  hi
}

#' Numerical comparison of exact and asymptotic conditional power
#'
#' For a design scenario defined by a control-arm event rate and a
#' relative risk reduction, sizes the trial exactly for the target
#' power, then evaluates exact and asymptotic conditional power at
#' a set of information fractions with interim data equal to their
#' expectation under the alternative. The interim configuration
#' uses the clean mapping of completely observed subjects: at
#' information fraction `f`, `round(f * n)` subjects per arm are
#' fully observed and the remainder are unenrolled, so the exact
#' calculation is the Poisson-binomial of equation (9) with
#' two-valued weights and the asymptotic calculation is
#' [halperin_conditional_power()] with `m = round(f * n)`.
#'
#' @param control_rate Numeric vector of control-arm event
#'   probabilities.
#' @param reduction Numeric. Relative risk reduction under the
#'   alternative; the treatment rate is
#'   `control_rate * (1 - reduction)`.
#' @param info_fractions Numeric vector of information fractions
#'   at which to evaluate conditional power.
#' @param alpha Numeric. One-sided significance level.
#' @param power Numeric. Target design power.
#' @param n_max Integer. Upper bound for the sample-size search.
#'
#' @return A data frame with one row per scenario and information
#'   fraction: `control_rate`, `treatment_rate`, `n`,
#'   `attained_size`, `fraction`, `x1`, `y1`, `cp_exact`,
#'   `cp_asymptotic`, and `difference`
#'   (`cp_asymptotic - cp_exact`).
#'
#' @examples
#' \donttest{
#' conditional_power_comparison(0.20, info_fractions = 0.5)
#' }
#'
#' @export
conditional_power_comparison <- function(control_rate,
                                         reduction = 0.5,
                                         info_fractions =
                                           c(0.25, 0.50, 0.75),
                                         alpha = 0.05,
                                         power = 0.8,
                                         n_max = 5000) {
  rows <- lapply(control_rate, function(lam_c) {
    lam_t <- lam_c * (1 - reduction)
    n <- exact_sample_size(lam_t, lam_c, alpha, power, n_max)
    region <- fisher_rejection_region(n, alpha)
    p_bar <- (lam_t + lam_c) / 2
    size <- sum(outer(stats::dbinom(0:n, n, p_bar),
                      stats::dbinom(0:n, n, p_bar))[region])
    per_fraction <- lapply(info_fractions, function(f) {
      m <- round(f * n)
      x1 <- round(m * lam_t)
      y1 <- round(m * lam_c)
      trend_t <- x1 / m
      trend_c <- y1 / m
      q_t <- c(rep(0, m - x1), rep(trend_t, n - m))
      q_c <- c(rep(0, m - y1), rep(trend_c, n - m))
      data.frame(
        control_rate = lam_c, treatment_rate = lam_t, n = n,
        attained_size = size, fraction = f, x1 = x1, y1 = y1,
        cp_exact = exact_conditional_power_pb(
          n, x1, y1, q_t, q_c, alpha = alpha, region = region
        ),
        cp_asymptotic = halperin_conditional_power(
          n, m, trend_t, trend_c, alpha = alpha
        )
      )
    })
    do.call(rbind, per_fraction)
  })
  out <- do.call(rbind, rows)
  out$difference <- out$cp_asymptotic - out$cp_exact
  out
}
