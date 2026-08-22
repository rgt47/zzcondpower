#' Exact joint at-risk state distribution under scheduled visits
#'
#' Computes the exact joint distribution of the arm-1 and arm-2
#' at-risk counts at each of a sequence of discrete assessment
#' visits, under a life-table (piecewise-constant-hazard) model in
#' which an at-risk subject in arm \eqn{j} experiences the event
#' during visit interval \eqn{v} with probability \eqn{h_{jv}},
#' independently across subjects. Because subjects in the two arms
#' are independent, the bivariate process
#' \eqn{(a_{1v}, a_{2v})_{v=1}^{V}} is the product of two
#' independent binomial-thinning Markov chains, so the joint state
#' space has at most \eqn{(n_1+1)(n_2+1)} support points at each
#' visit: a polynomial bound, exact.
#'
#' @param n1,n2 Integer. At-risk counts entering the first future
#'   visit in arm 1 and arm 2.
#' @param h1,h2 Numeric vectors of length \eqn{V}, the per-visit
#'   conditional event probabilities for an at-risk subject in each
#'   arm (piecewise-constant hazard over the visit schedule).
#'
#' @return A list of length \eqn{V}, each element a matrix with
#'   `n1 + 1` rows and `n2 + 1` columns (0-indexed) giving
#'   \eqn{P(a_{1v} = i, a_{2v} = j)} after visit `v`.
#'
#' @export
logrank_atrisk_dist <- function(n1, n2, h1, h2) {
  stopifnot(length(h1) == length(h2), all(h1 >= 0), all(h1 <= 1),
            all(h2 >= 0), all(h2 <= 1), n1 >= 0, n2 >= 0)
  vv <- length(h1)
  p1 <- c(1, rep(0, n1))
  p2 <- c(1, rep(0, n2))
  out <- vector("list", vv)
  for (v in seq_len(vv)) {
    p1 <- thin_dist(p1, h1[v])
    p2 <- thin_dist(p2, h2[v])
    out[[v]] <- outer(p1, p2)
  }
  out
}

#' Binomial-thinning update of an at-risk count distribution
#'
#' Given the distribution of the number currently at risk, applies
#' one visit's binomial thinning (independent Bernoulli\eqn{(h)}
#' event per at-risk subject) and returns the distribution of the
#' number at risk after the visit. Internal helper.
#'
#' @param p Numeric vector, `p[k+1] = P(a = k)` for `k = 0,...,m`.
#' @param h Numeric scalar hazard for this visit.
#' @keywords internal
#' @noRd
thin_dist <- function(p, h) {
  m <- length(p) - 1L
  out <- rep(0, m + 1L)
  for (a in 0:m) {
    pa <- p[a + 1L]
    if (pa <= 0) next
    surv <- stats::dbinom(0:a, a, 1 - h)
    out[1:(a + 1L)] <- out[1:(a + 1L)] + pa * surv
  }
  out
}

#' Log-rank visit-level score and information increment
#'
#' Computes the Mantel-Haenszel (grouped-data log-rank) increment
#' to the numerator (observed minus expected treatment-arm events)
#' and to the score-statistic variance for one assessment visit,
#' given the at-risk counts entering the visit and the events
#' observed in each arm during the visit.
#'
#' @param a1,a2 At-risk counts entering the visit.
#' @param d1,d2 Events observed during the visit in each arm.
#'
#' @return A length-2 numeric vector `c(oe, v)`.
#' @export
logrank_visit_increment <- function(a1, a2, d1, d2) {
  n <- a1 + a2
  d <- d1 + d2
  if (n <= 0 || d == 0) return(c(oe = 0, v = 0))
  oe <- d1 - a1 * d / n
  v <- if (n > 1) a1 * a2 * d * (n - d) / (n^2 * (n - 1)) else 0
  c(oe = oe, v = v)
}

