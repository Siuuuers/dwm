# Ending scene-validation aggregate observation — 2026-10-22

## Outcome and authority
Measure configuration and compilation within the existing final Accept without removing any of its three checkpoints. Bootstrap and SaveManagerCheckpointPort retain all authority, arguments and returned results. This candidate implements the prior writer-purpose-and-next-observation contract; it does not optimize production behavior or establish root cause.

## Candidate
Parent b0c6ac928371ed849bb4c7f6a37d8921465aade9.
Candidate 0b9095e5c63275bc4721cd257413d286bcd958b0; tree 022d60f5fa708066258c84fc06aed4a3f17f7281.
Branch codex/ending-validation-timing-20261022.
All five published files fetched back and text-exact verified. Manifest below hashes the uploaded contents.

[
  {
    "path": "scripts/narrative/DialogicRuntimeAdapter.gd",
    "bytes": 100103,
    "sha256": "5b8edeeb27eefa097a02c249026ff93ef016255955d0096f1661dcaec7379711",
    "blob": "39d441c636688177e9b1b809013843cc8db0e47d"
  },
  {
    "path": "scripts/narrative/SceneValidationTiming.gd",
    "bytes": 1415,
    "sha256": "b07eddde556ea8b15d633da93640c500e910223cc1b2de579480992e050bf793",
    "blob": "88b7cf8c00ec2b71942fa33c299498b34161c9db"
  },
  {
    "path": "scripts/narrative/SoloReadingSession.gd",
    "bytes": 53874,
    "sha256": "1639a42e6f4d5a76a516a2738cea247a0e797bfda53990dbdf46d597a6b19cdf",
    "blob": "cf9e72d23c21a0926248d706f41098cdf3256b1a"
  },
  {
    "path": "tests/integration/scene_seven_day_connected_child.gd",
    "bytes": 30036,
    "sha256": "1ae0943ad187e6f85d42345a439178cd01f692ca61348a9cf40330ace6c9f7fb",
    "blob": "d9f31e79658a83b3a835766564033ba448177cc0"
  },
  {
    "path": "tests/integration/test_scene_ending_direct_return.gd",
    "bytes": 7840,
    "sha256": "88e554c884e613018309fd9225014121f50a48ab5f5d67ec9f86a94c2d81835d",
    "blob": "d270ab1535e966f8b32f3a3100350332142c4c5f"
  }
]

## Changes
- SceneValidationTiming is a dependency-free, process-local diagnostic record. begin_scope is gated by DWM_SCENE_VALIDATION_PROFILE=1 and refuses overlapping scopes.
- SoloReadingSession.configure_scene and DialogicRuntimeAdapter.compile_scene_programme wrap the unchanged original bodies. Each forwards the original arguments once and returns the original result. Ordinary early errors are observed too.
- Disabled samples take no timestamp and bypass result observation. There is small wrapper-call overhead; do not claim zero overhead or use this as an optimized baseline.
- The inherited test port opens/closes one scope around each capture/prepare/commit/rollback call. Only a scope it successfully opened can close. Labels are scalar reads of lifecycle state, playback stage and next step; no snapshot/history capture is added.
- The direct-ending test enables the aggregate flag only around final real Accept and restores prior environment presence/value. Existing checkpoint profiler, viewport input, all durable/Title/Gallery checks and deadlines are retained.
- Aggregates contain counts, elapsed microseconds and failure counts for configuration/compilation. Configuration includes compilation; neither should be summed with the inclusive outer elapsed time. No per-resource new logging or diagnostic data in saved bytes.
- end_scope retires active attribution before printing. A killed/interrupted operation does not emit a completed aggregate; process termination remains the isolation boundary after exceptions/timeouts. Censored measurements are not zero durations.

## Verification
Independent reviewer review_prepare approved inert publication. Recovered-original comparison exactly restored both original runtime files after stripping wrappers and restoring function names. Reviewer checked early-return cleanup, scope ownership, scalar labels, saved-data exclusion, nesting and disabled behavior. No blocking static issue found. No local Godot/PowerShell or cloud execution in this checkpoint; parsing and runtime behavior are not yet validated.

## Next bounded task
Prepare and independently review a pinned cloud packet for this candidate with the same short direct-ending fixture, engine, renderer, runner and existing deadlines used by run39739944128. Reuse current assets66ff24b8096bbf4245bfc2e27634c8df3cfe6cc6 where compatible. Preparation custody must explicitly allow/hash all five changed paths plus inherited scene_later_caption_child.gd; the new runtime diagnostic helper and two runtime wrappers must not be overlooked as test-only files.
Reconcile PR30/current refs and active runs before dispatch. Expect three writer-stage mappings (EPILOGUE_PLAYED, GALLERY_RECORDED, COMPLETED) and returned per-operation aggregates. Preserve original failure on missing/malformed records or timeout; missing returned aggregates cannot be fabricated. Retain checkpoint phase profiles and whole Accept/writer totals, not just compilation totals.
This is observation, not an optimization comparison. Any later surgery needs matched whole-operation baseline/candidate with identical profile flags and preserved recovery obligations. Short-route success does not qualify the restored full-history journey. No automatic unchanged retry, deadline extension, cache, validation bypass, checkpoint coalescing, merge/release or export/WCT run.

## Reconciled state
Prior run39739944128 success69 assertions remains separate from failed general CI39739944158. No active run was observed. Held master41592fcc792aa615e47ee2ce2f05008ca195b311, PR36c8358870d3ece92d5f8cc7ba65aefe34a746be5c and integration3ae6d9138fb53c388380c78550cf6082eafc0ea3 unchanged; PR30controllerf588be78ae850ed490f187ae59937880b7ef3efa unchanged.
