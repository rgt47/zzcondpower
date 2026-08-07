# Pin the worked example of Section 4: estimator values from
# equations (4) to (6) and conditional power by both routes.

library(tinytest)

## First interim look: t = 2, 244 enrolled per arm, events 2 and 5.
look1 <- thomas1991_example(look = 1)
expect_equal(look1$estimates$t_bar, 1,
             info = "look 1 mean enrollment time")
expect_equal(look1$estimates$lambda_hat, c(2, 5) / 48.8,
             tolerance = 1e-12,
             info = "look 1 marginal rate estimates (equation 4)")
expect_equal(look1$estimates$p1_hat, c(2, 5) / 48.8 / 5,
             tolerance = 1e-12,
             info = "look 1 pre-interim components (equation 5)")
expect_equal(look1$cp_homogeneous, 0.9385744, tolerance = 1e-6,
             info = "look 1 conditional power, equation (2)")
expect_equal(look1$cp_stratified, 0.9492984, tolerance = 1e-6,
             info = "look 1 conditional power, equation (9)")

## Second interim look: t = 6, 350 per arm, events 15 and 25.
look2 <- thomas1991_example(look = 2)
expect_equal(look2$estimates$t_bar, 2,
             info = "look 2 mean enrollment time")
expect_equal(look2$estimates$lambda_hat,
             c(15, 25) / (122 + 228 * 4 / 5),
             tolerance = 1e-12,
             info = "look 2 marginal rate estimates (equation 4)")
expect_equal(look2$cp_homogeneous, 0.5417020, tolerance = 1e-6,
             info = "look 2 conditional power, equation (2)")
expect_equal(look2$cp_stratified, 0.4954246, tolerance = 1e-6,
             info = "look 2 conditional power, equation (9)")

## The estimators satisfy their defining moment identity:
## lambda_hat * (n1 + n2 * (t - t_bar) / F) recovers the counts.
est <- look2$estimates
expect_equal(est$lambda_hat * (122 + 228 * (6 - est$t_bar) / 5),
             c(15, 25), tolerance = 1e-12,
             info = "moment equation reproduces observed counts")
