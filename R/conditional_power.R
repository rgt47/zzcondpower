#' Exact conditional power under simultaneous entry (equation 2)
#'
#' Evaluates the exact conditional power of the manuscript's
#' equation (2): the probability, given the interim event counts,
#' that the final \eqn{2 \times 2} table falls in the Fisher
#' rejection region, when the remaining subjects in each arm share
#' a common conditional future-event probability.
#'
#' @param n Integer. Number of subjects per arm at the final
#'   analysis (the sample size defining the rejection region).
#' @param x1 Integer. Events observed in the treatment arm at the
#'   interim analysis.
#' @param y1 Integer. Events observed in the control arm at the
#'   interim analysis.
#' @param gamma Numeric. Conditional probability that an at-risk
#'   treatment-arm subject experiences the event before the end of
#'   follow-up, \eqn{\gamma = p_2 / (1 - p_1)}.
#' @param beta Numeric. The control-arm analogue,
#'   \eqn{\beta = \lambda_2 / (1 - \lambda_1)}.
#' @param alpha Numeric. One-sided significance level of the final
#'   Fisher exact test.
#' @param region Optional precomputed rejection region from
#'   [fisher_rejection_region()]; supplying it avoids
#'   reconstruction across repeated calls.
#'
#' @return The conditional power, a single numeric value.
#'
#' @examples
#' exact_conditional_power(371, x1 = 2, y1 = 5,
#'                         gamma = 0.0331, beta = 0.0837)
#'
#' @export
exact_conditional_power <- function(n, x1, y1, gamma, beta,
                                    alpha = 0.05, region = NULL) {
  stopifnot(x1 >= 0, y1 >= 0, x1 <= n, y1 <= n,
            gamma >= 0, gamma <= 1, beta >= 0, beta <= 1)
  q_treatment <- rep(gamma, n - x1)
  q_control <- rep(beta, n - y1)
  exact_conditional_power_pb(n, x1, y1, q_treatment, q_control,
                             alpha = alpha, region = region)
}

#' Probability mass function of the Poisson-binomial distribution
#'
#' Computes the exact probability mass function of a sum of
#' independent, non-identically distributed Bernoulli variables by
#' the direct convolution recursion of the manuscript's equation
#' (8). The recursion requires `O(length(q)^2)` operations and is
#' numerically stable at small event probabilities.
#'
#' @param q Numeric vector of Bernoulli success probabilities.
#'
#' @return Numeric vector of length `length(q) + 1` whose `k`-th
#'   element is the probability of `k - 1` successes.
#'
#' @examples
#' pois_binom_pmf(c(0.1, 0.2, 0.3))
#'
#' @export
pois_binom_pmf <- function(q) {
  stopifnot(all(q >= 0), all(q <= 1))
  pmf <- 1
  for (qi in q) {
    pmf <- c(pmf, 0) * (1 - qi) + c(0, pmf) * qi
  }
  pmf
}

#' Exact conditional power with subject-specific event
#' probabilities (equation 9)
#'
#' Evaluates the survival-formulation conditional power of the
#' manuscript's equation (9). The future event count in each arm is
#' the sum of independent Bernoulli variables with
#' subject-specific conditional probabilities, so its distribution
#' is Poisson-binomial; conditional power is the Poisson-binomial
#' mass summed over the Fisher rejection region. With constant
#' probabilities within each arm this reduces exactly to
#' [exact_conditional_power()].
#'
#' @inheritParams exact_conditional_power
#' @param q_treatment Numeric vector of length `n - x1`:
#'   conditional future-event probabilities for the treatment-arm
#'   subjects without an observed event, from equation (7).
#' @param q_control Numeric vector of length `n - y1`: the
#'   control-arm analogue.
#'
#' @return The conditional power, a single numeric value.
#'
#' @export
exact_conditional_power_pb <- function(n, x1, y1, q_treatment,
                                       q_control, alpha = 0.05,
                                       region = NULL) {
  stopifnot(length(q_treatment) == n - x1,
            length(q_control) == n - y1)
  if (is.null(region)) {
    region <- fisher_rejection_region(n, alpha)
  }
  stopifnot(nrow(region) == n + 1L)
  fx <- pois_binom_pmf(q_treatment)
  fy <- pois_binom_pmf(q_control)
  mass <- outer(fx, fy)
  sum(mass[region[(x1:n) + 1L, (y1:n) + 1L, drop = FALSE]])
}
