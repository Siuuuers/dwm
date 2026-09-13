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
