# Coordinator A — Gallery rehearsal integration, 2026-10-18

## Observable outcome and owner
Starting an admitted Gallery rehearsal with an empty retained pre-DTL reaches its private board automatically. DatingRehearsalOwner owns private phase resolution; the live story catalog continues to refuse retired entries. Save, recovery, history, and profile eligibility owners are unchanged.

## Director-requested first-error triage
Baseline source: b5f59a25a0eb4adc02b8a19cc56e0b09b7e07bcc. Original broad [run 39090268581](https://github.com/Siuuuers/dwm/actions/runs/39090268581) completed **failure**. This table classifies inspected first errors, not every failure in those jobs. Original failures remain recorded; bounded excerpts are retained alongside this report.

| Suite / job | First observed failure | Supported cause and scope | Action |
| --- | --- | --- | --- |
| persistence / 117566534168 | test_frozen_run_context.gd::_dating line 41 accesses absent value after build failure | Retained dating fixture cannot resolve against current registration; related hospital fixtures also reference unavailable entries. Cascade failures require separate classification. | Pending scoped reconciliation of fixture vocabulary and historical-load guarantees; do not discard by suite name. |
| new_account / 117566534165 | test_run_snapshot_schema.gd line 230: contacts_frozen_entry_unavailable | Current snapshot test uses unavailable retained contact entry. Separate schedule-gate historical hospital walk references retired health:+1. | Pending fixture/current-path review. Do not restore retired health merely to satisfy historical expectations. |
| minesweeper / 117566534085 | Mounted Gallery Start journey remains pre_challenge instead of challenge, test_gallery_rehearsal_host.gd line 84 | Actual integration defect: private admission uses retained presentation vocabulary, while phase lookup uses the live eight-entry story registration. Owner and mounted test were unchanged from PR1; startup registry selection changed. | Fixed and qualified in this slice. |
| reading_delivery / 117566534110 | test_dtl_master_structure.gd expects 137 entries, receives 8 | Census assumes former catalog; some empty-DTL assumptions also conflict with executable current result routes. Further errors are unclassified. | Pending exact contract reconciliation; keep current executable-route checks. |

## Change and failure boundaries
Private phase resolution now parses and fully validates the existing retained schema-v1 presentation manifest, then resolves the admitted entry with an explicit empty retired-fallback map. Schema-v2/live startup registration is never invoked through this helper. Missing, malformed, duplicate, or unknown entries fail closed through the existing Retry path. Existing source-and-leaf empty-route validation remains in force.

This introduces no new manager or persistence authority. It runs at narrative phase admission, not on board moves or per-frame. No performance improvement is claimed. The original mounted host test remains unchanged. A focused owner regression also verifies that private resolution does not reopen canonical registration, closed commands are rejected, and canonical run/profile state stays unchanged.

## Cloud qualification
- Tested candidate: 8ecac286bcb2c5396c71009d80d5ec34e267c2d3
- Tested tree: 7c0546cc9c4dc0416ac63773820d2811eb4da85c
- PR30 workflow controller: 6d5be41904a45c87efb853ee5f92d1f45aaf58b7
- [Run 39092313867, job 117571461600](https://github.com/Siuuuers/dwm/actions/runs/39092313867/job/117571461600): success
- Godot 4.6.3 standard GDScript, Windows PowerShell cloud execution only.
- Owner + mounted-host rehearsal: 11 tests, 591 assertions, no failures/errors/skips.
- Public-surface inventory: 11 tests, 352 assertions, no failures/errors/skips.
- Six recorded clean process exits; strict log error checks passed.
- Independent read-only agent reviewed diagnosis and candidate before final qualification.
- Archive: qualification.zip, SHA-256 7bbf333a2b88ddaf92bbbd45addedc768342d7137a794aecf61c0a28f46dd59c, 736191 bytes.
- Independently verified all 33 retained manifest members, JUnit census/status/assertions, and retained Git source blob hashes.
- GameState inventory differs only in four call-site records belonging to the edited owner/test; SaveManager inventory is byte-identical. Required surfaces and dynamic references are unchanged.
- Cloud index removal of two malformed skill gitlinks was harness-only; no such deletion is published in the product tree.
- Publication adds generated caller inventory and evidence/handoff files to the tested candidate. Runtime and tests remain exactly those qualified above.

## Remaining work
The broad run is still red and is not superseded by this bounded pass. Next integration work should reconcile the persistence/new_account registration fixtures against current behavior while retaining historical recovery obligations, then classify the remaining reading_delivery errors. Do not launch another broad campaign before the compatible audits and fixes are coherent.

C's prepared exported-journey capability gate remains pending: adjacent exported exe/pck normal startup, existing validation package, UIA-scoped Backup controls, no source override or fixture bootstrap, and the approved normal seven-day journey. This pass is mounted-host integration evidence, not exported rendered E2E or final game acceptance. B's inventory and timeout-report work is complete; no repeat is requested.

PR36 remains draft. PR30 remains workflow-only. No merge, master update, or release is authorized by this report.
