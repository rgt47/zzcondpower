# Validate the Halperin-type asymptotic comparator: limiting
# behavior, monotonicity, worked-example regression values, and
# bounded disagreement with the exact calculation at large n.

library(tinytest)

## With no interim information the calculation reduces to the
## unconditional normal-approximation power.
n <- 400
pT <- 0.05
pC <- 0.10
sigma2 <- (pT + pC) / 2 * (1 - (pT + pC) / 2)
info_final <- n / (2 * sigma2)
unconditional <- pnorm(
  (pC - pT) * sqrt(info_final) - qnorm(0.95)
)
expect_equal(
  halperin_conditional_power(n, 0, pT, pC), unconditional,
  tolerance = 1e-12,
  info = "m = 0 recovers unconditional normal-theory power"
)

## Conditional power is increasing in the assumed future effect.
cp_theta <- vapply(
  c(0, 0.02, 0.05, 0.08),
  function(th) halperin_conditional_power(400, 200, 0.06, 0.09,
                                          theta = th),
  numeric(1)
)
expect_true(all(diff(cp_theta) > 0),
            info = "monotone in the assumed future effect")

## Worked-example regression values (current-trend assumption).
expect_equal(
  halperin_conditional_power(371, 48.8, 2 / 48.8, 5 / 48.8),
  0.9570119, tolerance = 1e-6,
  info = "look 1 asymptotic conditional power"
)
expect_equal(
  halperin_conditional_power(350, 304.4, 15 / 304.4, 25 / 304.4),
  0.6188620, tolerance = 1e-6,
  info = "look 2 asymptotic conditional power"
)

## The worked-example wrapper exposes the comparator.
look2 <- thomas1991_example(look = 2)
expect_equal(look2$m_effective, 304.4, tolerance = 1e-12,
             info = "effective interim sample size at look 2")
expect_equal(look2$cp_halperin, 0.6188620, tolerance = 1e-6,
             info = "wrapper reproduces the comparator value")
expect_true(
  look2$cp_halperin > look2$cp_homogeneous &&
    look2$cp_homogeneous > look2$cp_stratified,
  info = "asymptotic value overstates both exact values at look 2"
)

## At large n with a clean mapping (m subjects fully observed,
## n - m unenrolled) the asymptotic and exact values agree to
## within a few points; the residual gap is Fisher conservatism.
n <- 1000
m <- 500
x1 <- 35
y1 <- 50
lam_t <- x1 / m
lam_c <- y1 / m
q_treatment <- c(rep(0, m - x1), rep(lam_t, n - m))
q_control <- c(rep(0, m - y1), rep(lam_c, n - m))
exact <- exact_conditional_power_pb(n, x1, y1, q_treatment,
                                    q_control)
asym <- halperin_conditional_power(n, m, lam_t, lam_c)
expect_true(abs(asym - exact) < 0.03,
            info = "large-n disagreement bounded by 0.03")
expect_true(asym > exact,
            info = "asymptotic value is optimistic at large n")
