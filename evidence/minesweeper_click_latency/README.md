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

### Post-merge re-seal and re-verification (merge commit 88b92f77f, master f8c16c1ee)

- settlement3-reseal-desktop-88b92f77f.log and settlement3-reseal-minesweeper-88b92f77f.log: the two
  handoff contracts regenerated through the isolated runner.
- settlement3-post-merge-green-88b92f77f.log: 31 unit suites including test_desktop_contract_evidence
  and test_minesweeper_contract_evidence, 560 passing / 0 failing.
- settlement3-post-merge-bench-88b92f77f.log: App win settled 728 ms, loss 620 ms, dating win 431 ms
  on the merged tree.

## settlement4 (branch perf/terminal-settlement-4 from master 22b6a4fb2, dwm-634.3)

Session 4 starts from master 22b6a4fb2 (17 commits past a2f394f89, none in the save, checkpoint
or consequence layer). The machine is shared with another agent's Godot runs this session: routine
App reveals read 30-40 ms in every run below against 17-23 ms in the settlement3 runs, so end-to-end
settled times are compared phase by phase, not run to run.

### Step 1: DesktopPublicationLedger normalizes the new record by a walk, not by emit + re-parse (commit after 22b6a4fb2)

The archived settlement3 profile logs already carried the ledger's per-phase split (scope
desktop_publication_ledger). On the terminal frame the third write (board_fate, entry 80-124 KB)
cost 100.6 ms (post-merge bench) to 225.7 ms (gate-profile-win), of which write_atomic was 30-39 ms;
the rest was CPU: entry_normalize (canonical emit plus StrictJson re-parse purely for StringName to
String) 36.5-100.1 ms, confirmation (two more canonical emits of the entry) 11.8-30.4 ms,
shape_check (a third canonical emit of the publication for its digest) 6.0-18.2 ms.

Under the 2026-09-13 ruling (remove redundant canonical passes and strict parses only; entry bytes
identical) the commit replaces the emit + re-parse with an identity-preserving StringName walk (an
exact mirror of SaveDocumentSchema._normalize_engine_text), passes the publication digest already
emitted and compared in _check_request into the record shape check, and confirms the durable record
with CanonicalJsonWriter._deep_same (type-aware, StringName folded on the entry side, 1 and 1.0
distinct) instead of two canonical emits. The request digest, the whole-document emit, write_atomic,
the exact byte reread and the disk-validation path (which still canonicalizes every stored
publication) are unchanged. The unreachable serialization refusal in _commit_new_entry is gone: the
entry is canonicalizable by construction once _check_request has digested the publication, because
every kind binds semantic_receipt to a member of it. The profile record drops entry_bytes (no text
exists to measure).

- settlement4-step1-red-22b6a4fb2.log: tests/unit/test_desktop_publication_ledger.gd, 18 tests,
  16 passing / 2 failing: the source pins (walk present, re-parse and double emit absent) and the
  _normalize_engine_text identity/number-type rows fail against the untouched ledger; the
  engine-typed board_fate byte-equality row (StringName keys and values, a typed array, unsorted
  nested keys, 1.0 and 2.5, non-ASCII text; golden bytes computed the old way inside the test, then
  a cold restart and an identical replay) is green before and after.
- settlement4-step1-green-22b6a4fb2.log and settlement4-step1-attrib-baseline-22b6a4fb2.log: the
  18 suites that reference the ledger (10 unit including the frozen schedule gate, 8 integration),
  run once with the patched ledger (411 tests, 339 passing / 72 failing) and once with the ledger
  reverted to HEAD in the same tree (337 / 74). The failing sets are identical except the two RED
  rows: every one of the 72 is pre-existing on master 22b6a4fb2 (the frozen nine-role handoff gate
  against a live ten-role order, missing schedule_view members, expected-4-saw-5 requests).
- settlement4-step1-profile-win-22b6a4fb2.log and -loss-: profiled fresh-account runs. board_fate
  ledger write 42.3 / 59.5 ms (entry_normalize 2.5 / 1.9, shape_check 0.6 / 0.5, confirmation
  2.8 / 4.3, request_digest 6.4 / 5.1, full_emit 7.6 / 7.9, write_atomic 18.5 / 35.2) against
  100.6-225.7 ms before; the four small publication writes are unchanged at 22-40 ms, all but 1-3 ms
  of it write_atomic. App win settled 733 ms, loss 665-714 ms, dating 445-451 ms; on this slower
  machine day those sit inside the noise band and no end-to-end claim is attached beyond the
  phase figures above.

### Step 2: prepare-side profile record, and no redundant journal copy in SaveDocumentSchema.build (commit after 7d38c4fbf)

