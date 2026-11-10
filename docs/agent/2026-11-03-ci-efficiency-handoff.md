# CI efficiency and source lint handoff

## Outcome

Each change runs the smallest set of checks that covers its affected behavior, with an explicit reason for each selected suite. Measure total completion time and compute time separately. Preserve required behavior coverage; a reduction in job count alone is not success.

This mission can be investigated alongside story progression PR #176. Coordinate edits to shared workflows before integration. Base inspected: `87a4153836a2d8d47ce36c423d891fc13c3a769d`.

## Existing work to preserve

`.github/workflows/windows-tests.yml` already uses sparse checkout for coverage selection, a Python selector, and focused lanes including self-talk. `tools/testing/test_windows_coverage.py` already checks those decisions. Do not replace these with a second selector or repeat completed optimization work.

## Investigation and implementation

1. Recheck master, open work, and repository instructions. Inspect recent representative workflow runs before making performance claims.
2. Record checkout/download, setup/import, execution, queue, and total elapsed time separately. Compare documentation, artwork, UI, and shared runtime changes. Note cache conditions and runner differences.
3. Trace selected suites to the behavior changed. Identify unnecessary selection and missing coverage using current test bodies and owners.
4. Group short related suites only when shared setup saves measurable work; retain isolated saves and test data. Remove job dependencies only when no artifact or result requires them.
5. Extend the existing selector with focused tests. Keep unknown shared runtime edits on suitable broader coverage. Account for deletions, renames, and mixed changes.
6. Validate the selector locally and exercise the changed workflow on a representative PR. Report measured before/after values, skipped checks, and remaining limits. Do not claim gameplay speed improvement from CI changes.

No game state-machine rewrite, save migration, test-framework replacement, or repository-wide comment removal belongs in this PR. Further CI edits require evidence from this investigation, not speculative tuning.

## Lint now implemented

`tools/lint/check_comments.py` rejects new or edited explanatory comments only in first-party runtime `.gd` files under `scripts` and `autoload`. The owner narrowed the policy on 11 November: comments in all tests, tools and Python are allowed and retained. Python syntax checking keeps its existing broader first-party scope. The comment scanner reads complete source to distinguish comments from strings, including multiline strings. Existing unchanged comment lines are grandfathered, including Git-detected renames; deleting surrounding string delimiters cannot turn a previously literal line into an exempt legacy comment.

The rule excludes `addons`, out-of-scope roots, and directories named `generated`, `vendor`, or `third_party`. It preserves SPDX/copyright notices and recognized machine directive prefixes. Preserve any other required legal text when doing a future cleanup; extend narrowly identified exceptions rather than deleting obligations.

The 11 November cleanup removes existing explanatory comments from runtime GDScript only. Other languages and embedded code are not checked by this lint. The rule does not remove comments automatically.

The focused workflow uses Python and Git, a sparse partial checkout, and no Godot or asset import. It runs rule tests, changed Python syntax checks, comment lint, and `git diff --check` on relevant PRs. Changed workflow files also run pinned actionlint 1.7.12; its optional ShellCheck/Pyflakes integrations are disabled to keep this check focused on workflow structure and expressions. The binary is downloaded and hash-checked only when workflow files changed. The PR merge result is compared with its first parent, so changes already in the target branch are not treated as new PR comments. Whitespace checks are limited to GDScript, Python, workflow YAML, and agent Markdown. It is independent of gameplay test jobs and does not replace them. The Windows workflow ignores changes limited to the six exact lint implementation/workflow/handoff files; mixed runtime changes and edits to the Windows workflow still run its coverage selector. Manual dispatch remains available. Repository branch protection is not changed by adding the workflow.

Local commands:

```sh
python3 -m unittest discover -s tools/lint -p 'test_*.py'
python3 tools/lint/check_comments.py --base BASE_SHA --head HEAD_SHA
python3 tools/lint/check_python.py --base BASE_SHA --head HEAD_SHA
git diff --check BASE_SHA HEAD_SHA
```

Do not add arbitrary function-length, file-length, or complexity thresholds. Keep rules mechanically decidable. Single ownership, suitable tests, readable names, and justified abstractions remain review criteria; syntactic checks cannot prove them.

## PR 177 completion scope

The source-lint checkout reuses the existing disposable-index workaround for two incomplete skill gitlinks so checkout credential cleanup succeeds. This does not delete tracked repository files. The rename regression uses a temporary real Git repository and verifies both an unchanged rename and a newly added comment after a rename.

PR 176 progression implementation is owned by another conversation. Do not edit its runtime owners here. The no-explanatory-comment policy remains; required legal notices and machine directives retain their existing exceptions. Repository-wide legacy comment removal remains separate.

## Next session prompt

Implement the CI-efficiency mission in this document using measured workflow evidence. Preserve existing focused selection and the source lint rule. Coordinate shared workflow edits with story progression PR #176. Keep changes scoped, run selector tests and a representative workflow, report exact improvements and limitations, and open or update a focused PR. Direct merge is authorized after relevant checks and review. Ask only for a concrete blocking product decision.


## Measured setup reduction after PR 179

The progression runner batches the three `stops_` methods: unread-line stop,
Skip boundary stop, and Auto boundary stop. Matched separate/combined then
combined/separate runs measured 23.016/7.642 seconds and 22.375/7.700 seconds.
Mean wall time fell from 22.696 to 7.671 seconds (66.2%), preserving exactly
three methods and 72 assertions. Each invocation used isolated storage; normal
per-test fixture resets remain. This is CI runtime evidence, not gameplay speed.

