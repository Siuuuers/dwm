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

`tools/lint/check_comments.py` rejects new or edited explanatory comments in first-party `.gd` and `.py` files under `scripts`, `autoload`, `tests`, and `tools`. It reads complete source to distinguish comments from strings, including multiline strings. Python uses its standard tokenizer. Existing unchanged comment lines are grandfathered, including Git-detected renames; deleting surrounding string delimiters cannot turn a previously literal line into an exempt legacy comment.

The rule excludes `addons`, out-of-scope roots, and directories named `generated`, `vendor`, or `third_party`. It preserves SPDX/copyright notices and recognized machine directive prefixes. Preserve any other required legal text when doing a future cleanup; extend narrowly identified exceptions rather than deleting obligations.

This is an incremental enforcement stage, not a completed repository-wide comment ban. Other languages and embedded code are not checked. Existing comments are removed in a separate coordinated cleanup after shared story files settle. The rule does not remove comments automatically.

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