SaveManagerCheckpointPort.prepare had no timer at all; commit() was the only decomposed side. The
commit adds a permanent env-gated record (same DWM_CHECKPOINT_PROFILE=1 gate, helpers and output
line as commit's save_checkpoint record) scoped save_checkpoint_prepare with the phases
view_capture_us (entry through the schedule-view capture and live composition),
run_snapshot_build_us, journal_prepare_us, document_build_us and backup_us (the last two on
autosave prepares only); one boolean per phase while unset. It also drops the journal.duplicate(true)
in SaveDocumentSchema.build: RunSnapshotSchema._normalize_integral_floats allocates a fresh
container at every node, so the copy rebuilt the whole retained history twice per save, and every
production caller passes a fresh copy nothing else retains. SaveManagerCheckpointPort.gd is bound by
the desktop handoff contract, so evidence/phase_2r/handoff/desktop_contract.json is regenerated in
this commit (the minesweeper contract came back byte-identical).

- settlement4-step2-red-7d38c4fbf.log: test_save_document_schema and test_save_manager_checkpoint_port,
  51 tests, 49 passing / 2 failing on the source pins (no journal.duplicate(true); the
  save_checkpoint_prepare scope and the five phase strings). The detachment guard (both mutation
  directions, identity at depth) and the profiled-prepare guard are green before and after.
- settlement4-step2-green-7d38c4fbf.log: the 26 unit suites that reference either file, 485 passing / 0.
- settlement4-step2-reseal-desktop-7d38c4fbf.log and -minesweeper-: the handoff contracts regenerated.
- settlement4-step2-profile-win-7d38c4fbf.log and -loss-: the first prepare split. Per big autosave
  prepare (35-76 ms): document_build 25-62 ms, run_snapshot_build 3-10, backup 2-6, journal_prepare
  1-3, view_capture under 1.5. Non-autosave day_resolution_stage prepares are 6-8 ms. So the
  remaining prepare cost is SaveDocumentSchema.build re-validating and re-normalizing the two
  retained journal bundles (about 300 KB) on every save although the journal already holds them
  validated; that is the next measured candidate, not this step. The duplicate removal is not
  separable from run noise. App win settled 678-691 ms, loss 693-808 ms, dating 424-446 ms;
  board_fate ledger write 56-70 ms (write_atomic 35-42 of it).

### Step 3: --user-data stress option on the click benchmark (commit after 2e9530128)

tests/manual/benchmark_minesweeper_click_latency.gd gains `--user-data=<absolute directory>`:
in the SceneTree script's _initialize (which runs before ApplicationBootstrap's deferred start) it
copies that directory into the isolated user:// root (refusing a missing source, source equal to
target, or a target that already holds saves; prints CLICK_LATENCY_SEED), then enters through the
title's real Log In and the Backup picker's autosave Load exactly as verify_playable_startup's
completed-load journey does (CLICK_LATENCY_LOGIN), probes playability honestly (the App opens, the
presentation is valid, the board is unsettled, a difficulty is enabled, two rounds are left) and
plays the same App first-reveal, routine, win and loss sequence as the fresh-account path. The
dating half is skipped in seeded mode (CLICK_LATENCY_NOTE). An unplayable loaded run prints
CLICK_LATENCY_UNPLAYABLE with the observed state and exits 0; the fresh-account path only gains a
trailing CLICK_LATENCY_MODE line. The runner is untouched.

- settlement4-harness-live-refused-22b6a4fb2.log and settlement4-harness-live-refused-step1-tree.log:
  a hash-verified read-only copy of the live AppData DWM saves (written 2026-09-12 22:29: Day-1
  run, 108 publication records in a 785 KB ledger, 2.3 MB consequence checkpoint, 3 MB
  continuation journal with 35 completed operations; kept outside the repo at
  C:/Users/glori/Documents/dwm-stress-20260914 with source-before, source-after and copy sha256
  manifests). The seed lands (22 files, 14.5 MB) and the final-mode bootstrap then fails
  initialize_saves: journal_schema_invalid, DesktopContinuationOperationJournal: profile material
  is not normalized. NewRunMaterials compares each stored new-run profile material against
  ProfileSchema.validate's value, and since 2026-09-13 (3a1712f39 Minesweeper view defaults,
  7b911b5ca Steady Interface default) validate admits new default leaves into that value, so no
  journal written before those commits round-trips. That is a boot-blocking regression for
  existing players, filed as bug dwm-6fl; the long-history stress measurement waits on it.
- settlement4-harness-seed-source-2e9530128.log: a fresh-account run kept with -KeepRoot; its user
  directory (13 files, 1.15 MB, today's schema) is the seed for the two runs below.
- settlement4-harness-seeded-run1-2e9530128.log and -run2-: the seeding, Log In, picker Load and
  probe all run; the loaded autosave's route is dating with minesweeper_rounds_left 0 (the source
  run had finished both rounds and the dating challenge), so the desktop never mounts and the run
  reports desktop_not_mounted_after_load with session_active true and exits 0. The seeded play
  path beyond the probe is the same _minesweeper_app_benchmark every fresh run exercises; a
  positive seeded play measurement needs either the dwm-6fl fix (live data) or a seed captured
  while the desktop is mounted with rounds left.

