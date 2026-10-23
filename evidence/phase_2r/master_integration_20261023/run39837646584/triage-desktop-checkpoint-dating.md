# Canonical triage — run39837646584

Read-only XML/log and pinned7606 source inspection; no product edits, remote changes or engine execution.

| Suite | Expected cases | Executed | Pass | Fail | XML assertions | Process exit |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| desktop | 326 | 326 | 289 | 37 | 25233 | 1 |
| checkpoint_diagnostics | 22 | 22 | 22 | 0 | 3604 | 0 |
| dating | 175 | 163 | 145 | 18 | 5037 | 1 |

Expected census independently derived from the canonical suite path list and each pinned source's test functions. No XML error/skipped elements, but dating has12 entirely absent cases due to a script load failure; absence must not be called a skip or pass. Assertions above include executions inside failing cases.

## Accepted bounded observations

Checkpoint diagnostics: all22 expected cases/3604assertions, clean exit0, no engine/script errors observed. Preserve this passing lane rather than rerunning it merely because other suites fail.

Restored PR32 Backup entry tests all pass:3cases/78assertions in tests/integration/test_scene_backup_desktop_entry.gd (uncached consent/view reuse; refused configuration retry; absent confirmation host cancellation). This does not qualify the entire desktop suite.

## Desktop failures

| Test file | Failed / executed | Concrete findings |
| --- | ---: | --- |
| test_application_bootstrap.gd | 9/11 | Fresh off-tree GameState reaches absolute /root/SaveManager lookup at GameState4320; later graphs hit scene_identity_issuer_conflict. RecoverySaves fake lacks newly called configure_scene_new_run. |
| test_desktop_bootstrap_wiring.gd | 18/27 | Restore-stage graph construction repeatedly refuses scene_validation_already_configured / owner replacement. |
| test_contacts_frozen_context.gd | 7/8 | Legacy invitation/ordinary IDs fail current registry admission, then helpers expose empty dictionaries and cascading reply_ids/ok access errors. |
| test_phase2r_schedule_desktop_handoff.gd | 1/111 | Retained schedule-view restore-configuration replay fails its replay-success assertion. Related owner rebinding requires investigation; do not infer distinct gameplay corruption from this alone. |
| test_ui_art_placements.gd | 2/5 | Test expects Title artwork position320,64 while current MenuScene explicitly uses320,0. Shop fixture uses retired coffee fallback, which is null in current supported art catalogue, then dereferences get_size. |

Bootstrap source supports a fixture/lifetime mismatch hypothesis: _make_graph constructs targets with autofree without mounting them; configure_scene_runtime_validation now performs an absolute root lookup. FrozenRunContext retains a static issuer and rejects a different issuer at lines29–31. Creating fresh issuers across tests therefore conflicts with process-wide authority. This requires a deliberate test ownership/isolation correction, not weakening production issuer or owner replacement refusals. The smaller RecoverySaves fake is also concretely stale. Distinguish fixture correction from any demonstrated production replay defect before modifying runtime.

## Dating failures and shared registry cause

test_frozen_presentation_context.gd fails5/6; test_dating_narrative_playback.gd3/18; test_dating_attempt_runtime.gd10/45. Shared first failure is frozen_context_unknown_entry for legacy IDs, followed by missing value/schema_version/ok fields and mismatched later expected refusal precedence.

FrozenPresentationContext._load_registry first chooses the active scene registration (lines156–162); legacy disk manifests load only when scene registration is absent. The old tests explicitly enumerate137 legacy entries or use dating/contact legacy IDs while the current application selects scene registration. ContactsFrozenContext delegates to this same schema owner and converts absent schemas into contacts_frozen_entry_unavailable. This is a concrete common context-selection mismatch, not evidence that all18+7 downstream assertions require independent runtime fixes. Preserve current scene registration and supply a legitimately isolated historical fixture context or revise the test's contract to current supported behavior; do not restore legacy production catalogue solely to satisfy old tests.

Separately, all12 cases from test_ordered_ending_real_runtime.gd fail to load. ReadingBoundaryBridge._begin_entry_playback at314–315 overrides five arguments; parent DialogicBridge3737–3738 now has a sixth optional scene_restore_operation:String parameter. This is a direct test subclass signature mismatch and a narrow maintenance candidate. It must be fixed before claiming the175-case dating census ran.

## Suggested sequencing

1. Preserve checkpoint22/3604 and PR32three78 evidence now.
2. Address the narrow ordered-ending override signature; qualify original cases without suppressing errors.
3. Resolve registry fixture ownership once for the shared legacy Contact/Dating family, preserving current scene and saved-data authority.
4. Correct bootstrap fixture mounting/process-lifetime ownership and the stale RecoverySaves interface; investigate schedule replay under that coherent setup.
5. Align art tests to already approved current Title placement and an actually supported Shop item, retaining wrong-size fallback checks.

These are triage recommendations, not implementation approval or proof every failure is test-only. No unrelated Checkpoint rewrite or blanket assertion deletion is justified.
