# Authored late continuation — 23 October 2026

Continue cloud-only Windows / Godot 4.6.3 standard. Read AGENTS.md and CLAUDE.md. User requests autonomous progress, minimal meaningful checks and smooth flow. No design question currently blocks the scoped work. Do not merge diagnostic overrides, change master/PR51 or upload Steam.

## Completed boundary

Corrected run39929612232 passed both late-recovery/replay and exact-source Windows export/startup jobs. No cloud run remains pending for this candidate. The next independent task is measured terminal-admission performance, scoped below. A fresh session now avoids carrying this long qualification history into that patch. No design question blocks it.

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

## Bounded continuation and navigation correction

[Run39927141430](https://github.com/Siuuuers/dwm/actions/runs/39927141430), controller `44922e68cafbdfc7d54dc7daaafdd50626ff7530`, source `7f353cbb7b85744d36e8871ab70c4adfc1d026d8`, tree `b284ed0971c051a0d46126c9f0f52ae4111cd9f5`. Runtime is byte-identical to qualified910027b4; only `authored_week_late_recovery.gd` was added. Run failed after genuine Day7 recovery and entry into the ending. All source history/consequences checks passed and slot2 was physically written. The helper then clicked `_sheet_back`, which is deliberately hidden for the ordinary ending Pause host. This is a harness route assumption, not a readiness delay or failed disk Save. Result:362 passing/1 failing assertions, seed exit0/test exit1; replay never ran and export was skipped. Artifact12490497031 outer SHA256 `d4465fb60ba582cd6ff28bd9b49521d6aa7d4f2fbf387820809604b56a9244da`, inner `dc47fa7f0cd8eca5edf4907ad2a42135d2d61babe17a7eb8a035fba940aa068e`; both CRCs and120 retained hashes verified. Exact compressed logs and failure metadata are retained at `run39927141430_failed_ending_navigation`.

It restores the genuine Day7 interruption, verifies no repeated effects/publications/Profile consequences, finishes30 remaining captions, saves ending slot2, completes, then uses the existing fresh-process replay/New Game test. Verified successful evidence in the corrected retry:31 recovery observations,36 completed phases,30 transition timings;23 replay/New Game observations; two passing cases and three clean seed/recovery/replay exits. Windows export/startup depends on success and uses the exact same source. Existing1800s per-process deadline is unchanged.

The corrected retry has now completed; no duplicate is needed. This establishes stitched route coverage and genuine recovery, not a passing uninterrupted full journey. The earlier full run remains failed. If late recovery fails, inspect its persistent pending_phase/profile/log before choosing a fix. No repeated artwork/Settings suite is needed.

Both authored-followup and authored-recovery automatic PR triggers are retired. Controller commit `7dab26a826b8fc2c5929625fe3d70d4d90c1ed84` removed the latter after journey success; manual dispatch remains. Diagnostic changes stay out of product. Keep exact final-source export and performance limitations explicit.

### Corrected retry (passed)

[Run39929612232](https://github.com/Siuuuers/dwm/actions/runs/39929612232), controller `d6bf43200e5f24f25b0864becd953b8eb7df1a2f`, source `3c9fb089d8f15329fcb4f8e8efe6e83f2e3aa873`, tree `71c1e1b88e9f1d51472c6f12dc44701949d8aa00`. Runtime is unchanged. The authored Save helper keeps direct-host Back for scenes; ending uses real Escape to leave Backup, verifies the host closed, then clicks Continue, retaining unpaused/frontier/disk checks. Independent review confirmed physical key release before Continue and existing input custody. The new late test UID `uid://bp1pchbloqeq2` comes from the failed run's genuine editor import.

Only the same two late/replay cases repeated; no anchor/artwork/settings suite. Late root measurements: Load114.161s, control163.990s, ending-entry68.837s, Save-panel operation408.744s (including opening/capture/save, ending at harness navigation refusal). This is not smooth flow. The Save-panel profile records791 bundle validations/169.095s and123 configurations/12.457s, overlapping other scopes. Do not label the whole408s as disk-writing time or add inclusive timings.

### Final verified evidence

Run39929612232 passed: recovery692 assertions, replay300, total992 across two cases; seed/recovery/replay all exit0 with distinct PIDs3308/592/5684. Recovery took19m15s and replay28m08s including process setup. Both endings reach COMPLETED/GALLERY_RECORDED; replay preserves the single Gallery receipt and slots1/2, then starts a fresh PLAYING Day1 RunID with no ending_plan.31 recovery captions and23 replay/NewGame observations match the ending suffix. Independent review agrees; restored-ending and fresh-Day1 native screenshots were visually inspected.

Journey artifact12493716326: outer SHA256 `4e084890be753b58fbb650a750d6efa864047ad567943ec8bfd2b0f4c16415e2`; inner `f02fba7da271befce0ff674e7e31b050cb94edc684b76f3d1a8c20511b4162e1`. Both CRCs and128 retained hashes verified. Compact evidence and lossless logs: `evidence/phase_2r/authored_followup_20261023/run39929612232_late_success`.

The complete authentic40-file post-replay root is also preserved there as `genuine-post-replay-root.zip`, SHA256 `82251bc333baaccdc4c1de38fb175f72b411466b8c4583d41e8fc7fc09edc029`. It retains12 JSON/backup documents. **Autosave is now fresh Day1; use slot2 for the genuine ending Load baseline.** Slot2 remains PRIMARY_PENDING, checkpoint71,61receipts, first ending caption plus814 retained source-scene captions in ending_plan. This is not the original pre-save ending root. Preserve all authority/history files and use isolated copies for paired measurements.

Successful profiled operations: late Load118.334s, control departure171.827s, ending entry69.386s, whole ending Save395.709s, completion293.652s. Save includes791 structural checks/161.869s,123 configurations and306 physical proofs; completion739 structural checks/143.206s,66 configurations and253 physical proofs. Inclusive times overlap. The replay process takes28minutes; no claim of smooth performance. Its ordinary ending advances measure126–164ms in that harness, while recovery's broader phase timings include additional waits/checks and are not directly comparable.

Windows export job120354018836 passed on exact source3c9fb089/tree71c1e1b8. Scope: unsigned x86_64 release export,136 packaged runtime-data files checked, isolated headless startup240iterations with a fresh profile. It does not establish graphical export/UIA/screen-reader/full release acceptance. Artifact12494051068 SHA256 `0823b5508db16ac4de11653d18ef6462d17bcad70cb69be1120643c29b8b2b45`; package `DWM-windows-x86_64-validation.zip` SHA256 `b4a9da5b0e756cde8ec164f6bd4067b9a56055d3d3f09ce31e58cebc76b918d4`. Both archive CRCs,13 retained hashes and19 packaged file hashes independently verified. Executable SHA256 `91724f15024a3a545e28ccd83134403d31ce2323a38e51c95e4dfa282f732ab6`; PCK `fb30ecbe4cbe11c2f1f9928b700cabf70844cf269359555122fbb034b066f52b`. Compact validation/logs: `run39929612232_export`. Build remains in the Actions artifact (expires22November2026); no Steam upload.

The original full journey39920770730 remains failed at its deadline. Successful stitched recovery and replay must not be relabeled an uninterrupted full-week pass. Master remainsd2062f8d; PR51 head remains328edfe0. No merge performed.

### Measured next performance target (read-only)

The failed ending Save-panel operation includes85 complete Run validations,35 terminal. RunSnapshotSchema's terminal/custom independent receipt call could use the existing selected-receipt API after its earlier exact selected-bundle equality gate, retaining fresh authentication; this removes only one bundle check per qualifying Run validation.

The larger repeated path: SceneEventContract.validate_scene_terminal_admission calls generic validate_scene_receipts and rebuilds through make_scene_terminal_admission, each rechecking structural registration. RunSnapshotSchema's terminal reading validation and FrozenRunContext's terminal/full/checkpoint paths invoke that admission repeatedly. A selected terminal-admission entry point could reuse the already recursively frozen canonical tables while retaining fresh receipt/issuer/Profile/trigger proof. Keep public arbitrary-bundle APIs fresh. Required focused coverage: valid terminal input; changed receipt/trigger/issuer/physical Profile on subsequent calls; altered arbitrary-bundle refusal. Measure complete ending Load/Save afterward. No player-design change is currently needed. This is a proposed next patch, not implemented or qualified.169.095s bundle time is nested inside261.131s receipt time: do not sum or promise that whole amount as a speedup.

Independent read-only review narrowed that proposal:

- Add `SceneEventContract.validate_selected_scene_terminal_admission(record, issuer, receipts, creation_owner, contacts)`, obtaining tables only from `DialogicEntryManifest.scene_contract_tables()`. Share the constructor's validated-table body privately; accept no caller-supplied trusted tables, cached receipts or bypass flags.
- Switch RunSnapshotSchema's terminal-reading call and FrozenRunContext's `_validate_scene_terminal()` to this selected API. Preserve FrozenRunContext's existing full/checkpoint receipt calls. Leave GameState ending creation/retry and RunSnapshotSchema's independent input-fields path unchanged initially.
- Preserve generic constructor/validator arbitrary-bundle validation order, terminal source-reading history, anchors, reconstructed-record equality, issuer order, trigger hash, creation and physical Profile proof. No saved-byte or checkpoint-policy changes.
- Extend existing terminal-lifecycle coverage, but do not mistake its synthetic bundle fixture for selected-owner coverage. Use an actually installed registration and authenticated terminal fixture: valid equivalence, changed trigger/receipt/issuer/record or physical Profile on later calls, then valid input again. Assert fewer structural checks with unchanged receipt/physical-proof counts.
- Compare complete ending Save/Load from isolated copies of the same genuine ending root, preferably paired on one cloud runner. A lower check count proves work removal; wall-time benefit remains unproven if costs move elsewhere, total time fails to improve beyond variation, or unchanged phases improve equally. Repeat only the relevant ending/replay journey, not artwork or the full week.

Exact tree comparison of source `3c9fb089` and product `3acf937d` found no difference in `autoload`, `scripts`, `scenes`, `tests`, `project.godot` or `export_presets.cfg`.
