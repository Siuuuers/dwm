# Run39588849613: failed early-construction observation

Official cloud Windows Godot4.6.3-standard run39588849613 attempt1/job119184434437 FAILED. Controller b968bede9db9bc795b418aee753d83918a81d8dc; source cb9724686be5efb0c0930a2543501074fdc7302c; helper ae2aae7a726da8f0117b3168b4c96f1edab34608. Director6313768169's single attempt is consumed. No retry or replacement run.

## Actual result and evidence limits

Exactly one initial-registration case; no remaining cases/native invocation/export. Child/GUT exit1, raw log16/18 assertions. Two reported failures: initial registration timeout and an unexpected diagnostic script error. Original JUnit has root failures=1, suite failures=2,18 assertions,0 skips, and only one failure element. Preserve this discrepancy rather than flattening the XML into a misleading count.

Error: Cannot call method get_instance_id on a null value, at tests/manual/test_continue_reveal_publication.gd:18 in _continue_registration_phase, called for mounted_settle from inherited fixture line1049. The diagnostic checked caption validity but unconditionally dereferenced layout.get_parent(). The layout existed without a parent at this point. Phase assignment and zero-counter creation had already happened; appending the mounted_settle boundary did not happen. Execution continued through ordinary entry/bind, reparent, timeline, script replacement/rebind and final wait. This is a diagnostic defect, not evidence that production must attach earlier. Clean/noninterfering observation is NOT established.

Early records exist: original instance_init at8338966us outside tree; ordinary tree entry at8353434us; same surface492914608802 throughout. The second instance_init is script replacement on that same surface, not a second object. Reparent records one exit and second entry. Shared metadata and24-event prefix survive replacement, with aggregate/per-phase counters and latest facts retained beyond the cap.

| Phase | Projection queue request/return | Retirement queue request/return | Handler notifications |
|---|---:|---:|---:|
| mounted_settle | 1/1 | 2/2 | 0 |
| timeline_start | 0/0 | 1/1 | 0 |
| timeline_settle | 1/1 | 4/4 | 0 |
| post_mount_rebind | 1/1 | 1/1 | 0 |
| All other recorded phases | 0/0 | 0/0 | 0 |
| Total | 3/3 | 8/8 | 0 |

Element/admission/owner capture/probe capture/action registration are also0 in every phase. Two binds enter/return; final timeout publications0,reveal1,label Continue,available/source_visible/visible_in_tree true. Initial-wait boundary8758121us to final13772644us =5.014523s (boundary-to-snapshot, not an exact internal deadline measurement).

Bounded finding:11 existing queue calls returned, but this handler recorded no accessibility-update notification during the observed construction-to-timeout sequence. No earlier registration was observed, and no positive delivery difference across reparent/rebind. Queue return is not proof of scheduling/delivery; downstream zeros do not prove downstream correctness. The diagnostic error limits causal/noninterference claims. Do not infer a backend defect, ordinary gameplay failure, consumer acceptance, completion-refresh cause or successful clean exit.

Preparation/import/exact settings restoration/post-test policies all passed. Official archive pin and source/helper/runtime pins unchanged. ANGLE fallback warning retained. Separate ordinary run39588849462 failed public API surface contracts and seven-day retained history; downstream jobs skipped. It is not the focused result and is not repaired here.

## Concrete smallest correction, prepared but NOT installed

candidate/test_continue_reveal_publication.gd contains the exact proposed replacement for the manual fixture at sourcecb9724686. Only the boundary recorder changes:
- Guard layout independently.
- Default layout_id/layout_parent_id to0 and layout_parent_present tofalse.
- Read parent's ID only if valid; record true when present.
- Guard caption/background identity independently.
- Always append the boundary; do not return early or insist a parent already exists.

This represents the observed parentless lifecycle state without changing it. No mount reorder, added parent, queue request, notification, capture, input, wait, readiness override, runtime owner, helper or controller change. All original source is otherwise byte-identical. Static exact-delta review only; no local Godot/PowerShell execution or runtime acceptance. Internal independent actual-outcome review agrees with the diagnosis and limitations; external C review remains pending.

C: review actual findings and exact inert correction. Director: reconcile the consumed attempt and whether to authorize one corrected same-scope run after C clearance. The concrete unresolved decision is whether the same requests-without-handler finding persists with a nonthrowing observer and complete boundary record, before selecting any production correction. This is a repair of the existing diagnostic, not a new instrumentation layer. No automatic retry.

## Original evidence custody

Both downloaded ZIPs matched live artifact sizes/SHA256, had unique safe member names and passed CRC. originals/ contains166 exact binary parts, each up to65536bytes. parts.json gives ordered filenames, byte counts, SHA256 and Git blob IDs; the Git tree accepted all referenced objects. Reconstruct each ZIP by concatenating its numeric parts and verify against custody.json before extraction. Originals remain authoritative; readable JSON/log/XML copies are supplied for review.

- Focused artifact12340178473:4742bytes,4members,SHA256 d5ae1a261a5ca7c6a41d9503b880b1f2169b1c19b291dedf391ae9863b19973d.
- Preparation artifact12340043887:10804146bytes,5280members,SHA256 f7e58b10f0e4e2f9294d12f1fa309de0f34ba396e246cc2b0d99f531ca0aa372.

Large preparation UID/parser audit reused; only actual run policies/custody checked here. No product/master/integration movement, export, merge or release. Standing publication permission persists.
