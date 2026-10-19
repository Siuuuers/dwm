# Offline ordered-wait binder correction

This directory contains Python-only analysis of retained run evidence. No native executable, Rust build, PowerShell script, or new gameplay run was executed. Original evidence and original binding reports are unchanged. This is not official-build acceptance.

Extract baseline-evidence.zip and corrected-evidence.zip into sibling directories named baseline-evidence and corrected-evidence beside analysis. From their parent directory run:

```sh
python analysis/test_offline.py
python analysis/run_analysis.py
```

The copied source tree retains the original consumer/query readers, package constants, and harness. Binder source exceptions are restricted to the exact retained commit `d37ad1f6d3c0148205c1b4d21444d05d01e7cca6`, tree `7a49df0c816e4aa059ead494b925976cf3402498`, and two known binder SHA256 values. Retained source pins remain enforced. Other source matching, engine/package/SDK provenance, trace readers and bounds remain enforced.

The validator walks the complete event stream in logged order, validates every ending wait start/end, requires deadline 30 for every start, rejects nested/unpaired waits and out-of-order timestamps, validates all ending boundaries against the game PID and one consistent positive HWND, and selects wait ordinal zero. It does not require exactly three waits or select a successful interval. Every observed harness batch is checked, with query ordinals restarting at zero separately for each validated wait. Later waits are excluded from first-interval query/harness results. Native query request IDs and harness ordinals are not assumed to correspond.

11 tests passed, including absent/startless/endless/reordered waits, later deadline/PID/HWND changes, exact source exceptions, and a complete-binding negative test for a later wait's wrong query ordinal. Tests also check both retained packets and trace inclusion bounds.

| First interval evidence | Baseline | Corrected |
| --- | ---: | ---: |
| Validated total ending waits | 1 | 3 |
| Eligible consumer snapshots | 13 | 6 |
| Eligible native query observations | 148 | 111 |
| Native query observations selecting caption | 0 | 3 |
| Harness enumerations in first wait | 2 | 1 |
| Matches in first-wait harness enumerations | 0, 0 | 1 |

All eligible consumer snapshots carry the caption label/role. These observations establish diagnostic interval associations only; they do not establish delivery causality, an exclusion cause, or official acceptance.

`*-evidence-unchanged.json` records full SHA256 censuses compared before/after analysis. `binder-source-hashes.json` and `binder-correction.diff` document the two binder modifications. `analysis-source-manifest.json` records all copied Python/harness source hashes, including the new validator. Reports are written only here, never into the retained evidence directories.
