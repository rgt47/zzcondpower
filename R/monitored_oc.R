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
#' @param region Optional precomputed rejection region from
#'   [fisher_rejection_region()], checked against `n` and `alpha` as
#'   described for [exact_conditional_power()]. In
#'   `conditional_power_grid()` it is validated but not used when
#'   `driver = 'asymptotic'`.
#'
#' @return An `(m + 1) x (m + 1)` matrix; entry `[x1 + 1, y1 + 1]`
#'   is the current-trend conditional power at that interim state.
#'   Attributes `n`, `m`, `alpha` and `driver` record the construction
#'   inputs; [monitored_operating_characteristics()] and
#'   [monitored_size()] check them when the grid is supplied as
#'   `cp_grid`.
#'
#' @export
conditional_power_grid <- function(n, m, alpha = 0.05,
                                   driver = c("exact",
                                              "asymptotic"),
                                   region = NULL) {
  driver <- match.arg(driver)
  stopifnot(m > 0, m < n)
  # Validated before the asymptotic branch even though that branch does
  # not use it, so a region built for another design is never accepted.
  region <- check_region(region, n, alpha)
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
    return(stamp_cp_grid(grid, n, m, alpha, driver))
  }
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
  stamp_cp_grid(grid, n, m, alpha, driver)
}

stamp_cp_grid <- function(grid, n, m, alpha, driver) {
  attr(grid, "n") <- n
  attr(grid, "m") <- m
  attr(grid, "alpha") <- alpha
  attr(grid, "driver") <- driver
  grid
}

#' Validate a supplied conditional-power grid against its intended use
#'
#' Internal helper. A grid built by [conditional_power_grid()] records
#' the `n`, `m`, `alpha` and `driver` it was constructed with. When a
#' caller supplies a precomputed grid, its dimensions and those
#' attributes are checked against the arguments of the call, so that a
#' grid built for one design cannot silently be used for another.
#'
#' A grid of the wrong dimensions, or one whose recorded attributes
#' disagree with the call, is an error. A grid that lacks some or all
#' of the attributes (built by hand, or by zzcondpower 0.4.0 or
#' earlier, which did not record them) cannot be checked; it is
#' accepted with a warning, and the returned copy is stamped with the
#' requested values so that nested calls do not warn again.
#'
#' @param cp_grid A conditional-power grid, or `NULL`.
#' @param n,m,alpha,driver The design requested by the caller.
#'
#' @return `cp_grid`, invisibly, with any missing attributes filled in
#'   from the call. `NULL` if `cp_grid` is `NULL`. Errors on mismatch.
#' @keywords internal
check_cp_grid <- function(cp_grid, n, m, alpha, driver) {
  if (is.null(cp_grid)) {
    return(invisible(NULL))
  }
  if (!is.matrix(cp_grid) || nrow(cp_grid) != m + 1L ||
      ncol(cp_grid) != m + 1L) {
    stop("`cp_grid` must be an (m + 1) x (m + 1) matrix; with `m` = ",
         m, " that is ", m + 1L, " x ", m + 1L, ".", call. = FALSE)
  }
  requested <- list(n = n, m = m, alpha = alpha, driver = driver)
  recorded <- lapply(names(requested), function(nm) {
    attr(cp_grid, nm, exact = TRUE)
  })
  names(recorded) <- names(requested)
  present <- !vapply(recorded, is.null, logical(1))
  checkable <- names(requested)[present]
  agrees <- vapply(checkable, function(nm) {
    isTRUE(all.equal(recorded[[nm]], requested[[nm]]))
  }, logical(1))
  mismatched <- checkable[!agrees]
  if (length(mismatched) > 0L) {
    detail <- vapply(mismatched, function(nm) {
      paste0(nm, " = ", recorded[[nm]], " (requested ",
             requested[[nm]], ")")
    }, character(1))
    stop("`cp_grid` was built with ", paste(detail, collapse = ", "),
         ". Supplying a grid does not override the design arguments; ",
         "rebuild the grid or drop the argument.", call. = FALSE)
  }
  if (!all(present)) {
    warning("`cp_grid` does not record ",
            paste(names(requested)[!present], collapse = ", "),
            ", so it cannot be checked against the call. Assuming it ",
            "was built for the requested design; rebuild it with ",
            "conditional_power_grid() to enable the check.",
            call. = FALSE)
    for (nm in names(requested)[!present]) {
      attr(cp_grid, nm) <- requested[[nm]]
    }
  }
  invisible(cp_grid)
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
#'   across thresholds and true-rate settings. It must have been built
#'   with the same `n`, `m`, `alpha` and `driver` as the call: a grid
#'   whose recorded values disagree is an error, and a grid that does
#'   not record them (built by hand or by zzcondpower 0.4.0 or
#'   earlier) is accepted with a warning.
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
  region <- check_region(region, n, alpha)
  cp_grid <- check_cp_grid(cp_grid, n, m, alpha, driver)
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
  # Checked once here; the stamped copies keep the per-rate calls below
  # from repeating a missing-attribute warning.
  region <- check_region(region, n, alpha)
  cp_grid <- check_cp_grid(cp_grid, n, m, alpha, driver)
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
