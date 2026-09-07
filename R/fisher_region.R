#' Rejection region for the one-sided Fisher exact test
#'
#' Constructs the rejection region \eqn{R} of the one-sided Fisher
#' exact test comparing two binomial proportions with `n` subjects
#' per arm, as defined in the Appendix of the manuscript. The test
#' conditions on the total number of events \eqn{s = x + y} and
#' rejects for small treatment-arm counts: the region contains all
#' pairs \eqn{(x, y)} whose lower-tail hypergeometric probability
#' \eqn{P[X \le x \mid s]} does not exceed `alpha`.
#'
#' @param n Integer. Number of subjects per arm.
#' @param alpha Numeric. One-sided significance level.
#'
#' @return A logical `(n + 1) x (n + 1)` matrix. Entry
#'   `[x + 1, y + 1]` is `TRUE` when the outcome of `x` treatment
#'   events and `y` control events rejects the null hypothesis.
#'   Attributes `n` and `alpha` record the construction inputs.
#'
#' @examples
#' r <- fisher_rejection_region(10, alpha = 0.05)
#' r[0 + 1, 7 + 1]
#'
#' @export
fisher_rejection_region <- function(n, alpha = 0.05) {
  stopifnot(length(n) == 1L, n == as.integer(n), n > 0,
            length(alpha) == 1L, alpha > 0, alpha < 1)
  x <- 0:n
  q_mat <- matrix(x, n + 1L, n + 1L)
  s_mat <- outer(x, x, "+")
  region <- matrix(
    stats::phyper(q_mat, n, n, s_mat) <= alpha,
    n + 1L, n + 1L
  )
  attr(region, "n") <- n
  attr(region, "alpha") <- alpha
  region
}

#' Exact power of the one-sided Fisher exact test
#'
#' Computes the unconditional exact power (or size, when the two
#' event probabilities are equal) of the one-sided Fisher exact
#' test by enumeration over the full outcome grid.
#'
#' @param n Integer. Number of subjects per arm.
#' @param p_treatment Numeric. Event probability in the treatment
#'   arm (the arm expected to have fewer events).
#' @param p_control Numeric. Event probability in the control arm.
#' @param alpha Numeric. One-sided significance level.
#'
#' @return The rejection probability, a single numeric value.
#'
#' @examples
#' exact_fisher_power(371, 0.05, 0.10)
#'
#' @export
exact_fisher_power <- function(n, p_treatment, p_control,
                               alpha = 0.05) {
  region <- fisher_rejection_region(n, alpha)
  px <- stats::dbinom(0:n, n, p_treatment)
  py <- stats::dbinom(0:n, n, p_control)
  sum(outer(px, py)[region])
}

#' Validate a supplied rejection region against its intended use
#'
#' Internal helper. A region built by [fisher_rejection_region()]
#' records the `n` and `alpha` it was constructed with. When a caller
#' supplies a precomputed region, those attributes are checked against
#' the arguments of the call, so that a region built at one
#' significance level cannot silently be used at another.
#'
#' @param region A rejection region, or `NULL`.
#' @param n Integer. Number of subjects per arm requested by the
#'   caller.
#' @param alpha Numeric. One-sided significance level requested by the
#'   caller.
#'
#' @return `region` unchanged, invisibly, if it is consistent with `n`
#'   and `alpha`. Errors otherwise.
#' @keywords internal
check_region <- function(region, n, alpha) {
  if (is.null(region)) {
    return(invisible(NULL))
  }
  if (nrow(region) != n + 1L) {
    stop("`region` is ", nrow(region), " x ", ncol(region),
         " but `n` = ", n, " requires ", n + 1L, " rows.",
         call. = FALSE)
  }
  ra <- attr(region, "alpha")
  if (!is.null(ra) && !isTRUE(all.equal(ra, alpha))) {
    stop("`region` was built with alpha = ", ra,
         " but alpha = ", alpha, " was requested. Supplying a region ",
         "does not override `alpha`; rebuild the region or drop the ",
         "argument.", call. = FALSE)
  }
  invisible(region)
}
