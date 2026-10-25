# Shared reading configuration Load comparison — 26 October 2026

Cloud run: https://github.com/Siuuuers/dwm/actions/runs/40221681725

Baseline: `80adad98c066a2296c211f0634c460c7c6cb8876`.
Candidate/diagnostic branch: `5c310c573718ae36281b02b4214c5be1d834b6e2`.
Pinned base observer: `d72b67506e05c03f161201df7b9fc5430e2b136e`.
The candidate branch extends that observer with the Load journey. Its product
runtime also includes Replay changes; this is a full-product comparison, not a
cache-only ablation. The measured journey does not invoke Replay.

One genuine fresh baseline New Acc creates the current-format seed. Four separate
exported Windows processes then load identical full copies of that seed in
baseline/candidate, candidate/baseline order, on the same runner. All 74 input
file hashes match. Shader caches are included in that matched input; this is not
a cold OS/driver-cache experiment. No obsolete save archive or Steam upload is used.

| Measure | Baseline, AB / BA | Candidate, AB / BA |
|---|---:|---:|
| Load click to Ready | 6.745 / 7.073 s | 5.584 / 5.200 s |
| Load click to complete drawn caption | 6.907 / 7.232 s | 5.748 / 5.376 s |
| Log in click to complete drawn caption | 6.995 / 7.323 s | 5.838 / 5.466 s |
| Maximum Load frame gap | 6.845 / 7.172 s | 5.686 / 5.309 s |
| Configuration calls in Log in/Load scope | 26 / 26 | 26 / 26 |
| Compiler calls in Log in/Load scope | 2,396 / 2,396 | 4 / 4 |

Matched Load-click savings are 1.159 and 1.856 seconds (16.8% and 25.7%). The
complete Log in journey also improves in both orders. Backup screenshot/pointer
dwell is 44–45 ms and is reported separately. Compiler counts include cache hits;
they are not physical parse counts. Title timing is mixed: candidate is 1.024 s
slower in AB and 0.415 s faster in BA. No consistent startup speedup is claimed.
Load still stalls for several seconds. Two samples per variant do not establish
a statistical latency distribution or full-game performance coverage.

All five processes (seed plus four Loads) pass strict logs, actual Button input,
caption and clean-exit checks. Each Load confirms the saved gameplay, scene and
complete expanded reading checkpoint, unchanged source autosave, original run
identity, a newly allocated branch and a settled continuation journal. Identity
bookkeeping is allowed to change; full profile-byte equality after Load is not
claimed. The 10 downloaded durable output files per Load match their recorded
hashes. All 14 screenshot hashes pass, representing four distinct images.
The coordinator visually reviewed all four unique images: Title, selected
autosave and both loaded-caption variants. The saved caption and layout match;
the latter variants differ only in the visible clock. Independent visual review
also found no new defect.

`comparison.json` is the original exact sample and paired-difference report.
`cloud-evidence.tar.xz` retains all 52 non-profile files from the original evidence
artifact: reports, logs, screenshots and source/package/observer hash receipts.
`members.json` gives each original member's byte length and SHA-256. Every archived
member was reread and checked against it.
Archive SHA-256: `faca3413876ba40ffe35960a4331206088d2c20ac84295cfef6d645fe3e10122`.

Original full evidence artifact: `12609696448`, ZIP SHA-256
`4482bf00612f03d8bd6bd64fe3fcb7186c98b5e270c5cf031f790f9e677cac11`.
Exact packages remain in cloud artifact `12610305156` (not downloaded for this
retention audit); its reported digest is
`2486a4646e642b9f890efe6b8d70e80fd9332ac0c1537f7449f2a5fe01b5723f`.
Profile bytes and executable packages are omitted from this repository selection.
The cloud artifacts have a seven-day retention limit.

The diagnostic branch disables the product PR test trigger and must not be
merged. Preserve these evidence files on the product branch; final correctness
CI remains a separate acceptance gate.
