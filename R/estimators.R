#' Moment-based event-rate estimation under staggered entry
#' (equations 3 to 6)
#'
#' Implements the manuscript's method-of-moments estimators for the
#' marginal event rate and its partition at an interim monitoring
#' time under staggered uniform enrollment and a constant hazard.
#' All arguments are vectorized over arms.
#'
#' @param x1 Integer. Events observed by the interim time `t`.
#' @param n_completed Integer. Subjects who have completed the full
#'   follow-up period at `t` (\eqn{n_{j1}}).
#' @param n_on_study Integer. Subjects enrolled and still under
#'   follow-up at `t` (\eqn{n_{j2}}).
#' @param t Numeric. Interim monitoring time (years from start).
#' @param entry_period Numeric. Planned enrollment period `E`.
#' @param follow_up Numeric. Follow-up horizon `F` per subject.
#'
#' @return A list with components `lambda_hat` (marginal event
#'   rate, equation 4), `p1_hat` (pre-interim component, equation
#'   5), `p2_hat` (post-interim component, equation 6), and `t_bar`
#'   (mean enrollment time of on-study subjects).
#'
#' @examples
#' estimate_partitioned_rates(x1 = c(2, 5), n_completed = 0,
#'                            n_on_study = 244, t = 2,
#'                            entry_period = 3, follow_up = 5)
#'
#' @export
estimate_partitioned_rates <- function(x1, n_completed, n_on_study,
                                       t, entry_period, follow_up) {
  stopifnot(t > 0, entry_period > 0, follow_up > 0,
            all(x1 >= 0), all(n_on_study >= 0),
            all(n_completed >= 0))
  # Past entry_period + follow_up the last subject has completed
  # follow-up, so there is no remaining exposure to partition. The
  # arithmetic below would give a mean exposure exceeding follow_up and
  # hence a negative p2_hat, which propagates as a negative event
  # probability into the conditional power functions.
  if (t > entry_period + follow_up) {
    stop("`t` = ", t, " is past entry_period + follow_up = ",
         entry_period + follow_up, ", when all subjects have completed ",
         "follow-up. There is no future exposure to partition, so ",
         "conditional power is not defined at this time.", call. = FALSE)
  }
  t_bar <- (min(t, entry_period) + max(0, t - follow_up)) / 2
  mean_exposure <- t - t_bar
  lambda_hat <- x1 /
    (n_completed + n_on_study * mean_exposure / follow_up)
  p1_hat <- lambda_hat * mean_exposure / follow_up
  p2_hat <- lambda_hat - p1_hat
  # At t == entry_period + follow_up the exposure fraction is exactly 1
  # in real arithmetic, so p2_hat is 0. In floating point it lands a few
  # ulp below, and the negative value is then rejected by the
  # `gamma >= 0` guard downstream. Clamp the rounding error, but only
  # the rounding error: anything materially negative is a real problem
  # and should still surface.
  tiny <- 8 * .Machine$double.eps * pmax(lambda_hat, 1)
  p2_hat[p2_hat < 0 & p2_hat > -tiny] <- 0
  list(lambda_hat = lambda_hat, p1_hat = p1_hat, p2_hat = p2_hat,
       t_bar = t_bar)
}

#' Follow-up durations accrued at an interim monitoring time
#'
#' @param t Numeric. Interim monitoring time.
#' @param entry_times Numeric vector of enrollment times; use
#'   values greater than `t` (or `Inf`) for subjects not yet
#'   enrolled.
#' @param follow_up Numeric. Follow-up horizon `F` per subject.
#'
#' @return Numeric vector of follow-up durations
#'   \eqn{c_i = \min(F, \max(0, t - e_i))}.
#'
#' @export
follow_up_durations <- function(t, entry_times, follow_up) {
  pmin(follow_up, pmax(0, t - entry_times))
}

#' Conditional future-event probability given event-free follow-up
#' (equation 7)
#'
#' Computes \eqn{q_i = (S(c_i) - S(F)) / S(c_i)}: the probability
#' that a subject who is event-free after `time_on_study` years of
#' follow-up experiences the event by the horizon `follow_up`,
#' under the survival function `surv_fn`.
#'
#' @param time_on_study Numeric vector of accrued event-free
#'   follow-up durations, in `[0, follow_up]`.
#' @param follow_up Numeric. Follow-up horizon `F`.
#' @param surv_fn Function. Survival function \eqn{S(u)},
#'   vectorized over `u`, with \eqn{S(0) = 1}.
#'
#' @return Numeric vector of conditional event probabilities. A
#'   completed subject (`time_on_study == follow_up`) returns 0; an
#'   unenrolled subject (`time_on_study == 0`) returns the marginal
#'   event probability \eqn{1 - S(F)}.
#'
#' @examples
#' s_exp <- exponential_survival(rate_from_risk(0.10, 5))
#' conditional_event_prob(c(0, 2.5, 5), 5, s_exp)
#'
#' @export
conditional_event_prob <- function(time_on_study, follow_up,
                                   surv_fn) {
  stopifnot(all(time_on_study >= 0),
            all(time_on_study <= follow_up))
  s_c <- surv_fn(time_on_study)
  s_f <- surv_fn(follow_up)
  (s_c - s_f) / s_c
}

#' Exponential survival function factory
#'
#' @param rate Numeric. Constant hazard \eqn{\theta}.
#'
#' @return A function of `u` returning \eqn{\exp(-\theta u)}.
#'
#' @export
exponential_survival <- function(rate) {
  stopifnot(rate >= 0)
  function(u) exp(-rate * u)
}

#' Constant hazard implied by a cumulative event risk
#'
#' Inverts \eqn{1 - \exp(-\theta F) = \lambda} to recover the
#' exponential hazard that produces the cumulative event
#' probability `risk` over `follow_up` years.
#'
#' @param risk Numeric. Cumulative event probability by the
#'   horizon.
#' @param follow_up Numeric. Follow-up horizon `F`.
#'
#' @return The hazard rate \eqn{\theta}, a single numeric value.
#'
#' @export
rate_from_risk <- function(risk, follow_up) {
  stopifnot(all(risk >= 0), all(risk < 1), follow_up > 0)
  -log(1 - risk) / follow_up
}
