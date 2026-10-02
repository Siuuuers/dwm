# Hospital source7 static acceptance review

**Static-only. No runtime or cloud acceptance is reported.**

Source: `dca8b35b40e4ba9d80f204c77064357d16f07319`. Tree: `55c167fa5d47e2ef5bd76c821a2ce5cb7f13963c`. Base: `28dbdd345abfce3915dcefdc514530c40a299f27`.

Generated: 2026-10-02T17:19:43.721049+00:00.

Static review of the seven source7 risk-guard changes plus the retained, conditional bounded Hospital Schedule-Done acceptance checklist. This review does not report a passing cloud run or expand acceptance scope.

No blocking defect identified in the reviewed source7 diff. Guard claims are source observations only; actual Focus5 and final Hospital evidence remain required.

No connector calls, engine/PowerShell execution, reruns or repository edits. Only these review artifacts were written.

## Correction to the prior static review

The source6 checklist did not identify the bootstrap fixture direct issue(causal_day_instance) call, which the issuer rejects as allocator-only. Source7 now creates a real committed continuation allocation, then prepares and commits each day advance through CausalDayAdvanceIdentityPort. This corrects that static-review omission; neither source6 nor source7 is accepted by this review.

The source6 review files are retained unchanged; all eleven original acceptance checks remain conditional.

## Exact source binding

Source SHA, tree and clean working tree checked. Source-file bytes were read from the exact Git commit, hashed with SHA256, and compared byte-for-byte to the working tree. All seven changed paths, blob IDs, byte lengths and SHA256s match the supplied source7 manifest.

Manifest SHA256: `244738c663a1230271f72c82434845679f1bdc71c38412f3cf746ac339f6702b`.

| Role | File | Bytes | SHA256 |
| --- | --- | ---: | --- |
| handoff | `docs/agent/2026-09-23-next-session-handoff.md` | 19966 | `e61915f28cad691d5fb3c583439d023d7f6ba72075b6228a4285cfc38bd7ff6e` |
| implementation_proposal | `evidence/phase_2r/paused_settings_load_2026_10_02/next-slice-source-review/hospital-next-slice-implementation-plan.md` | 11957 | `2ba6c13cea9d0bf1333c506fd4e462836c0870eaecaa7e54b2c56b767a51645f` |
| runner | `tools/testing/run_hospital_reading_journey.py` | 39812 | `c9ca043ac55b3377befa208e762e34a0751f59d985cefbabecd90b5038f17c14` |
| verifier | `tests/integration/verify_hospital_reading_journey.gd` | 44523 | `aa8bf58599b4df54a58e472a0ea15ede96b417afdf8f6d9f30a07d9ad5c7e599` |

All seven changed files also match their manifest Git blob identities:

| Changed file | Bytes | SHA256 |
| --- | ---: | --- |
| `scripts/application/run/SaveManagerCheckpointPort.gd` | 59395 | `ab8824ecb5617b48c5feb581133e4286facae70d42714add825fbea88e60272f` |
| `scripts/infrastructure/storage/JsonFileStorage.gd` | 47109 | `c54adb2ab4e0208a783bc98f7784aa4246eb294f5176aa8a3ff1e76f3affe2cc` |
| `tests/integration/test_application_bootstrap.gd` | 28774 | `a91d98e5ef3081e739dcc76890048450b5495dffdbdb1434f6a8e9763cc728e2` |
| `tests/unit/test_checkpoint_preparation_retry.gd` | 8643 | `bd62bf707b89e92415963c47d60b99615965c379ae285efd011e8200dd35ed8c` |
| `tests/unit/test_dialogic_presentation_owner_adapter.gd` | 27253 | `1e7c0473cb644644e74c1748737d1718fb4f03cab3cebca75d5a2ba31b0b2e74` |
| `tests/unit/test_json_file_storage.gd` | 23359 | `1e9d934f8bbd72f9c6bbbc786d878bf11dc1c7400bb64e7d697a68db6c555b57` |
| `tools/testing/Invoke-CloudTests.ps1` | 20582 | `368f8de6392aa5e174ff7aa9ce77f1a0b6f5496185d64931889390b2a0ed8704` |

The JSON additionally binds four supporting owner/allocator sources and the unchanged source6 review.

## Source7 risk guards and remaining evidence

### Missing lease requires validated reconciliation and a real leased reread

JsonFileStorage.read_text emits reason=lease_missing only after relative-path validation when the path has no lease and before physical reading. SaveManagerCheckpointPort._capture_storage_backup allows same-attempt continuation only for that reason, through the ordinary witness document validator and then a genuine read_text. The final backup text is validated and hashed after that reread. Reconciliation and reread errors return immediately; no retry loop or synthetic lease was added.

