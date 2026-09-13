# Minesweeper click latency evidence

Headless benchmark logs from tests/manual/benchmark_minesweeper_click_latency.gd, run through
tools/testing/Invoke-IsolatedGodot.ps1 (fresh account, 22x22 expert App board, 18x18 dating board).
Each runner record is appended to runs.jsonl; the log named in its log_path is archived here under a
step name and the commit it measured.

## settlement3 (branch perf/terminal-settlement-3, dwm-634.3)

- settlement3-baseline-5afc63bb0.log: baseline at 5afc63bb0 with DWM_CHECKPOINT_PROFILE=1.
  App win 845 ms and loss 827 ms to settled, App first reveal 241 ms, new-board first reveal 539 ms,
  dating first reveal 316 ms, dating win 467 ms, routine App reveal 23-25 ms early and 37-42 ms later.
- settlement3-markers-profile-5afc63bb0.log: same tree plus the permanent env-gated markers
  (DWM_CONSEQUENCE_PROFILE=1 and DWM_CHECKPOINT_PROFILE=1). App win 822 ms to settled; inside
  DesktopConsequenceCoordinator.accept_prepared_action (557 ms): five per-stage checkpoints
  (ordinals 1, 2, 8, 9, 10) cost about 30 ms prepare plus 13 ms live restore each (215 ms total),
  progress_causal_sequence and progress_action_source 47-48 ms each, two DesktopPublicationLedger
  writes 33 and 51 ms, completion autosave 171 ms (prepare 47, commit 124: schema 35, stringify 23,
  write_atomic 52). Before accept, MinesweeperRoundCoordinator spends 30 ms preparing and 90 ms
  committing the preterminal source save and 24 ms assembling the receipt.
- settlement3-markers-gut-5afc63bb0.log: the five suites that cover the three marker files
  (145 passing; the 3 failing rows are the not-yet-implemented CheckpointJournal bundle-text tests
  written RED for the next step, not marker regressions).

The markers cost one boolean per phase while the variables are unset.
### Step: splice remembered bundle texts into the autosave document (commit after 989216180)

- settlement3-splice-gut-989216180.log: tests/unit/test_checkpoint_journal.gd and
  tests/unit/test_save_manager_checkpoint_port.gd, 46 passing / 0 failing, including the three RED
  journal rows and four byte-equality rows (three commits, sentinel-poisoned snapshots, a journal
  seeded from disk, and a mixed native/checked emitter document with the splice active).
- settlement3-splice-profile-run1-989216180.log and -run2-: two profiled runs of the same tree.
  Per App save the current-bundle stringify is 8-14 ms where the whole-document stringify was
  21-28 ms, and the splice itself is under 0.1 ms; schema validation (34-49 ms) and write_atomic
  (39-80 ms) are unchanged. Three saves in the run-start sequence before the dating challenge fall
  back to the whole-document writer (splice_us 29-37 ms) because the reset path installs the
  initial bundle without passing through the port, so its text is never remembered until it leaves
  retention; no click sits on that path. End-to-end settled times (win 975 / 874 ms, loss 912 / 946
  ms against 822 / 776 ms in the marker run) are within this machine's run-to-run variance: the
  untouched request_fingerprint phase moved from 11.2 to 14-15 ms between the same runs.

### Step 1: pass the one proven recovery payload hash along accept (commit after 99305fd36)

- settlement3-step1-red-99305fd36.log: tests/unit/test_desktop_consequence_state.gd RED, 39 passing /
  3 failing on the three new rows (validate and prepare_restore refuse a second argument).
- settlement3-step1-green-99305fd36.log: nine suites GREEN, 249 passing / 0 failing
  (consequence state, coordinator, checkpoint port, causal sequence port, round coordinator,
  shop purchase participant, checkpoint preparation retry, checkpoint validation reuse, journal).
  This run also proves the splice guard correction folded into the same commit: a non-object
  outgoing value again falls through to strict text validation with outgoing_validation_failed
  (test_checkpoint_validation_reuse had one failing row against 99305fd36).
- settlement3-step1-profile-win-99305fd36.log and -loss-: profiled runs. Inside
  accept_prepared_action: checkpoint1_prepare 30.6 -> 18.7-20.9 ms, live_restore1 14.2 -> 1.9-2.2,
  checkpoint2_prepare 29.2 -> 18.8-20.3, admission_commit 19.2 -> 6.4-7.1; App win settled
  771-790 ms, loss 746-825 ms. The three forward ordinals (8, 9, 10: prepare 30-36 ms,
  live_restore 13-16 ms) did not move because token-less adopts between them (outbox
  publications, the detached notification restore) reset the retained proof; that is the next step.

### Step 1b: keep the proven hash across token-less adopts, and Step 2: identity-preserving normalization (commits after d590f5513)

- settlement3-step1b-step2-red-d590f5513.log: consequence state and checkpoint port suites, 76 passing /
  2 failing: the three keep rows of test_token_less_adopt_keeps_the_token... and the three identity
  rows of test_normalized_preimage_is_deep_equal_and_never_aliases... fail for their own reasons.
- settlement3-step1b-step2-green-d590f5513.log: ten suites GREEN, 257 passing / 0 failing (the nine of
  Step 1 plus test_desktop_consequence_restore_participant).
- settlement3-step1b-step2-profile-win-d590f5513.log and -loss-: inside accept_prepared_action the
  forward ordinals now carry the proof: ordinal_8/9/10 prepare 30-36 -> 20-22 ms, their live
  restores 13-16 -> 0.7-1.2 ms, progress_causal_sequence and progress_action_source 48-54 -> 26-28 ms;
  prepare_and_forward_inclusive 437-493 ms against 546 in the marker run. App win settled 716-793 ms,
  loss 742-758 ms; dating settled 433-517 ms; first reveals unchanged within noise. The
  identity-preserving normalizer (Step 2) is not separable in these numbers from run noise; its
  expected 4 ms per checkpoint sits inside the 20 ms prepare figures above.

