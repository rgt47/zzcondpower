# zzcondpower 0.2.0: Package Review and Gap Analysis
*2026-08-15 16:40 PDT*

Referee-grade review of the R package at
`~/prj/sfw/16-zzcondpower/zzcondpower`, covering CRAN readiness, the
help system, the user interface, and coding practices. Every claim is
tagged with its epistemic status: verified (ran it, observed output),
inspected (read the source), inferred, or unverified. No earlier
dated review exists in `docs/`; this is the first.

## 1. Verdict

Not ready for CRAN submission, but close. `R CMD check --as-cran
--no-manual` on the local machine: **0 errors, 0 warnings, 1 NOTE**
(the unavoidable 'New submission' NOTE) (verified). The computational
core is sound: the test suite is behavioral, pins published values,
and cross-validates against `fisher.test()` and Monte Carlo; coverage
is 97.5 percent (verified). What blocks submission is not the code
but the front door and the metadata: there is no `README.md`, no
`NEWS.md`, no vignette, no package-level help topic, no
`URL`/`BugReports`, a `LICENSE` file that contradicts the declared
GPL-3 license, and `\donttest{}` examples that take 60 to 70 seconds
each (all verified). There are also several silent-NaN paths and one
silently ignored argument that should be fixed before anyone depends
on the interface.

## 2. `R CMD check` and tooling results

### 2.1 rcmdcheck

Run as `rcmdcheck::rcmdcheck(pkg, args = c('--as-cran',
'--no-manual'), error_on = 'never')` under R 4.6.1 on
aarch64-apple-darwin25.4.0, with `R_PROFILE_USER=/dev/null` to bypass
the zzcollab `.Rprofile` (verified; duration 4 m 07 s).

- Status: 0 errors, 0 warnings, 1 NOTE.
- The single NOTE is 'CRAN incoming feasibility ... New submission'.
  It is informational and expected for a first submission.
- Tests ran under check (`Running 'tinytest.R' [5s/16s] ... OK`), so
  the pass is not a `load_all()` artifact (verified).
- Examples, including `--run-donttest`, passed but took 45 s CPU /
  134 s elapsed (verified). See Section 2.3.
- The only Suggests is `tinytest`, which is installed, so nothing was
  silently skipped for missing Suggests (verified).

### 2.2 DESCRIPTION and tarball hygiene

- Version 0.2.0: acceptable for a release; not a `.9000` dev version
  (inspected).
- **License conflict.** `DESCRIPTION` declares `GPL-3`, but the root
  `LICENSE` file is the two-line `YEAR:`/`COPYRIGHT HOLDER:` MIT
  template stub (inspected). The file is `.Rbuildignore`d, so the
  tarball is internally consistent (verified by listing the built
  tarball), but the repository as published contradicts itself.
  Either delete `LICENSE` or replace it with the actual GPL-3 text.
- **No `URL` or `BugReports` fields** (inspected). CRAN does not
  require them, but their absence leaves users nowhere to report
  problems and costs the package its link on the CRAN page.
- **Stale `CITATION.cff`.** It records version 0.1.0 (package is
  0.2.0), `affiliation: Your Institution`, an empty ORCID, and the
  zzcollab compendium boilerplate abstract (inspected). It is
  `.Rbuildignore`d, so CRAN never sees it, but GitHub will render it.
  If citation metadata is wanted for the package itself, it belongs
  in `inst/CITATION`; there is none.
- Tarball contents verified by `R CMD build` + `tar tzf`: only
  `DESCRIPTION`, `NAMESPACE`, `R/`, `inst/tinytest/`, `man/`,
  `tests/`. The `.Rbuildignore` correctly excludes `analysis/`,
  `docs/`, `Makefile`, `.github/`, `.devcontainer/`, and the zzcollab
  scaffolding (verified). `R CMD build` removed the empty
  `vignettes/` directory itself.
- **No `NEWS.md`** (verified by listing the root). Version 0.2.0
  added the entire monitored-procedure module (per `git log`); a
  release without a changelog gives users no way to see that.
- No non-ASCII characters in `R/`, `DESCRIPTION`, or the tests; all
  source files end with a trailing newline (verified by grep and a
  byte-level scan).
- No `.onLoad`/`.onAttach`, no startup messages (inspected; there are
  none to inspect).
- No `Language: en-US` field in DESCRIPTION; `spelling` defaulted to
  en-US and the prose is US English throughout (verified).

