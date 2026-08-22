#' Gamma-Poisson (negative-binomial) predictive distribution of a
#' subject's future event count
#'
#' Under the mean-1 gamma frailty formulation of the negative
#' binomial, a subject's events occur in a Poisson process of rate
#' \eqn{\theta Z}, \eqn{Z \sim \mathrm{Gamma}(1/\phi, 1/\phi)}
#' (shape, rate; mean 1, variance \eqn{\phi}). Having observed
#' \eqn{n} events in exposure \eqn{c}, the posterior for \eqn{Z} is
#' \eqn{\mathrm{Gamma}(1/\phi + n,\ 1/\phi + \theta c)}, and by
#' conjugacy the predictive count over additional exposure
#' \eqn{c^{+}} is exactly negative binomial with
#' `size = 1/phi + n` and
#' `prob = (1/phi + theta*c) / (1/phi + theta*c + theta*c_future)`.
#' As `phi -> 0` the gamma prior degenerates to a point mass at
#' \eqn{Z = 1} and the predictive converges to
#' \eqn{\mathrm{Poisson}(\theta c^{+})}, the pure-Poisson case with
#' no residual frailty.
#'
#' @param n Integer. Events observed so far.
#' @param c Numeric. Exposure (person-time) accrued so far.
#' @param c_future Numeric. Additional exposure to the final
#'   analysis.
#' @param phi Numeric \eqn{\ge 0}. Frailty dispersion (variance of
#'   \eqn{Z}); `phi = 0` is the pure-Poisson limit.
#' @param theta Numeric. Poisson rate parameter.
#' @param kmax Integer, optional. Upper support point; if `NULL`,
#'   chosen adaptively via `tol`.
#' @param tol Numeric. Target truncation error: support is extended
#'   until `1 - sum(pmf) < tol`.
#'
#' @return A list with `pmf` (numeric vector, `pmf[k+1] = P(N+ = k)`
#'   for `k = 0,...,kmax`), `kmax`, and `trunc_error`
#'   (`1 - sum(pmf)`, the exact, directly computed truncation error
#'   incurred, not a bound derived from an inequality).
#'
#' @export
nb_predictive_pmf <- function(n, c, c_future, phi, theta,
                              kmax = NULL, tol = 1e-10) {
  stopifnot(n >= 0, c >= 0, c_future >= 0, phi >= 0, theta >= 0)
  if (c_future == 0) {
    return(list(pmf = 1, kmax = 0L, trunc_error = 0))
  }
  if (phi <= 0) {
    lam <- theta * c_future
    if (is.null(kmax)) {
      kmax <- stats::qpois(1 - tol / 2, lam) + 10L
    }
    pmf <- stats::dpois(0:kmax, lam)
  } else {
    size <- 1 / phi + n
    prob <- (1 / phi + theta * c) / (1 / phi + theta * c + theta * c_future)
    if (is.null(kmax)) {
      kmax <- stats::qnbinom(1 - tol / 2, size = size, prob = prob) + 10L
    }
    pmf <- stats::dnbinom(0:kmax, size = size, prob = prob)
  }
  list(pmf = pmf, kmax = kmax, trunc_error = 1 - sum(pmf))
}

#' Convolution of independent, non-identical discrete pmfs
#'
#' Direct convolution recursion analogous to [pois_binom_pmf()], but
#' for arbitrary (not necessarily Bernoulli) component pmfs on
#' `{0, 1, 2, ...}`, used to build the arm-level future-count
#' distribution from per-subject negative-binomial predictive pmfs.
#'
#' @param pmf_list A list of numeric vectors, each a pmf on
#'   `0, 1, ..., k_i`.
#'
#' @return Numeric vector, the pmf of the sum, on
#'   `0, ..., sum(k_i)`.
#'
#' @export
convolve_pmf_list <- function(pmf_list) {
  if (length(pmf_list) == 0) return(1)
  out <- pmf_list[[1]]
  if (length(pmf_list) > 1) {
    for (j in 2:length(pmf_list)) {
      out <- stats::convolve(out, rev(pmf_list[[j]]), type = "open")
      out[abs(out) < 1e-13] <- 0
      out[out < 0] <- 0
    }
  }
  out
}

