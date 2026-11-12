# Public-surface checkout reduction

Base: `0c138db5ab205136ba9dcdb691a5dbeccaf6bc31` (PR #298).
Goal: omit historical evidence from the disposable public-surfaces CI checkout
while preserving every inventory, retirement-scan and native-caption input.
No runtime code, game assets, archive contents or job dependencies change.

## Audit and change

Coverage selection is already sparse; leave it unchanged. The public-surfaces
job still used a full checkout. Its evidence inputs are four canonical JSONs in
`evidence/phase_2r/runtime/` (446,601 bytes). Retain that directory and
`evidence/.gdignore`; omit other evidence files from this job only.
All other paths remain included. Retirement scans retain complete autoload,
scripts, scenes and tests roots; census additionally retains tools/testing and
.github/workflows. Native caption uses current assets and writes user evidence.
The terminal ZIP in Invoke-CloudTests is conditional on another suite and is not
an input here. The isolation runner creates its output directories when absent.
Independent read-only review confirmed these dependencies.

## Measured checkout content

On the base commit, apply the exact workflow patterns to a detached local Git
worktree and sum tracked blob sizes for files present. This is uncompressed file
content, not transfer bytes or elapsed GitHub checkout time.

| Content | Bytes |
| --- | ---: |
| Full tracked blobs | 1391134742 |
| Sparse checkout | 169594909 |
| Omitted historical evidence | 1221539833 |

All 2,655 tracked files across the audited scan roots remain present and byte
identical to base (the workflow/test edits are outside the measured base tree).
No tracked archive is deleted. Existing checkout action performs sparse retrieval;
actual compressed transfer/time savings need an Actions observation.

## Focused validation

- Real Git sparse-pattern regression: canonical JSONs, nested source, tools,
  workflow and asset inputs retained; historical archive/image omitted.
- All 48 coverage-selector tests pass after correcting the new test's job-block
  extraction. Initial test invocation used the wrong class; no runtime defect.
- Fresh Godot 4.6.3 Linux sparse-tree import exits 0, without script/load errors.
- Both GameState and SaveManager canonical inventory drift checks pass on sparse tree.
- Inventory unit suite on sparse tree: 14 tests, 411 assertions, exit 0.
- Retirement scan: 10 symbols, 1,206 GDScript/scene files, zero references.

Reproduce checkout with the public-surfaces `sparse-checkout` block and run
`python tools/testing/test_windows_coverage.py`. Inventory commands use
`tools/runtime/generate_public_surface_inventory.gd -- --script=res://autoload/GameState.gd`
(or SaveManager), corresponding required/output JSONs, `--check`, and all four
`--search-root=res://autoload|scripts|scenes|tests` arguments individually.

No Windows native-caption execution, rendered acceptance, full gameplay matrix,
network speed claim or in-game smoothness claim. The job's existing Windows checks
remain unchanged. This is checkout scope reduction, not retirement of evidence.