### 2.3 Example runtime (a CRAN problem despite the clean check)

The two heavy examples are wrapped in `\donttest{}` and therefore
produced no timing NOTE locally, but CRAN's incoming checks run
donttest code, and the human reviewers see the timings.

- `exact_sample_size(0.05, 0.10)`: 66.6 s elapsed (verified by
  timing the call directly).
- `conditional_power_comparison(0.20, info_fractions = 0.5)`: 58.9 s
  elapsed (verified).

`\donttest{}` is the right marker semantically (the code runs; it is
merely slow), but 60 to 70 seconds is far beyond what CRAN tolerates
even in donttest. Two fixes, both worth doing: give the examples a
small `n_max` (e.g. `n_max = 400`, as the test suite already does,
which brings the comparison call to a few seconds), and reduce the
cost of the search itself (Section 6, performance).

### 2.4 Automated tooling

- `covr::package_coverage()`: **97.47 percent** (verified). Per file:
  `monitored_oc.R` 92.75, `comparison_study.R` 97.87, all others
  100. The uncovered lines are the `is.null(region)`/`is.null(cp_grid)`
  default branches in `conditional_power_grid()`,
  `monitored_operating_characteristics()`, `monitored_size()`, and
  the `n_max` failure `stop()` in `exact_sample_size()` (verified via
  `zero_coverage()`). The default branches matter: every test
  supplies `region` and `cp_grid` explicitly, so the code path a
  naive user actually takes (all defaults) is exercised only
  indirectly.
- `lintr::lint_package()`: 13 style lints, no correctness lints
  (verified). Substantive ones: eight `semicolon_linter` hits in
  `R/worked_example.R:40-48` (compound `t <- 2; n <- 371; ...`
  assignments), `object_length_linter` on
  `monitored_operating_characteristics` (35 characters), and three
  style lints in test files.
- `spelling::spell_check_package()`: 23 flagged words, all proper
  names (Halperin, Haseman, Lachin, Jennison, Kunz, Kieser, DeMets)
  or defensible technical terms (unenrolled, recomputation,
  comparator, enrollees) (verified). Add a `inst/WORDLIST` and the
  `Language` field so the check is clean and repeatable.
- `urlchecker::url_check()`: all URLs correct (verified; the package
  contains almost none).
- `codetools::checkUsagePackage(all = TRUE)`: only benign 'parameter
  changed by assignment' notes from the `is.null(...)` default
  idiom; no missing globals, no unused locals (verified). No
  'no visible binding' issues; the package uses no non-standard
  evaluation.
- `goodpractice::gp()`: **not run**; the package is not installed in
  the system library and its dependency tree was not worth
  installing for this review. Its main components (check, covr,
  lintr, cyclomatic complexity) were run individually.

## 3. Functional bugs

These are defects a user can hit on documented paths. None is caught
by `R CMD check`.

1. **`alpha` is silently ignored when `region` is supplied**
   (`R/conditional_power.R:91-99`, and by propagation every function
   with a `region` argument). Verified:
   `exact_conditional_power(50, 2, 5, 0.05, 0.10, alpha = 0.05,
   region = fisher_rejection_region(50, alpha = 0.01))` returns
   0.0508, the alpha = 0.01 answer, with no warning; the same call
   without `region` returns 0.2725. The function checks
   `nrow(region) == n + 1L` but never compares `attr(region,
   'alpha')` to its own `alpha` argument, even though
   `fisher_rejection_region()` stores exactly that attribute for the
   purpose. The fix is two lines: if `region` is supplied and
   carries an `alpha` attribute differing from the argument, stop.
   The same check should compare `attr(region, 'n')` to `n`, which
   would also produce a better error message than the current
   `nrow(region) == n + 1L is not TRUE`.

2. **Out-of-range probabilities produce NaN with only a low-level
   warning.** `exact_fisher_power(20, 1.5, 0.1)` and
   `exact_fisher_power(20, -0.1, 0.1)` both return `NaN` with the
   bare `dbinom` warning 'NaNs produced' (verified).
   `exact_fisher_power()` validates nothing about `p_treatment` or
   `p_control` (`R/fisher_region.R:57-63`). The same gap exists in
   `conditional_power_comparison(control_rate = ...)`. Validate at
   the entry point.

