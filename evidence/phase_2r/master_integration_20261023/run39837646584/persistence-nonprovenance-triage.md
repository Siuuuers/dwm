# Persistence non-provenance triage

Read-only source at d1d8313; actual cloud run39837646584/job120033199824. Evidence: verified original persistence artifact, `phase2r_logs/cloud-persistence.log` and `ci/persistence.xml`. No runtime edits or local engine execution.

44 failed test cases total: one known provenance failure, 41 frozen-context/reading cases, two ordinary-correspondence cases. These are failed cases, not XML failures attribute totals (which count multiple assertions).

## Empty snapshot diagnosis

All nine `test_reading_next_checkpoint.gd` cases fail during setup. Engine log4991–4999 records `ReadingNextFixture.snapshot:25` invalid `.value` access, followed by `_fixture:60` and `invalid_snapshot_shape: unexpected top-level keys: []`. The fixture directly accesses `FROZEN.build(ENTRY, fields).value`. Its legacy `dating.solo.priscilla.day1.pre_challenge` entry is not in the selected scene registration's context registry. The build refuses; the erroneous `.value` access aborts the helper with empty Dictionary; RunSnapshotSchema correctly refuses that empty Dictionary. None of these nine failures reaches the intended persistence operation. Four Next cases in `test_reading_restore_admission` show the identical fixture backtrace (log4566–4636).

`FrozenPresentationContext._load_registry` selects `DialogicEntryManifest.scene_registration()` first, then loads that scene's context registry. Historical files still contain old schemas but are only fallback when registration is absent. Thus broad historical fixtures cannot assume the production default selects their old registry. Other 28 frozen/reading failures cover Solo, group, hospital and ending entries under the same selection conflict; not every downstream assertion has independently run.

## Minimal test-only repair

Reuse existing `tests/support/RetainedFrozenContextFixture.gd` in per-test setup/teardown for the three affected frozen/reading suites. It validates explicit entry IDs against retained context/entry files, installs only selected frozen schemas/IDs, and restores exact prior cache references. Enumerate actual suite entry dependencies (including history and future frames), not a blanket production fallback. Keep all schema/version/causal checks unchanged. Add setup result checks before extracting values; this improves diagnosis, it cannot replace running the tests. Existing fixture does NOT change live scene registration or default lookup. Some NarrativeRestoreParticipant fingerprint/entry lookup dependencies may need additional bounded historical test injection after those callers are traced; do not claim all41 fixed by the first cache injection without cloud qualification.

## Separate ordinary-correspondence mismatch

Two failures have `OrdinaryReplyEchoState._load_registry:329` `.reply_ids` access (engine log1746ff and6216ff). It calls `MANIFEST.load_ids_default()` and `validate_ids_document()` successfully for selected scene IDs, then assumes the legacy reply_ids/reply_lines/atoms family. `test_seven_day_calendar` directly requests legacy ordinary messages. `test_save_manager_public_boundaries` calls `GameState.ensure_contact_presentation_contexts` → ContactsFrozenContext.prepare_projection → same loader. A frozen-context cache fixture alone cannot fix these. Isolate the legacy registry/entry dependencies for these explicitly legacy tests; inspect whether any actual production scene path reaches this legacy API before deciding a runtime family-specific refusal is needed. Do not add legacy reply keys to scene manifests or accept unknown snapshot fields.

## Qualification

After independent registry/caller audit and test-only edits, regenerate canonical inventories once and run canonical cloud persistence. Confirm the previously failing cases reach their behavioral assertions, not skipped/early returned setup, and retain unknown-entry/schema refusal tests. Existing historical source-provenance repair is separate. Production Notes hold remains unchanged.

## Exact failed cases from XML

### tests/unit/test_frozen_run_context.gd (10)

