# PR32 missing Backup desktop test — static compatibility review

Reviewed 23 October 2026 against playable source `5eee8406f4c2c466ac05d03c489c7cdd1cbc1164`, whose runtime is preserved in integration PR42 head `339c48939b8846445f961734e1bc5d72cc1ed267`. Read-only; no test import, runtime edit, Godot/PowerShell execution or workflow dispatch.

## Recommendation

Import the exact PR32 test body as a focused candidate, with a minimal explicit canonical-runner registration. No architectural decision or runtime adaptation is established by source review. The exact test is source-compatible with the current APIs and assertions inspected, but remains unexecuted on this composition; do not label it passing until cloud execution completes.

Source: `424e0a917e77c13c143088a1e018e01a8cac0c31:tests/integration/test_scene_backup_desktop_entry.gd`, verified Git blob `2e8453db00ae4a5a0cfc82e37c63cb60ffe30163`.

## Compatibility findings

- Both imported support fixtures are byte-identical to PR32. All named methods/properties still exist. Desktop navigation and command semantics are unchanged; ComputerDesktop differs only by removal of one trailing blank line.
- The normal case starts with the real Backup default `selected_locator = "slot:1"`. Its injected record retains `fallback = true`, `load_family = "scene"`, and null `load_saved_time`, so the exact expected fallback/`--:--`/replace-progress confirmation remains consistent with current `_confirmation_copy` and `_record_time`.
- Current `open_app` removes and queues the refused view before caching/admission; the refusal/retry case matches that path. Its two-frame settle and WeakRef assertion check eventual release. No obsolete error code or changed signature was found.
- Current missing-host handling cancels the prepared token, clears it, and enters recovery; Cancel refreshes the view and permits returning Home. These match the third test's existing assertions.
- BackupApp's later projection revision optimization suppresses already-covered notifications, not explicit refreshes. These three tests do not assert obsolete read counts. Its earlier detached-view guard concerns commit completion; these cases cancel/refuse and do not commit.

## Runner integration is necessary

`tools/testing/Invoke-CloudTests.ps1` selects explicit per-suite file arrays and invokes GUT with `-gconfig=` and a comma-joined `-gtest` list. It does not discover new integration files automatically. The missing file and both related scene desktop/app tests are absent from the canonical workflow/runner selection search.

Adding the exact file alone would therefore leave its three cases unexecuted by canonical CI. Add the one new path to the existing `desktop` suite, near its desktop consent tests, or use an explicitly selected focused packet first and then register it. Preserve all current assertions and cloud-only execution. No deadline increase, new runner, broad test rewrite or owner changes are justified by this review.

## Scope

This is real mounted desktop/Backup/confirmation integration over injected Bootstrap, app preparation, board dispatch and lower save owner. It is not production Bootstrap or physical disk/restore acceptance. The absent test is an outstanding coverage obligation, not an observed runtime defect. Existing `test_scene_backup_inspection.gd` tests different owner-level inspection/admission cases and was not treated as equivalent coverage.