3. **Silent NaN from degenerate interim data.**

   - `halperin_conditional_power(100, 50, 0, 0)` returns `NaN` with
     no warning (verified): `sigma2 = 0` gives `0/0`. The vectorized
     grid variant guards this with
     `pmax(..., .Machine$double.eps)` (`R/monitored_oc.R:62`), but
     the exported scalar function does not
     (`R/halperin.R:56-64`). The two disagree about the same input.
   - `estimate_partitioned_rates(0, 0, 0, t = 2, entry_period = 3,
     follow_up = 5)` returns `lambda_hat = NaN` silently (verified):
     the denominator is zero when no subject has any exposure.
     Require `n_completed + n_on_study > 0`.
   - `conditional_event_prob()` returns `NaN` when `surv_fn`
     evaluates to 0 at the accrued time (verified with a step
     survival function). The `@param surv_fn` docs require
     `S(0) = 1` but nothing enforces positivity at `c_i`; an error
     message naming the problem would be better than NaN.

4. **`exact_sample_size()` documents a minimality guarantee that
   bisection cannot deliver.** The docs say it 'finds ... the
   smallest per-arm sample size whose exact power reaches `power`'
   (`R/comparison_study.R:3-5,14`). The exact Fisher power function
   is not monotone in `n` (verified: for `p = (0.05, 0.50)` the
   power sequence over `n = 2:120` is non-monotone), and bisection
   on a non-monotone function can skip a smaller passing `n`. In the
   scenario scanned, the returned `n = 14` happened to be minimal
   (verified), and the sawtooth of Fisher exact power is small
   enough that a miss will be rare and off by little (inferred).
   Still, either document the caveat or finish with a short backward
   linear scan from the bisection answer, which costs a handful of
   power evaluations.
   A second, smaller edge: bisection starts at `lo = 2L` without
   testing it, so when `n = 2` itself meets the target the function
   returns 3 (inspected, not run; the invariant `power(lo) < target`
   is assumed, never established).

5. **`thomas1991_example()` hard-codes an unstated assumption in the
   stratified route.** `q_arm()` drops the *first* `n_events`
   entries of the duration-ordered `q` vector
   (`R/worked_example.R:66-70`), i.e. it assigns the observed events
   to the earliest-enrolled subjects, who have the longest follow-up
   and the smallest conditional `q`. Neither the help page nor the
   function output states this convention, yet `cp_stratified`
   depends on it (inspected; the sensitivity was not quantified).
   The `@details` section should state the assignment convention.

## 4. Help system

Counts (verified against `NAMESPACE` and `man/`):

- 17 exports, 17 `.Rd` files, zero undocumented exports.
- 10 of 17 exports have `@examples`. The seven without:
  `exact_conditional_power_pb`, `follow_up_durations`,
  `exponential_survival`, `rate_from_risk`,
  `conditional_power_grid`, `monitored_operating_characteristics`,
  `monitored_size`. The last three are the headline v0.2.0 feature
  (the futility-rule operating characteristics) and have no example
  anywhere; `exact_conditional_power_pb` is the paper's equation (9)
  and likewise has none.
- `@return` completeness is good: 15 of 17 describe the concrete
  value including list components, matrix indexing convention, and
  attributes (inspected across all 17). No class-only returns; the
  package defines no classes. The two thin ones are
  `follow_up_durations` and `exponential_survival`, whose returns
  are adequately described by their formulas.
- Doc-versus-code spot check (inspected implementation against
  documented behavior for `fisher_rejection_region`,
  `exact_conditional_power_pb`, `estimate_partitioned_rates`,
  `conditional_event_prob`, `monitored_operating_characteristics`):
  no mismatches. The documented `conditional_event_prob` boundary
  behavior (0 for completed, `1 - S(F)` for unenrolled) was verified
  by execution.
- All runnable examples were executed and produce the documented
  behavior (verified). Both `\donttest{}` examples were also
  executed successfully, with the runtimes reported in Section 2.3.
  `\dontrun{}` is used nowhere, which is correct.

Gaps, in decreasing order of cost to the user:

- **No `README.md`** (verified absent). There is no rendered entry
  point at all: a visitor to the repository, or a CRAN user landing
  on the package page, gets nothing but the DESCRIPTION paragraph.
- **No package-level topic.** There is no `_PACKAGE` roxygen block,
  so `?zzcondpower` fails (verified absent from `man/`). With 17
  functions implementing a specific manuscript's equations, the
  package needs one page that maps equations to functions and
  sequences the workflow.
