# Replay the manual-save validation comparisons

## Production adoption: Run81

Use Godot 4.6.3 standard and the isolated PowerShell runner in a disposable Windows
GitHub Actions checkout. Engine and PowerShell execution stays cloud-only.

- Measured production source: `f28d2bdccd572894267317d04f7373d46430d83c`.
- Final source `724ff76fabafe358d6f445b404386baa65d20062` changes only two inventories.
- Run: https://github.com/Siuuuers/dwm/actions/runs/36846965941
- Original ZIP: `run81-manual-save-witness-artifact.zip`.
- ZIP SHA256: `ea45d8fef754d4357e85d0c1a5143541036b96ae164dbc2f1039f55adf334151`.
- Readable results: `run81-manual-save-witness.json`.
- Shared correctness/adoption receipt: [save-witness-production-run78-82.json](../save-witness-production-run78-82.json).

The ZIP retains all 18 process receipts/logs and the complete 15-file producer
fixture (6,235,916 bytes), including the original manual slot, backups, Profile
and journals. All 66 checkpoint identities are retained. The benchmark uses real
physical save I/O, fixed immutable capture and a fixed clock. It excludes live
capture/issuer/UI callbacks, rendering and physical input-to-paint. Processes are
fresh; OS caches are not flushed. Four pairs per cache mode do not establish
statistical significance or a gameplay-wide gain.
The archive preserves the full input fixture. Physical post-write output files
are not archived; their equality is bound to the size/hash oracles in all sixteen
raw manual-process logs. Full Profile-state equality is not an independent claim.

At the measured source, fetch complete Git history and run:

```powershell
./tools/testing/Invoke-ManualSaveWitnessPerformance.ps1
```

The runner needs immutable source `9a4c63f05d13bc2960aae4fa6c58db9911916f86`
locally. It proves the frozen full-result baseline body, verifies the production
body against the formerly diagnostic witness, and reconstructs the whole old
SaveManager to prove only that helper block differs. `baseline` executes the
frozen helper; `production` forwards to the actual SaveManager implementation.
There is no copied candidate implementation or unchecked replay override.

For exact-input replay, copy the ZIP outside the checkout before switching
sources, verify the ZIP hash, then expand it under a fresh
`.godot/phase2r_tests/run81-replay` directory. Verify every fixture path, byte count
and SHA256 against `producer-manifest.json` and all 14 source hashes against the
measured Git source. Reuse the original full `producer-user` directory for the
fresh Login proof, and its `saves` directory for each manual probe. Follow the
isolated probe example in the historical section below with `run81-replay`,
unique log/receipt names, and explicit `--write-variant=baseline` or
`--write-variant=production`. Alternate four pairs separately in each parser-cache
mode. Preserve every driver source/control, exact-input/output, journal, cache,
retention, process and error guard; the single-probe example alone is insufficient.

All eight Run81 envelope pairs improve. Median paired differences are
-208.1125 ms with caching enabled and -222.829 ms disabled; candidate envelope
medians are 3.130266 and 3.116270 seconds. Enabled preparation pair 3 is +4.532 ms.
Keep nested preparation/commit/envelope metrics separate. Cross-run absolute
latencies are observations, not matched causal comparisons.

## Earlier correctness diagnostic: Run78

Run https://github.com/Siuuuers/dwm/actions/runs/36844427614 measured source
`63005694f76594e8458fff4f107b39b80dc336bd`. Production was still unchanged there.
The shared diagnostic port was extracted from the earlier inline benchmark;
variants at that historical source are `baseline` and `witness`.

- Original ZIP: `run78-manual-save-witness-artifact.zip`.
- ZIP SHA256: `85579771d4379d39cbdc0c1028e61d724fbd3177d7f160fb0491bc2a5f4103ac`.
- Readable results: `run78-manual-save-witness.json`.
- Complete fixture: 15 files / 6,235,468 bytes; 18 processes and 66 checkpoints.

Follow the same full-fixture/source verification rules. Seven of eight envelope
pairs improve; enabled pair 2 regresses by +292.054 ms. Median paired envelope
differences are -196.9915 ms enabled and -217.7695 ms disabled. Preserve that
unfavorable sample. Run79 later registered the complete modern Quick suite;
Run78 itself did not execute that suite. The shared receipt records the exact
correctness scope and the separate actual-production evidence.

## Historical Run75 diagnostic

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
