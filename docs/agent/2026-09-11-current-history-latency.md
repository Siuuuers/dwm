# Current-history latency follow-up, September 11

The earlier playtest used a September 9 snapshot. The new report reproduced with an isolated September 11 copy: 17 files, 8.4 MB, including a 299 KB issuer root, 496 KB publication history, and 910 KB continuation journal. Source hashes were unchanged during the copy; all writes occurred in isolated test roots.

## Measured results

Godot 4.6.3 on the local Windows machine, using the same copied history and board action sequence. These are observed local runs, not platform timing guarantees.

| Action | Before this follow-up | Final |
| --- | ---: | ---: |
| Account startup after confirming Start | 23.37 s | 3.60 s |
| Longest startup frame gap | 3,678 ms | 301 ms |
| First Reveal | 835 ms | 367-370 ms |
| Winning Reveal | 6.914 s | 1.006 s |
| Losing Reveal | No matched loss baseline | 885 ms |
| Ordinary Reveal/Flag | Not measured | 67-78 ms |

Board materialization itself took 0.386 ms. Seed preloading would not meaningfully improve the measured first-Reveal delay; persistence and receipt processing dominate. The board generator, dimensions, pressure-adjusted mine count, and first-click rules are unchanged.

Native idle pacing varied between roughly 18 and 265 ms per frame across runs. The startup verifier measures preparation, startup, and idle separately, excludes screenshot readback, and rejects startup gaps above max(350 ms, idle max + 100 ms). It also verifies wall-clock dot cadence and mutation custody during actual saving.

## Changes and boundaries

- Canonical JSON composition verifies scalar exactness without reparsing each entire emitted document. The old writer and new writer matched all 1,177 deterministic compatibility cases, including exact bytes, float refusal, Unicode, and structural-error precedence. Native escaping applies only to printable ASCII; control and Unicode handling retain the original path.
- Continuation serialization reuses detached, type-equal operation text. Strict parsing and cold schema validation remain; syntax proofs and validated documents are bounded and keyed by exact text.
- Issuer writes reuse cold parser proofs in the existing three-text window. Read/restart still validates the full issuer laws.
- Publication appends preserve every historical receipt, normalize the new record once, and reuse at most three exact parsed documents. Syntax-only cache entries still require domain validation before public use. Changed bytes and schema-invalid documents fail closed; readback must match the exact outgoing payload.
- Title dots use elapsed monotonic time. SaveManager yields at existing completed-operation boundaries after an 8 ms work budget, with the complete intent retained, busy guard set, and mutation lease held. Initial title painting, synchronous APIs, and atomic writes are preserved.

The required preterminal board save and complete-outcome save remain. No seed bank, background worker, new persistence protocol, or intermediate-stage disk save was introduced. Outcome completion still takes around one second with this large history; this is a substantial reduction, not a claim of instantaneous or universally lag-free gameplay.

## Verification

The 1,177-case legacy differential had zero mismatches. Focused serializer/storage tests passed (34 tests), issuer/continuation/consent/lifetime checks passed (93 tests), and the cold-recovery regression suites passed (13 tests). Publication cache rejection and startup retry tests also passed. Nine final isolated fresh-process phases passed: completed and interrupted round write/read pairs, completed and interrupted Day 2 write/read pairs, and legacy-save loading. Existing test-harness orphan/cleanup reports remain; this is not a whole-game leak-free claim.

Recovery verification additionally found a real startup ordering bug: an interrupted New Run could finish recovery and activate its session before a later cold-recovery check, which then rejected startup even with no pending action. The helper now permits only the proven no-pending no-op; actual pending actions and retained prepared sources still require an inactive session. The unchanged failing integration test passed after this fix. Local logs are under `.godot/phase2r_logs/`: `canonical-native-differential.log`, `canonical-final-checks.log`, `new-account-final-owned-tests.log`, `new-account-current-atomic-boundaries.log`, `latency-final-ledger-retry.log`, `board-latency-fresh-lru-win.log`, and `board-latency-fresh-lru-loss.log`, `cold-recovery-active-session-fix.log`, and `recovery-*-20260911-latency-followup.log`.

Long manual/dialogue-history stress remains tracked in `dwm-634`. The unrelated intermittent ordinary-reply report remains in `dwm-hsi`; this pass does not claim to reproduce or fix it. Final story, artwork, and export verification remain separate from these performance fixes.
