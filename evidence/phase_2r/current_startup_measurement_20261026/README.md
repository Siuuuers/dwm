# Current master startup and Load measurements

Measured source: `51763f0af4d71909411ff208b3f3584516f09d37`.
Cloud run: [40263114679](https://github.com/Siuuuers/dwm/actions/runs/40263114679).

This is a measured baseline. No runtime optimization was made. Do not merge the diagnostic branch.

## Player-visible times

Each row has four samples. Values are seconds. All samples use a new process.

| Interval | Median | Minimum–maximum |
|---|---:|---:|
| Launch to usable Title, empty user data | 8.395 | 8.119–8.853 |
| Launch to usable Title, retained New Acc profile | 6.955 | 6.881–7.421 |
| Launch to usable Title, Load seed | 6.987 | 6.936–7.122 |
| New Acc click to complete caption, empty user data | 14.826 | 14.756–14.885 |
| New Acc click to complete caption, retained profile | 14.860 | 14.801–15.160 |
| Confirmation click to complete caption, retained profile | 14.768 | 14.702–15.073 |
| Log in click to usable Backup | 0.055 | 0.054–0.059 |
| Load click to ready signal | 7.360 | 7.337–7.781 |
| Load click to complete caption | 7.546 | 7.525–7.981 |

Retained New Acc includes a median 0.052 seconds of scripted confirmation dwell.
Load starts at the Load button. It excludes launch, Backup opening and the observer's screenshot dwell.

## Frame stalls

| Action | Median longest frame gap | Minimum–maximum |
|---|---:|---:|
| Fresh New Acc | 9.485 s | 9.387–9.567 s |
| Retained New Acc, after confirmation | 9.347 s | 9.236–9.574 s |
| Load | 7.466 s | 7.447–7.896 s |

## Internal measurements

| Work | Fresh New Acc | Retained New Acc | Load |
|---|---:|---:|---:|
| Story-bundle validation calls | 36 | 36 | 23 |
| Story-bundle validation, inclusive seconds | 3.906 | 3.844 | 2.494 |
| Reading configuration, inclusive seconds | 0.198 | 0.195 | 0.109 |
| Compilation, included within configuration, seconds | 0.055 | 0.054 | 0.042 |

Load snapshot validations: Total: median 5.342 s; range 5.281–5.618 s. Seven calls per run.

Load snapshot validations: Before semantic validation: median 4.167 s; range 4.122–4.373 s. Seven calls per run.

Load snapshot validations: Semantic validation: median 1.138 s; range 1.123–1.208 s. Seven calls per run.

These costs overlap. Do not add bundle validation to snapshot totals.
The Load profiler scope starts before Log in and ends at the saved caption. It is wider than Load-click timing.
New Acc uses a separate creation-validation path. Its empty snapshot-detail list does not mean that it skips validation.
Fresh New Acc phase medians: decision preparation 5.229 s; resume transaction 7.783 s. The resume value includes nested work.

## Immutable story tables

DialogicEntryManifest owns tables indexed by authored entry, target, board-profile, Challenge, Contact and marker IDs.
The owner validates and freezes these tables. They describe story content. They do not contain player money, choices, board progress or reading history.
RunSnapshotSchema.validate_current_scene currently calls structural bundle validation again. That validation rebuilds indices and checks authored links and fingerprints.
The measured bundle counters cover all callers. They do not prove how much time one reuse change would save.

Next investigation: trace redundant structural validation of the selected immutable bundle. Keep checks for changing save state and independent inputs. Measure a separate candidate before accepting an optimization.

## Conditions and evidence

- One Windows Server 2022 cloud runner, Microsoft Hyper-V Video. These are not player-PC performance guarantees.
- One exported release with the pinned observation and profiling overlay. Instrumentation can affect timing.
- Four repetitions in fixed order: fresh New Acc, retained New Acc, Load.
- Retained means retained user data in a new process. Cold OS/driver caches and warm-process performance were not measured.
- Each retained profile matches its own fresh output. All four Load inputs match the same 74-file current-format seed.
- All 12 processes exited cleanly. Load preserved saved gameplay, scene, reading position and source Autosave bytes.
- All 32 screenshot hashes were verified. All 32 images were visually reviewed through contact sheets.
- Four samples describe this runner. They do not establish statistical significance or a speedup over earlier runs.

See [summary.json](summary.json) for every sample and aggregate. See [manifest.json](manifest.json) for archive hashes and retention scope.
