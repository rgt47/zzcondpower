#' Current-trend conditional power over all interim states
#'
#' Computes, for every interim state \eqn{(x_1, y_1)} of a design
#' with `m` completely observed subjects per arm and `n - m` yet to
#' be enrolled, the current-trend conditional power of the final
#' one-sided Fisher exact test. The `exact` driver evaluates
#' equation (2) with trend rates `x1 / m` and `y1 / m`; the
#' `asymptotic` driver evaluates [halperin_conditional_power()] at
#' the same rates.
#'
#' @param n Integer. Subjects per arm at the final analysis.
#' @param m Integer. Completely observed subjects per arm at the
#'   interim analysis, `0 < m < n`.
#' @param alpha Numeric. One-sided significance level.
#' @param driver Character. `'exact'` or `'asymptotic'`.
#' @param region Optional precomputed rejection region.
#'
#' @return An `(m + 1) x (m + 1)` matrix; entry `[x1 + 1, y1 + 1]`
#'   is the current-trend conditional power at that interim state.
#'
#' @export
conditional_power_grid <- function(n, m, alpha = 0.05,
                                   driver = c("exact",
                                              "asymptotic"),
                                   region = NULL) {
  driver <- match.arg(driver)
  stopifnot(m > 0, m < n)
  if (driver == "asymptotic") {
    grid <- outer(0:m, 0:m, function(x1, y1) {
      # The normal approximation is undefined where the pooled interim
      # rate is 0 or 1, because the pooled variance vanishes. Both
      # corners are degenerate in the same direction: with no events in
      # either arm, or events in every subject of both arms, the final
      # table cannot fall in the rejection region. Return 0 there, which
      # is what the exact driver computes.
      p_bar <- (x1 + y1) / (2 * m)
      ifelse(
        p_bar * (1 - p_bar) <= 0, 0,
        halperin_conditional_power_vec(n, m, x1 / m, y1 / m,
                                       alpha)
      )
    })
    return(grid)
  }
  check_region(region, n, alpha)
  if (is.null(region)) {
    region <- fisher_rejection_region(n, alpha)
  }
  k <- n - m
  grid <- matrix(0, m + 1L, m + 1L)
  py <- lapply(0:m, function(y1) {
    stats::dbinom(0:k, k, y1 / m)
  })
  for (x1 in 0:m) {
    px <- stats::dbinom(0:k, k, x1 / m)
    v <- as.vector(px %*% region[(x1:(x1 + k)) + 1L, ])
    for (y1 in 0:m) {
      grid[x1 + 1L, y1 + 1L] <-
        sum(v[(y1:(y1 + k)) + 1L] * py[[y1 + 1L]])
    }
  }
  grid
}

# Vectorized body of halperin_conditional_power() without the
# scalar argument checks, for grid evaluation.
halperin_conditional_power_vec <- function(n, m, p_treatment,
                                           p_control, alpha) {
  p_bar <- (p_treatment + p_control) / 2
  # Deliberately not floored. Flooring at .Machine$double.eps turned a
  # degenerate input into a finite, plausible, wrong number instead of
  # NaN; callers must screen the degenerate corners themselves, as
  # conditional_power_grid() does.
  sigma2 <- p_bar * (1 - p_bar)
  info_interim <- m / (2 * sigma2)
  info_final <- n / (2 * sigma2)
  info_remaining <- info_final - info_interim
  theta <- p_control - p_treatment
  numerator <- theta * info_interim -
    stats::qnorm(1 - alpha) * sqrt(info_final) +
    theta * info_remaining
  stats::pnorm(numerator / sqrt(info_remaining))
}

