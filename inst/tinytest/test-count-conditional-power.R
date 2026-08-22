library(tinytest)

# --- convolve_pmf_list matches a known closed-form sum of
# independent Poissons (sum of Poisson(2) and Poisson(3) is
# Poisson(5)) ---
p1 <- stats::dpois(0:10, 2)
p2 <- stats::dpois(0:10, 3)
conv <- convolve_pmf_list(list(p1, p2))
known <- stats::dpois(0:20, 5)
expect_true(max(abs(conv - known)) < 5e-4,
            info = "convolution of two Poisson pmfs matches the known-closed-form Poisson sum")

# --- nb_predictive_pmf closed form validated against direct Monte
# Carlo integration over the gamma posterior (the derivation this
# function encodes is not simulated: it is verified against
# simulation here) ---
set.seed(1)
n <- 2; c <- 3; c_future <- 4; phi <- 0.5; theta <- 0.4
post_shape <- 1 / phi + n
post_rate <- 1 / phi + theta * c
nsim <- 2e6
z <- stats::rgamma(nsim, shape = post_shape, rate = post_rate)
nfut <- stats::rpois(nsim, theta * c_future * z)
emp <- tabulate(nfut + 1, nbins = 15) / nsim
res <- nb_predictive_pmf(n, c, c_future, phi, theta)
expect_true(max(abs(res$pmf[1:15] - emp[1:15])) < 5e-3,
            info = "gamma-Poisson conjugate predictive pmf matches Monte Carlo integration over the posterior")
expect_equal(sum(res$pmf), 1, tolerance = res$trunc_error + 1e-9,
             info = "pmf sums to 1 minus the reported truncation error")

# --- phi -> 0 recovers the pure-Poisson predictive distribution
# (the stated reduction) ---
res0 <- nb_predictive_pmf(n, c, c_future, phi = 1e-8, theta = theta)
pois_pmf <- stats::dpois(0:res0$kmax, theta * c_future)
expect_true(max(abs(res0$pmf - pois_pmf)) < 1e-6,
            info = "phi -> 0 reduces the negative-binomial predictive to Poisson")

# --- exact conditional Poisson (Przyborowski-Wilenski) conditional
# power validated against Monte Carlo simulation of the same
# pure-Poisson future-data model ---
set.seed(7)
x1 <- 5; x2 <- 2; fe1 <- 30; fe2 <- 30
theta1 <- 0.30; theta2 <- 0.15
res_p <- count_conditional_power_poisson(x1, x2, fe1, fe2, theta1,
                                         theta2, alpha = 0.025)
nsim <- 3e5
n1f <- stats::rpois(nsim, theta1 * fe1)
n2f <- stats::rpois(nsim, theta2 * fe2)
d1 <- x1 + n1f; d2 <- x2 + n2f; d_tot <- d1 + d2
pv <- stats::pbinom(d1 - 1, d_tot, res_p$p0, lower.tail = FALSE)
p_sim <- mean(pv <= 0.025 & d_tot > 0)
se_sim <- sqrt(p_sim * (1 - p_sim) / nsim)
expect_true(abs(res_p$power - p_sim) < 5 * se_sim,
            info = paste0("exact conditional-Poisson power (",
                           round(res_p$power, 4),
                           ") vs Monte Carlo (", round(p_sim, 4), ")"))

# --- NB (frailty) conditional power reduces to the pure-Poisson
# result as phi -> 0 ---
subj1 <- data.frame(n = c(2, 3), c = c(10, 10), c_future = c(15, 15))
subj2 <- data.frame(n = c(1, 1), c = c(10, 10), c_future = c(15, 15))
res_nb_tiny <- count_conditional_power_nb(subj1, subj2, theta1 = 0.3,
                                          theta2 = 0.15, phi = 1e-9,
                                          alpha = 0.025)
res_poisson_equiv <- count_conditional_power_poisson(
  sum(subj1$n), sum(subj2$n), sum(subj1$c_future), sum(subj2$c_future),
  0.3, 0.15, alpha = 0.025)
expect_equal(res_nb_tiny$power, res_poisson_equiv$power,
             tolerance = 1e-6,
             info = "phi -> 0 recovers the pure-Poisson conditional power exactly")

# --- NB (frailty, phi > 0) conditional power validated against
# Monte Carlo simulation of the full frailty-posterior future-data
# generating model ---
set.seed(11)
subj1b <- data.frame(n = c(1, 0, 2), c = c(8, 8, 8),
                     c_future = c(12, 12, 12))
subj2b <- data.frame(n = c(0, 1, 0), c = c(8, 8, 8),
                     c_future = c(12, 12, 12))
phi <- 0.6; theta1b <- 0.25; theta2b <- 0.10
res_nb <- count_conditional_power_nb(subj1b, subj2b, theta1b, theta2b,
                                     phi, alpha = 0.025)
sim_future_sum <- function(subjects, theta, phi, nsim) {
  tot <- matrix(0, nsim, nrow(subjects))
  for (i in seq_len(nrow(subjects))) {
    ps <- 1 / phi + subjects$n[i]
    pr <- 1 / phi + theta * subjects$c[i]
    z <- stats::rgamma(nsim, shape = ps, rate = pr)
    tot[, i] <- stats::rpois(nsim, theta * subjects$c_future[i] * z)
  }
  rowSums(tot)
}
nsim <- 3e5
n1f <- sim_future_sum(subj1b, theta1b, phi, nsim)
n2f <- sim_future_sum(subj2b, theta2b, phi, nsim)
d1 <- sum(subj1b$n) + n1f; d2 <- sum(subj2b$n) + n2f; d_tot <- d1 + d2
pv <- stats::pbinom(d1 - 1, d_tot, res_nb$p0, lower.tail = FALSE)
p_sim <- mean(pv <= 0.025 & d_tot > 0)
se_sim <- sqrt(p_sim * (1 - p_sim) / nsim)
expect_true(abs(res_nb$power - p_sim) < 5 * se_sim,
            info = paste0("exact frailty-conditioned power (",
                           round(res_nb$power, 4),
                           ") vs Monte Carlo (", round(p_sim, 4), ")"))