- **No vignette** (verified; the directory is empty and was pruned
  from the tarball). The natural vignette already exists in spirit:
  `thomas1991_example()` walks both interim looks, and
  `conditional_power_comparison()` reproduces the numerical study.
  A single 'Getting started' vignette wrapping those two would cover
  most of the API.
- **Zero `@seealso` or `@family` tags across all 17 topics**
  (verified by grep). Every topic is an island. A user who finds
  `halperin_conditional_power()` has no pointer to
  `exact_conditional_power()`, and nothing links the
  `fisher_rejection_region()` primitive to its consumers. One
  `@family` per module (region/power, estimators, monitoring,
  comparison) would fix this in minutes.
- The docs repeatedly cite 'the manuscript' and 'equation (2)', 'the
  Appendix', etc. (e.g. `R/fisher_region.R:4`,
  `R/conditional_power.R:3`), but no help page cites the manuscript
  itself; only Halperin (1982), Lachin (2005), and Kunz and Kieser
  (2012) get `@references`. A reader of the installed package cannot
  resolve the equation numbers. Add the Thomas (1991) reference (or
  whatever the manuscript is) to every topic that cites equations,
  and to DESCRIPTION as an `Authors@R`-adjacent `Description`
  citation in CRAN's `<doi:...>` style.

## 5. User interface

### 5.1 First-use walkthrough

There is no README or vignette, so the walkthrough must start from
the help index, which is itself the first finding: a new user has no
prescribed entry point and must infer the workflow from 17
alphabetized topics. Working from `help(package = 'zzcondpower')`, I
guessed `thomas1991_example` as the front door because its title
mentions a worked example, then followed its `@return` links
backward. The actual first result (verified):

```r
library(zzcondpower)
thomas1991_example(look = 1)$cp_stratified
#> 0.949, in 0.23 s
```

One line to a result, but the result is the package demonstrating
itself. Reproducing it manually took five calls
(`estimate_partitioned_rates`, `fisher_rejection_region`,
`exact_conditional_power`, `follow_up_durations` +
`conditional_event_prob` + `exponential_survival` + `rate_from_risk`,
`exact_conditional_power_pb`), and at two points I had to read the
source of `thomas1991_example()` rather than the help: (a) how to
turn `p1_hat`/`p2_hat` into `gamma`/`beta` (the formula is in the
`@param` text of `exact_conditional_power`, but nothing in
`estimate_partitioned_rates` points there), and (b) the convention
for dropping event subjects from the `q` vector (Section 3, item 5).
That friction is exactly what the missing vignette and `@seealso`
links would remove.

### 5.2 Findings

Strengths, tersely: argument naming is consistent across the API
(`n`, `m`, `x1`, `y1`, `alpha`, `p_treatment`, `p_control`,
`follow_up` mean the same thing everywhere; verified by tabulating
all 17 formal lists); the `region`/`cp_grid` precompute-and-pass
pattern is a good design for enumeration-heavy code; returns are
type-stable (always a scalar, matrix, list, or data frame as
documented; nothing changes shape with input); the export surface is
minimal (the one internal helper,
`halperin_conditional_power_vec()`, is correctly unexported); no
function uses `...`, so there is nothing to swallow typos (all
inspected).

Weaknesses:

- **Errors as interface: bare `stopifnot()` everywhere.** Every
  validation failure echoes an expression instead of naming the
  problem: `n == as.integer(n) is not TRUE`,
  `length(q_treatment) == n - x1 is not TRUE`,
  `p_treatment < p_control is not TRUE` (all verified by triggering
  them). The last is the worst: `exact_sample_size(0.2, 0.1)` fails
  without saying that the function requires the treatment rate to be
  the smaller one, which is a substantive statistical convention,
  not a typo guard. Named `stopifnot()` conditions or explicit
  `stop()` calls with the received value would fix all of these
  cheaply.
- **The one-sided convention is load-bearing and easy to violate
  silently.** The whole package assumes treatment has *fewer* events
  (rejection for small `x`). `exact_fisher_power(371, 0.10, 0.05)`
  runs happily and returns near-zero power rather than flagging the
  probable argument swap (inferred from the region construction;
  the swap itself was not run). Only `exact_sample_size()` enforces
  the ordering. A documented convention plus a consistent check (or
  at least a documented pointer in `exact_fisher_power` and the
  conditional-power functions) would prevent silent nonsense.