Together with the earlier write-refusal pair, 17 methods now use 14 Godot test
processes. All six rendered journeys remain separate, including fresh-process
load checks. Project import was already shared once per job and remains so.

Before import, source-based checks require every configured filter to match its
exact declared method set. XML still checks executed identities and each method's
passing assertions afterward. The lightweight source check follows the current
suite convention of top-level `func test_...` declarations; it is not a GDScript
parser or a replacement for runtime results.

Python syntax checking compiles changed committed first-party `.py` source without
executing it or producing bytecode. Added, modified and renamed destinations are
checked; deleted files and third-party/generated code are excluded. It runs under
the CI runner's Python version. This checks syntax, not dependencies or behavior.

No arbitrary style thresholds, full-repository formatting, new shared fixtures,
or tool caches were added. Caching and checkout changes remain measurement-led
follow-ups. Runner-only changes now select the focused progression job; lint-only
changes do not require gameplay tests.


## Progression package setup measurement

Four fresh hosted Ubuntu 24.04 jobs compared the current forced archive mirror
with the runner's configured mirror. All used image `20261025.353.1`, installed
exactly the same 66 package names/versions, and enumerated 13,151 native speech
voices on the first attempt. The experiment uses 15-second acquisition timeouts
and no acquisition retries equally for both variants; production keeps its
existing APT timeout/retry settings.

| Mirror | Update seconds | Update + install seconds |
| --- | ---: | ---: |
| Runner, repeat 1 | 5 | 17 |
| Runner, repeat 2 | 4 | 18 |
| Forced archive, repeat 1 | 7 | 19 |
| Forced archive, repeat 2 | 9 | 35 |

These are integer-second observations on four separate hosts. Download timing
varied, so they do not establish a guaranteed speedup. Retaining the runner's
mirror was faster in both repeats and removes an override. Only the progression
job changes; the package list, update/install commands and native speech check
remain intact. Other jobs' mirror choices are outside this slice.

The large codec dependency chain comes from PulseAudio's required ALSA plugins.
Removing redundant explicit package names produced an identical dependency set,
so no packages were removed and no cache was introduced.

Experiment: https://github.com/Siuuuers/dwm/actions/runs/41642580060 . Its isolated
`codex/package-setup-measurement` branch is measurement evidence, not a workflow
added to master. Workflow-only progression edits now qualify for focused coverage
only when every part outside that job is unchanged; other workflow edits retain
the existing coverage decision.


## Runtime comment cleanup — 11 November 2026

The owner requested removal only from game code, with all test/tool comments
retained and renames allowed only where meaning is unclear. From master
`1f7a3f1196f3450cef9a514300012e32c00c7d36`, 7,457 explanatory comment lines were
removed from 286 GDScript files under `scripts/` and `autoload/`. All 302 runtime
GDScript files now contain no explanatory comments. The runtime shader already
had none. Add-ons, tests, tools, Python, resources and story content were not
included in the removal. No runtime legal notices or machine directives were
found; their lint exemptions remain. No justified rename was identified in the
reviewed owners, so this change preserves all names and signatures.

The removal used the existing string-aware comment scanner. A separate Python
standard-library tokenizer comparison verified exact equality of every remaining
token, including string literals and indentation, in all 286 changed runtime
files. Godot 4.6.3 import exited 0 with no script/parse/load errors. Its existing
GUT online version lookup failed; that network notice is not a script failure.

Source-sensitive dependencies were handled explicitly:

- Refreshed only four generator source hashes (`rng`, `reducer`, `kernel`,
  `verifier`). Every budget, corpus, device-evidence and fallback value is
  unchanged; this does not certify a new hardware calibration.
- Removed a test assertion requiring a runtime deprecation comment, retaining
  all timeline API checks. The existing historical comment-stripper proof now
  reads its already-pinned historical source. Test comments remain.
- Narrowed comment lint to runtime GDScript. Tests/tools/Python can contain
  explanations; changed-Python syntax validation retains its broader scope.
- Preserved engine accessibility ordering, hidden-volume drag cancellation and
  native JSON control-character rationale in existing design records. Save
  cache rationale also remains in the untouched explanatory tests.

Focused validation: 23 Python lint tests pass. Four selected Godot methods pass
53 per-test assertions with exact JUnit names, positive counts and exit 0:
real budget freshness (1), real Beginner board certification (8), timeline API
compatibility (8), and the historical source/comment-stripper check (36).
Independent review also confirmed unchanged runtime tokens and the four-key
manifest delta. Comment lint, changed-Python syntax and whitespace checks pass.
The checked code is local commit `8526b17cbcd433b86350f30d76821caa5aa5f51c`;
subsequent changes update documentation and generated caller-path inventories.

Both public-surface checks initially found preexisting stale caller paths. An
isolated reconstruction of 1,206 baseline source/scene/scanner files generated
inventories byte-identical to the candidate, proving comment removal did not
change their output. The refreshed GameState and SaveManager inventories contain
only caller-path updates; declarations, signatures and required contracts remain
unchanged. Both final `--check` validations pass.

No broad gameplay matrix, new injection campaign, Windows export/render/audio
qualification or performance benchmark was run. Publication skips broad fallback
CI for this mechanically verified change; local checks are not an Actions pass.
