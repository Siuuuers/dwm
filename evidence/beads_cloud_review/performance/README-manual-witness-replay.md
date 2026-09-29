# Replay the Run75 manual-save witness diagnostic

This is a cloud-only diagnostic, not a production optimization or full gameplay latency claim.
Use Godot 4.6.3 standard and the existing isolated PowerShell runner on a disposable Windows GitHub Actions checkout.

- Measured source: `2dd0f8c91fe7b1f7dcf105e56f4309f2658b3aa2`.
- Final source `d0831f1dfe420443803658c47c28ee95caa7be9f` changes only the two public inventories.
- Cloud run: https://github.com/Siuuuers/dwm/actions/runs/36522797798
- Exact original Actions artifact: `run75-manual-save-witness-artifact.zip`.
- Artifact SHA256: `3842d027603a56948443c2b0fd4bd23d754e977b723228a97a1a1852d8d044e0`.
- Readable normalized copy of its results: `run75-manual-save-witness.json`.

The ZIP retains `ci/manual-save-witness/results.json`, `producer-manifest.json`, all 18 process receipts and logs, and the complete `producer-user` directory. The latter has 15 files / 6,235,146 bytes, including all 66 retained checkpoints, the original `slot_1.json`, autosave/backups, Profile, journals and seven-day recovery proof. Do not substitute the autosave alone.

For a fresh experiment at the measured source, install/import using the pinned workflow steps, restore committed `project.godot` after import, then run:

```powershell
./tools/testing/Invoke-ManualSaveWitnessPerformance.ps1
```

This creates a new source fixture; its timing/input bytes are a separate experiment, not additional matched Run75 samples. The driver requires a fresh output directory and verifies the exact copied baseline helper body before executing.

For exact-input replay, first copy the committed ZIP outside the tracked checkout before switching to the measured source. Verify its SHA256, then expand it inside a new directory under `.godot/phase2r_tests/`. Verify every filename, byte count and SHA256 against `producer-manifest.json`; verify every listed source hash against the measured checkout. All paths in the manifest are relative to its `producer-user` directory. Use the archived full producer directory for the `benchmark_seven_day_history.gd --history-phase=read --user-data=...` fresh Login proof, and its `saves` directory for each manual probe.

With the archive expanded to `.godot/phase2r_tests/run75-replay`, one probe is:

```powershell
$sourceSaves = [IO.Path]::GetFullPath('.godot/phase2r_tests/run75-replay/ci/manual-save-witness/producer-user/saves')
$env:DWM_CHECKPOINT_PROFILE = ''
$env:DWM_CONSEQUENCE_PROFILE = ''
$env:DWM_SAVE_LOAD_PROFILE = ''
$env:DWM_SAVE_PARSE_CACHE_DISABLED = ''
./tools/testing/Invoke-IsolatedGodot.ps1 -SuiteId replay-manual-baseline `
  -LogName replay-manual-baseline.log -EvidenceLogPath .godot/ci/replay-manual-baseline.jsonl `
  -TimeoutSeconds 180 -GodotArgs @('-s', 'res://tests/manual/benchmark_manual_save_write.gd', '--',
    '--phase2r-bootstrap-mode=test_manual', "--write-source=$sourceSaves", '--write-variant=baseline')
```

Run `baseline`/`witness` in four alternating pairs with fresh process roots and unique log/receipt names. Repeat separately with `DWM_SAVE_PARSE_CACHE_DISABLED=1`; restore the prior environment afterward. Require identical candidate, input, record, source/output file, journal and cache-state proofs within the relevant mode. The strict validation call count is one per commit. Inspect every isolated exit, marker and error guard rather than relying on the final exit alone.

The standalone example is not a replacement for the driver's source/control and comparison guards: reproduce those checks when replaying archived input. The committed driver deliberately has no unchecked replay override.

Preparation and commit are sequential subscopes of the continuous envelope. Compare each separately; do not add them to the envelope. The envelope includes only cheap token/reference/timer/counter and shallow cache bookkeeping between calls. Canonical/hash/deep-copy oracles run outside it. Enabled Run75 caching has one 1,872,307-byte prior slot before commit and two entries afterward; disabled caching has none. These are parser-cache modes, not the earlier cold/mixed/warm journal-proof states, and OS caches are not flushed.

No live capture owner, issuer flush callback, UI subscribers, rendering, human confirmation, physical input-to-paint, Quick Save or witness-specific failure/restart proof is included. Production adoption requires the latter correctness work. Keep all favorable and unfavorable samples; do not pool modes or infer significance from four pairs.
