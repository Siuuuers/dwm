# Shared reading configuration cloud comparison — 26 October 2026

Cloud run: https://github.com/Siuuuers/dwm/actions/runs/40220118337

Baseline: `80adad98c066a2296c211f0634c460c7c6cb8876`.
Candidate: `b7caa07d37c86c1165f22cdbaa4771947576fa6c`.
Pinned diagnostic controller: `d72b67506e05c03f161201df7b9fc5430e2b136e`.

Eight exported Windows New Acc journeys ran on one runner: baseline then
candidate, then candidate then baseline. Each variant had its own fresh and
retained profile pair. Fresh means empty user data, not cold OS or driver caches.
The observer was applied equally to both source revisions. No Steam upload ran.

| Measure | Baseline | Candidate |
|---|---:|---:|
| Fresh click to complete caption | 16.69–16.72 s | 11.22–11.59 s |
| Retained click to complete caption | 17.57–18.27 s | 11.98–12.35 s |
| Maximum New Acc/confirmation frame gap | 10.71–10.97 s | 7.19–7.51 s |
| Fresh compiler calls in New Acc scope | 8,300 | 112 |
| Retained compiler calls in New Acc scope | 8,853 | 21 |

Matched full-journey savings were 5.14–5.92 seconds (about 31–33%). Retained
confirmation dwell was 31–39 ms and is recorded separately. Configuration call
counts remain 90/96; the reused work inside those calls changed. Compiler counts
include cache hits and must not be called physical parses. Inclusive phase
measurements must not be added to parent durations.

All eight processes passed exact-caption, input, settled-journal and clean-exit
checks. All 20 screenshot hashes were verified. The coordinator visually reviewed
the eight distinct images: Title, retained consent, and full opening captions.
The visible opening text and layout match; timestamps and form styling account
for the distinct caption images. This is bounded New Acc evidence, not full-game
acceptance. There is no Load measurement in this harness. Two samples per
variant/case do not establish a statistical latency distribution. Several-second
pauses remain. Title timing is mixed and is not claimed as a consistent speedup.

`comparison.json` contains exact samples and paired differences.
`cloud-evidence.tar.xz` retains all 73 non-profile files from the original evidence
artifact, including reports, logs, screenshots, package/source and harness hashes.
`members.json` contains the original member byte lengths and SHA-256 values.
Archive SHA-256: `fda573dfa56ece51d1c6d4093809413cbe267a89b32f618796127aa291fc2512`.

The original full evidence artifact ID is `12608609408`, SHA-256
`22a66e7fe0f59e3155d0548b765b01901b786e10745641fd88233bae4dc841c2`.
Profile files are omitted from this retained selection. Exact diagnostic packages
are in cloud artifact `12609278503`; they are not copied into the product repo.
Those cloud artifacts have a seven-day retention limit. The pinned source and
observer plus retained hashes identify the measured exports.

The comparison workflow is manual-only after collection. Later inventory,
author-guide, localization-validator and handoff changes do not change the
measured runtime files. Final correctness CI is a separate acceptance gate.
