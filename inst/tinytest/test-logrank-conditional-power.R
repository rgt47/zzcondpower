library(tinytest)

# --- pmf sanity: at-risk state distribution sums to 1 and is
# non-negative at every visit ---
d <- logrank_atrisk_dist(5, 5, h1 = c(0.3, 0.2), h2 = c(0.15, 0.1))
expect_equal(length(d), 2L, info = "one matrix per visit")
for (m in d) {
  expect_true(all(m >= -1e-12), info = "no negative probability mass")
  expect_equal(sum(m), 1, tolerance = 1e-10,
               info = "at-risk distribution sums to 1")
}

# --- visit increment: null case (no events) contributes nothing ---
inc0 <- logrank_visit_increment(5, 5, 0, 0)
expect_equal(unname(inc0), c(0, 0), info = "no events, no increment")

# --- visit increment matches the textbook single-stratum
# Mantel-Haenszel formula ---
inc <- logrank_visit_increment(a1 = 6, a2 = 4, d1 = 2, d2 = 1)
n <- 10; dtot <- 3
expect_equal(unname(inc["oe"]), 2 - 6 * 3 / 10, tolerance = 1e-12)
expect_equal(unname(inc["v"]), 6 * 4 * 3 * (10 - 3) / (10^2 * 9),
             tolerance = 1e-12)

# --- exact conditional power: probability bounds ---
res <- logrank_exact_conditional_power(5, 5, h1 = c(0.3, 0.3),
                                       h2 = c(0.15, 0.15),
                                       alpha = 0.025)
expect_true(res$power >= 0 && res$power <= 1,
            info = "conditional power is a probability")

# --- exact conditional power validated against Monte Carlo
# simulation of the same discrete-visit process (regression-level
# tolerance; simulation SE with 2e5 replicates is about 0.0007 for
# a probability near 0.1, so 5 SE gives a wide but meaningful
# check) ---
simulate_logrank_power <- function(n1, n2, h1, h2, alpha, nsim,
                                   seed) {
  set.seed(seed)
  z_alpha <- stats::qnorm(1 - alpha)
  reject <- 0L
  for (s in seq_len(nsim)) {
    a1 <- n1; a2 <- n2; s_stat <- 0; v_stat <- 0
    for (v in seq_along(h1)) {
      d1 <- stats::rbinom(1, a1, h1[v])
      d2 <- stats::rbinom(1, a2, h2[v])
      inc <- logrank_visit_increment(a1, a2, d1, d2)
      s_stat <- s_stat + inc["oe"]; v_stat <- v_stat + inc["v"]
      a1 <- a1 - d1; a2 <- a2 - d2
    }
    z <- if (v_stat > 0) s_stat / sqrt(v_stat) else -Inf
    if (z >= z_alpha) reject <- reject + 1L
  }
  reject / nsim
}
nsim <- 2e5
p_sim <- simulate_logrank_power(5, 5, c(0.3, 0.3), c(0.15, 0.15),
                                0.025, nsim = nsim, seed = 42)
se_sim <- sqrt(p_sim * (1 - p_sim) / nsim)
expect_true(abs(res$power - p_sim) < 5 * se_sim,
            info = paste0("exact enumeration (", round(res$power, 4),
                           ") vs Monte Carlo simulation (",
                           round(p_sim, 4), "), 5-SE band ",
                           round(5 * se_sim, 4)))

# --- moment-matched normal approximation: same order of magnitude
# as exact enumeration (no strict convergence proof is claimed;
# this pins the observed discrepancy so a future regression is
# detected) ---
mom <- logrank_moment_conditional_power(5, 5, h1 = c(0.3, 0.3),
                                        h2 = c(0.15, 0.15),
                                        alpha = 0.025)
expect_true(abs(res$power - mom$power) < 0.03,
            info = "moment-matched normal approximation within 0.03 of exact enumeration for this small configuration")

# --- max_states guard actually triggers (documents the
# combinatorial bound rather than silently truncating) ---
expect_error(
  logrank_exact_conditional_power(6, 6, h1 = c(0.3, 0.3, 0.3),
                                  h2 = c(0.15, 0.15, 0.15),
                                  max_states = 5),
  info = "state-space cap is enforced, not silently ignored"
)

# --- degenerate case: zero at-risk subjects gives zero power
# (cannot reject with no data) ---
res0 <- logrank_exact_conditional_power(0, 0, h1 = c(0.2),
                                        h2 = c(0.1), alpha = 0.025)
expect_equal(res0$power, 0)