#' Exact conditional power of the discrete-time log-rank statistic
#' by full path enumeration
#'
#' Enumerates, exactly, every joint sequence of arm-1/arm-2 event
#' counts across the remaining scheduled visits, accumulates the
#' Mantel-Haenszel score numerator \eqn{S = \sum_v (O_v - E_v)} and
#' variance \eqn{V = \sum_v v_v} along each path, and sums the
#' probability of the paths whose final \eqn{Z = S/\sqrt{V}} exceeds
#' the one-sided critical value. This is exact given the assumed
#' visit hazards, but the number of enumerated paths is bounded
#' above by \eqn{\prod_{v=1}^V (a_{1,v-1}+1)(a_{2,v-1}+1)} (worst
#' case, before state merging), so it is only computationally
#' tractable for a small number of remaining visits and a small
#' number of at-risk subjects: the "few-event regime" this
#' manuscript targets. Paths are merged whenever they reach an
#' identical `(a1, a2)` state with `S` and `V` equal after rounding
#' to `round_digits` digits, which is lossless (not an
#' approximation) except for the negligible risk of two genuinely
#' distinct rational values coinciding after rounding; this risk is
#' not corrected for and is noted as a limitation.
#'
#' @param n1,n2 At-risk counts entering the first future visit.
#' @param h1,h2 Numeric vectors of per-visit hazards (length \eqn{V}).
#' @param alpha One-sided level of the final log-rank test.
#' @param s0,v0 Numeric. Score numerator and variance already
#'   accrued from history prior to the first future visit (0 if the
#'   interim analysis coincides with the start of the visit
#'   schedule).
#' @param max_states Integer safety cap on the number of enumerated
#'   `(a1, a2, S, V)` combinations at any one visit; the function
#'   errors rather than silently truncating if exceeded.
#' @param round_digits Digits used to merge floating-point-equal
#'   `(S, V)` values.
#'
#' @return A list with elements `power` (the exact conditional
#'   power), `n_paths` (final number of distinct enumerated states,
#'   a diagnostic of the combinatorial cost actually incurred), and
#'   `z_alpha` (the critical value used).
#'
#' @export
logrank_exact_conditional_power <- function(n1, n2, h1, h2,
                                            alpha = 0.025, s0 = 0,
                                            v0 = 0,
                                            max_states = 2e6,
                                            round_digits = 8) {
  stopifnot(length(h1) == length(h2))
  z_alpha <- stats::qnorm(1 - alpha)
  state <- data.frame(a1 = n1, a2 = n2, S = s0, V = v0, p = 1)
  for (v in seq_along(h1)) {
    hh1 <- h1[v]
    hh2 <- h2[v]
    rows <- vector("list", nrow(state))
    for (i in seq_len(nrow(state))) {
      a1 <- state$a1[i]; a2 <- state$a2[i]
      Si <- state$S[i]; Vi <- state$V[i]; pi <- state$p[i]
      pd1 <- stats::dbinom(0:a1, a1, hh1)
      pd2 <- stats::dbinom(0:a2, a2, hh2)
      grid <- expand.grid(d1 = 0:a1, d2 = 0:a2)
      pr <- pi * pd1[grid$d1 + 1L] * pd2[grid$d2 + 1L]
      keep <- pr > 0
      grid <- grid[keep, , drop = FALSE]
      pr <- pr[keep]
      Nn <- a1 + a2
      dd <- grid$d1 + grid$d2
      if (Nn > 0) {
        inc_oe <- grid$d1 - a1 * dd / Nn
      } else {
        inc_oe <- rep(0, nrow(grid))
      }
      if (Nn > 1) {
        inc_v <- a1 * a2 * dd * (Nn - dd) / (Nn^2 * (Nn - 1))
      } else {
        inc_v <- rep(0, nrow(grid))
      }
      rows[[i]] <- data.frame(a1 = a1 - grid$d1, a2 = a2 - grid$d2,
                               S = Si + inc_oe, V = Vi + inc_v,
                               p = pr)
    }
    state <- do.call(rbind, rows)
    state$Sr <- round(state$S, round_digits)
    state$Vr <- round(state$V, round_digits)
    agg <- stats::aggregate(p ~ a1 + a2 + Sr + Vr, data = state,
                             FUN = sum)
    names(agg)[names(agg) == "Sr"] <- "S"
    names(agg)[names(agg) == "Vr"] <- "V"
    state <- agg[, c("a1", "a2", "S", "V", "p")]
    if (nrow(state) > max_states) {
      stop("logrank_exact_conditional_power: state space exceeded ",
           "max_states (", nrow(state), " > ", max_states, "); ",
           "reduce the number of remaining visits or at-risk ",
           "subjects, or use logrank_moment_conditional_power().")
    }
  }
  z <- ifelse(state$V > 0, state$S / sqrt(state$V), -Inf)
  power <- sum(state$p[z >= z_alpha])
  list(power = power, n_paths = nrow(state), z_alpha = z_alpha)
}

