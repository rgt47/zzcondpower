#' @keywords internal
#'
#' @section Significance level conventions:
#' The `alpha` default is not uniform across the package, because the
#' two families of methods follow the conventions of their respective
#' source literatures.
#'
#' \itemize{
#'   \item The Fisher exact family ([exact_conditional_power()],
#'     [exact_conditional_power_pb()], [fisher_rejection_region()],
#'     [exact_fisher_power()], [halperin_conditional_power()]) and the
#'     monitoring utilities ([conditional_power_grid()],
#'     [monitored_operating_characteristics()], [monitored_size()])
#'     default to `alpha = 0.05`, one-sided.
#'   \item The log-rank family
#'     ([logrank_exact_conditional_power()],
#'     [logrank_moment_conditional_power()]) and the conditional
#'     Poisson family ([count_conditional_power_poisson()],
#'     [count_conditional_power_nb()]) default to `alpha = 0.025`,
#'     one-sided, the equivalent of a two-sided 0.05 test.
#' }
#'
#' Both members of each pair agree with each other, so an exact result
#' and its approximation are always comparable. Results are **not**
#' comparable across families unless `alpha` is set explicitly. When
#' comparing a Fisher-based conditional power against a log-rank one,
#' pass `alpha` to both rather than relying on the defaults.
#'
#' @section Precomputed rejection regions:
#' Several functions accept a `region` argument to avoid rebuilding the
#' rejection region across repeated calls. A region records the `n` and
#' `alpha` it was built with, and supplying one that disagrees with the
#' arguments of the call is an error rather than a silent override.
#' Supplying a region does not change the significance level.
"_PACKAGE"

## usethis namespace: start
#' @importFrom stats aggregate convolve dbinom pbinom pnorm qnorm
## usethis namespace: end
NULL
