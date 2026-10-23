# Authored late continuation — 23 October 2026

Continue cloud-only Windows / Godot 4.6.3 standard. Read AGENTS.md and CLAUDE.md. User requests autonomous progress, minimal meaningful checks and smooth flow. No design question currently blocks the scoped work. Do not merge diagnostic overrides, change master/PR51 or upload Steam.

## Sources

Product: `codex/authored-week-followup-20261023`. PR30 is historical; PR50 is diagnostic controller `codex/story-day-qualification-20261023`. Master independently remains `d2062f8d9807f7f06935f86065640ff14a5400d6`.

Previous handoff: [reading costs](a-authored-reading-costs-20261023.md). Its next isolated patch was recovered from the prior worktree, reviewed independently and qualified.

Runtime `910027b4cfdd3ea8975a1b373db035b6c22d3488`, tree `99e432f78991518fa421cbda99adc38bd542837d`, reuses the fresh RunSnapshotSchema reading admission for anchor membership only with exact GameState/Bridge scripts and matching issuer/SaveManager owners. GameState separates semantic preparation from anchor joins; SoloReadingSession owns the matcher. Custom/terminal paths remain fresh, callback replacements are rechecked, and detached-input mutation refusal still wins over anchor failure. No cross-call proof cache or save schema change.

Independent reviews found and corrected a test gap: authenticated missing-publication and wrong-catalogue cases now explicitly bind the real creation owner and exercise the reused-reading path. Existing tests cover changed reading on later calls, custom Bridge fallback, callback replacement/mutation precedence and public first-anchor/empty-anchor ordering.

## Qualified bounded recovery

[Run39925757295](https://github.com/Siuuuers/dwm/actions/runs/39925757295), controller `4b36259a61e353eeeb45b7f9168cdd50a3353a02`: 19 passing cases / 384 assertions / four clean requested child exits. Suites: saved-event-anchor14, public-membership4, genuine Day2 recovery1. Original artifact12489691231 outer SHA256 `0af52236825eecc2477bfea8bf8981b9360de27cbb1cafe8f8e7e2b7cdee8611`; inner `6702a4c0f753bef2412e77976469b2adcd311dd5012d8b29c624a2863e9fcdcf`. Both ZIP CRCs and182 retained member hashes verified, source/tree/JUnit/process records checked, native continuation screenshot inspected.

Compared with c27f94a1/run39919967249 on the same genuine root:

| Operation | Prior | Candidate | Configuration calls |
| --- | ---: | ---: | ---: |
| Boot | 8.358 s | 8.442 s | 4 → 4 |
| Load | 57.289 s | 49.001 s | 58 → 30 |
| Control departure | 76.448 s | 71.595 s | 49 → 25 |
| Ordinary captions | .717 / .747 s | .706 / .734 s | 0 → 0 |

Load physical proofs remain29; departure62. Deterministic removal and modest elapsed improvement are established, not smooth performance. Ordinary timings include native test waits and input readiness; they are not pure game latency. Standalone caption-memory projection measured87.9ms at293 captions; no dominant ordinary-caption cause established. Do not perform speculative surgery on that path.

## Full journey failure and usable later root

[Run39920770730](https://github.com/Siuuuers/dwm/actions/runs/39920770730) on c27f94a1 failed; export was skipped. Creator passed1 case /4,287 assertions, exit0,469 captions to Day4 and real slot1 Save. Fresh Load PID2852 (creator5700) restored Day4 with exact state/Profile preservation, then recorded3,124 passing assertion records with no assertion/script-error markers before1800s timeout/exit124. No completed Load JUnit; replay never ran.

Last verified caption index805: `line.Day7.untouched.impulse.004`. Index806 `line.Day7.A.001` has only an advance-start record. Authentic autosave: checkpoint66,58 receipts,806 captions, entry `Day7.untouched.impulse`, control/program4, pending destination. Autosave SHA256 `53c3db44785b0296ac27bb24ea714cf5bd9f0d0ad86a173763d88438a5c5ce3b`.

Artifact12489238097 contains the whole40-file root (12 JSON/backup files) at `ci/native/authored-week/0/appdata/Godot/app_userdata/DWM/` inside `original-evidence.zip`. Outer SHA256 `86bcc222c600c352cac163d57b9006b7f61e5b83fe227f321aafd163a2b8d42f`; inner `a6945e7dff4bdde7180cf6a23c4f90a2672e0e0f1dfdf294178d60279ab92aba`. Both archive CRCs and66 retained hashes verified independently. Preserve the whole root; do not construct replacement authority/history. Compact exact logs are losslessly gzip-compressed in `evidence/phase_2r/authored_followup_20261023/run39920770730_comparison`; original full artifact remains on GitHub.

## Active bounded continuation

[Run39927141430](https://github.com/Siuuuers/dwm/actions/runs/39927141430), controller `44922e68cafbdfc7d54dc7daaafdd50626ff7530`, source `7f353cbb7b85744d36e8871ab70c4adfc1d026d8`, tree `b284ed0971c051a0d46126c9f0f52ae4111cd9f5`. Runtime is byte-identical to qualified910027b4; only `authored_week_late_recovery.gd` was added. Import and authenticated staging passed; recovery/replay outcome pending when written.

It restores the genuine Day7 interruption, verifies no repeated effects/publications/Profile consequences, finishes30 remaining captions, saves ending slot2, completes, then uses the existing fresh-process replay/New Game test. Expected successful evidence:31 recovery observations,36 completed phases,30 transition timings;23 replay/New Game observations; two passing cases and three clean seed/recovery/replay exits. Windows export/startup depends on success and uses the exact same source. Existing1800s per-process deadline is unchanged.

Collect this run before launching any duplicate. This establishes stitched route coverage and genuine recovery, not a passing uninterrupted full journey. The earlier full run remains failed. If late recovery fails, inspect its persistent pending_phase/profile/log before choosing a fix. No repeated artwork/Settings suite is needed.

Authored-followup PR trigger is retired. Authored-recovery PR trigger remains active for this bounded run: retire it before unrelated controller updates because PR path filters are cumulative. Diagnostic changes stay out of product. Keep exact final-source export and performance limitations explicit.
