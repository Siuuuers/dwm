# Trusted story runtime performance — 26 October 2026

## Result

[PR #110](https://github.com/Siuuuers/dwm/pull/110) removes repeated whole-story validation, registration copies and hashes. The manifest owns the immutable tables; snapshot, scene and audio paths reuse them. Session preparation parses each DTL once for its entries and retains only frozen semantic mappings. Mutable save checks remain. CI validates authored content inside the exact exported Windows pack.

The owner prioritized speed and deferred edited-DTL rejection/soft-error work. This candidate contains no new edited-DTL skip UI, native skip guard or recovery machinery.

## Matched measurements

Baseline: `4d214741177df293b424d08b213daff060d37e40`.
Candidate: `baa4b41cf5c852c144a9537150763462dcc73995`.
[Successful timing run, attempt 2](https://github.com/Siuuuers/dwm/actions/runs/40285967600/attempts/2).

Four samples per variant/case, 24 fresh processes in AB/BA/AB/BA order on one Windows Server 2022 cloud runner. Retained New Acc uses its own fresh profile. Every Load uses the same 74-file baseline seed. Fresh user data does not imply a cold OS cache. These results describe this runner, not all player hardware.

| Complete interval (median) | Baseline | Candidate | Reduction |
|---|---:|---:|---:|
| Launch to usable Title, fresh | 8.352 s | 7.849 s | 6.0% |
| Fresh New Acc click to complete caption | 14.638 s | 6.428 s | 56.1% |
| Retained New Acc confirmation to complete caption | 15.149 s | 6.542 s | 56.8% |
| Load click to complete saved caption | 7.701 s | 3.150 s | 59.1% |

All 12 paired journey comparisons improved. Full bundle-validation calls during New Acc fell from 36 to 0, and during Load from 23 to 0; prepared-owner lookups are not full validations. Registration is still structurally prepared once per process. Candidate compilation totals are approximately 0.49 s for New Acc and 0.42 s for Load. Do not add inclusive compilation/configuration/phase counters together.

Median longest frame gaps remain 4.139 s for fresh New Acc, 4.172 s after retained confirmation, and 3.087 s during Load (baseline 9.405/9.554/7.616 s). Waiting has been reduced, not eliminated. The early interval before the observer is still not isolated; do not attribute it to disk, GPU or compilation without another measurement.

## Verification

[Windows regression run](https://github.com/Siuuuers/dwm/actions/runs/40285967588): 61 jobs passed, one expected archived-comparison skip, no failures. Includes cold shared-parse coverage, immutable ownership/audio parity, current save/content-update behavior, native execution, exact exported-pack authored validation, and rendered journeys.

The final timing run passed all 24 processes, complete caption assertions, Load gameplay/scene/reading preservation, unchanged source Autosave, identical seed hashes, clean exits, and unchanged package hashes. All 64 screenshots were hash-verified and visually reviewed through contact sheets and full-size representatives. No visual regression was observed in these journeys.

The first timing attempt on this same candidate stopped at r4-candidate-retained after the complete caption and exit code 0: Godot reported ObjectDB instances leaked and two resources still in use at shutdown. The same signature is recorded in [an earlier investigation](../../../handoff/y-desktop-dependency-investigation-20261025.md), but the resource owner/cause is unproven. The unchanged non-verbose rerun passed all 24 processes. This does not establish a fix for the intermittent shutdown issue; the failing result/process/log files are retained in `prior_attempt_shutdown/`. No log check was suppressed and no arbitrary exit delay was added.

## Retained evidence

- `summary.json`: raw samples, aggregates, all paired deltas, source/package/seed hashes.
- `source.json`, `harness.json`: pinned revisions and diagnostic overlay provenance.
- `contact-1.jpg` through `contact-4.jpg`: all 64 final-run screenshots.
- `evidence.zip.part01` through `evidence.zip.part05`: byte-exact GitHub artifact 12634657644, split only for storage. Includes raw logs, profiles, screenshots, per-process receipts and export manifests.
- `SHA256SUMS`: individual retained-file hashes and reconstructed archive hash.

Reconstruct the original ZIP by concatenating the five parts in numeric order. Its SHA-256 is `d82453a13f5c3d1264f62180424c30297e2386bd00f864fcbcf83a83fd4f33b4`. After extraction, use the candidate's `tools/testing/trusted_runtime_comparison.py summarize --root <extracted-directory>` to rerun the data-integrity checks. Exact diagnostic executables/packages were separately uploaded as artifact 12634293800; their hashes are retained here. They are instrumented diagnostics, not a new Steam upload.

## Next work

The [continuation handoff](../../../handoff/ad-trusted-runtime-performance-results-20261026.md) records the merged source and two independent next investigations.