### Post-merge re-verification (merge commit 6eea08ec6, master 835e50ee7)

- settlement4-post-merge-green-6eea08ec6.log: the settlement3 31-suite set plus
  test_desktop_publication_ledger, 32 suites, 582 passing / 0 failing, both contract evidence
  suites included, so no further re-seal is needed after the merge.
- settlement4-post-merge-bench-6eea08ec6.log: App win settled 733 ms, loss 623 ms, dating win
  396 ms, App first reveal 265 ms, routine reveal median 34 ms on the merged tree (same slow-machine
  day as every settlement4 run above).

Session 4 summary: the board_fate ledger write lost its emit + re-parse and two redundant canonical
passes (100-225 ms to 42-70 ms per terminal frame), the prepare side is now profiled and shows
SaveDocumentSchema.build as the next 25-62 ms target, the benchmark can replay a seeded user
directory, and the live-data stress run is blocked by dwm-6fl.

## dwm-6fl (branch fix/dwm-6fl from master 524409049, P1 boot refusal of pre-2026-09-13 continuation journals)

Master 524409049 also carried an unsealed drift: commit 3d37a3e80 (SystemTtsCoordinator autoload)
changed project.godot and autoload/DialogicBridge.gd, both bound by the desktop handoff contract
(project.godot by the minesweeper one too), so test_desktop_contract_evidence and
test_minesweeper_contract_evidence were red on master. The first commit on this branch regenerates
the two contracts through their no-arg generators; the leaf-level diff moves exactly the three
sha256 leaves (desktop: DialogicBridge.gd and project.godot; minesweeper: project.godot) and nothing
else (174 and 290 leaves before and after).

- 6fl-reseal-desktop-524409049.log and 6fl-reseal-minesweeper-524409049.log: the generator runs.
- 6fl-reseal-green-524409049.log: both contract evidence suites, 22 passing / 0 failing.
- 6fl-probe-checkpoint-journal-524409049.log: a one-file GUT run on the master-based warm worktree
  (no --import), 15 passing / 0, so the new master scripts compile from the existing class cache.

The fix (NewRunMaterials): ProfileSchema.validate has admitted default leaves into its validated
value since 2026-09-13 (Minesweeper view defaults 3a1712f39, Steady Interface default 7b911b5ca) and
reports migrated=true when it does. NewRunMaterials compared the stored before/candidate profile
material against that value and refused every pre-admission journal with "profile material is not
normalized"; the outgoing_text canonical check would have refused it a second way, because the
validated candidate carries leaves the stored canonical text does not. Under the 2026-09-14 ruling a
validation that reports migrated is admitted as normalized, and the candidate-vs-expected comparison
and the outgoing_text canonical check run over the stored material; for non-migrated material the
stored and validated values are equal, so nothing else moves. Journal bytes are untouched.

- 6fl-red-954a6b54c.log: tests/unit/test_new_run_materials.gd, 5 tests, 4 passing / 1 failing: the
  new legacy-material row (all eight Minesweeper view leaves and steady_interface erased from both
  stored profiles, outgoing text and hash recomputed from the stored candidate, ProfileSchema
  precondition asserts migrated) fails against the untouched validator on the refusal.
- 6fl-green-954a6b54c.log: 5 passing / 0. 6fl-green-journal-954a6b54c.log: the three caller suites
  (test_desktop_continuation_operation_journal, test_completed_load_continuation,
  test_new_run_replacement_baseline), 42 passing / 0.
- 6fl-live-run1-954a6b54c.log and -run2-: the click benchmark with --user-data on the hash-verified
  live-data copy (22 files, 14.5 MB) that settlement4 could not boot. Final-mode bootstrap now
  passes initialize_saves, Log In and the picker Load complete (CLICK_LATENCY_LOGIN 21.4 / 23.7 s,
  off-click), the loaded Day-1 run has the Minesweeper app open with two rounds left, and the App
  win and loss sequence plays to CLICK_LATENCY_PASS. These two runs are therefore also the first
  long-history measurement, taken with DWM_CHECKPOINT_PROFILE=1 and DWM_CONSEQUENCE_PROFILE=1 on the
  same shared-machine day as the settlement4 runs: App first reveal 1208 / 1277 ms and New Board
  first reveal 1562 / 1525 ms (against 265 ms fresh), win settled end to end 1343 / 1311 ms and loss
  1329 / 1470 ms (against 623-733 ms fresh), routine reveal median 29-35 ms (unchanged from fresh).
  Inside the win accept (852 / 780 ms) the two publication ledger writes cost 235 + 208 ms and
  197 + 242 ms on a 790-807 KB ledger document (write_atomic 88-116, disk_refresh 46-59, full_emit
  44-50 ms each); the three big autosaves cost 82-138 ms each (document_build 30-49 ms of every
  prepare). The routine click carries none of that growth. The stress candidate of dwm-634.3 now
  has its baseline; those phases are the next targets.