#' Operating characteristics of a conditional-power futility rule
#'
#' Computes, by exact enumeration over all interim states, the
#' operating characteristics of a monitored procedure that stops
#' for futility when current-trend conditional power falls below
#' `tau` at a single interim look with `m` completely observed
#' subjects per arm, and otherwise proceeds to the final one-sided
#' Fisher exact test on `n` subjects per arm. In the sense of
#' Lachin (2005) and Kunz and Kieser (2012), the futility rule can
#' only deflate the attained size and inflate the type II error;
#' this function quantifies both without approximation.
#'
#' @inheritParams conditional_power_grid
#' @param tau Numeric. Futility threshold: stop when conditional
#'   power is below `tau`.
#' @param p_treatment Numeric. True treatment-arm event
#'   probability used for the enumeration.
#' @param p_control Numeric. True control-arm event probability.
#' @param cp_grid Optional precomputed matrix from
#'   [conditional_power_grid()]; supplying it avoids recomputation
#'   across thresholds and true-rate settings.
#'
#' @return A list: `reject` (probability of final rejection with
#'   the futility rule in force), `stop` (probability of stopping
#'   at the interim), and `ess` (expected total sample size over
#'   both arms).
#'
#' @references Lachin JM (2005). A review of methods for futility
#'   stopping based on conditional power. Statistics in Medicine
#'   24, 2747-2764. Kunz CU, Kieser M (2012). Curtailment in
#'   single-arm two-stage phase II oncology trials. Biometrical
#'   Journal 54, 445-456.
#'
#' @export
monitored_operating_characteristics <- function(n, m, tau,
                                                p_treatment,
                                                p_control,
                                                alpha = 0.05,
                                                driver = c(
                                                  "exact",
                                                  "asymptotic"
                                                ),
                                                region = NULL,
                                                cp_grid = NULL) {
  driver <- match.arg(driver)
  check_region(region, n, alpha)
  if (is.null(region)) {
    region <- fisher_rejection_region(n, alpha)
  }
  if (is.null(cp_grid)) {
    cp_grid <- conditional_power_grid(n, m, alpha, driver, region)
  }
  continue <- cp_grid >= tau
  k <- n - m
  kern_t <- vapply(0:m, function(x1) {
    stats::dbinom(0:n - x1, k, p_treatment)
  }, numeric(n + 1L))
  kern_c <- vapply(0:m, function(y1) {
    stats::dbinom(0:n - y1, k, p_control)
  }, numeric(n + 1L))
  reject_given <- t(kern_t) %*% region %*% kern_c
  w_t <- stats::dbinom(0:m, m, p_treatment)
  w_c <- stats::dbinom(0:m, m, p_control)
  weight <- outer(w_t, w_c)
  p_stop <- sum(weight[!continue])
  p_reject <- sum(weight * continue * reject_given)
  list(
    reject = p_reject,
    stop = p_stop,
    ess = 2 * (m + k * (1 - p_stop))
  )
}

#' Attained size of the monitored procedure over a null grid
#'
#' Evaluates [monitored_operating_characteristics()] under
#' `p_treatment = p_control = p` for each `p` in `null_rates` and
#' returns the rejection probabilities; their maximum estimates
#' the attained size of the monitored procedure.
#'
#' @inheritParams monitored_operating_characteristics
#' @param null_rates Numeric vector of common event rates under
#'   the null hypothesis.
#'
#' @return Numeric vector of attained rejection probabilities,
#'   one per element of `null_rates`.
#'
#' @export
monitored_size <- function(n, m, tau, null_rates, alpha = 0.05,
                           driver = c("exact", "asymptotic"),
                           region = NULL, cp_grid = NULL) {
  driver <- match.arg(driver)
  check_region(region, n, alpha)
  if (is.null(region)) {
    region <- fisher_rejection_region(n, alpha)
  }
  if (is.null(cp_grid)) {
    cp_grid <- conditional_power_grid(n, m, alpha, driver, region)
  }
  vapply(null_rates, function(p) {
    monitored_operating_characteristics(
      n, m, tau, p, p, alpha, driver, region, cp_grid
    )$reject
  }, numeric(1))
}
