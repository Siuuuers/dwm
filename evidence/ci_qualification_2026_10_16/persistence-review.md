# Persistence and new-account CI triage

Read-only source/log audit, 2026-10-15. Baseline: `3ae6d9138fb53c388380c78550cf6082eafc0ea3`. Reviewed checkout: `84a0c966` plus the two schema-test edits described below. No Godot or PowerShell was executed locally. Baseline classifications below are source comparisons, not a baseline cloud execution.

## Observed cloud failures

Product CI run `38725742391`:

| Job | Result | Failed tests |
| --- | --- | --- |
| persistence `116392942052` | 239 tests, 237 passed; 5111/5113 assertions | Future-version migration fixture; historical alias provenance |
| new_account `116392942070` | 182 tests, 177 passed; 4596/4608 assertions | Two future-version precedence fixtures; direct issuer census; resolution-kind census; hospital observed vector |

The four implicated test files were unchanged from baseline before the schema-fixture correction. `scripts/infrastructure/save/SaveDocumentSchema.gd`, `SaveMigrations.gd`, `scripts/domain/narrative/SceneEventContract.gd`, `scripts/application/run/CausalDayAdvanceIdentityPort.gd`, and `data/manifests/effects.json` are also unchanged from baseline.

## Independently reviewed schema-fixture correction

The local diff changes exactly four future-version assignments and one explanatory comment:

- `tests/unit/test_save_migrations.gd:149`: `DOCUMENT.DOCUMENT_VERSION + 1` becomes `DOCUMENT.SCENE_DOCUMENT_VERSION + 1`.
- `tests/unit/test_save_document_schema.gd:146,392,843`: hardcoded `9` becomes `schema.SCENE_DOCUMENT_VERSION + 1`.

These are justified corrections: supported document versions are 8 and 9. A purported future Save9 containing a Run8 is a version mismatch, not a future format. The malformed-document test at line146 previously passed for that wrong reason; fixing it alongside the two visibly failing precedence tests restores its stated purpose.

Review verdict: the narrow diff preserves all failure codes and assertion strength. The schema precedence tests still establish malformed key set before saved-time metadata, metadata before version, version before discriminator, discriminator before current bundle, and current bundle before recovery-journal details. `_assert_refused_unchanged` still checks no returned repaired document/Profile patch and exact preservation of both input record and locator. Historical v6/v7 fixture bytes remain untouched. The explicit Save8/Run9 mismatch probe remains unchanged, as required: that is a valid mismatch test, not a future-format probe. No runtime admission or persisted-data behavior changes.

This is source review only; the corrected tests still require cloud acceptance.

## Issuer census remediation boundary

`tests/unit/tooling/test_phase2r_schedule_gate.gd:632–666` lists six direct issuer calls, but baseline and current source contain nine. Keep exact path/call attribution and registered-kind checks; do not merely replace the expected count.

Add these three established scene call sites in source census order:

1. `autoload/GameState.gd:4547`: `_identity_issuer.derive_child(request.value)` in `_accept_scene_runtime_event`, whose request comes from `SceneEventContract.scene_completion_request`. The contract fixes child kind `scene_day_completion` and role `scene_day_complete`.
2. `scripts/domain/narrative/SceneEventContract.gd:735`: scene-admission call with child kind `continuation_operation` and role `scene.admission`.
3. The same file at line788: initial-admission call with child kind `continuation_operation` and role `scene.initial_admission`.

The two contract calls place `child_kind` on a subsequent line. Authenticate their bounded owning method/call body rather than claiming that their first line proves the kind. Preserve the existing sole-minting-definition and delegating-context checks. Existing scene identity contracts provide behavioral coverage.

At the same test file line851, the exact expected resolution-kind array omits the established third kind `scene_day_complete`. Add it while preserving the exact array assertion. Neither adjustment should alter historical generated vectors or evidence artifacts.

## Hospital observed vector

`test_observed_vectors_for_the_day3_hospital_walk_with_two_superseded_dates` fails at line975 because a stage before `hospital_if_triggered` refuses `health:+1` with `unknown_effect_id`. This is a legacy fixture/content incompatibility, not an issuer-count problem. Do not restore global legacy health effects merely to green the test. Reconcile the fixture with the current condition/effect architecture while retaining its real-owner hospital walk and causal receipt assertions. This audit does not prescribe a runtime behavior change.

## Historical alias provenance: keep separate

`tests/integration/test_run_restore_isolation.gd` deliberately reconstructs an exact historical whole owner through authenticated reversal layers. Its first failure occurs in `_without_authenticated_note_counts()`.

Exact literal occurrence counts in both baseline and current GameState source are `1,1,0,1,0,1,0`. Missing fragments are **3 (557 bytes), 5 (575 bytes), and 7 (724 bytes)**. A prior handoff stating fragments3/4/6 were missing was inaccurate. The first missing fragment is sufficient to explain the observed failure, but does not qualify later whole-owner hashes as unaffected.

Preserve the historical source identity `226d3da868784baacc6fc33f58823f95b5815a51`, reference method hashes, immutable retirement artifacts, and six executable historical alias witnesses. The reference classes inherit current GameState while overriding exact historical method bodies; their behavioral failing controls remain valuable.

Repair requires a deliberate provenance rebase: authenticate later owner changes as additional exact reversal layers, or explicitly redesign provenance around retained authenticated historical source while continuing to compare current isolation with executable failing historical controls. Updating expected hashes, deleting checks, rewriting historical evidence, or skipping the failing control would not establish the contract. Keep this work separate from the straightforward future-version fixtures and issuer census maintenance.

## Scope and acceptance

No files outside this temporary report were edited by the reviewer. No cloud dispatch, external comment, or runtime test was performed. These findings do not qualify the complete broad CI run or justify merging PR36. Schema-fixture fixes are narrowly reviewable now; issuer census needs explicit producer authentication; hospital compatibility and alias provenance remain independent blockers.
