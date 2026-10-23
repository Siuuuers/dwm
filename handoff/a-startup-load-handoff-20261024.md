# Startup and Load efficiency handoff — 2026-10-24 (Hong Kong)

## Accepted source

PR [#55](https://github.com/Siuuuers/dwm/pull/55) merged as `153f17bbe7ed8d6b4080e8c7991a06658108202b`, tree `3f3a43fc892fd078c4b6bfae6d1a5be9d716f96a`. PR [#56](https://github.com/Siuuuers/dwm/pull/56) merged as `10a4dae0ae50ddc4f28158347261ec9be558a49a`, tree `2f69e073325c111a634ba440a4e964eaa8cd8573`. Both merged trees equal their qualified source trees. Duplicate post-merge CI was skipped; this did not bypass an unpassed test.

The compiler now performs its resource-type load only when its existing per-path cache is absent or physical text changes. Fresh file reads and argument-sensitive, detached compiled results remain. The registration has 92 entries sharing seven Day files: 10, 12, 13, 12, 13, 12 and 20 references respectively. Repeated loader messages were redundant calls, not evidence by themselves of repeated physical disk reads.

Hidden Backup windows invalidate their projection on changed notifications instead of inspecting all slots. Preview, entry, reopening, actions and visible updates keep their existing fresh checks. ProfileManager reuses one strict-JSON parse for exact matching text up to 1 MiB; this bounds source size, not exact heap memory. Schema validation still runs on detached input every time. Physical storage reads, revision/hash checks, canonical serialization, mutable registry checks and receipt comparison remain intact.

CI selects a small suite set only for the exact reviewed private-method/test/tool scope. Changes elsewhere and manual dispatch retain full validation. This is not a new claim of full-game acceptance beyond the prior integrated handoff.

## Cloud acceptance and measurements

- [Run 39996703616](https://github.com/Siuuuers/dwm/actions/runs/39996703616): five suites, 72 cases / 5,131 assertions, plus two native variants with 112 assertions each.
- [Run 39997322266](https://github.com/Siuuuers/dwm/actions/runs/39997322266): six suites, 116 cases / 5,711 assertions, plus two native variants with 112 assertions each. This includes the prior five-suite coverage; do not sum it as disjoint coverage.
- [Run 39999976015](https://github.com/Siuuuers/dwm/actions/runs/39999976015): candidate-first repeat, two native variants with 112 assertions each. Diagnostic source `8a90bec16706eefb7cd94429c6f3d9a251eb0a36` changes only the measurement order and adds its isolated workflow. It is not product source.

All selected cases passed, with no failed, errored or skipped cases. Broad jobs were intentionally not selected. All native runs used fresh processes and isolated user roots, the identical retained 40-file input, four checked helper hashes, and source slot SHA-256 `17934c8199a7d25f97c69890f0ca609e5106c6bb6dc187464d58c40d2baf987c`. The retained helper archive SHA-256 is `c49053565e4b9430f2e9f0157eea9c1602898156de13df2837ca714235279670`. Actual runtime hashes were checked against the intended revisions. Rendered post-Load and post-Save captures were inspected for every variant.

Seconds, baseline → candidate, each comparison on its own runner:

| Comparison | Boot helper | Complete Load | Load to Ready | Complete Save |
| --- | ---: | ---: | ---: | ---: |
| #55, baseline first | 53.522 → 52.625 | 343.961 → 333.758 | 253.091 → 246.447 | 221.537 → 210.812 |
| #56, baseline first | 40.702 → 38.406 | 275.353 → 245.603 | 207.495 → 181.184 | 167.240 → 175.062 |
| #56, candidate first | 53.035 → 51.988 | 338.395 → 317.397 | 250.372 → 235.182 | 225.074 → 207.274 |

The #55 complete-journey Day loader-message count fell 20,772 → 15. Both #56 variants retain 15 messages. This is not a startup-only count. Boot begins inside the helper after process startup; it is not launch-to-Title latency. Complete Load/Save include the helper's verification and capture. Ready is the existing live-session signal. Press-return timings include five existing frame waits. Nested timings overlap and must not be added.

Accept #56 for Load improvement reproduced in both orders (6.2–10.8% for the complete helper). Save observations are mixed: +4.7% time in the first pair, −7.9% in the reversed pair. Corresponding validation call counts match in all four executions; physical-proof work improves in both orders. Unchanged routines slowed later in the first candidate, which suggests variability but does not establish its cause. No universal Save-speed or latency-distribution claim is warranted. The substantial remaining pauses are real; the game is not yet smooth on this workload.

The native helper verifies restored caption visibility/full reveal/DONE state, exact ledger/checkpoint semantics, preserved gameplay and unchanged Profile, then Save and Continue. It does not rerun the full uninterrupted authored week, every branch, Steam packaging or release installation.

## Durable evidence

See [`results.json`](../evidence/phase_2r/startup_load_20261024/results.json) and [`exact-evidence.zip`](../evidence/phase_2r/startup_load_20261024/exact-evidence.zip). The ZIP preserves exact uncompressed bytes of every member of all 14 original Actions artifacts, deduplicated as `objects/<sha256>`. Its `manifest.json` maps each original member path to the object, records original archive hashes and GitHub artifact metadata, and permits member-by-member verification. Original ZIP container bytes are not preserved in this compact bundle. Bundle SHA-256: `995ab5831653ef1d5d1d19c16471ceade8ade14ab5027f66b52286931cbcbbbe`.

## Next product decision

Backup currently performs full admission and restore-participant preparation for every displayed slot before presenting the list. Proposed next outcome: present basic save details before those expensive checks, and fully validate the chosen save before restoration.

Choose whether clicking Load should begin that check, or selecting a slot should automatically check it while Load remains disabled. Click-time validation is the smaller route to browsable metadata. Selected-slot checking preserves the current button promise, but the synchronous check must be sliced to avoid freezing browsing; `call_deferred` alone does not solve this. Title currently selects the first proven-loadable slot, so initial selection and honest unverified/incompatible labels need explicit treatment. Never describe unadmitted scene-shaped bytes as an admitted scene save.

Keep `prepare_backup_action` and commit freshness authoritative. A restore lease alone cannot justify caching every proof: Profile adoption and issuer allocation change state within that lease, and it does not freeze physical files or mutable registries. Further reuse should be within an unchanged owner phase and should follow attribution, not deletion of expensive checks.

No unresolved internal implementation choice blocked the accepted changes. This Backup presentation choice is the next user-facing design boundary. No new session is required merely to answer it.

## Branch and PR preservation

Historical drafts #14, #30 and #50 remain preserved; they are not finished product changes waiting to be blindly merged. Earlier functional integration already reached master through #52. All branches remain intact, including the new diagnostic branch `codex/profile-parse-reverse-check-20261024`. Do not merge that diagnostic controller into product source or reapply older superseded implementations.
