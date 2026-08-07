# Validate the conditional-power computations: degenerate cases,
# the Poisson-binomial reduction to equation (2), and agreement
# with Monte Carlo simulation.

library(tinytest)

## Degenerate case: no future events possible, so conditional power
## is the indicator that the interim table already rejects.
n <- 20
region <- fisher_rejection_region(n, 0.05)
expect_equal(
  exact_conditional_power(n, x1 = 0, y1 = 9, gamma = 0, beta = 0,
                          region = region),
  as.numeric(region[0 + 1, 9 + 1]),
  info = "gamma = beta = 0 returns rejection indicator"
)

## Poisson-binomial pmf sums to one and matches dbinom for equal q.
q <- rep(0.13, 12)
expect_equal(sum(pois_binom_pmf(q)), 1, tolerance = 1e-12,
             info = "pmf sums to one")
expect_equal(pois_binom_pmf(q), stats::dbinom(0:12, 12, 0.13),
             tolerance = 1e-12,
             info = "equal-q Poisson-binomial equals binomial")

## Equation (9) with constant q reduces to equation (2).
n <- 371
region <- fisher_rejection_region(n, 0.05)
gamma <- 0.0331
beta <- 0.0837
expect_equal(
  exact_conditional_power_pb(n, 2, 5, rep(gamma, n - 2),
                             rep(beta, n - 5), region = region),
  exact_conditional_power(n, 2, 5, gamma, beta, region = region),
  tolerance = 1e-12,
  info = "Poisson-binomial formulation reduces to equation (2)"
)

## Monte Carlo agreement at moderate n with heterogeneous q.
set.seed(20260413)
n <- 40
x1 <- 1
y1 <- 4
q_treatment <- seq(0.02, 0.10, length.out = n - x1)
q_control <- seq(0.05, 0.20, length.out = n - y1)
region <- fisher_rejection_region(n, 0.05)
exact <- exact_conditional_power_pb(n, x1, y1, q_treatment,
                                    q_control, region = region)
n_sim <- 5e5
x_final <- x1 + colSums(
  matrix(stats::runif((n - x1) * n_sim) < q_treatment, n - x1)
)
y_final <- y1 + colSums(
  matrix(stats::runif((n - y1) * n_sim) < q_control, n - y1)
)
mc <- mean(region[cbind(x_final + 1, y_final + 1)])
mc_se <- sqrt(mc * (1 - mc) / n_sim)
expect_true(abs(exact - mc) < 4 * mc_se,
            info = "exact value within 4 SE of Monte Carlo")