**Cloud evidence still required:** The cold-success case must run and pass: two physical final reads, actual document validation, exact backup descriptor, no mutating FileOps for the clean-final preparation, unchanged pre-commit journal/disk, and the expected journal sequence after explicit commit. The connected Hospital reader must load the manual slot in its single prepare/commit attempt, then complete Hospital and reach durable Day 4.

**Limit:** lease_missing means no lease now, not necessarily first-ever cold use. It can occur on a later call after invalidation. Normal reconciliation may perform established transaction recovery or cleanup writes; do not generalize the clean-final fixture to zero FileOps.

Cases to verify:

- `tests/unit/test_checkpoint_preparation_retry.gd::test_cold_existing_autosave_reconciles_and_rereads_before_first_preparation_succeeds`

### Changed bytes and failed reads still refuse the current preparation

Existing absent-lease disagreement, read failure, hash mismatch and UTF-8 failure branches retain reconcile_required without lease_missing. The checkpoint port may reconcile those artifacts but still returns the original refusal for that attempt. A failed post-reconciliation physical reread also returns immediately. Existing exact-text proof caching and invalidation remain in place; a cold validation miss reaches strict JSON and SaveDocumentSchema validation.

**Cloud evidence still required:** Run all six preparation-retry cases and the updated storage lease case. Preserve explicit-retry behavior, corrupt/ambiguous artifact refusal, exact journal/disk preservation in the negative fixtures, and a second-read failure that is not mislabeled lease_missing. Inspect actual case names and failures in settings/new_account XML, rather than relying on script registration.

**Limit:** No new targeted runtime test changes bytes specifically between cold reconciliation and the reread. The unchanged reread hash check statically refuses that case; this review makes no additional runtime race claim.

Cases to verify:

- `tests/unit/test_checkpoint_preparation_retry.gd::test_cold_existing_autosave_reconciles_and_rereads_before_first_preparation_succeeds`
- `tests/unit/test_checkpoint_preparation_retry.gd::test_cold_corrupt_or_ambiguous_autosave_preserves_all_artifacts_and_journal`
- `tests/unit/test_checkpoint_preparation_retry.gd::test_cold_leased_reread_failure_refuses_current_preparation_without_committing`
- `tests/unit/test_checkpoint_preparation_retry.gd::test_transient_prepare_read_failure_keeps_explicit_retry_and_exact_candidate_without_journal_or_disk_mutation`
- `tests/unit/test_checkpoint_preparation_retry.gd::test_corrupt_durable_final_is_refused_with_artifacts_and_journal_preserved`
- `tests/unit/test_checkpoint_preparation_retry.gd::test_changed_but_valid_bytes_refuse_current_attempt_then_require_explicit_new_preparation`
- `tests/unit/test_json_file_storage.gd::test_read_and_remove_require_a_fresh_unchanged_lease`

### Bootstrap eviction fixture now uses actual identity allocation

_allocate_fixture_run_identity issues only an ordinary transaction ID, prepares and commits a new_run continuation allocation, and resets RunLifecycle from the committed identity bundle. _publish_fixture_day_change derives a real day_resolution_stage child, passes the existing source identity and issuer receipt to CausalDayAdvanceIdentityPort.prepare_advance, commits its candidate, and publishes the returned target identity. No direct issue(causal_day_instance) remains in this fixture. The literal expected autoload list now includes the existing SystemTtsCoordinator.

**Cloud evidence still required:** The route-independent eviction test and literal autoload test must execute in desktop. Prove one retained unbound eviction adapter handles day advance before desktop mount, the same adapter is reused after mount, later eviction dispatches once, cache clears and no fatal latch occurs.

**Limit:** The bootstrap fixture deliberately installs a committed identity boundary and emits day_changed; it does not execute the Hospital day-resolution transaction. Actual Hospital completion, settlement and navigation remain the connected driver claim.

Cases to verify:

- `tests/integration/test_application_bootstrap.gd::test_day_resolution_installs_route_independent_eviction_before_desktop_mount`
- `tests/integration/test_application_bootstrap.gd::test_project_autoload_order_is_the_exact_final_literal_sequence`

### Adapter fixture teardown cancels pending starts and releases only its own layouts

The fixture records its baseline text-node IDs and each style root at style_changed, including deferred-ready replacements. Teardown frees its bridge, invokes the retained runtime adapter halt_with_error to cancel admitted pending starts, disables only fixture text nodes, and keeps the fixture runtime attached through native cleanup frames. It asserts no new native start occurred, releases exact owned layouts, diagnoses any surviving fixture caption, then restores the original runtime/layout and asserts the exact baseline text-node identity set. No production runtime adapter code changes in source7.

