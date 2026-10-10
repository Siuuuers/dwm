# Replaying retained warm-proof measurements

The raw pair files retain every sample, invariant, process receipt and source binding.
The matching `runNN-day7-autosave.json` files preserve the exact synthetic inputs
after GitHub's original seven-day archives expire. They contain fixture game state,
not a user's save. Input-retention receipts bind extraction to the original run,
length and SHA256; root independently checks chunk transport and Git-blob readback.

To repeat a comparison, use a disposable **GitHub cloud** checkout at the receipt's
exact `tested_merge_sha`, with full ancestry and Godot 4.6.3 standard. The benchmark
compares frozen accepted methods with that candidate; do not silently substitute
the current branch. Keep Godot and PowerShell execution in cloud.

1. Import that project using the existing cloud setup, then restore any tracked
   settings changed by editor import.
2. Copy the matching retained input, unchanged, to
   `.godot/ci/seven-day-history/day7-autosave.json`.
3. Write the corresponding review receipt's `history_job.proof` object as UTF-8
   JSON to `.godot/ci/seven-day-history/results.json`. This restores the original
   checkout, payload and retained-history admission metadata; do not synthesize
   values from a different run.
4. Run `tools/testing/Invoke-WarmOutgoingProofPerformance.ps1`. Its existing
   provenance guards and 24 isolated processes must succeed. Retain the new
   `results.json`, per-process execution records and logs.

The Run69 partial receipt predates that shared `history_job.proof` field;
its exact metadata is retained separately as `run69-history-input-metadata.json`.
Run70 and subsequent completed receipts use the shared field.

Audit the twelve `pairs` in each raw comparison: five samples produce each metric
median; candidate minus baseline produces each paired delta; the six summary
medians must follow those paired records. Compare all non-timing/non-variant
invariants within each proof-state mode. Require 24 unique process IDs, user/test
directories and log paths, successful exits, and exact current/reference source hashes.

There are 240 retained timings: 120 direct schema compositions and 120 complete
port commits. “Cold/mixed/warm” means 0/51/66 journal proofs; OS caches are not
flushed. Complete commits use the real journal/storage protocol over FakeFileOps.
Public preparation, live capture, physical disk and input-to-paint are excluded.
Timing values will vary on shared runners; judge matched pairs within the new run,
not wall-clock differences between runs. Preserve unfavorable results.

The auxiliary `codex/retain-run69-71-inputs-20260929` branch exists only to extract
known synthetic inputs with read-only Actions permissions. It does not replace the
PR's tested source or alter its workflow. Its source/run/job identities are included
in the input-retention receipts. The main PR remains draft.
