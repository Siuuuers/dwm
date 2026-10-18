# A — Backup refresh notification correction, 18 October 2026

## Change and owner

BackupApp now skips a deferred projection notification only when this view already adopted a valid projection covering that notification's revision. BackupPresentationPort increments a presentation-only revision for every metadata/capability invalidation, including those coalesced into an already-queued publication. It still publishes to every subscriber.

The view captures the revision before reading and records it only after validation. Changes during/after a read require another refresh. Failed projections do not suppress retry; separate views track their own adoption; older injected ports without the optional getter retain unconditional refresh. Explicit refresh, action preparation and commit still inspect through existing owners. No SaveManager, persisted schema, file revision, restore admission, receipt or history rule changed.

This addresses the duplicate path established in [the phase diagnosis](a-post-save-phase-profile-20261018.md): successful _commit_pending refresh followed by deferred projection_changed refresh. It does not cache restore validation.

## Focused cloud qualification

[Run39124136055](https://github.com/Siuuuers/dwm/actions/runs/39124136055), job117665605713, succeeded with Godot4.6.3 standard GDScript and PowerShell on Windows cloud only.
Source8a431447b3fffa180b4cdd22fdc8f74a40e95d77; tree8aa17066accfc5ae8877780b50007acc16df0aea.
Controller1817a808e390030850d42eba086189ad8676f45f.

| Suite | Tests | XML assertions | Process exit |
| --- | ---: | ---: | ---: |
| Backup presentation | 11 | 3458 | 0 |
| Scene Backup inspection | 2 | 46 | 0 |
| Pause Backup host/custody | 13 | 320 | 0 |
| Total | 26 | 3824 | |

The five new tests cover successful Save/read counts and status with two views, changes during/after reading, failed-read retry and equal-number port replacement, getter-less ports, and every invalidation advancing the real port's revision despite coalesced delivery. Existing suites cover scene admission/cancelled consent, real record revisions, stale source refusal, recovery, parent custody and prepared-token cancellation.

A deliberate baseline used the original BackupApp from318e77ff454e6035d2ac1dbb7ef68885681a9ff4 with the candidate's additive port counter and new tests. The selected regression exited1 with exactly one failing testcase/two read-count assertion failures. It was not a parse failure or an unchanged whole-tree baseline. Candidate then passed all26 cases. Original failure retained.

Original ZIP84945bytes, SHA2564bf76fc2fb43204813056ee0d1dae44194d835a23bad9881bb292f24399cbfe9. All22 retained entries, six source blob pins, exact source/XML census and three exit receipts independently verified. Unit logs report orphans; this is clean process-exit evidence, not a leak-free claim. Scene stdout reports49 assertions while XML records46;3824 is specifically the XML count.

Tracked source is unchanged after testing except the two documented disposable-index gitlink removals. Import also generates untracked UID/image-import sidecars; these are recorded in final-status and not promoted. Scene-view revision adoption was source-reviewed; new mounted-view race tests use configure_backup.

## Publication limits and next work

Keep draft/unmerged; no integration/master change or release. Broad automatically triggered Windows CI is not accepted by this bounded result. B's completed fixture proposal remains queued after the active exported journey. The next export uses the tested runtime and a separate opt-in continuation harness; its outcome is recorded below.

## Exported continuation: previous boundary crossed, later observation failure retained

[Run39124502119](https://github.com/Siuuuers/dwm/actions/runs/39124502119), job117666685695, built a fresh export from63f1e4dbfe649039881d138541abd377a8639778, tree d8da757693c190bb6cde7eafdbeacaf02c7330cd. Its runtime matches the qualified source; the only additional source change is the isolated external PowerShell harness. Controller249f9598c91f5c8f8b32b7d2b1a5a6823226669d; driver blobd2003611a97c99626b72a727a56d0c9d55a72f55.

The harness adds opt-in ContinueAfterQuiet. Default diagnostic behavior still fails intentionally. Opt-in resumes all ordinary Saved/Back/state/ending/normal-exit gates without marking success early. Generic failure capture resumes after continuation. Native CDB/WER dump setup is not enabled in this controller. No timeout increased.

Package artifact12135278742, backup-refresh-package-39124502119-1:
- ZIP99457763bytes, SHA256ef5f3f19980064080a84a28bcae9f97db4feb41934a9f007bc828172394f3431.
- EXE SHA25691724f15024a3a545e28ccd83134403d31ce2323a38e51c95e4dfa282f732ab6.
- PCK SHA256cdf5c0063473c008faceea725f889abf58283c46dec107400f577b2f5b67419b.
- Packaging/headless startup and117 packaged runtime-data hashes passed.
- ProjectDefault renderer (D3D12 Forward+ Microsoft Basic Render Driver), Always accessibility, Dummy audio. Existing phase profiling enabled only in Load.

Observed correction: raw phase records contain one complete nine-locator inspection pass after successful witness Save, rather than the prior two. Save commit4.857508s; subsequent top-level inspection sum19.957882s (nested phases excluded). First responsive quiet native sample21.845184s; final11/40 samples respond. Fresh UIA returns75 descendants/one Saved; immediate native check responds on the original HWND. This demonstrates removed duplicated work and observed recovery in this run, not universal latency or hardware-performance acceptance.

The loader then:
- Captures Saved, invokes actual Back, and displays the full restored Day4 closing caption.
- Completes six restored-field comparisons, same-run/new-branch checks and whole Profile equality after Load/witness Save.
- Invokes the Day4 closing caption once to advance.
- Fails UIA_UNAVAILABLE_OR_TIMEOUT: TEST Day5 opening.

Crucially, the later failure screenshot visibly renders Day5 opening. The later failure tree contains the exact trimmed caption as a visible, enabled Button with InvokePattern, and the separate native probe finds the original HWND responsive. These observations occur after the timeout; they do not establish whether the transition/provider update was late or earlier UIA observations were stale. Preserve the original failure; do not weaken selector requirements or increase timeout as a fix.

Source slot1 remains byte-identical in retained failure evidence. Quiet-before/quiet-after Profile equality holds; after the actual Day5 advance, failure Profile differs only in visited_line_ids and witnessed_caption_variants for the newly observed Day5 line. That later difference must not be described as failed Load preservation or whole-run unchanged Profile.

Capability/Create pass with normal exit0. Load remains ok=false, forced cleanup-1. Ending, Gallery completion and normal loader shutdown are not reached. This is bounded post-Save/Back evidence, not complete exported-journey acceptance.

Original evidence ZIP894954bytes, SHA256c3d9e119c986c1ca54b47705cfced62232d6b3b0c96c928a21d511706ecc03e7; all149 retained entries, inner mode manifests, source pins and phase sequence independently verified. Actual restored/failure images reviewed independently.

## Concrete next action

Keep this runtime correction. Reuse artifact12135278742 if still available; no rebuild is needed for harness-only work. At the Day4→Day5 boundary, retain bounded polling diagnostics for candidate caption name, enabled state, bounds and InvokePattern together with native responsiveness. Separate observed caption from actionable caption diagnostically while preserving the existing acceptance gate. This will distinguish delayed transition/readiness from stale observation before another correction.

Do not repeat completed unit/custody campaigns or prior snapshot audits merely to restate them. Once the observation boundary is resolved, finish ending/Gallery/normal-exit checks, then B's existing scoped fixture corrections and the established framework/author-guide handoff.
