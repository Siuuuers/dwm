# Exported startup evidence

Read [the result and continuation](../../../handoff/x-exported-startup-attribution-20261025.md).

| File | Contents |
|---|---|
| `run40198504876-measurements.zip` | Initial baseline/menu/font/minimal experiment: logs, 44 screenshots, process receipts, profile data and package identities |
| `run40198504876-members.json` | Every original artifact member's size/SHA256, original ZIP hash and explicit retained-member list |
| `run40198504876-summary.json` | Complete-operation timings, bootstrap phases and font-cache observations |
| `run40199783167-failed-renderer.zip` | Failed same-package renderer experiment, including the compatibility fallback and shutdown error |
| `run40199783167-members.json` | Original renderer artifact manifest and retained subset |
| `run40200659481-autoloads.zip` | Exact downloaded compact trace artifact: four processes, 30 events each, 10 screenshots, logs and current-format profiles |
| `run40200659481-members.json` | Exact compact artifact hash and member hashes; separate package artifact identity |
| `run40200659481-summary.json` | Autoload preparation/constructor intervals and surrounding startup intervals |

The first two retained ZIPs omit package binaries and shader caches. The complete
original-member manifests retain their hashes. Original package artifacts are
available from the linked GitHub runs for their retention period. They are not
duplicated in this repository. Source overlays and pinned engine/template
checksums are preserved at the exact diagnostic controller revisions in the
handoff. The third ZIP is the complete compact evidence artifact, unchanged.

The measurements establish attribution and tested journeys. They do not establish
a product speedup, cold disk-cache latency, installed-Steam latency, full gameplay
regression acceptance, or performance on a hardware GPU.
