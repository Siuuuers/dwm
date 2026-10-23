# Frozen producer successor: bounded predicate work

Read-only follow-up to `docs/agent/2026-09-21-successor-cutover-readiness.md`, while run 47 validates the current v6 producer fixes. No schema or validation source changed by this audit.

## Confirmed gaps before enabling strict validation

1. `FrozenRunContext._condition_candidates()` invokes `_dating(..., false)` even when outer `require_complete` is true. A detached candidate with a nonempty `active_dating_challenge` and deleted Dating cache can therefore replace valid current gameplay without meeting v7 completeness. Pass the inherited requirement to Dating against the candidate's own route facts. Preserve the existing merged candidate/current append-only rollover receipts so a historical pending pair is not rewritten after later rollover.
2. `FrozenRunContext._narrative_checkpoint()` returns success when either semantic discriminator is absent. Current `NarrativeRestoreParticipant.prepare()` selects semantic validation only if `entry_id` is present; a nonempty `frozen_context` without it falls through the no-playhead success branch. Therefore another participant does not close this gap. Under strict v7, presence of either `entry_id` or `frozen_context` must require both before producer matching. Preserve `{}` and genuine legacy physical-owner restart transports, such as timeline/boundary dictionaries. A v6 compatibility decision can remain unchanged by gating this stricter check on `required`.

## Historical candidate constraints

Condition owner candidates represent earlier boundaries; they do not carry a full historical lifecycle. Do not apply the outer Run's later ENDING state as proof that an earlier candidate needed an ending seed. Validate present Ending caches as today. Require additional absent Ending/Hospital caches only when the candidate's retained source facts prove that presentation was admitted. The saved lifecycle constructed for historical Hospital checks has no active plan and does not fabricate one. Hospital miss annotations already require their actual saved request/closure source.

## Targeted tests

- Strict outer validation refuses deletion of a Dating cache in a prepared Condition candidate with a real active challenge, without changing any candidate, Run, Profile, or receipt bytes.
- The same candidate with no generated challenge remains legal; an existing pending pair context remains pending and validates after a later saved rollover.
- Removing only `entry_id` or only `frozen_context` from a full semantic checkpoint is refused under strict validation before installation; unrelated generic restart transport remains accepted.
- Semantic canonical presentation differing from its producer cache remains refused; empty new Run does not acquire speculative contexts.
- The successor version bump and old-v6 refusal tests belong to the coordinated cutover batch, not these probes in isolation. Current optional v6 passes do not close the strict successor bead.

## Exact implementation ownership proposal

Core producer/version owner:

- `scripts/narrative/FrozenRunContext.gd`: the two strictness predicates above, preserving historical candidate applicability.
- `scripts/domain/run/RunSnapshotSchema.gd`: v7 constant and strict producer-validation call.
- `scripts/infrastructure/save/SaveDocumentSchema.gd`: matching v7 document constant; preserve recovery journal handling and optimization semantics.
- `tests/unit/test_frozen_run_context.gd`: missing nested cache and partial semantic checkpoint probes, plus lawful empty/pre-admission counterexamples.
- `tests/unit/test_run_snapshot_schema.gd`: explicit current empty Contacts fixture, successor/future-version expectations, and correctly authored current ordered-ending cases. Existing legacy ending acceptance cases cannot merely gain a version tag.
- `tests/unit/test_save_document_schema.gd`: matching constants, current empty Contacts fixture, and v7 outer/inner agreement tests.
- `tests/unit/test_save_migrations.gd`: actual retained v6 document refusal with unchanged source and no patch; current fixtures use current schema and full empty Contacts. Existing SaveMigrations production code already rejects all older versions; no new migration implementation is needed.
- `tests/unit/test_checkpoint_journal.gd`: explicitly authored current empty Contacts fixture; mixed historical/invalid-cache recovery entries cannot become selected/seeded candidates. Preserve existing skip/report policy for invalid retained bundles.
- `tests/integration/test_save_manager_public_boundaries.gd`: real storage Load refusal keeps Run state, files, and Profile chronology unchanged; existing real New Run case proves empty admission remains legal.

Fixture consumers to update after producing an explicit v7 empty-narrative prepared-board fixture:

- New `tests/fixtures/saves/v7_desktop_prepared.json`; preserve historical `v6_desktop_prepared.json` for refusal evidence. The existing v6 prepared fixture has complete empty Contacts and no generated presentation, so new fixture authorship needs no invented historical contexts.
- `tests/integration/test_desktop_quick_commands.gd` (the readiness report's `tests/unit/` directory is incorrect).
- `tests/unit/test_save_manager_parse_cache.gd`.
- `tests/unit/test_save_manager_checkpoint_port.gd`, including its literal serialized document version and prepared fixture helper.
- `tests/support/BackupSnapshotFixture.gd`, which currently starts from `v5_desktop_prepared.json` and uses the current version constant. Give current fixtures full empty Contacts explicitly.

Optional additional adapter regression location: `tests/integration/test_dialogic_restore.gd`, if the semantic discriminator is tightened at NarrativeRestoreParticipant too. Strict RunSnapshot validation is already before installation; avoid a second implementation of the same policy unless the direct adapter contract also needs it.

Root/performance owner separately coordinates `.github/workflows/windows-tests.yml`, `tools/testing/Invoke-CheckpointPerformance.ps1`, `tools/testing/Invoke-OutgoingNormalizationPerformance.ps1`, fresh localized journey payload production, and paired exact-payload evidence. Historical committed timing payloads remain unchanged. Final public inventory regeneration/read-only proof must follow all source edits.

This is a confirmed path map from current fetched files and the saved repository tree, not a claim of an exhaustive full-checkout textual search. Before publishing the coordinated cutover, search the full cloud checkout for direct v6 fixture consumers and literal Run/document version expectations; the working checkout here is partial.

## Current producer fix boundary

Run 46 showed that production New Run uses sparse Dating state, while `reset_game()` test fixtures initialize explicit relationship fields. The current-capture helper now uses the existing friend/zero defaults only for absent keys. Present malformed fields remain refused. This does not add defaults to restored frozen presentation data, modify Run schema versions, or repair old historical contexts.
