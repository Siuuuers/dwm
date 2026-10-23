# A — exported Save phase diagnosis, 18 October 2026

## Disposition

Two bounded cloud diagnostics are complete and independently reviewed. No runtime change or performance fix is accepted. PR30 remains the workflow controller; PR36 receives evidence only. Draft/unmerged; integration and master unchanged, no release.

Observable next outcome: after successful witness Save, Backup presentation must not repeat expensive inspection for an already-satisfied notification, while displaying fresh slot state and preserving revision checks, loadability, action admission, recovery and history. BackupApp and BackupPresentationPort own presentation refresh; SaveManager retains file and restore authority. Establish caller ownership before changing either refresh.

## Provenance

Both runs use the same retained Godot 4.6.3 standard GDScript Windows export:
- Artifact 12127144275 from run39103588380, exported-backup-package-39103588380-1.
- Packaged product bb167aa1b5692f6bf5ceb6789201f38d4f86360a.
- Package ZIP SHA256 625fad0d7ab746c6413192f82db6b461e9db05f40634772e0b1e387dcdb017bf.
- EXE SHA256 91724f15024a3a545e28ccd83134403d31ce2323a38e51c95e4dfa282f732ab6.
- PCK SHA256 e6fe5dab1eb7588704c24ae5d7eb231f7e475dff62cb663b637cbd5ea1baa22d.
- ProjectDefault renderer, observed D3D12 Forward+ Microsoft Basic Render Driver; accessibility Always; Dummy audio.
- Ordinary UI creator saves Day4 slot1 and exits cleanly; a fresh loader loads it and saves slot2. No injected save fixture.

### Post-query native observation

