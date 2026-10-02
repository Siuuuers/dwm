# Broad1 ordinary suite and public evidence audit

**Bounded evidence passes: 12 available suites, 2,331 ordinary executions, 192 script executions, 2,327 unique script/test pairs and 191 unique scripts.** Every actual named multiset matches the recursively corrected source census; failures, errors, skips and disabled cases are zero. This is **not whole-run acceptance**.

Run `37044894986`, attempt 1; actual checkout `1bc4f6afd759e969f82b9c2134eb178479c19d13`; runtime source `856520f09440d9b47cc272de3363009924ffedca`. All 12 successful jobs independently report the actual checkout immediately after `git log -1 --format=%H`. Each XML agrees with its exact `CLOUD_GUT_RESULT`, isolated exit-zero runner receipt and retained engine/import logs. Original ZIP digest, size, CRC and every retained extracted file match.

| Suite | Executed cases | Script executions |
|---|---:|---:|
| public_surfaces | 11 | 1 |
| minesweeper | 210 | 22 |
| shop | 144 | 8 |
| desktop | 334 | 22 |
| settings | 357 | 31 |
| checkpoint_diagnostics | 22 | 4 |
| new_account | 179 | 15 |
| reading_delivery | 480 | 35 |
| localization | 153 | 18 |
| dating | 167 | 12 |
| persistence | 230 | 22 |
| audio | 44 | 2 |
| Endings | Not executed (106 predicted) | Not executed (12 predicted) |

## Explicit census correction

The initial helper counted only methods declared in each fixture: full prediction 2,421 executions / 2,417 unique cases, Shop 128. Both `tests/scene/test_shop_card.gd` and `tests/scene/test_shop_plate.gd` extend `tests/unit/test_shop_catalog_projection.gd`, which extends `addons/gut/test.gd`. Each scene fixture inherits the same eight base tests, giving **Shop 144**, a corrected full prediction of **2,437 executions / 2,433 unique cases**, and 2,331 currently observed executions. No other suite prediction changes, including Endings 106.

`resolved-census.json` retains every suite/script/test, declaring source line, source hash and complete ancestry. The helper now resolves recursive inheritance with child overrides and refuses unknown bases. Initial helper/checklist/identity copies and the original manifest remain preserved. No product/test source was changed to fit a count.

## Public evidence

The actual job ran `Invoke-PublicSurfaceValidation.ps1 -EmitPayloads` once, without regeneration. Both emitted inventories equal their committed source bytes: GameState 568,948 bytes, SHA256 `804ca7f1bbe1b929b8c6ce59de390ab15c00f521ddc6290df1fed0a175157631`; SaveManager 151,143 bytes, SHA256 `ccb1a6e576801c4f62cd4c159e89a9e4d9c814cbcf364140c61fc2338365c4d0`. Both check-only receipts exit zero and each engine log contains one inventory PASS; one console receipt confirms canonical reproduction.

An independent scan of the actual checkout reproduces **all 908 records across 963 files**, including exact path, source line, text, family ordering and console records. Family memberships: 887 schema/version, eight historical Day3 seeds, seven BackupSnapshotFixture references, four older prepared fixtures and two empty-contacts literals. The older prepared references comprise an explicit current-schema fixture builder and three refusal/skip tests. Empty contacts appear in bounded attestation/composer inputs. These are observational references, not proof of production migration. A separate scan reproduces **954 files / ten retired symbols / zero references**.

## Exact intentional controls and standalone work

`negative-controls-subaudit.json` binds the independently reviewed control bytes, source and four Actions logs. The audit reopens both negative XMLs and their complete repository snapshots; it independently scans the ordinary new-account process log.

- Exactly two Settings refusal XMLs each contain **83 cases: 80 `test_root_missing` failures and three storage-free passes**, zero errors/skips; both children exit 1. All four complete repository snapshots are identical. These **166 intentional executions are excluded** from ordinary totals.
- Exactly one new-account `ff` invalid-UTF8 diagnostic belongs to `test_prepare_counts_nonempty_unreadable_autosave_but_not_zero_bytes`; one `CORRUPT_SAVE_DIAGNOSTIC_VERIFIED` receipt corroborates it. No other Unicode/NUL, script, parse or lifetime diagnostic is exempt.
- Public isolation records one `fixture-timeout`, exit 124, **20.025938 seconds**, with two retained nonempty logs. The source-bound `ISOLATION_HELPER: PASS` follows checks of four intentional forbidden argument/path exit-124 children and cleanup. Individual forbidden-child receipts are internal, so that part is source-bound PASS corroboration, not separately retained child receipts.
- Manual witness storage: one PASS, **61,180 assertions / 94 snapshots**, exit zero. Save/load capture: one PASS, **136 checks / zero failures**, exit zero. Latency: exactly fresh/replacement samples, `ok=true`, positive button-to-desktop times and nonnegative frame gaps. These assertions are excluded from GUT totals.

## Remaining limits

Endings job `110965240440` failed during **Install Godot 4.6.3 standard**, before test execution; no XML or GUT receipt exists. Its 106 cases remain predicted. Parent reports broad1 is superseded because warm/region benchmark guards need repair after the cold-lease change; corrected-source broad2 must supply its own complete evidence. This audit preserves component results and does not combine them into whole-run acceptance.

No engine, PowerShell, connector or remote calls were used. The full JSON binds source identities, original archive identities, every retained member, receipts, XML and log hashes. Rendered semantics, visual review, other performance/export components, production Hospital content and native accessibility remain outside this report.
