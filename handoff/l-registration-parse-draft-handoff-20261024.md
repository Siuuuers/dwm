# Registration-local parse reuse — draft checkpoint, 24 October 2026

**Start here in the next session. The user requested a useful handoff before further qualification. Draft PR [#77](https://github.com/Siuuuers/dwm/pull/77) is NOT qualified or merged. No cloud run is pending for this draft.**

## Current published state

- `master` at checkpoint: `bb518236c741497d657b8b5bac19838b3ce1a4f0`.
- [PR #74](https://github.com/Siuuuers/dwm/pull/74) is merged: same-call canonical registry encoding reuse. Its cloud checks passed; one matched pair improved fresh Load 43.851→40.555 s and Save 39.880→34.118 s. It did not make loading fast. Read [handoff i](i-bundle-encoding-handoff-20261024.md) for full evidence and limits.
- [PR #75](https://github.com/Siuuuers/dwm/pull/75) is merged, records only: 50 reviewed font captures across source native/GL, mounted UI and retained exported resources did not reproduce the player's corruption. The font report remains unresolved; [handoff j](j-font-scale-investigation-20261024.md) identifies missing player evidence. Do not reopen an issue merely to track it; the user requested development records instead.
- [PR #76](https://github.com/Siuuuers/dwm/pull/76) is merged, records only: native source-project launch/New Acc baseline and compiler attribution. Read [handoff k](k-startup-new-acc-attribution-20261024.md). Fresh/retained Title: 16.427/15.897 s; fresh New Acc: 13.579 s; retained confirmation: 13.949 s; frame gaps approach 9 s. These are cloud source-build measurements, not an identified installed Steam build.
- No new Steam upload or live branch change occurred. The old master Steam workflow pins an earlier runtime; do not dispatch it expecting current master.

## Exact unqualified candidate

Product/test commit: **`d4fa64d22385d1aa4bacf3645f889c00ff61edb7`**, parent `bb518236c741497d657b8b5bac19838b3ce1a4f0`, tree `bb814815032c104b06fecc946588d584ec7657c9`.

Branch: `codex/registration-parse-reuse-20261024`. A later documentation-only commit on the same draft PR adds this handoff and the archived controller. Inspect current PR head/master before resuming; do not assume the branch has stayed unchanged.

Only three implementation/test files differ in the product/test commit:

1. `scripts/narrative/DialogicEntryManifest.gd`: creates one temporary `parsed_sources` dictionary inside `validate_scene_registration`, immediately before its entry loop.
2. `scripts/narrative/DialogicRuntimeAdapter.gd`: a private registration compiler seam accepts that scope; public compilation supplies an empty scope. Fresh physical bytes are read and compared on every request. Translation-enabled calls neither read nor populate the temporary parse scope. Native timelines/events stay inside the synchronous registration operation; the existing process-wide cache still retains only bytes and detached primitive results. Parsing and per-entry projection are separated; the entire projection/validation/result-building body is byte-identical to baseline.
3. `tests/unit/test_scene_compiler_cache.gd`: six new tests, eight total in the file. They cover shared-file graph/native-index/hash equivalence and detached outputs; marker/callable boundaries; invalid unselected siblings; changed/deleted source; mutable translations; independent manifest validation calls; and all currently shipped entries compared exactly against independent cold public compilation and approved manifest hashes. Coverage follows the manifest's declared entry count (currently 92), rather than introducing a new fixed story-count requirement.

Runtime diff is +27/-5 lines across two files. The draft introduces no saved-data format, new manager, persistent parsed-event cache, or content change. Its intended observable improvement is faster complete startup with identical compiled programmes and player behavior, not just fewer lines or a lower microbenchmark.

## Evidence motivating this candidate

[Run 40092073156](https://github.com/Siuuuers/dwm/actions/runs/40092073156), diagnostic source `3fbc22320962ec0cba1ccc1fb05dcb1746e9b7a1`, measured 92 cold compiler requests across seven physical story files. `timeline.process()` consumed 3.026983 s of 3.259659 s compiler time (92.86%). The files were processed once per entry, with 25,048 native events processed/scanned versus 1,950 projected selected events. This is attribution on the baseline, **not evidence that the draft is faster**.

The target is to share processing within one registration operation. Independent public calls remain fresh under their existing physical-byte/result-cache rules. Avoid broadening this to a global parsed-event cache: Dialogic's mutable parser event registry and character/translation resolution are additional inputs beyond the DTL bytes.

## What has and has not been checked

Completed: scoped implementation, independent source review, unchanged-projection-body comparison, resource-path/duplicate-test-name checks, `git diff --check`, and exact equality of local and published candidate Git trees. Source review found no concrete blocker. The public compiler signature remains unchanged; the source-string compiler wrapper remains fresh. Longer transient object lifetimes and any hidden mutable event behavior still need runtime verification.

**Not run:** Godot import/parser checks, any new or existing unit test against this candidate, native gameplay qualification, actual parse-count confirmation, or a matched performance comparison. No speedup or runtime correctness is claimed. New test expectations, especially native indices and the translation fixture, are unqualified. The PR is deliberately draft with `[skip ci]` checkpoint commits; that is not a test pass.

## Archived cloud-controller draft

The archive and byte manifest in [drafts](drafts/) preserve two controller files: `.github/workflows/restore-proof-preflight.yml` and `tools/testing/Invoke-RegistrationParseQualification.ps1`. They are **not installed as active files** on this product branch. Extract only into an isolated controller checkout after review.

The controller pins baseline `bb518236c741497d657b8b5bac19838b3ce1a4f0` and diagnostic overlay `3ed9cf1fd51cc1910d1d2a96fb4eb87784bb822c`. Candidate must be an explicitly reviewed 40-character SHA. The isolated push trigger uses branch `codex/registration-parse-checks-20261024`; its placeholder candidate must be replaced before publishing a runnable controller. Manual dispatch may supply the SHA where available. Missing/placeholder values fail validation. The current GitHub connector exposes Git-object writes but no workflow-dispatch tool, so a pinned isolated push controller is the established route.

Two Windows lanes are drafted:

- Focused: ten complete compiler/manifest/registration/authoring suites on the untouched candidate, source-derived test census, and four public-surface inventory generation/check executions. Baseline census was 159 cases; six added cases imply 165 if the listed suites remain unchanged. Inspect actual collection and output, not just that estimate. Review generated inventory payloads and copy only justified changes into the candidate; do not hide stale inventories by regenerating without inspection.
- Native: baseline then candidate on one runner, independently imported and each using an initially empty isolated profile followed by a retained-profile process. It uses the corrected actual-button input harness, five captures per runtime, exact first-caption checks and clean exits. Both runtimes get the same six pinned temporary overlay files: `ApplicationBootstrap.gd`, `SaveManager.gd`, `MenuScene.gd`, `StartupAttributionTiming.gd`, `startup_new_acc_attribution.gd`, and `Invoke-StartupNewAccAttribution.ps1`. Candidate compiler/manifest bytes are never overwritten. Wrapper provenance records actual runtime SHAs; the unchanged nested helper still labels its original instrumentation base `88e44`.

The controller has only static YAML/whitespace checks; PowerShell has not executed. Review it before launch, particularly adding a bounded editor-import deadline: its draft synchronous import currently relies on the overall job timeout. No fixed speed threshold is invented. A single ordered pair may need a reverse-order repeat if results are noisy or contradictory. Compare full launch, New Acc/confirmation, frame gaps, all captions and failure/exit evidence. Fresh profile does not mean cold OS cache.

The existing compiler counter measures compilation requests, so it may remain 92 even if processing falls to seven calls. If claiming an exact process-count reduction, add a narrow candidate-aware diagnostic separately. Do **not** overlay the old whole adapter attribution file onto the candidate: that would replace the optimization itself.

## Resume sequence

1. Read this handoff and current draft PR #77 metadata; compare current master and candidate. Preserve the three scoped changes. Review tests and controller before executing anything.
2. Run focused cloud checks and the matched native comparison using exact candidate/runtime/controller identities. Fix genuine failures in their owning layer; diagnostic input failures are not product latency.
3. Finish independent caller/test/evidence audits before final acceptance. Verify unchanged compiled programmes, refusals, physical-source freshness, translation behavior and detached results. Inspect complete-operation timing, not just parsing time.
4. Retain compact exact evidence and source reconstruction/provenance, refresh only justified inventory changes, update the PR around its final result, and merge only after qualification supports it. The user already permits scoped PRs/direct merges; no new permission is needed merely for these steps. Steam deployment is separate.

No running cloud jobs need to be resumed for this draft. Git writes were made through the GitHub connector because local `git push` has no credentials. Public fetch works. Godot/PowerShell execution belongs on Windows cloud runners; do not substitute local engine testing. Local worktrees are scratch and may disappear—the Git commit, draft PR and archived controller are the durable checkpoint.

For fonts, still needed from the player: an original corruption screenshot with affected screen/locale/font style/text size/window resolution, installed Steam BuildID (or exact package hashes), and whether Readable mode changes that same screen. This missing evidence does not block the scoped startup work.