[Run39122098427](https://github.com/Siuuuers/dwm/actions/runs/39122098427), job117659591995.
Candidate aba8cf9a4674d5bebe3193ffb5e0be8c88793197; tree aac85d329d300cba86df88b42627fe3314596451; driver blob3551260da0402a21449976df9a4f7c608ea6b0ec.
Controller2cfb7fe04cd1ac375a421431244552ebd74dc273; workflow blob5767ebca0ea91bac25c121436393f9f7c7fab7c8.

Adds exactly one native observation immediately after final fresh UIA, before activation, capture or additional traversal. Invoke0.0005351s; readable-file wait11.335929s. Original window responds before/after Invoke, is hung after file detection, and remains hung through all40 quiet samples. UIA begins at quiet30.0055548s, returns zero descendants at45.0104384s (~15s query). The immediate original-HWND sample at45.0117211s remains hung/nonresponsive; foreground is a different process's Ghost window.

Original ZIP751445bytes; SHA256 27496880509b2046af5026ae0730accb064ba51b55a52a41d73d5ce6f4aa6fab. All137 outer manifest entries and per-mode manifests verified.

### Existing SaveManager phase hooks

[Run39122595303](https://github.com/Siuuuers/dwm/actions/runs/39122595303), job117661039428.
Candidate39990c0834d6eb94bd34aa1947245c998c42ed21; tree b4808a6cf95e98c24c51b791e8f7c8f9fb62abe0; driver bloba47c412c825f83f45ca8384d60af8d1ca05b5a62.
Controller7cb7dc7b28086aad04af48d2de09136e5cc2b903; workflow blob108a1d3c8185816173a1501c8c1aac4c204f1e59.

Only loader enables existing DWM_SAVE_LOAD_PROFILE=1 and DWM_SAVE_LOAD_CONTEXT=exported-load-phase-diagnostic. Capability/Create do not. Mode guard rejects profiling outside Load. Runtime hooks already exist in the exact package; SaveManager blob319449c17e7d3859076d7ba20e362b775f096802 matches packaged/current source. They report timing and return the original result. This is an instrumentation difference, not a matched performance comparison.

93 records are taken once from game.stdout.log, not double-counted from game.log. Completion order:
1. Witness backup_prepare save:5.439143s.
2. Witness backup_commit save succeeds:4.785992s. Atomic write3.012797s, source recheck0.979222s, journal commit0.781930s; metadata refresh0.000006s.
3. Two subsequent complete nine-locator backup_inspection sequences. First top-level sum19.584911s, second19.703791s. Nested parse/restore timings are excluded from these sums.

| Sequence | Autosave | Slot1 | Slot2 |
| --- | ---: | ---: | ---: |
| First after commit | 5.776359s | 6.134033s | 7.673527s |
| Second after commit | 5.800465s | 6.199489s | 7.702849s |

Admission and restore preparation dominate occupied-file inspection. The microsecond metadata_refresh phase does not include this later work. Records establish completion order, not a shared timestamped call tree.

Invoke0.0004282s; readable-file wait10.2960649s. Original window responds before/after Invoke, is hung after file detection and through all40 quiet samples. Fresh UIA begins at quiet30.0070187s and returns zero descendants at41.9613932s. Immediate native observation at41.962256s finds the original Engine HWND responsive/not hung and foreground restored to it. This proves one observed recovery point, not sustained usability, UIA-caused recovery or a fix.

Original ZIP794681bytes; SHA256 98cc346606a49ea87386ad04269203bc1ffa81107fd6cd8b1d3e91acf064052b. All138 outer entries, per-mode manifests, source pins and phase records independently verified.

## Preservation and acceptance limits

For both runs, quiet-before, quiet-after and failure snapshots retain equal narrative_checkpoint, gameplay, scene, command_receipts, applied_effect_transaction_ids and applied_variable_transaction_ids between source/witness. Same run/different branch semantics, whole Profile semantic equality and byte-identical source slot1 hold. Copies are live/non-atomic diagnostic observations, not arbitrary-interruption guarantees.

Capability/Create pass with clean exit0. Load intentionally ends DIAGNOSTIC_ONLY_QUIET_OBSERVATION_COMPLETE, ok=false, forced cleanup. No ending, normal loader exit, complete journey, hardware-renderer/audio/default-accessibility or broad CI acceptance. No timeout enlargement, validation removal or runtime caching was introduced.

## Next owner audit and verification contract

Exact packaged BackupApp successful _commit_pending calls refresh_view; refresh_view calls port.get_projection. The view also binds projection_changed directly to refresh_view. Exact packaged BackupPresentationPort (blobaae70e9b6be376ee2b36340f5d408810bcfd4a97) queues deferred projection_changed from metadata/capability signals; get_projection inspects all nine locators. This is a concrete duplicated-work candidate, not proof that either refresh is dispensable.

Trace explicit refresh versus queued notification, including changes occurring during a refresh. Before surgery, account for:
- Successful Save with queued metadata/capability notification.
- Failure/refusal/uncertain commit and retry.
- Changes after the fresh projection but before deferred publication.
- Separate subscribers, injected ports, unmount/scene activation and focus/status preservation.
- External file changes and stale revision/action tokens.

Prefer coalescing an already-satisfied presentation notification over caching restore admission or weakening fresh validation, if caller analysis proves it safe. Focused notification-order tests plus existing owner/storage integration tests precede one matched exported replay. Compare complete Save-to-responsive-visible-state behavior with identical package settings and profiling policy; do not claim speedup from these two different diagnostic settings.

Master rechecked unchanged at0c8b2384415d71bd3de4ff7408640bbf60b63740. B fixture correction remains queued after active A boundary work; prior completed audits need not be repeated.

## Retained evidence

Under evidence/phase_2r/exported_gameplay_20261018:
- 39122098427-post-query-native.zip and postquery verification script/report.
- 39122595303-save-phase-profile.zip and profile verification script/report.
- save-phase-records.json preserves raw parsed records in stdout completion order.

All Godot/PowerShell execution was cloud-only. Local Python was used only for archive/hash/source/evidence inspection.