### Steps A4 and A6: journal prepare_record proof pass-along and ok-only storage backup proof (commit after 9ce127e52)

- settlement3-a4a6-red-9ce127e52.log: journal and validation-reuse suites RED on the two new
  prepare_record rows (arity 2 vs 3) and the missing _cached_document_text_proof.
- settlement3-a4a6-green-9ce127e52.log: journal, validation reuse, checkpoint port, preparation
  retry and consequence coordinator suites GREEN, 100 passing / 0 failing.
- settlement3-a4a6-integration-9ce127e52.log: test_desktop_board_persistence and
  test_desktop_quick_commands, 14 passing / 2 failing; both failures are Quick-command UI rows
  (F9 confirmation, F5 status, focus custody) that die on a stale fake ContactsPort calling
  get_projection with arguments in ComputerDesktop._refresh_contact_notice, code this branch never
  touches (git diff 072ec79f4..HEAD over scripts/ui and those suites is empty): pre-existing.
- settlement3-a4a6-backup-script-9ce127e52.log: tests/backup_operations/test_backup_operations.gd
  (a SceneTree script, not a GUT suite) BACKUP_OPERATIONS_PASS; its NUL parse lines are the
  pre-existing ones.
- settlement3-a4a6-profile-win-9ce127e52.log and -loss-: source_prepare 43-49 -> 24-44 ms,
  completion_save prepare 52-57 -> 44-49 ms, accept_prepared_action 410-433 ms; App win settled
  666-716 ms, loss 677-763 ms; dating 403-464 ms.

### Steps A1-A3: drop the pre-normalization deep copies, compose the current bundle once, identity-preserving engine-text normalization (commit after c13087180)

- settlement3-a1a3-red-c13087180.log: test_run_snapshot_schema and test_save_document_schema RED,
  33 passing / 4 failing on rows 1, 3, 4 and 6 (source-string pins for the removed copies, composed
  bundle member order, identity of StringName-free subtrees); rows 2, 5 and 7 are green guards
  (detachment in both directions, refusal order under seven simultaneous defects, build detachment).
- settlement3-a1a3-green-c13087180.log: 26 unit suites that reference either schema, 472 passing /
  1 failing; the one failing row is A7's mutation test written RED ahead of its step (the storage
  lease reporting a value the bytes never had), not a regression.
- settlement3-a1a3-profile-win-c13087180.log and -loss-: outgoing_schema per big save 26-48 ms
  against 30-58 ms in the previous step; source_prepare, completion_save prepare and the settled
  times (App win 722 ms, loss 726-761 ms) are within run-to-run noise. The removed copies are
  real (one 450 KB and one 150 KB duplicate per validation, five validations per save) but the
  write_atomic phase (34-76 ms) dominates each save, so no latency claim is attached to this step.

### Step A7: validate the outgoing document against the journal's own retained bundles (commit after 06b6920d8)

- settlement3-a7-red-c13087180.log: test_checkpoint_validation_reuse RED, 15 passing / 1 failing:
  after a caller mutates recovery_journal[0].snapshot.gameplay.money between prepare and commit,
  the bytes on disk still come from the remembered texts (401) while the storage lease seeded from
  the in-memory document reports 999999. This gap was opened by the splice commit 99305fd36 and is
  closed here.
- settlement3-a7-green-06b6920d8.log: the same 26 unit suites, 473 passing / 0 failing.
- settlement3-a7-profile-win-06b6920d8.log and -loss-: outgoing_schema per big save 26-38 ms
  (one 57 ms fallback save) against 30-48 ms before; App win settled 688-703 ms, loss 729-746 ms;
  accept_prepared_action 405-426 ms. Session trend for the App win settlement: 822 (baseline) ->
  ~700 ms.

### Review fixes: remember gate, rollback proof clear, marker hoist; and build-side composition (commits after 42ce7bcb9)

- settlement3-remember-gate-red-42ce7bcb9.log: validation-reuse and consequence-state suites RED. An
  in-place edit of the document's current bundle between prepare and commit was written and accepted
  (as the law allows) but its text was remembered under the journal's unedited bundle id, so the next
  spliced save carried the edit for an entry the journal holds unedited (journal entry 987654 vs
  501, lease not equal to a strict re-parse). Rollback carried the proven payload proof across an
  unvalidated backup.
- settlement3-build-walk-red-42ce7bcb9.log: test_save_document_schema RED on the source-string pin
  for build's whole-document re-walk of an already normalized bundle candidate.
- settlement3-gate-build-green-42ce7bcb9.log: 28 unit suites GREEN, 497 passing / 0 failing.
- settlement3-gate-profile-win-42ce7bcb9.log: App win settled 685 ms, loss 731 ms, dating win 453 ms,
  accept_prepared_action 393-429 ms. settlement3-gate-profile-loss-42ce7bcb9.log and
  settlement3-gate-unprofiled-win-42ce7bcb9.log hit a slow period on the machine (the same
  source_prepare phase reads 22 ms then 89 ms within one run; the unprofiled run is slower than
  the profiled ones), so they are archived as noise, not as measurements of these commits.

Session trend (fresh account, headless, same machine): App win settlement 845/822 ms at the baseline
to 685-703 ms, App loss 827/776 to 729-746 ms, dating win 467-481 to 453 ms, accept_prepared_action
546 to about 400-430 ms, routine reveal unchanged at 17-23 ms.