#' Exact conditional power of the conditional Poisson (Przyborowski-
#' Wilenski) final test, pure-Poisson case
#'
#' In the absence of frailty (\eqn{\phi = 0}), each subject's future
#' count is Poisson, so each arm's future total is exactly Poisson
#' (sum of independent Poissons), and the conditional Poisson test
#' given the total final event count \eqn{D} has an exact fixed
#' rejection region (Przyborowski and Wilenski, 1940). This function
#' enumerates that rejection region exactly and sums its probability
#' under the specified rates, conditional on the interim event
#' counts.
#'
#' @param x1,x2 Interim event counts in arm 1 (treatment) and arm 2
#'   (control).
#' @param future_exposure1,future_exposure2 Total remaining exposure
#'   (sum across at-risk subjects) to the final analysis in each
#'   arm.
#' @param theta1,theta2 Assumed future event rates per unit exposure
#'   in each arm.
#' @param alpha One-sided level.
#' @param p0 Null exposure-weighted share used to define the
#'   rejection region, `p0 = future_exposure1 /
#'   (future_exposure1 + future_exposure2)` under \eqn{H_0} of
#'   common rate and no further complication; supplied explicitly to
#'   allow a design-stage exposure ratio distinct from the observed
#'   interim ratio.
#'
#' @return A list with `power`, and `rejection_region` (a logical
#'   vector over `k = 0,...,Dmax` future total events, `TRUE`
#'   where the arm-1 split rejects at that total).
#'
#' @export
count_conditional_power_poisson <- function(x1, x2,
                                            future_exposure1,
                                            future_exposure2,
                                            theta1, theta2,
                                            alpha = 0.025,
                                            p0 = NULL) {
  stopifnot(x1 >= 0, x2 >= 0, future_exposure1 >= 0,
            future_exposure2 >= 0, theta1 >= 0, theta2 >= 0)
  if (is.null(p0)) {
    denom <- future_exposure1 + future_exposure2
    p0 <- if (denom > 0) future_exposure1 / denom else 0.5
  }
  lam1 <- theta1 * future_exposure1
  lam2 <- theta2 * future_exposure2
  kmax1 <- stats::qpois(1 - 1e-12, lam1) + 10L
  kmax2 <- stats::qpois(1 - 1e-12, lam2) + 10L
  pmf1 <- stats::dpois(0:kmax1, lam1)
  pmf2 <- stats::dpois(0:kmax2, lam2)
  power <- 0
  z_alpha <- stats::qnorm(1 - alpha)
  for (i in seq_along(pmf1)) {
    n1_future <- i - 1L
    for (j in seq_along(pmf2)) {
      n2_future <- j - 1L
      p_path <- pmf1[i] * pmf2[j]
      if (p_path < 1e-16) next
      d1 <- x1 + n1_future
      d2 <- x2 + n2_future
      D <- d1 + d2
      if (D == 0) next
      # exact conditional (binomial) test: reject if the
      # one-sided exact binomial upper-tail p-value for
      # (d1 | D, p0) is <= alpha
      pval <- stats::pbinom(d1 - 1L, D, p0, lower.tail = FALSE)
      if (pval <= alpha) power <- power + p_path
    }
  }
  list(power = power, p0 = p0)
}

#' Conditional power under gamma-Poisson (negative-binomial)
#' heterogeneity, applying the conditional Poisson test's
#' (nominal) rejection region
#'
#' Extends [count_conditional_power_poisson()] to `phi > 0` by
#' convolving the per-subject negative-binomial predictive pmfs
#' ([nb_predictive_pmf()]) into an arm-level future-count
#' distribution, then applying the same conditional-Poisson
#' rejection rule used in the pure-Poisson case. This is exact
#' *conditional on the assumed frailty model for the future data*,
#' but note carefully: when `phi > 0` the conditional Poisson test's
#' classical exact-size guarantee (which relies on the arm totals
#' being Poisson, not negative binomial) no longer holds, so the
#' quantity returned is the exact probability that the *nominal*
#' conditional-Poisson decision rule rejects when the true generating
#' process is negative binomial, not the exact power of a test with
#' guaranteed exact size. This function does not compute or claim an
#' exact-size test for `phi > 0`; see the manuscript's discussion of
#' this distinction.
#'
#' @inheritParams count_conditional_power_poisson
#' @param subjects1,subjects2 Data frames (or `NULL` for a
#'   homogeneous-exposure shortcut) with columns `n` (events so
#'   far), `c` (exposure so far), and `c_future` (remaining exposure)
#'   for each at-risk subject in the arm.
#' @param phi Numeric \eqn{\ge 0}. Common frailty dispersion assumed
#'   for both arms.
#' @param tol Truncation tolerance passed to [nb_predictive_pmf()]
#'   for each subject; per-subject truncation errors are additive to
#'   a first order and the achieved total is returned.
#'
#' @return A list with `power`, `p0`, and `trunc_error` (sum of the
#'   per-subject truncation errors, an upper bound on the resulting
#'   error in `power`).
#'
#' @export
count_conditional_power_nb <- function(subjects1, subjects2,
                                       theta1, theta2, phi,
                                       alpha = 0.025, p0 = NULL,
                                       tol = 1e-10) {
  build_arm <- function(subjects, theta) {
    pmfs <- lapply(seq_len(nrow(subjects)), function(i) {
      nb_predictive_pmf(subjects$n[i], subjects$c[i],
                        subjects$c_future[i], phi, theta, tol = tol)
    })
    list(pmf = convolve_pmf_list(lapply(pmfs, `[[`, "pmf")),
         trunc_error = sum(vapply(pmfs, `[[`, numeric(1),
                                  "trunc_error")),
         x_observed = sum(subjects$n))
  }
  arm1 <- build_arm(subjects1, theta1)
  arm2 <- build_arm(subjects2, theta2)
  if (is.null(p0)) {
    fe1 <- sum(subjects1$c_future); fe2 <- sum(subjects2$c_future)
    denom <- fe1 + fe2
    p0 <- if (denom > 0) fe1 / denom else 0.5
  }
  pmf1 <- arm1$pmf; pmf2 <- arm2$pmf
  power <- 0
  for (i in seq_along(pmf1)) {
    n1_future <- i - 1L
    if (pmf1[i] < 1e-14) next
    for (j in seq_along(pmf2)) {
      n2_future <- j - 1L
      p_path <- pmf1[i] * pmf2[j]
      if (p_path < 1e-16) next
      d1 <- arm1$x_observed + n1_future
      d2 <- arm2$x_observed + n2_future
      D <- d1 + d2
      if (D == 0) next
      pval <- stats::pbinom(d1 - 1L, D, p0, lower.tail = FALSE)
      if (pval <= alpha) power <- power + p_path
    }
  }
  list(power = power, p0 = p0,
       trunc_error = arm1$trunc_error + arm2$trunc_error)
}
