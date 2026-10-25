# Current feature status — 25 October 2026

## Scope and evidence

This is a read-only comparison of the design records and runtime at
`cf60203f077ad0bb39a0d2b06068988153fb53c3` (merged PR #97).
It is not a complete release certification or approval to add every old feature.
Later owner decisions take precedence over retained design records.

[Cloud run 40187985765](https://github.com/Siuuuers/dwm/actions/runs/40187985765)
passed 50 jobs. The archived timing comparison was intentionally skipped.
Startup, New Run, current Scene Save/Load, Contacts return and ordinary passage
completion have automated evidence. Steam installation on the player's computer
is a separate check. No local Godot tests were run for this inventory.

## Work that remains

| Function | Current state | Next action | Evidence |
|---|---|---|---|
| Dedicated Priscilla self-talk text panel | Missing. Yes and multiple-option controls exist. They are not a separate thought-text panel. | Design the text source, location, caption coexistence, History/TTS behavior and opportunity expiry. Then implement with the existing reading and choice owners. | [Foundation](../../story/09-priscilla-foundation-amendment.md), [SceneHost](../../scripts/ui/SceneHost.gd), [scene layout](../../scenes/narrative/SceneHost.tscn) |
| New choice presentation | The current Yes/default and multiple-option mechanisms work. The proposed replacement rules are not specified. | State which behavior changes. Keep the current mechanism until that decision is made. | [Save design discussion](../design/2026-10-25-save-load-validator-audit.md), [approved adaptation](../../story/auditions/playable-week-20261023/DIFFERENCES.md) |
| Second sustained route and second ending | The Day3 fork exists. Sylvia temporarily joins the supplied P–L Day4 continuation. Only the umbrella completion passage is installed. | Select and author the second route continuation and ending. Integrate the chosen text through ordinary DTL. Do not add a separate ending selector. | [Adaptation](../../story/auditions/playable-week-20261023/DIFFERENCES.md), [current save/ending contract](../design/2026-10-25-current-scene-state.md), [installed registration](../../data/manifests/scene_story_registration.json) |
| Reproducible story generation | Repair needed. The installed Day7 passage is correct, but the Python source generator still emits the retired ending role. | Fix the generator before regenerating story files. Verify that regeneration preserves the approved captions, IDs and Start/Finish markers. | [Day7 generator](../../tools/authoring/story_days_4_7.py), [builder](../../tools/authoring/build_playable_week.py), [native role validation](../../tools/authoring/AuthoredWeekRegistration.gd) |
| Two-language captions and History | Approved future scope; not implemented by the current single-primary-language presenter. | Implement secondary-language selection and paired text rendering when scheduled. Keep menus in one UI language. Check translation coverage separately. | [Accepted scope](../design/current-ui/owner-ui-updates-2026-09-21.md), [caption presenter](../../scripts/ui/witnessed/WitnessedCaptionLayer.gd) |
| Contacts in the current story | The app and save/return infrastructure exist. Production registration has no authored Contacts messages or replies. | Decide whether Contacts remains and what role it serves. Author messages only after that decision. Do not delete the shared app infrastructure merely because current content is empty. | [Bootstrap app wiring](../../autoload/ApplicationBootstrap.gd), [registration](../../data/manifests/scene_story_registration.json), [foundation](../../story/09-priscilla-foundation-amendment.md) |
| Observer awareness and optional epilogue | Perfect branches contain authored recognition text. Current chapter-wide thresholds, limits and optional epilogue predicates are not fully selected. | Review carry from earlier results. Specify only facts required by selected passages. Do not invent counters, forced exits or an all-Perfect ending. | [Foundation section 5](../../story/09-priscilla-foundation-amendment.md), [adaptation](../../story/auditions/playable-week-20261023/DIFFERENCES.md) |
| Startup with incompatible development data | No old-save migration is intended. Retained operation journals can fail current validation before the title screen. Existing New Run retry recovery is narrower than a general reset. | Choose explicit archive/reset handling or separate development data. Decide whether Profile data is preserved. Do not silently delete files. A generic journal_schema_invalid report does not identify the exact failing member. | [Operation journal](../../scripts/infrastructure/save/DesktopContinuationOperationJournal.gd), [startup recovery](../../autoload/ApplicationBootstrap.gd), [current save policy](../design/2026-10-25-current-scene-state.md) |
| Steam-installed player journey | Exported executable startup is tested. An upload does not establish installed-client acceptance. | Select the uploaded BuildID on the intended test branch. Verify game.exe launch, New Run, Save/Load, exit and restart through Steam. Check existing development data separately. | [Upload procedure](../steam/CLOUD_UPLOAD.md), [export validator](../../tools/testing/Invoke-WindowsExportValidation.ps1) |
| Reported font corruption and enlarged text | The player's defect remains unresolved. Cloud captures did not reproduce it. | Record the installed BuildID, display settings and affected text. Compare pixel and readable modes on that installation. Do not call this fixed from clean cloud screenshots. | [Font investigation](../../handoff/j-font-scale-investigation-20261024.md) |
| Layout and visual polish | The owner reports unfinished panel design. Existing rendered tests cover selected surfaces, not a completed visual design. | Approve the self-talk/story/board layout first. Then check caption placement, control labels, overlays and text sizes in the installed build. | [UI owner updates](../design/current-ui/owner-ui-updates-2026-09-21.md), [current Scene layout](../../scenes/narrative/SceneHost.tscn) |
| Remaining pauses | No current whole-operation speedup is established by the save-format reduction. | Measure a reproducible pause in the current build. Compare the complete operation before and after a targeted change. | [Current save contract](../design/2026-10-25-current-scene-state.md), [startup/Load investigation](../../handoff/a-startup-load-handoff-20261024.md) |

## Requirements to amend or retire

These are not automatic implementation tasks.

| Retained requirement | Current disposition | Action |
|---|---|---|
| Angela-specific HUD, keepsakes, self-talk queue and Schedule refusal | Conflicts with the current Priscilla foundation in its named scope. | Amend the active UI guidance. Audit callers before removing runtime code. Keep compatible generic shell behavior. |
| Capture/Compare/restraint interactions | Explicitly suspended. | Keep suspended. New observer interactions require a new scoped decision. See [suspension record](../design/current-ui/observer-interactions-suspended-2026-09-21.md). |
| Affection-led partner selection, random ending forms and separate ending resume plans | Superseded for current Scene play. | Do not restore them to meet old backlog entries. Review retained calendar callers before deleting shared code. |
| Old summaries that say localization, ordinary passage completion or all Days4–7 are absent | Some are historical and no longer describe the installed game. | Reconcile status against current code and dated decisions. Preserve the historical record; link to this current inventory. |
| A different week for every Challenge outcome | Not required by the current foundation. | Keep authored local variations and valid shared joins. Do not expand the route count without a selected narrative need. |

The current runtime already supports registered choices, five distinct Challenge
outcomes, exact board restoration, current-day History, inventory/economy state,
primary-language localization and ordinary passage Gallery replay. These systems
can need content or UI work without needing to be rebuilt.

## Recommended order

1. Upload the pinned test build and verify its Steam installation.
2. Repair story-generator drift before any new dialogue regeneration.
3. Decide and implement the self-talk panel and its choice presentation.
4. Select the second route content and ending; decide whether Contacts stays.
5. Schedule dual-language display, remaining visual work and measured performance fixes.

An incompatible-data startup decision can move ahead of step 2 if it blocks the
player's test installation. This inventory does not authorize a reset or choose
its scope. It also does not change story canon or approve archived features.