#' Exact first two moments of the log-rank score statistic, and a
#' moment-matched normal-approximation conditional power
#'
#' Computes \eqn{E[S_V]} and \eqn{\mathrm{Var}(S_V)} of the
#' cumulative Mantel-Haenszel score numerator exactly, by
#' propagating first and second moments (rather than the full
#' distribution) through the polynomial-size joint at-risk-state
#' recursion of [logrank_atrisk_dist()]. This step is exact and
#' polynomial-time regardless of the number of visits or at-risk
#' subjects. Conditional power is then approximated by treating the
#' accrued information \eqn{V_V} as its expectation (a standard
#' simplification also used in the Brownian-motion / Lan-DeMets
#' approximation) and \eqn{S_V} as normal with its exact mean and
#' variance; this is NOT an exact calculation and its accuracy
#' should be checked against [logrank_exact_conditional_power()]
#' where the latter is computationally feasible. It is expected to
#' improve on the standard asymptotic drift approximation because
#' the moments used are exact for the assumed discrete-visit model
#' rather than themselves approximated, but no general error bound
#' is derived here; only the numerical convergence checks in the
#' package test suite support this expectation.
#'
#' @inheritParams logrank_exact_conditional_power
#'
#' @return A list with `power` (moment-matched normal-approximation
#'   conditional power), `mean_S`, `var_S`, and `mean_V`.
#'
#' @export
logrank_moment_conditional_power <- function(n1, n2, h1, h2,
                                             alpha = 0.025, s0 = 0,
                                             v0 = 0) {
  stopifnot(length(h1) == length(h2))
  z_alpha <- stats::qnorm(1 - alpha)
  state <- data.frame(a1 = n1, a2 = n2, p = 1, mS = s0, mS2 = s0^2,
                       mV = v0)
  for (v in seq_along(h1)) {
    hh1 <- h1[v]; hh2 <- h2[v]
    rows <- vector("list", nrow(state))
    for (i in seq_len(nrow(state))) {
      a1 <- state$a1[i]; a2 <- state$a2[i]; p <- state$p[i]
      mS <- state$mS[i]; mS2 <- state$mS2[i]; mV <- state$mV[i]
      pd1 <- stats::dbinom(0:a1, a1, hh1)
      pd2 <- stats::dbinom(0:a2, a2, hh2)
      grid <- expand.grid(d1 = 0:a1, d2 = 0:a2)
      pr <- pd1[grid$d1 + 1L] * pd2[grid$d2 + 1L]
      keep <- pr > 0
      grid <- grid[keep, , drop = FALSE]; pr <- pr[keep]
      Nn <- a1 + a2; dd <- grid$d1 + grid$d2
      if (Nn > 0) {
        inc_oe <- grid$d1 - a1 * dd / Nn
      } else {
        inc_oe <- rep(0, nrow(grid))
      }
      if (Nn > 1) {
        inc_v <- a1 * a2 * dd * (Nn - dd) / (Nn^2 * (Nn - 1))
      } else {
        inc_v <- rep(0, nrow(grid))
      }
      Snew <- mS / max(p, .Machine$double.eps) + inc_oe
      newp <- p * pr
      rows[[i]] <- data.frame(a1 = a1 - grid$d1, a2 = a2 - grid$d2,
                               p = newp, mS = newp * Snew,
                               mS2 = newp * Snew^2,
                               mV = newp * (mV / max(p, .Machine$double.eps) +
                                              inc_v))
    }
    st <- do.call(rbind, rows)
    agg <- stats::aggregate(cbind(p, mS, mS2, mV) ~ a1 + a2,
                             data = st, FUN = sum)
    state <- agg
  }
  mean_S <- sum(state$mS)
  mean_S2 <- sum(state$mS2)
  var_S <- mean_S2 - mean_S^2
  mean_V <- sum(state$mV)
  z_thresh <- z_alpha * sqrt(max(mean_V, 0))
  power <- if (var_S > 0) {
    stats::pnorm((mean_S - z_thresh) / sqrt(var_S))
  } else {
    as.numeric(mean_S >= z_thresh)
  }
  list(power = power, mean_S = mean_S, var_S = var_S, mean_V = mean_V)
}