**Cloud evidence still required:** All owner-adapter cases must execute with after_each assertions active, especially begin/replay/conflict tests that can stop before layout readiness and the synchronous failure-observer retry case. Require no delayed start, no surviving fixture caption, exact baseline restoration, and clean process/resource lifetime logs. Preserve the existing completion provenance and stale/duplicate-refusal assertions.

**Limit:** This is fixture ownership and teardown coverage. It does not independently accept arbitrary production partial-reveal cancellation paths or whole-application lifetime behavior.

Cases to verify:

- `tests/unit/test_dialogic_presentation_owner_adapter.gd (all cases and per-case teardown)`
- `tests/unit/test_dialogic_presentation_owner_adapter.gd::test_failure_observer_can_immediately_retry_without_reusing_the_retired_layout`

## Focus5 predictions, not results

Parent reports [Focus5 run 37039358038](https://github.com/Siuuuers/dwm/actions/runs/37039358038) running at workflow head `e0317e13c226f3c7142ac31d1ae28050561c65b0`. This run identity was supplied by the parent; this review did not query the run or inspect its artifacts.

| Suite | Script registrations | Static test functions |
| --- | ---: | ---: |
| reading_delivery | 35 | 480 |
| persistence | 22 | 230 |
| desktop | 22 | 334 |
| settings | 31 | 357 |
| new_account | 15 | 179 |
| public_surfaces | 1 | 11 |

**Predicted: 1,591 test executions across six XML reports.** These are static function counts, not passed tests. Public-surface outputs and rendered Hospital evidence remain separate required outputs.

Replace predictions with actual six-XML totals, exact executed scripts/cases and failures/errors/skips. Confirm rendered evidence and checkout identity. Focus5 alone is not the canonical broad gate; preserve the required final gate and prior accepted reading/F5/F9 regressions before final bounded acceptance.

## Retained conditional Hospital acceptance checklist

1. **Source and execution identity.** result.json.checkout_sha equals the tested checkout; source hashes match the runner, helper and verifier. Three distinct positive process IDs for write, read and forge agree between stdout and reports; one pass marker per process; zero exit codes and no timeout, parser, engine, resource-leak or orphan-name failures. Bind the actual workflow checkout separately from its dispatch/workflow head. For source7, the tested checkout must be dca8b35b40e4ba9d80f204c77064357d16f07319 (tree 55c167fa5d47e2ef5bd76c821a2ce5cb7f13963c); Focus5 workflow head e0317e13c226f3c7142ac31d1ae28050561c65b0 is separate execution metadata.

   Evidence: `result.json`, `write.json`, `read.json`, `forge.json`, `per-process stdout/stderr/Godot logs`.

2. **Evidence integrity.** write_seal_verified is true. Independently recompute sealed writer hashes and confirm the later transactions.jsonl preserves its writer prefix. Exact stage order, standalone stage JSON, reports and process IDs agree. Keep failed-attempt diagnostics separate from acceptance.

   Evidence: `write-seal.json`, `sealed-write/`, `transactions.jsonl`, `standalone stage JSON`.

3. **Lawful ingress and fresh History.** Day-1 prior Solo History was observed and then retired after actual completion; Day 2 proceeds through empty Schedule Done. Day-3 Sylvia source is accepted through Contacts and placed in Schedule before explicit condition injection. Hospital starts with only A and a distinct session. The actual canonical deferred-pair preview reports required=false.

   Evidence: `write-prior_solo.json`, `write-prior_retired.json`, `write-hospital_a.json`, `saved-hospital-slot.json`.

4. **Independent saved authority.** Parse the original raw saved slot. Independently derive the Schedule-Done request from the saved plan, accepted Contacts receipts and route context, then recompute command hash and physical token. Confirm active Hospital stage, Day 3, Sylvia eligibility, null pre-completion witness, strict reading schema 3 with Hospital family, the exact immutable frame, A/B publication rows and B frontier. The catalogue fingerprint matches the retained injected Hospital catalogue.

   Evidence: `saved-hospital-slot.json`, `write-catalogues.json`, `write-saved.json`.

5. **Partial B preservation.** hospital-input.json proves admitted Enter/Escape down/up packets with neutral frames and contact retirement. B is literally partial. Pause, Return Cancel, Continue and History preserve semantic source; Cancel retains the exact suspension handle. History contains exactly A/B, owns focus while open and returns rail focus when closed. Querying Save availability is pure.

   Evidence: `hospital-input.json`, `write-paused_b.json`, `write-pause_cancelled.json`, `write-availability.json`, `write-pause_continued.json`, `write-hospital-partial-history-entered.json`, `write-hospital-partial-history-closed.json`.

6. **Current-line-only Save.** Explicit Backup entry completes B once. Manual Save preserves the source, line identity, History, gameplay, Profile observation and route. The writer contains no Hospital or physical completion. Raw slot bytes bind the observed checkpoint and command, and remain byte-identical across write-output, reader input/output and forge input/output.

   Evidence: `write-pause_reentered.json`, `write-backup_entered.json`, `write-saved.json`, `saved-hospital-slot.json`, `primary-file snapshots`.

7. **Fresh Load.** The fresh reader loaded checkpoint, command and ordered History equal the saved source. B is complete and recorded restore text starts never include A. Enabled read-aloud remains a live control, but restored speech admissions, Hospital completions and physical completions are zero. Loaded Profile equals the reader-input raw Profile. Restored History inspection preserves the exact loaded source.

   Evidence: `read-loaded.json`, `read-hospital-restored-history-entered.json`, `read-hospital-restored-history-closed.json`, `read-input-profile.json`.

8. **Actual completion and durable exit.** hospital-completion-input.json proves fresh admitted Enter on stable B. The passive owner trace aligns the native end, Hospital bridge signal, physical receipt and coordinator settlement. Exactly one Hospital and one physical completion bind the saved command and token. The raw settled Autosave contains the completed Hospital stage and exact physical receipt, Day 4, Sylvia date RESOLVED_MISSED, one newly earned Sylvia witness and retired Hospital History. The driver additionally checks health 6, pressure 3 and pending_hospital=false.

   Evidence: `hospital-completion-input.json`, `read-owner-events.jsonl`, `read-settled.json`, `settled-hospital-autosave.json`.

9. **Fresh next scene.** Day-4 Priscilla Solo is reached through invitation, Contacts and Schedule owners. Its session differs from both the prior Solo and Hospital. History contains only fixture.next.solo.pre.a. History inspection is read-only and restores rail focus.

   Evidence: `read-next_solo.json`, `read-next-solo-history-entered.json`, `read-next-solo-history-closed.json`.

10. **Forgery refusal.** The genuine prepare control succeeds. Independently reconstruct both retained forged candidates from the original snapshot: coherent shared-frame Sylvia alteration, and earlier caption reassigned to a foreign day entry. The independent validator and narrative prepare both refuse before installation, with unchanged idle observations. All four primary files are byte-identical across forge input/output.

   Evidence: `forge.json`, `forge-frame-candidate.json`, `forge-caption-candidate.json`, `forge-forge-frame.json`, `forge-forge-caption.json`, `forge-input-primary-files.json`, `forge-output-primary-files.json`.

11. **Visual evidence.** Inspect the original retained five PNGs. Structural existence and hash validation alone do not establish readable pixels or final visual polish.

   Evidence: `hospital-partial-history.png`, `hospital-saved.png`, `hospital-restored-history.png`, `hospital-restored.png`, `next-solo-history.png`.

## Registration and scope limits

Source7 adds the six-case preparation-retry script to `settings`. Bootstrap coverage is in `desktop`, owner-adapter coverage in `reading_delivery`, and raw storage coverage in `new_account`; the reading suite alone is insufficient.

The connected route lawfully retires the prior Solo before Hospital; it does not itself prove replacement of a still-retained prior ledger.

The existing native Hospital session fixture must also execute retained-ledger replacement, stale/foreign/abandoned completion refusal, silent adoption and same-process cached-port re-adoption.

- The connected proof uses noncanonical Day-3 Sylvia-present Schedule-Done A/B prose. Condition values are intentionally injected after real Contacts/Schedule receipt acquisition.
- No acceptance of production Hospital prose/selectors, no-Sylvia timing or Continue conformance, authored holds, condition-Hospital reading, immediate pair reading, ordered-ending continuity, all Hospital days, or Hospital Next/Skip.
- Both Hospital captions share one immutable frame. The forgery proof is coherent shared-frame rejection plus foreign-row membership, not an earlier-only-frame mutation with an untouched current frame.
- Connected Load is fresh-process. Same-process cached-port re-adoption depends on its separately executed native integration test.
- Slot bytes are invariant across all subsequent process boundaries. All primary files are invariant only during forge. The reader later legitimately progresses gameplay and adds next-Solo witnesses; do not claim the whole reader is Profile/Autosave byte-inert or restore performs zero FileOps.
- Input uses injected InputEventKey through normal Godot routing. Linux software rendering and this input path do not establish native Windows hardware, accessibility, glyph-pixel, OS-crash or whole-game acceptance.
- Production catalogue registration remains disabled. The PR stays draft and unmerged; Beads statuses/dependencies and the live-Dolt limitation remain unchanged.
- The source7 storage success fixture uses FakeFileOps and a clean final; actual fresh manual-slot restart remains the rendered Hospital evidence. Do not claim universal disk purity, zero restore FileOps, or a new OS-crash guarantee.
- All Focus5 counts in this document are static predictions. No cloud result, XML, screenshot or run conclusion was audited in this review.