## settlement5 (branch perf/terminal-settlement-5 from master ae5b78282, dwm-634.3)

Session 5 starts after dwm-6fl landed on master (section above). The machine is shared with another
agent's Godot runs again, so every end-to-end figure below is compared phase by phase against a
same-day baseline; the two baselines are the fresh-account runs
settlement5-baseline-fresh-win-ae5b78282.log / -loss- (App win 563 / 627 ms, loss 599 / 650 ms,
dating 389 ms, App first reveal 232 / 249 ms, routine reveal 30 ms, issuer root 100 KB) and the two
live-copy runs of the dwm-6fl section (6fl-live-run1/2-954a6b54c.log, same code for the files this
session touches).

### Step 1: build composes the autosave journal from the journal's proven document bundles (commit after ae5b78282)

SaveDocumentSchema.build re-walked the two retained earlier bundles on every autosave (primitive-tree
validation, engine-text walk, integral-float walk over ~300 KB) although each was validated,
normalized and byte-proven at its own commit; document_build was 25-62 ms of every 35-76 ms prepare
on a fresh account and up to 83 ms on the live copy. Under the 2026-09-14 ruling CheckpointJournal now
retains, beside each remembered canonical text and under the same id, forget and clear rules, a
private deep copy of the document bundle those bytes describe (the document's current_snapshot the
port composed at that commit); the port hands those to build() as a trailing proven_journal, and
build composes recovery_journal by duplicate(true) of each proof with no walk. A proof set that does
not cover the whole journal (a seeded, restored or reset journal, or a bundle whose commit refused the
memory because the outgoing bundle was edited) takes the full path unchanged, exactly like the splice.
SaveManagerCheckpointPort.gd is desktop-contract-bound, so the handoff contract is regenerated in this
commit (one leaf moved, the port's own digest; the minesweeper contract came back byte-identical).

- settlement5-step1-red-ae5b78282.log: test_checkpoint_journal, test_save_document_schema and
  test_save_manager_checkpoint_port with the new rows against the untouched production files, 72
  tests, 64 passing / 8 failing: journal (document bundle remembered as a private deep copy served
  by reference; forgotten with its bundle; cleared on reset candidate, seed, restore and reset),
  schema (proven composition byte-equal to the full builder over StringName keys and values, 1.0
  and 2.5, non-ASCII text, detached in both directions; a poisoned journal entry is never read when
  a proof stands in and is refused invalid_recovery_journal without one; a short or empty proof set
  falls back to the full path), port (a committed autosave remembers the document bundle under the
  text's own remember gate and an in-place edit between prepare and commit remembers neither; source
  pin on the prepare wiring).
- settlement5-step1-green-ae5b78282.log: the 32-suite set, 589 tests, 586 passing / 3 failing, the
  three being test_desktop_contract_evidence's digest rows for the edited port before the re-seal.
- settlement5-step1-reseal-desktop-ae5b78282.log and -minesweeper-: the generators;
  settlement5-step1-contracts-green-ae5b78282.log: both contract suites, 22 passing / 0.
- settlement5-step1-profile-fresh-win-ae5b78282.log and -loss-, settlement5-step1-profile-live-run1-
  and -run2-: profiled runs (DWM_CHECKPOINT_PROFILE=1, DWM_CONSEQUENCE_PROFILE=1). Per big autosave
  (document over 150 KB) document_build_us: live copy 16-83 ms before to 8-12 ms after (6 saves per
  run, same document bytes save for save); fresh account 12-38 ms before to 5-12 ms on the saves
  whose earlier bundles are all remembered, while the three saves that follow the non-autosave
  day_resolution_stage commit still read 26-36 ms because that bundle has no remembered proof until
  it leaves retention (the known fallback). Prepare elapsed follows: live 44-101 ms to 17-22 ms.
  End-to-end: fresh App win 644 / 558 ms, loss 660 / 691 ms, dating 427 / 416 ms; live win 1275 /
  1181 ms, loss 1302 / 1236 ms, first reveal 1193 / 1142 ms, routine 29-34 ms; all inside the
  day's noise band and no end-to-end claim is attached beyond the phase figures.

### Step 2: the first reveal mints its identities deferred and the pre-board autosave flushes the issuer root once (commit after f684f34bb)

A read-only trace of the App first reveal (no profile record covered the frame) found five DURABLE
identity mints per first reveal: the transaction id in MinesweeperPresentationPort._mint_transaction
and board_token, placement_nonce, debug_nonce and explosion_nonce in
GameStateDesktopBoardPort.prepare_spec, each a whole rewrite of desktop-issuer-root.json through
write_atomic (808 KB on the live account: two deep copies, compose, write, read-back, backup
classification and about four SHA-256 passes each). The same frame then commits the pre-board
autosave, whose write already runs the saves root's before-write hook
(ApplicationBootstrap._flush_before_run_save, dwm-634.1) and flushes every deferred receipt before
the autosave bytes. Under the 2026-09-14 ruling all five mints now use issue_deferred (the
has_method fallback to issue stays for issuers without the seam), so the root is written once per
frame by that hook, durably before anything that references the receipts, and the final root bytes
are the same. MinesweeperRoundCoordinator._first_reveal_durable gains a permanent env-gated
DWM_CONSEQUENCE_PROFILE record, scope first_reveal_durable, mirroring complete_round's block with
eighteen phases. Neither handoff contract binds these three files (the bound
MinesweeperRoundCoordinator.gd is the domain one), so the regenerated contracts came back
byte-identical. The benchmark's seeded login deadline is widened from 30 s to 120 s: the live copy's
Log In measured 21-33 s on this loaded day and two runs (-live-run1- and -run2-, plus the
attribution run -attrib-live-) hit the old deadline and reported desktop_not_mounted_after_load with
the production files both applied and reverted, so that verdict was the harness, not the change.

- settlement5-step2-red-f684f34bb.log: test_minesweeper_presentation_port (the old
  first-reveal-issues-durably row rewritten to the new law), the new
  test_game_state_desktop_board_port (prepare_spec mints its four identities deferred, and a
  durable-only issuer still takes issue) and test_minesweeper_round_coordinator (the scope and every
  phase pinned in order; the env-unset helpers return an empty profile and write nothing): 78
  tests, 75 passing / 3 failing, one RED row per suite.
- settlement5-step2-green-f684f34bb.log: the 32-suite set plus the three suites above, the issuer
  suites and five first-reveal integration suites, 39 suites, 714 tests, 708 passing / 6 failing;
  settlement5-step2-attrib-baseline-f684f34bb.log: the two failing integration suites with the
  three production files reverted, 30 tests, 24 passing / 6 failing, the same six rows (the
  expected-4-saw-5 request class already listed as pre-existing in settlement4 Step 1).
- settlement5-step2-reseal-*.log and settlement5-step2-contracts-green-f684f34bb.log: generators
  and both contract suites, 22 passing / 0, no leaf moved.
- settlement5-step2-profile-live-run3-f684f34bb.log and -run4-: the live copy with the widened
  deadline. App first reveal 166 / 112 ms against 1193 / 1142 ms in the Step 1 runs, New Board first
  reveal 404 / 358 ms against 1562 / 1525 ms, issuer_root_bytes unchanged at 928474. The
  first_reveal_durable record reads elapsed 98 / 64 ms on the first board (checkpoint_commit 49 / 38,
  prepare_spec 18 / 10, checkpoint_prepare 9 / 7) and 318 / 285 ms on the New Board
  (checkpoint_commit 220 / 206 with the larger document, checkpoint_prepare 40 / 32, prepare_spec
  27 / 22). prepare_spec is now the four deferred mints, each still deep-copying the 808 KB root in
  memory (the port read-amplification candidate, not this step). These runs sat in a heavy-load
  window (routine reveal 46-55 ms, Log In 33 s), so their terminal end-to-end figures (win 1829 /
  1734, loss 2134 / 1702 ms) are not compared.
- settlement5-step2-profile-fresh-win-f684f34bb.log and -loss- (first pair, loaded window) and
  -fresh-win-run2- / -fresh-loss-run2- (second pair, still loaded: App win 956 / 817 ms against
  563-644 at the baseline): App first reveal 122 / 111 / 137 / 137 ms against 232 / 249 ms at the
  baseline, first_reveal_durable elapsed 61-83 ms of which checkpoint_commit 42-61 and
  prepare_spec 0.3-1.1 ms; routine reveal 36-38 ms medians under that load.

### Step 3: the publication ledger composes its document text from cached per-record canonical entries (commit after 8c62e2913)

On the live copy each of the two per-accept ledger writes cost 254-385 ms on the 790-807 KB
document: full_emit (canonicalizing the whole document for one appended record) 56-111 ms,
disk_refresh 64-106 ms, candidate_build 2.5-6.8 ms (a whole-document deep copy), cache_seed 4-16 ms
(another), confirmation 5-11 ms (a third, to fetch one record), write_atomic 98-142 ms. Under the
2026-09-14 ruling DesktopPublicationLedger now keeps, inside the validated-text memo entry of the
document it describes, the canonical text of every record and of every other top-level field, and
composes the outgoing text exactly as DesktopIssuerRootStore composes the issuer root: sorted
keys, one emit of the new record, the retained records' cached texts joined. The cache is rebuilt
once per distinct document text (the first write of a process, or after externally changed bytes)
and any composition it cannot prove identical (a non-printable-ASCII key, a refused emit) falls
back to the historical full emit, so a miss costs speed and never bytes. Cached documents are
immutable once cached: refresh no longer re-copies the parsed document, the candidate is a shallow
copy of the envelope and of the records map with the new key inserted, an already-owned document is
memoized without a copy, and the confirmation reads its one record from the memoized document by
reference. Whole-document deep copies per successful write go from 11 to 6 (the six remaining are
the storage validator callback's own copies). The pre-write reread, the exact byte read-back, the
_deep_same confirmation, every refusal and its order, and write_atomic with keep_backup are
unchanged; the profile record names which path fired (emit_path composed / full, compose_us beside
full_emit_us, canonical_rebuilt on the one-time rebuild). Neither handoff contract binds the ledger.

- settlement5-step3-red-f684f34bb.log: tests/unit/test_desktop_publication_ledger.gd with the new
  rows against the untouched ledger, 23 tests, 19 passing / 4 failing (the composed path and its
  per-record cache; externally changed bytes between two writes rebuild the cache and still write
  the full writer's bytes; a refused write leaves the cached document, the memo and the cache
  intact; the removed whole-document copies pinned by source). The byte-equality guard (six records
  with StringName keys and values, unsorted nested keys, 1.0 and 2.5, non-ASCII and brace-bearing
  strings, every write compared to the full canonical writer, a cold restart plus one more record,
  an identical replay) is green before and after by design.
- settlement5-step3-green-8c62e2913.log: the 32-suite set plus the thirteen suites that reference
  the ledger, 42 suites, 806 tests, 739 passing / 67 failing; settlement5-step3-attrib-baseline-
  8c62e2913.log: the six failing integration suites with the ledger reverted to HEAD, 159 tests, 92
  passing / 67 failing, the failing sets identical row for row (the frozen nine-role handoff gate
  against the live ten-role order, missing schedule_view members and expected-4-saw-5 requests,
  all listed as pre-existing in settlement4 Step 1).
- settlement5-step3-profile-live-run1-8c62e2913.log and -run2-: the live copy, still in the loaded
  window (routine reveal 47-50 ms, Log In 30-32 s). Per big ledger write: compose 7.5-15 ms where
  full_emit was 56-111 ms (the first write of each process rebuilds the cache once, 66 ms),
  candidate_build 0.03-0.07 ms from 2.5-6.8, cache_seed 0.9-5 from 4-16, confirmation 2.2-4.7
  from 5-11; disk_refresh 42-88 ms and write_atomic 91-158 ms unchanged in kind (the storage
  reconcile reading and hashing the final and its backup, ruled to stay). Per write elapsed
  162-260 ms against 254-385 ms in the Step 2 live runs of the same window.
- settlement5-step3-profile-fresh-win-8c62e2913.log and -loss-: fresh account, every ledger write
  takes the composed path (compose 0.3-1.1 ms on the 5-22 KB documents, 9.7-14 ms on the 89-107 KB
  board_fate write) with the one-time rebuild on the first write; App first reveal 89 / 117 ms.

### Post-merge re-verification (merge commit c53679203, master 366255a7d)

Master gained 352 files of Gallery work between the branch point and the merge, including a
DialogicBridge.gd change that master had already re-sealed in the desktop handoff contract. Both
sides therefore changed that single-line document and the merge conflicted on it; the resolution
takes master's file and regenerates the contract from the merged tree
(settlement5-merge-reseal-desktop.log, settlement5-merge-reseal-minesweeper.log: the minesweeper
contract byte-identical), and the leaf diff of the result carries exactly one moved leaf against
each parent: DialogicBridge.gd against this branch, SaveManagerCheckpointPort.gd against master.

- settlement5-post-merge-green-c53679203.log: the 32-suite set plus test_minesweeper_presentation_port,
  test_game_state_desktop_board_port and test_desktop_board_fate_port, 35 suites, 652 passing / 0
  failing, both contract evidence suites included, so no further re-seal is needed.
- settlement5-post-merge-bench-fresh-c53679203.log and -live-: the merged tree on the same loaded
  machine (routine reveal medians 50-56 ms against the usual 30). Fresh: App first reveal 144 ms,
  New Board 252 ms, win 957 / loss 912 ms, dating 603 ms. Live copy: Log In 30.8 s, App first reveal
  129 ms, New Board first reveal 265 ms, win 1517 / loss 1521 ms, issuer root 928474 bytes.

Session 5 summary: dwm-6fl fixed and closed (real players' journals boot again); the autosave no
longer re-walks its retained history (document_build 16-83 to 8-12 ms per big save on the live
copy); the first reveal writes the issuer root once instead of five times (live copy 1.19 / 1.14 s
to 112-166 ms, New Board 1.53-1.56 s to 265-404 ms) and has a permanent profile scope; the
publication ledger composes its text from a per-record canonical cache (full_emit 56-111 ms to
compose 7.5-15 ms per write). What remains on the live copy, in order: write_atomic plus the storage
reconcile on the 800 KB ledger and the 300-450 KB autosaves (ruled to stay), the four deferred
mints each deep-copying the 808 KB issuer root (prepare_spec 10-27 ms, the port read-amplification
candidate), and the 30-40 ms routine click of pure GDScript.

## settlement6 (branch perf/terminal-settlement-6 from master a3dcb775f, dwm-634.3)

Session 6 starts from the session 5 fast-forward. The same-day baseline is taken in a quiet window
(routine reveal medians 31-38 ms, live Log In 26.4 s): settlement6-baseline-a3dcb775f-live.log,
-fresh-win.log and -fresh-loss.log, all profiled (DWM_CHECKPOINT_PROFILE=1, DWM_CONSEQUENCE_PROFILE=1).
Live copy (108 publication records, 790 KB ledger, 928474-byte issuer root): App first reveal 125 ms,
New Board first reveal 214 ms, win settled two frames later at 1302 ms and loss at 1212 ms, accept
648-817 ms; each of the four publication ledger writes 140-238 ms of which disk_refresh 39-75 ms,
write_atomic 80-105 ms and compose 6-52 ms (the 52 is the one-time cache rebuild); each of the six
big autosaves 94-132 ms of which write_atomic 45-70 ms; first_reveal_durable 91 / 172 ms of which
prepare_spec (the four deferred mints) 11-17 ms. Fresh account: App first reveal 91 / 96 ms, New Board
255 / 212 ms, dating first reveal 338 / 294 ms, ledger writes 34-68 ms on 5-22 KB documents
(write_atomic 31-41 ms, so ~30 ms of every write is file-operation floor independent of size), big
autosaves 105-220 ms.

Rulings for this session (memory note dwm-terminal-settlement-rulings-2026-09-13, sixth extension):
the storage reconcile stays a law and is made cheap by a storage-only witness validator on
already-validated text (issuer-root precedent), ledger first, then the autosave port; the deferred
issuer mint stops copying the whole root; DesktopBoardState.capture and MinesweeperPanelPort.pull are
touched only if a routine-click profile shows them above noise.

### Step 2a: the publication ledger hands storage a validity witness instead of a document copy (commit after a3dcb775f)

Before every ledger write JsonFileStorage.write_atomic reconciles the family (final, .next, .bak):
each existing file is read, decoded, hashed and handed to the owner's validator, whose value storage
deep-copies (_classify_document) and reconcile deep-copies again, and the final read-back classifies
once more; write_atomic then returns a further copy. The ledger's validator answered a memoized text
with a deep copy of the whole ~800 KB document, and the ledger reads none of those values: refresh
re-reads through read_text and parses through _parse_known_document, and commit confirms from its own
memoized document. Under the 2026-09-14 ruling (no storage law change, DesktopIssuerRootStore
_parse_known_write_document precedent) the ledger gains _parse_known_storage_witness: on an
already-validated text it touches the memo and answers ok with an empty value; any other text takes
_parse_known_storage_text unchanged, so the cold path returns the full document, seeds the memo the
same way and keeps every refusal code and order. The reconcile in _refresh_from_disk and the
write_atomic calls in _commit_new_entry and _seed_empty_document pass the witness; every other reader
is untouched and JsonFileStorage.gd is not edited. The memo keeps three texts, so at write N the final
(text N-1), the .bak (text N-2) and the outgoing text (memoized in the cache_seed phase before
write_atomic) all hit the witness. Reads, hashes, bytes, the reread and the exact read-back stay.

- settlement6-step2a-red-a3dcb775f.log: tests/unit/test_desktop_publication_ledger.gd with the new rows
  against the untouched ledger, 27 tests, 24 passing / 3 failing: the witness answers a known text with
  an empty value; the witness delegates unknown and corrupt text to the full reader with identical code
  and message; the three value-discarding call sites pass the witness and none passes the full reader
  (source pin, with a pin that storage still requires a Dictionary value). Green before and after by
  design: external valid bytes after two writes still compose the full writer's bytes with the
  per-record cache rebuilt; malformed on-disk JSON still fails closed as indeterminate_transaction on
  load and on record_before_emit, bytes not rewritten (existing row extended).
- settlement6-step2a-green-a3dcb775f.log: the 35-suite set plus the thirteen suites that reference the
  ledger, 44 suites, 833 tests, 766 passing / 67 failing; the 67 failing rows are the identical set
  recorded in settlement5-step3-green-8c62e2913.log (frozen nine-role handoff gate, missing
  schedule_view members, expected-4-saw-5 requests), compared line for line.
- settlement6-step2a-profile-a3dcb775f-live.log and -live2-: the live copy (Log In 22.6 / 23.2 s,
  routine reveal medians 37 / 43 ms, so slightly loaded). Per ledger write on the 790 KB document:
  disk_refresh 39-75 ms at the baseline to 13-21 ms, write_atomic 80-105 to 29-61 ms (the final
  read-back also stops copying), compose unchanged 6-53 ms, per write elapsed 140-238 to 63-118 ms.
  accept_prepared_action 648-817 to 513-610 ms; win settled 1302 ms at the baseline to 1023 / 970 ms
  and loss 1212 to 1123 / 1018 ms two frames after the click (same-day quiet-to-light window). The
  residual disk_refresh is the read, UTF-8 decode and sha256 of the 790 KB final and its .bak, which
  is the law.
- settlement6-step2a-profile-a3dcb775f-fresh-win.log and -fresh-loss-: fresh account, ledger writes
  on 5-22 KB documents 25-53 ms (34-68 at the baseline), write_atomic 24-43 (31-41); the ~25-30 ms
  floor per write is marker writes, flushes and renames independent of size.

### Step 1a: the deferred issuer mint appends into the live root instead of copying it (commit after 08d88194e)

DesktopIssuerRootStore.issue_deferred minted through _minted_document, which deep-copies the whole
issuer root (928 KB on the live copy) so that the DURABLE issue() can write a candidate and burn no
counter if that write fails. The deferred path never writes (a crash loses receipt and effect
together by design, and every run save flushes the root first), so the copy bought nothing: four
such copies sat inside every first reveal (prepare_spec 11-17 ms live) and one inside every routine
click. Under the 2026-09-14 ruling issue_deferred decides both refusals first, then mints the receipt
from the live namespace and counter with the existing _mint_receipt, inserts a copy of it into the
live receipts map, advances next_counter and adopts it into the incremental canonical cache exactly
as before (_adopt_deferred drops its now-redundant document parameter). issue(), _minted_document and
the allocation paths are untouched; the returned token and receipts are still deep copies. The
identity-issuer boundary contract binds the store's blob at its historical commit and its public
surface (public, non-static, column-0 signatures), neither of which moves.

- settlement6-step1a-red-a3dcb775f.log: tests/unit/test_desktop_issuer_root_store.gd with the new rows
  against the untouched store, 41 tests, 40 passing / 1 failing: the source pin that issue_deferred no
  longer mints through _minted_document nor copies _document. Green before and after by design (byte
  equality on two FakeFileOps roots with the same namespace): six deferred mints then flush write the
  bytes six durable issues write, with identical tokens and receipt ids in order; a refused deferred
  mint (unknown purpose) leaves the live root, next_counter and the flushed bytes untouched; mutating
  a returned receipt or a capture() cannot reach the flushed bytes; one durable issue then two deferred
  mints flush three durable issues' bytes; and the same with the canonical cache cleared (the fallback
  _write_document path, reachable in production only after a refused canonical stringify).
- settlement6-step1a-green-08d88194e.log: the 35-suite set plus the seven first-reveal and issuer
  suites of settlement5 Step 2, 42 suites, 785 tests, 779 passing / 6 failing; the six are the
  expected-4-saw-5 request rows in test_desktop_bootstrap_wiring and
  test_desktop_completion_transaction already listed as pre-existing in settlement4 Step 1 and
  reproduced with production reverted in settlement5-step2-attrib-baseline-f684f34bb.log; every row is
  inside the session 5 failing set.
- settlement6-step1a-profile-08d88194e-live.log and -live2-: the live copy. first_reveal_durable
  prepare_spec 11-17 ms at the baseline (and in the Step 2a runs) to 0.3-3.6 ms; App first reveal
  125 ms at the baseline to 73 / 75 ms two frames after the click (the first run quiet at routine
  median 30 ms, the second loaded: New Board 339 ms, win 61 ms sync, accept 865-1053 ms, so only its
  prepare_spec is compared). Ledger and autosave phases unchanged in kind from Step 2a.
- settlement6-step1a-profile-08d88194e-fresh-win.log and -fresh-loss-: fresh account in a loaded
  window (routine medians 47 / 36 ms, App first reveal 133 / 129 ms against 89-96 at the quiet
  baseline); prepare_spec 0.3-2.1 ms, as before on a 100 KB root; no end-to-end claim.
