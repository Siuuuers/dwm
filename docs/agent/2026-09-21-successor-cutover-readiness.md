# DWM RunSave v7 readiness review

Read-only review, 2026-09-21. Source checkpoint: PR #1 `00c7c262fc42a7f02756888e975ca3abee81e9bf`; local workflow has concurrent root edits and is not an authoritative diff baseline. No repository source, Beads, GitHub state, or schema was changed by this review. No local Godot or PowerShell was executed.

**Decision: do not cut over yet.** Obtain a coherent cloud pass for current canonical producers and real Dialogic adapters first. The current producer verification has concrete failures being repaired by the assigned agents. Current `FrozenRunContext.validate(snapshot, true)` is a useful staged strictness seam, not by itself sufficient evidence for the successor cutover.

## Minimum coordinated implementation

1. Advance `scripts/domain/run/RunSnapshotSchema.gd:SCHEMA_VERSION` and `scripts/infrastructure/save/SaveDocumentSchema.gd:DOCUMENT_VERSION` together, from 6 to 7. Invoke `FrozenRunContext.validate(candidate, true)` at the existing pre-install validation seam. Keep individual frozen-cache schemas at v1; their shape has not changed. Preserve Profile v9 and its chronology.
2. `scripts/infrastructure/save/SaveMigrations.gd` already refuses every version older than `DOCUMENT_VERSION` without conversion or Profile patches. Add an explicit v6 refusal/no-mutation proof and move future-version probes to 8 (or current+1). There is no need to add a migration, backfill historical facts, delete Profile history, or ask again about old Run compatibility. Updating its explanatory error text is optional; preserve existing typed refusal contracts unless separately justified.
3. Audit strict completeness at nested restore candidates, then update current-authored fixtures and expectations. Historical fixtures and old measured evidence remain historical. A field/version replacement is not a migration proof.
4. Update both performance harness paths for v7-compatible payloads and validators, in the same publishable batch. Run cloud persistence/producer/adapter, actual New Account/Load, complete journeys, both performance lanes, and final public inventories before claiming completion of `dwm-n3h.1`.

## Completeness predicates to preserve and verify

| Saved boundary | Required frozen facts | Lawful absence |
| --- | --- | --- |
| Empty new Run | Full valid Contacts owner shape, although no presentation cache is generated yet | Empty/missing route bag and all four absent caches are valid when no relevant producer facts exist. Do not require future contexts or fabricated receipts. |
| Native Contacts | Every generated message, activated/opened group variation, and Sylvia-care witness has its exact source-bound entry; ordinary selected form matches the actual reply receipt | A current, unshown ordinary awaiting card and Day 7 echo card may still be admitted at their existing lazy boundary. Current implementation has no independent proof of every erased lazy admission; test the source-backed predicates actually claimed. |
| Dating | Nonempty canonical active challenge requires its board-bound cache, matching pre-entry, and matching post-entry once post/completed; actual effect/result and pair count source bindings hold | No active challenge means no Dating cache is required. Pending pair count stays null only with its saved pending/later committed rollover source. Never mint the attempt ID in pre-DTL. |
| Schedule Hospital | Saved admitted/active required request and completed required stage retain the source-bound presentation | Pending first activation may lack its request. Sylvia eligibility may precede a real witness and must not mint a future witness ID. |
| Condition Hospital | Active/completed present-hospital stage, including completed historical plans, retains its prepared source-bound request; missed annotations bind actual closure output | Stages before physical presentation admission may lack a presentation. |
| Ordered Ending | ENDING/COMPLETED requires the terminal-admission seed bound to saved eligibility; every completed step has its retained projection; every retained/current semantic projection matches its real step | Admitted next step can lack its presentation until the existing capture-before-play callback. Future step receipts/projections must not be generated. TERMINAL_PENDING is not automatically equivalent to reached ENDING. |
| Semantic Dialogic checkpoint | Present canonical projection matches the saved producer cache byte-for-value; replay mode is refused in canonical Run checkpoint | Empty or genuine physical-owner restart transport remains valid. Test incomplete semantic discriminators separately, rather than making every generic checkpoint pretend to be a semantic one. |

Two targeted cutover probes remain necessary:

- `FrozenRunContext._condition_candidates()` applies `required` to Contacts, but calls Dating/Ending/Hospital with `false`. A prepared owner candidate retaining a nonempty `active_dating_challenge` can therefore lose its Dating cache while the outer strict validator still accepts that nested bag. Determine applicable facts from that candidate's actual boundary and require the cache there before it can replace live gameplay. Do not blindly apply the Run's later ENDING lifecycle to a historical pre-ending candidate. The frozen producer agent has been notified; this is a readiness finding, not a reproduced cloud failure.
- `_narrative_checkpoint()` returns early if either `entry_id` or `frozen_context` is absent. Prove the existing narrative/restore participant rejects a partially semantic checkpoint before mutation, or tighten that discriminator locally while preserving genuine generic restart transports.

