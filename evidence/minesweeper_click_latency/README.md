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
