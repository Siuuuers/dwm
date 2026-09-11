# Schedule draft saving and Done fixes

Tracked as `dwm-rvp`.

A copied September 11 player save reproduced both failures. Slot 1 saved before editing Schedule, then failed with `invalid_expected_fingerprint` after adding Training. A seven-entry Schedule at five Motivation correctly refused, but the next Done still retried seven entries after the player removed two.

Live checkpoint composition now pairs a nonempty, uncommitted draft with the registry already held by its Schedule participant. Only the detached checkpoint gains that fingerprint. Saved-file validation remains strict; historical empty/null snapshots, existing fingerprints, committed receipts, and live gameplay are preserved. Manual, paused, automatic, and direct checkpoint paths use the same composition. The common path adds no snapshot copy; only a qualifying draft receives a detached candidate.

An `insufficient_motivation` refusal before preparation now releases the frozen command so the next Done captures the edited draft. Schedule stays editable, restores Done focus, and displays a localized Motivation message. Prepared and published retry semantics remain unchanged.

Validation:

- Schedule suites: 75 tests, 2,110 assertions passed.
- Snapshot/checkpoint suites: 48 tests, 481 assertions passed.
- Actual copied-save UI: Slot 1 Save before and after adding Training; seven-entry refusal; remove two entries; Done advances to Day 2 with one five-Motivation charge.
- Fresh-process Slot 1 Load restores the exact uncommitted draft, money, and Motivation.
- New Account -> Training draft -> actual Minesweeper Reveal -> durable Autosave preserves the draft.

Evidence is retained under `.godot/phase2r_logs/`: `live-backup-draft-repro.log`, `live-backup-draft-fixed.log`, `live-backup-draft-restored.log`, `draft-automatic-production-final.log`, `schedule-rvp-green`, and `backup-draft-boundary-noop-clone.log`. Native reproduction probes are in ignored `temp-artifacts/player-bugs-20260911/`. All writes used isolated test data; the user's running game and live saves were untouched.