- **Silent surprises**: the ignored `alpha` (Section 3, item 1) and
  the NaN paths (Section 3, items 2 and 3) are interface defects as
  much as bugs.
- **Inconsistent degenerate-input policy between the scalar and grid
  Halperin implementations** (Section 3, item 3): the grid clamps
  `sigma2`, the exported function does not. Whichever policy is
  right, it should be one policy.
- `t` as an argument name (`estimate_partitioned_rates`,
  `follow_up_durations`) shadows `base::t` and is a single
  uninformative letter next to otherwise descriptive names
  (`entry_period`, `follow_up`). `time` or `interim_time` would be
  better. Renaming is cheap now and breaking later (inspected).
- Pipe-friendliness is largely moot (scalar-first design, no data
  frame flows through), but argument order is consistent within the
  call stack: `n, x1, y1, ...` in every conditional-power function,
  `n, m, ...` in every monitoring function (verified).
- Discoverability: no common prefix; the four modules interleave
  alphabetically. With `@family` tags this is tolerable; without
  them it is not. A `cp_`/`fisher_`/`monitor_` prefix scheme is
  worth considering before the API freezes, but is a judgment call.
- No print methods exist and none are needed; returns are small and
  self-describing (inspected).

## 6. Coding practices

Checked and found sound (all inspected unless noted):

- `<-` assignment throughout; no `T`/`F`; no `library()`/`require()`
  in `R/`; no `set.seed()` in package code (the only `set.seed` is
  in a test file, where it belongs); no `options()`/`par()`
  anywhere; no `sapply()`; `vapply()` with type templates in
  `monitored_oc.R`; `drop = FALSE` on the one matrix subset that
  needs it (`R/conditional_power.R:103`); `seq_len()` where
  applicable (verified by grep).
- No S3 classes or methods, so no registration issues.
- RNG discipline: the package makes no RNG claims and uses no RNG;
  the Monte Carlo confirmation lives in the test suite with a fixed
  seed and validates an analytic quantity, so seed reuse is not a
  circularity concern (inspected).
- Tests are genuinely behavioral: region membership is checked
  exhaustively against `stats::fisher.test()` at n = 8; the
  Poisson-binomial reduction, the equation (2)/(9) agreement, and a
  4-standard-error Monte Carlo bound are all real properties, and
  the worked-example values are pinned to 1e-6 (inspected; verified
  to pass under `R CMD check`, not merely `load_all()`). No
  `zzcondpower:::` calls exist because no internal is tested
  directly; the one unexported function
  (`halperin_conditional_power_vec`) is exercised through
  `conditional_power_grid(driver = 'asymptotic')` (inspected).

Findings:

- **Performance: `exact_sample_size()` is quadratically wasteful.**
  Each bisection step calls `exact_fisher_power()`, which rebuilds
  the full `(n+1) x (n+1)` rejection region via `phyper` on the
  whole grid (`R/fisher_region.R:59`); the first step evaluates at
  `n_max = 5000`, a 5001 x 5001 matrix (about 200 MB of doubles in
  `outer`) whose cost dominates the verified 66 s runtime. A
  doubling search upward from a normal-approximation starting value
  would evaluate near the answer only and cut the default-call cost
  by an order of magnitude (inferred from the cost structure; the
  alternative was not implemented and timed).
- `pois_binom_pmf()` grows its vector inside the loop
  (`R/conditional_power.R:63-66`). Here it is the convolution
  recursion itself and the sizes are modest (n + 1 at most), so this
  is acceptable; preallocation would obscure more than it saves. Not
  a defect.
- `stats::dbinom(0:n - x1, k, p_treatment)`
  (`R/monitored_oc.R:126-131`) relies on the `(0:n) - x1` precedence
  and on `dbinom` returning 0 outside the support. It is correct
  (inspected; the enclosing computation is pinned by the tau = 0 and
  tau > 1 degenerate tests, verified), but the expression is the
  classic `0:n - 1` footgun and deserves parentheses.
- Compound semicolon assignments in `R/worked_example.R:40-48`
  (lint finding), and the scenario constants of the worked example
  are embedded in code rather than documented data; acceptable for a
  reproduction function, but a `@details` table of the scenario
  would help readers.
