# Authored progression profile continuation — 23 October 2026

Continue cloud-only Godot and PowerShell. Read AGENTS.md and CLAUDE.md. User requests minimal verification and a usable next-session handoff. No design question currently blocks continuation. No merge, master/PR51 alteration or Steam upload.

## Exact continuation

- Product branch: `codex/authored-week-followup-20261023`.
- Diagnostic/test source: `e6b3adf657b37bcac07c0d6d219978c8bf34a2c7`; tree `9f007fab92e9f43284c123ab9f79b50ae37a1b3d`. Runtime unchanged from prior source db9b896b. Documentation descendants do not imply new runtime results.
- PR50 controller: `b1c07d1697c36ec92234e5f2fab778cbdf78ff3b`, branch `codex/story-day-qualification-20261023`.
- [Bounded profile39895040994](https://github.com/Siuuuers/dwm/actions/runs/39895040994) was queued when this handoff was prepared. Collect its actual result before launching anything else. It is not accepted here.
- PR30 is historical; PR50 owns current diagnostics. Master and PR51 checked unchanged: `d2062f8d9807f7f06935f86065640ff14a5400d6` and `328edfe082c84bd9f6ca0a9d45e6603e0902695c`.

## What is now established

1. [Artwork retry39891351724](https://github.com/Siuuuers/dwm/actions/runs/39891351724) succeeded on db9b896b/tree d9309c97.25 tests /558 case assertions plus2 setup assertions;8 child exits0. Both ZIP CRCs and85 retained member hashes verified independently. All6 native992x558 screenshots visually inspected: artwork visible on New Account and fresh Load. Cloud-produced game_state_surface.json and save_manager_surface.json adopted exactly. No repeat artwork suite needed.
2. [Authored journey39888749357/job120203110074](https://github.com/Siuuuers/dwm/actions/runs/39888749357) failed: creator hit1800s, exit124.290 captions checked (230 Day1,60 Day2), last line.Day2.answer.019;2661 passed assertion records but no finished test/JUnit. Fresh Load/replay never ran. Day2 boundary at836353ms. Last retained autosave contains290 publications at Day2.answer control boundary; interruption inside marker handling is only an inference. Both ZIP CRCs and52 hashes verified. Do not increase timeout blindly.
3. Original artifacts are committed under evidence/phase_2r/authored_followup_20261023/run39891351724_art and run39888749357_journey. Each has inspection.json. Earlier Settings/export/historical results and limitations remain as documented in the predecessor; no repeated suites.

## Bounded measurement, not a game fix

The full journey stored scalar timings only at Day4 Save, losing them on timeout. authored_week_child.gd now prints begin/per-caption timing immediately. New authored_week_profile.gd measures32 captions from actual shipped Title with31 native input transitions, existing SceneValidationTiming scopes and input phase markers. Two separate read-only caption-memory projections are timed at captions1 and32. They are outside transition timings. The test asserts profiling is enabled; no game policy or save validation changed.

Controller runs exactly this test in one rendered process,600s cap. It requires32 observations,31 timing scopes,2 memory measurements, passing JUnit and exit0; retains original logs, screenshot, source pins and genuine imported UID provenance even on failure. YAML/embedded Python and caller/test reviews completed; native outcome pending.

Possible hotspot, NOT measured conclusion: SoloReadingSession.project_scene_caption_memory calls full _project_scene, which validates/copies the ledger and deep-copies/scans entry programmes per historical caption before filtering the current occurrence. Existing validation timing does not isolate that projection. Ordinary Enter uses native advancement, so do not optimize generic request_next checkpointing without evidence.

## Next session

1. Collect run39895040994; authenticate archive and inspect actual timing, failures and screenshot. Do not duplicate it. Diagnose earliest actual failure if it did not complete.
2. Retire authored-profile.yml pull_request trigger to workflow_dispatch before another controller push; path filters use cumulative PR diffs. The old art workflow was already retired; all other diagnostic workflows are manual. Keep controller changes out of product.
3. If useful timing establishes a cause, make the smallest owner fix and compare the same bounded operation. If only early-history behavior is measured, retain that limitation; genuine failed-run autosave may support a bounded late-history Load probe. Do not fabricate registration/ledger data or remove validations to pass.
4. Only then run the remaining necessary default authored journey/Save/Load/ending proof and final-source export. Earlier export predates artwork fix. Full authored-week flow remains unverified; this is not release acceptance.
5. Adopt any new UID only from genuine cloud import evidence. Update this handoff/PR50 with exact pins and results. Preserve originals and failures.

No need for a design interview or another generic audit. Independent reviewer confirmed artwork census/pins/exits and bounded profile plan. One coordinator owns controller/publication; use parallel review only for concrete independent questions.
