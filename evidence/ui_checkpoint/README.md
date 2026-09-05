# Verified runtime UI checkpoint — dwm-9fk

This checkpoint preserves Contacts, shared desktop hosting, Backup/save-load,
title Log in, routine title clock, keyboard navigation and neutral Shut down
confirmation on base `1790785bcfd37d2a27a0ecef81b9dc80fe501f71`.

The local checkpoint branch is `codex/ui-runtime-checkpoint`. This is a source
checkpoint, not a merge into the active gameplay destination or a release.
The user authorized checkpointing after the integration-readiness assessment.
The resulting commit ID is recorded in Beads dwm-9fk; it cannot be embedded in
its own committed contents without creating a circular reference.

## What is preserved

The exact reviewed path and raw SHA-256 inventory is [manifest.json](manifest.json).
The manifest omits itself to avoid self-reference. Everything else in this
checkpoint is enumerated, including this README and [verification.json](verification.json).
All six font/provenance/license files stay together. Headless evidence, original
and executed test project configuration files, and the inherited-shutdown
baseline are retained; no copied project tree, import cache or player-save file
is included. Test scratch storage remains ignored under `.godot`.

One coherent checkpoint is intentional: title depends on Backup and desktop
controls, Backup depends on changed save/storage/restore owners, and the real
restart runner depends on the full-loop runner and its baseline log. Inventing
independent feature commits from this accumulated state would risk broken
intermediate trees. Future changes should use smaller tested slices.

## Validation and byte preservation

Fresh production restart verification passed 103 checks (44 seed, 59 resume)
in two separate real application processes with disposable storage. Fresh
focused title verification passed 326 checks. The prior 3870-check Backup UI
and clock evidence still match the source bytes; these were not rerun for a
packaging-only change. [verification.json](verification.json) records exact
source and receipt hashes and source-binding validation.

Scoped `.gitattributes` rules retain the exact bytes of evidence, font provenance
and two pre-existing test runners with CRLF bytes. Otherwise Git's LF conversion
would silently break the retained hash evidence. Runtime implementation bytes
are unchanged. Older milestone documents and receipts retain their historical
claims; a statement that work was then uncommitted is not the checkpoint's
current status. Historical source bindings must not be treated as fresh results.

Independent packaging review inspected candidate paths, dependencies, licenses,
provenance and common credential signatures. It found no cache/player-save
payloads or material packaging blocker and recommended a single coherent
checkpoint. This is a packaging review, not a new whole-codebase audit.

## Remaining integration work

`dwm-oyo.3` gameplay work and `dwm-pxy` combined save-contract work were active
when this checkpoint began. Their existence does not block this local commit.
Integration needs a stable relevant runtime checkpoint and reviewed v4/v5 save
compatibility, including timestamp preservation and real combined restart tests.
See [the reviewed readiness assessment](../integration_readiness/README.md).
Do not merge the moving destination worktree merely because this task closes.

Existing exact baseline shutdown diagnostics remain in logs. No leak-free
shutdown, physical-device/GPU certification, full-game completion or historical
UI-00/UI-00R authority cutover is claimed. Other worktrees and actual player
storage are outside this checkpoint.