- Input validation gaps enumerated in Section 3 (missing probability
  range checks in `exact_fisher_power()`, no
  denominator-positivity check in `estimate_partitioned_rates()`,
  no `sigma2 > 0` guard in `halperin_conditional_power()`).
- `fisher_rejection_region()` allocates O(n^2) logicals with no
  guard on `n`; at `n = 50000` this is a multi-gigabyte allocation
  from a single innocuous call (inferred; not run). A soft cap or a
  documented memory note would be kind.

## 7. Prioritized checklist

(a) CRAN blockers:

- Replace or delete the MIT-template `LICENSE` stub; it contradicts
  `License: GPL-3` in the repository even though the tarball is
  clean.
- Cut `\donttest{}` example runtimes from about 60 s each to a few
  seconds (pass a small `n_max` in the examples; optionally fix the
  search itself).
- Add `NEWS.md` covering 0.1.0 and 0.2.0.
- Add `URL` and `BugReports` to DESCRIPTION, plus
  `Language: en-US` and an `inst/WORDLIST`.
- Add a `_PACKAGE` roxygen block so `?zzcondpower` works, and a root
  `README.md`.
- Add the manuscript citation (with DOI if available) to the
  Description field and to the equation-citing help topics.
- Submit-side checks not yet done: win-builder, R-hub, R-devel
  (Section 8).

(b) Bugs to fix before anyone depends on the behavior:

- Error when a supplied `region` disagrees with `alpha` (or `n`)
  instead of silently using the region's alpha.
- Validate probability arguments in `exact_fisher_power()` (and by
  extension `conditional_power_comparison()`); no more silent NaN.
- Guard the zero-variance and zero-exposure NaN paths in
  `halperin_conditional_power()` and
  `estimate_partitioned_rates()`, and make the scalar and grid
  Halperin implementations share one degenerate-input policy.
- Either implement the documented minimality of
  `exact_sample_size()` (backward scan after bisection, and test
  `lo`) or weaken the documented claim.
- Document the event-assignment convention inside
  `thomas1991_example()`.

(c) Documentation completion:

- Getting-started vignette built from `thomas1991_example()` and
  `conditional_power_comparison()`.
- `@examples` for the seven exports lacking them, above all the
  monitored-procedure trio and `exact_conditional_power_pb()`.
- `@family` tags (four natural families) so no topic is an island.
- Update or delete the stale `CITATION.cff`; add `inst/CITATION` if
  the package should be citable.

(d) Design decisions best made before first release (breaking
later):

- Rename `t` to `time` (or similar) in
  `estimate_partitioned_rates()` and `follow_up_durations()`.
- Decide whether to enforce, everywhere, the 'treatment arm has
  fewer events' convention that the rejection region hard-codes, or
  to accept and document silent near-zero power on swapped
  arguments.
- Decide on a function-name prefix scheme (or explicitly decline
  one) while renames are still free.
- Replace bare `stopifnot()` with named conditions or `stop()`
  messages across all entry points; error text is part of the API
  surface users script against.

## 8. Not evaluated

- Platforms: only macOS aarch64, R 4.6.1. Not checked: win-builder,
  R-hub, any Linux, R-devel, R-oldrel, 32-bit anything. The 'New
  submission' NOTE means CRAN's incoming checks have never seen this
  package.
- `--as-cran` was run with `--no-manual`; PDF manual construction
  (LaTeX errors, Rd2pdf) is unverified.
- `goodpractice::gp()` not run (not installed; components run
  individually).
- The r-btw MCP documentation server was not used; help content was
  read from the roxygen sources and generated Rd files.
- The manuscript itself was not available to this review; agreement
  of the code with equations (2) through (9) rests on the package's
  own test pins and internal cross-validation, not on independent
  derivation. The pinned worked-example values were not re-derived
  by hand.
- The sensitivity of `cp_stratified` to the event-assignment
  convention in `thomas1991_example()` (Section 3, item 5) was noted
  but not quantified.
- Memory behavior of `fisher_rejection_region()` at large `n` was
  inferred, not measured.
- The claimed swap behavior of `exact_fisher_power(371, 0.10,
  0.05)` (near-zero power, no warning) was inferred from the region
  construction, not executed.
- Vignette rendering: nothing to render; the vignettes directory is
  empty.
- No prior review exists in `docs/`, so there is no revision history
  to carry forward.
