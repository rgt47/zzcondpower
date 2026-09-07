#' Asymptotic conditional power in the Halperin tradition
#'
#' Computes the normal-approximation conditional power for the
#' two-proportion comparison, in the z-statistic formulation that
#' descends from Halperin et al. (1982) and that standard
#' conditional-power software implements (Jennison and Turnbull
#' 2000, Section 10.2; the same formulas appear in the PASS
#' documentation). The interim z-statistic is carried forward under
#' an assumed future treatment effect on the difference scale, with
#' statistical information \eqn{I = m / (2 \sigma^2)} for `m`
#' effective subjects per arm and \eqn{\sigma^2 = \bar p (1 - \bar
#' p)}.
#'
#' The interim data of the exact framework (partial follow-up of
#' staggered enrollees) are mapped to an effective number of
#' completely observed subjects per arm,
#' \eqn{m = n_1 + n_2 (t - \bar t) / F}, the denominator of the
#' moment estimator in equation (4); the interim event-rate
#' estimates are then `x1 / m` per arm. This is the mapping used by
#' [thomas1991_example()].
#'
#' @param n Integer. Subjects per arm at the final analysis.
#' @param m Numeric. Effective completely observed subjects per arm
#'   at the interim analysis; must be less than `n`.
#' @param p_treatment Numeric. Interim event-rate estimate in the
#'   treatment arm.
#' @param p_control Numeric. Interim event-rate estimate in the
#'   control arm.
#' @param theta Numeric. Assumed future treatment effect on the
#'   difference scale, `p_control - p_treatment`; defaults to the
#'   observed interim difference (current-trend conditional power).
#' @param alpha Numeric. One-sided significance level of the final
#'   test.
#'
#' @return The asymptotic conditional power, a single numeric
#'   value.
#'
#' @references Halperin M, Lan KKG, Ware JH, Johnson NJ, DeMets DL
#'   (1982). An aid to data monitoring in long-term clinical
#'   trials. Controlled Clinical Trials 3, 311-323.
#'
#' @examples
#' halperin_conditional_power(371, 48.8, 2 / 48.8, 5 / 48.8)
#'
#' @export
halperin_conditional_power <- function(n, m, p_treatment,
                                       p_control, theta = NULL,
                                       alpha = 0.05) {
  stopifnot(m >= 0, m < n,
            p_treatment >= 0, p_treatment <= 1,
            p_control >= 0, p_control <= 1,
            alpha > 0, alpha < 1)
  if (is.null(theta)) {
    theta <- p_control - p_treatment
  }
  p_bar <- (p_treatment + p_control) / 2
  sigma2 <- p_bar * (1 - p_bar)
  # Both arms at 0 or both at 1 give a degenerate pooled variance, and
  # the information terms below would be Inf, returning NaN silently.
  # Zero events in both arms is the expected early state of a
  # rare-event trial, so this is worth refusing explicitly.
  if (sigma2 <= 0) {
    stop("Pooled event rate is ", p_bar, ", giving zero variance; ",
         "the normal approximation is undefined. Use ",
         "`exact_conditional_power()` for degenerate interim data.",
         call. = FALSE)
  }
  info_interim <- m / (2 * sigma2)
  info_final <- n / (2 * sigma2)
  info_remaining <- info_final - info_interim
  numerator <- (p_control - p_treatment) * info_interim -
    stats::qnorm(1 - alpha) * sqrt(info_final) +
    theta * info_remaining
  stats::pnorm(numerator / sqrt(info_remaining))
}
