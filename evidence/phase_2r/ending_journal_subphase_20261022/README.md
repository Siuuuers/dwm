# Ending journal subphase observation — 2026-10-22

## Outcome and owner

Prepare a narrow opt-in observation of SaveDocumentSchema's existing proof equality, journal composition and scene-journal validation, including each existing bundle validation. The schema remains the canonical validation owner. No performance optimization or cloud acceptance is claimed by this source checkpoint.

Baseline: `0b9095e5c63275bc4721cd257413d286bcd958b0`; authoritative schema blob `44f7ebcb05d4b3fd0984018a8ac272999be67791`. The existing short-route run39745466691 passed 1 case/69 assertions, while its fresh Accept took 22.743922 seconds. Configuration/compilation were nested measurements and did not explain the entire duration. The prior source audit is retained at `evidence/phase_2r/ending_validation_timing_20261022/run39745466691/source-audit.md` on the evidence branch.

## Failure contract

- Invalid proof, malformed journal member, failed bundle validation, wrong family/registration, duplicate checkpoint and non-earlier sequence must retain the original refusal order and result.
- An empty diagnostic profile must not read labels or clocks in the new journal wrapper, and diagnostic fields must never enter saved candidates.
- A failing returned bundle may have an elapsed measurement and `ok=false`. A call interrupted before returning has no completed duration; absence is never zero or success.
- Journal cardinality is read from the actual input, never assumed to be two. An early refusal may produce fewer completed entry records than input members.
- Nested timings are inclusive and non-additive. Journal residual includes cross-entry checks and observation bookkeeping; it is not a pure validator measurement.

## Observation surface

The existing nonempty caller-owned profile enables the new fields. Build retains `document_schema_compose_us` and `document_schema_metadata_us`; outgoing validation retains `outgoing_schema_compose_proven_journal_us`. Added proof equality and journal composition fields subdivide those regions. The scene-journal wrapper records its inclusive duration, bundle-duration sum, checks/observation residual, input count, current scalar labels, completed per-entry records and returned success.

Per-entry records contain ordinal, checkpoint sequence, lifecycle/playback stage where admissible, elapsed microseconds and returned success. They contain no snapshots, narrative text, extra normalization, hashing or owner calls. Existing checkpoint profile scopes and synchronous ending-writer markers retain prepare/commit and writer-operation attribution; schema phase prefixes/current labels supplement it.

All three ending persistence boundaries remain: playback receipt, Gallery receipt, terminal COMPLETED. Proof equality, detached composition and full scene validation remain in place. No cache, checkpoint coalescing, timeout extension, driver change or export replay.

## Validation and next bounded task

See `review.md` and `transformation-verification.json` for independent static review and exact baseline reconstruction. These checks do not compile or execute GDScript. No local Godot/PowerShell or new cloud run was performed for this checkpoint.

Next prepare and independently review a pinned cloud packet using the same short route, official Godot4.6.3 standard, renderer and 120-second child deadline. Add the changed schema source/hash to all four existing custody policies alongside the inherited six sources. Extend strict evidence parsing to require both schema phases for all returned prepare/commit operations, actual input/record counts, valid scalars and nested residual arithmetic, and unchanged durable COMPLETED/GALLERY_RECORDED/Title assertions. Preserve original archives and exact source/event receipts. Review before one dispatch; do not automatically retry or extend deadlines.

Master `41592fcc792aa615e47ee2ce2f05008ca195b311`, product PR36 `c8358870d3ece92d5f8cc7ba65aefe34a746be5c`, integration `3ae6d9138fb53c388380c78550cf6082eafc0ea3`, and controller `ab23ee7f8327b8be96a7fbd69f57d4032b563cc6` were reconciled. The controller's latest focused run is complete; general CI is separately failed/unqualified. No merge/release or restored/export qualification.

## Published candidate

Source commit `bef78c105697a256ee0ff1a40e9b4c306e2740e7`, tree `b81c0bcd0af02ca8be0228bb4d46aadc1410d2a4`, branch `codex/ending-journal-subphase-20261022`. Published schema blob `c9b3b58e21671cf5de39e3d5195869462ef68ca2`, SHA256 `c0fe0f1e37d2c11fe4884a1efd6fde31c3f93c1963a65f6606c5ff9fe31cfce0`; fetched back text-exact against reviewed local bytes. One source file changed relative to baseline. Protected/product/controller refs unchanged.
