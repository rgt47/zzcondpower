#' Worked example of Section 4 of the manuscript
#'
#' Reproduces the manuscript's worked example: a hypothetical
#' two-arm mortality trial with uniform enrollment over
#' `entry_period = 3` years, follow-up horizon `follow_up = 5`
#' years, a one-sided Fisher exact test at `alpha = 0.05`, and the
#' Haseman exact sample size of 371 subjects per arm. Conditional
#' power is evaluated at each interim look by two routes: the
#' homogeneous plug-in of equation (2) with the moment estimators
#' of equations (4) to (6), and the exact stratified
#' Poisson-binomial calculation of equation (9) under an
#' exponential survival model with the same estimated marginal
#' rates and a uniform enrollment grid.
#'
#' Conventions: the rejection region at the first look uses the
#' planned final sample size of 371 per arm; at the second look it
#' uses the achieved enrollment of 350 per arm.
#'
#' @param look Integer, 1 or 2. Which interim look to evaluate.
#'
#' @return A list with components `estimates` (the
#'   [estimate_partitioned_rates()] output for both arms),
#'   `m_effective` (effective completely observed subjects per
#'   arm), `cp_homogeneous` (equation 2), `cp_stratified`
#'   (equation 9), and `cp_halperin` (the asymptotic comparator of
#'   [halperin_conditional_power()] under the current trend).
#'
#' @examples
#' \donttest{
#' thomas1991_example(look = 1)$cp_stratified
#' }
#'
#' @export
thomas1991_example <- function(look = 1) {
  stopifnot(look %in% c(1, 2))
  entry_period <- 3
  follow_up <- 5
  alpha <- 0.05
  if (look == 1) {
    t <- 2; n <- 371; enrolled <- 244
    n_completed <- 0; n_on_study <- 244
    x1 <- 2; y1 <- 5
    entry_times <- c(seq(0, t, length.out = enrolled),
                     rep(Inf, n - enrolled))
  } else {
    t <- 6; n <- 350; enrolled <- 350
    n_completed <- 122; n_on_study <- 228
    x1 <- 15; y1 <- 25
    entry_times <- seq(0, entry_period, length.out = enrolled)
  }

  est <- estimate_partitioned_rates(
    x1 = c(x1, y1), n_completed = n_completed,
    n_on_study = n_on_study, t = t,
    entry_period = entry_period, follow_up = follow_up
  )

  region <- fisher_rejection_region(n, alpha)
  gamma <- est$p2_hat[1] / (1 - est$p1_hat[1])
  beta <- est$p2_hat[2] / (1 - est$p1_hat[2])
  cp_homogeneous <- exact_conditional_power(
    n, x1, y1, gamma, beta, alpha = alpha, region = region
  )

  durations <- follow_up_durations(t, entry_times, follow_up)
  q_arm <- function(lambda, n_events) {
    surv <- exponential_survival(rate_from_risk(lambda, follow_up))
    q <- conditional_event_prob(durations, follow_up, surv)
    q[-seq_len(n_events)]
  }
  cp_stratified <- exact_conditional_power_pb(
    n, x1, y1,
    q_treatment = q_arm(est$lambda_hat[1], x1),
    q_control = q_arm(est$lambda_hat[2], y1),
    alpha = alpha, region = region
  )

  m_effective <- n_completed +
    n_on_study * (t - est$t_bar) / follow_up
  cp_halperin <- halperin_conditional_power(
    n, m_effective,
    p_treatment = est$lambda_hat[1],
    p_control = est$lambda_hat[2],
    alpha = alpha
  )

  list(estimates = est, m_effective = m_effective,
       cp_homogeneous = cp_homogeneous,
       cp_stratified = cp_stratified,
       cp_halperin = cp_halperin)
}