- `test_pair_pending_count_snapshot_stays_pending_after_actual_rollover`
- `test_schedule_hospital_uses_saved_plan_and_allows_lawful_pending_first_capture`
- `test_full_saved_run_boundary_rejects_hospital_checkpoint_frame_forgery`
- `test_full_saved_run_boundary_preserves_completed_hospital_anchor_until_destination`
- `test_condition_hospital_binds_historical_prepared_request_after_identity_remap`
- `test_strict_prepared_pair_keeps_pending_projection_after_a_real_saved_rollover`
- `test_ending_reading_restore_binds_old_and_current_frames_to_saved_plan`
- `test_ending_reading_between_steps_accepts_future_cache_without_fabricating_frame`
- `test_ending_reading_refuses_reordered_history_foreign_session_and_missing_prerequisite`
- `test_ending_reading_completed_tail_remains_an_inert_history_anchor`

### tests/unit/test_seven_day_calendar.gd (1)

- `test_all_six_ordinary_messages_keep_three_choices_and_day7_has_none`

### tests/unit/test_reading_restore_admission.gd (22)

- `test_all_history_frames_bind_independently_to_saved_canonical_facts`
- `test_session_and_each_phase_identity_belong_to_the_saved_physical_command`
- `test_board_boundary_retains_only_reached_frames_without_starting_future_prose`
- `test_causal_entry_order_and_unknown_history_owners_refuse`
- `test_reading_discriminator_cannot_downgrade_to_legacy_empty_playhead`
- `test_invalid_version_or_containers_stay_fail_closed_even_with_stale_content`
- `test_capture_boundary_refuses_stripped_or_expanded_semantic_envelopes`
- `test_prepare_checks_complete_catalogue_before_staging_and_finalization_is_one_shot`
- `test_catalogue_refusal_and_rollback_cannot_leave_a_future_resume`
- `test_active_playback_refusal_does_not_install_a_staged_helper`
- `test_next_source_and_destination_validate_and_restore_their_exact_own_frontiers`
- `test_next_checkpoint_rejects_changed_operation_and_sequence_without_staging`
- `test_next_plan_refuses_duplicate_source_and_foreign_entry_suffix`
- `test_next_completion_record_survives_exact_physical_board_boundary`
- `test_hospital_v3_prepares_exact_saved_frames_without_starting_or_changing_sources`
- `test_hospital_single_frame_forgery_cannot_rewrite_current_and_history_authority_together`
- `test_hospital_membership_checks_earlier_and_current_captions_and_exact_tail`
- `test_hospital_versions_family_and_operation_are_closed_without_solo_downgrade`
- `test_hospital_line_requires_active_retained_schedule_and_real_sylvia_sources`
- `test_hospital_saved_authority_refuses_other_cause_but_admits_coherent_ordinary_recovery`
- `test_hospital_internal_completed_anchor_survives_lawful_following_day_capture`
- `test_hospital_completed_anchor_requires_exact_committed_physical_receipt`

### tests/unit/test_reading_next_checkpoint.gd (9)

- `test_bootstrap_real_desktop_stringname_is_admitted_by_next_autosave_provider`
- `test_bootstrap_provider_preserves_bad_host_values_for_strict_next_refusal`
- `test_next_persists_source_then_destination_through_real_autosave_schema`
- `test_next_refuses_missing_source_and_changed_command_before_storage`
- `test_next_destination_rejects_unrelated_autosave_or_restored_journal`
- `test_next_postwrite_failure_restores_both_disk_and_journal_and_allows_exact_retry`
- `test_next_failed_first_write_restores_absence_and_grants_no_destination_credit`
- `test_next_indeterminate_promotion_latches_gate_and_cold_storage_recovers_exact_destination`
- `test_next_reentrant_checkpoint_writes_refuse_until_outer_commit_finishes`

### tests/integration/test_run_restore_isolation.gd (1)

- `test_frozen_owner_reproduces_all_six_historical_alias_directions`

### tests/integration/test_save_manager_public_boundaries.gd (1)

- `test_real_new_run_sparse_dating_supports_current_contacts_and_first_earned_offer`
