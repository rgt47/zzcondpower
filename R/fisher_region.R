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
#' supplies a precomputed region, its dimensions and those attributes
#' are checked against the arguments of the call, so that a region
#' built for one design or significance level cannot silently be used
#' for another.
#'
#' A region that is not a logical `(n + 1) x (n + 1)` matrix, or one whose
#' recorded attributes disagree with the call, is an error. A region
#' that lacks some or all of the attributes (built by hand, or one
#' whose attributes were dropped, for example by subsetting or
#' `matrix()`) cannot be checked; it is accepted with a warning, and
#' the returned copy is stamped with the requested values so that
#' nested calls do not warn again.
#'
#' @param region A rejection region, or `NULL`.
#' @param n Integer. Number of subjects per arm requested by the
#'   caller.
#' @param alpha Numeric. One-sided significance level requested by the
#'   caller.
#'
#' @return `region`, invisibly, with any missing attributes filled in
#'   from the call. `NULL` if `region` is `NULL`. Errors on mismatch.
#' @keywords internal
check_region <- function(region, n, alpha) {
  if (is.null(region)) {
    return(invisible(NULL))
  }
  if (!is.matrix(region) || nrow(region) != n + 1L ||
      ncol(region) != n + 1L) {
    stop("`region` must be an (n + 1) x (n + 1) matrix; with `n` = ",
         n, " that is ", n + 1L, " x ", n + 1L, ".", call. = FALSE)
  }
  # A numeric 0/1 matrix would be used as positional indices by
  # `mass[region]`, giving a silently wrong answer rather than an error.
  if (!is.logical(region)) {
    stop("`region` must be a logical matrix, as returned by ",
         "fisher_rejection_region(); got type '", typeof(region), "'.",
         call. = FALSE)
  }
  requested <- list(n = n, alpha = alpha)
  recorded <- lapply(names(requested), function(nm) {
    attr(region, nm, exact = TRUE)
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
    stop("`region` was built with ", paste(detail, collapse = ", "),
         ". Supplying a region does not override `n` or `alpha`; ",
         "rebuild the region or drop the argument.", call. = FALSE)
  }
  if (!all(present)) {
    warning("`region` does not record ",
            paste(names(requested)[!present], collapse = ", "),
            ", so it cannot be checked against the call. Assuming it ",
            "was built for the requested design; rebuild it with ",
            "fisher_rejection_region() to enable the check.",
            call. = FALSE)
    for (nm in names(requested)[!present]) {
      attr(region, nm) <- requested[[nm]]
    }
  }
  invisible(region)
}