Keep existing recovery policy: SaveDocument's journal container accepts primitive fallback records, and `CheckpointJournal.prepare_seed()` separately validates candidate snapshots and reports/skips invalid retained records. The v7 change must ensure every selected/seeded bundle passes strict v7 validation without accidentally replacing that recovery policy with a blanket all-history rejection. Add mixed-version and missing-cache fallback probes and assert no old bundle is installed or repaired.

## Confirmed fixture and harness blockers

- `tests/fixtures/snapshots/valid_day3.json` is a historical v3 source with `contacts: {}`. Current fixture helpers in `test_run_snapshot_schema.gd` and `test_save_document_schema.gd` relabel it to v6. Under strict v7, the full Contacts owner schema is invoked even when no cache exists; explicitly authored empty current cases must use `ContactInvitationState.make_defaults()`, not `{}`. Preserve deliberately malformed fixture shapes in negative cases.
- `tests/fixtures/saves/v6_desktop_prepared.json` already has the complete, empty Contacts shape and no admitted presentation source. A separately authored v7 prepared-board fixture can retain that intentional empty narrative state. Do not overwrite the historical v6 artifact. Confirmed direct consumers include `test_desktop_quick_commands.gd`, `test_save_manager_parse_cache.gd`, and `test_save_manager_checkpoint_port.gd`.
- Current helpers/expectations needing coordinated review include `test_checkpoint_journal.gd`, `test_save_migrations.gd`, the two schema suites, and `test_save_manager_checkpoint_port.gd` (including a literal serialized outer version 6). `tests/support/BackupSnapshotFixture.gd` uses the current schema constant but starts from a v5 prepared-board seed. Legacy ending fixtures in the RunSnapshot suite must become explicitly authored current ordered-ending cases with real seed/source facts, or remain refusal cases; do not append invented seed data to old endings. A full-cloud-checkout search is still required because this local checkout is partial.
- Both committed `evidence/beads_cloud_review/performance/fixed-zh-CN-autosave.json` and `fixed-zh-HK-autosave.json` are v6 documents, each with three snapshots, earned Contacts messages and active Dating, but none of the new frozen caches. **Regenerate through current localized production journeys.** Relabeling these documents or filling contexts from today's relationship state would invent history. Keep the old evidence as evidence of the old measurement.
- `Invoke-CheckpointPerformance.ps1` swaps the entire schema pinned at `681251dc832262c08826ce74d6a4480291eac4a8`, whose `DOCUMENT_VERSION` is 6. It cannot run against RunSnapshot v7. `Invoke-OutgoingNormalizationPerformance.ps1` separately loads the two committed old localized payloads plus its local seven-day payload, and swaps checkpoint port `4c4f9c...`. Regenerate fresh localized inputs in that job or transfer exact produced artifacts with explicit dependencies; independent GitHub jobs do not share a filesystem. Recheck the old port against current interfaces without weakening validation.

## Minimal performance ablation update

I fetched and diffed the exact pinned `681251d` SaveDocumentSchema against the reviewed candidate. The only functional difference is the redundant normalization branch:

```gdscript
# Baseline
if key == "current_snapshot":
# Candidate
if key == "current_snapshot" or (use_proven_journal and key == "recovery_journal"):
```

The minimum v7 harness can construct its baseline from the **current** schema bytes by reversing exactly this one condition in the disposable runner. Assert exactly one expected occurrence, hash the unmodified candidate and derived baseline, retain all current v7 checks in both, and restore candidate bytes in `finally`. No new production flag or old schema transplant is needed. Generate the fixed payload once with current producers; both variants must preserve its exact SHA256/canonical bytes and retained bundle count. Keep fresh journey timing separate from matched-payload timing. The old baseline/candidate hashes below describe this review only, not future v7 bytes:

- Pinned schema `681251d`: `230374b25001d1d7751cce1696845fd6416e55f0d457374c6386086c6ebfba92`.
- Reviewed current schema: `ead14e471ee834cf205f426df63053fa877fa99903360332d04c2a248bf1e2ea`.
- Reviewed FrozenRunContext: `18e67fb949eb9833bd2726aaae2a489d45bf93369d91b0b288f02627c5215232`.
- Reviewed RunSnapshotSchema: `f580e6902ebf7522125949b4c6cce3203ef104c7bde219edcd6292f2c877e7d8`.

## Required evidence and decisions

Cloud proof should cover real New Account with legally empty caches, every canonical producer admission/result boundary, close/reopen or fresh-process Load, deletion/forgery of each applicable cache, prepared Condition bags, semantic checkpoint disagreement, and old-v6 refusal. For refusals compare Run state, saved bytes, and Profile v9 chronology before/after; no participant installation, source repair, Profile reconciliation, or new completion may occur. Continue exact-once physical completion and no Continue/Done/special-mine behavior.

**No user architecture question is needed for this bounded v7 work.** Old Run refusal, Profile preservation, no historical reconstruction, and canonical capture-before-presentation are already decided. The separate `dwm-n3h.2` issue still needs an authored replay selector/successor and honest legacy presentation policy if future prose uses facts absent from Profile v9. Do not invent Profile v10, selector defaults, or authored narrative to unblock this cutover.
