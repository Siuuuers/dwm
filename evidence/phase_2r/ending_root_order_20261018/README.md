# Ending root-order experiment — change applied, native gate still failed

Updated 19 October 2026 Hong Kong time (18 October UTC).

**The corrected root-order experiment passed its focused recovery suite but failed the original native ending-caption gate. The intended node order was observed in the actual exported player before the first ending action query. Changing this order is therefore insufficient to resolve caption discovery in this pinned diagnostic run. Both attempts are retained; neither this ordering helper nor the earlier reconstruction candidate is promoted to PR36.**

This checkpoint adds evidence and the continuation handoff only. PR36 remains draft and unmerged. Product runtime remains `bf1c46715f0698dbcf9c2b9d1ca6e946a6dde74f`; master and integration remain at their recorded commits.

## Observable outcome and ownership

The proposed outcome was that the original native driver could discover the unique actionable `TEST Seven-day ending.` caption within its unchanged 30-second gate, then complete its original durable ending/Gallery-award/Title-return/normal-exit tail. Correct local recovery ordering and input custody were prerequisites. A later screenshot or passing headless tests could not substitute for that native result.

EndingScene remained the sole owner of the local recovery adjustment. Its deferred helper reads the current canonical layout metadata and moves only its own root sibling position:

- Hidden recovery: EndingScene after the caption CanvasLayer.
- Visible recovery: EndingScene before that CanvasLayer.
- Retired scene, absent/freed/queued layout, different root parent, or already-correct order: no move.

Existing caption providers, pause services, drawing layers, signals, checkpoints, authority checks and history owners were retained. No manager, cross-call cache, accessibility getter/refresh, timer or wider router/addon change was introduced.

The focused additions exercise a later technical playback failure followed by focused Retry of the same command, and stale deferred work after scene retirement or freed metadata. They are headless scene-integration tests with simulated input/focus, not rendered native recovery acceptance. The existing nine test bodies remain intact.

## Original attempts

| Item | Attempt 1 | Corrected attempt 2 |
| --- | --- | --- |
| Cloud run | [39155054285](https://github.com/Siuuuers/dwm/actions/runs/39155054285) | [39155624496](https://github.com/Siuuuers/dwm/actions/runs/39155624496) |
| Source | `a25fae335247ba8074ea01d44990b3c6cd00f8ba` | `81847d8b1560340a3a7769223cee0b46c6bdc0f9` |
| Tree | `6c44631f8f926461d86b44f29c25c970c22218e9` | `4581a9f12d63684836c722f72cffd533491f3c06` |
| Controller | `fb8377d546b32542975b867e76de51a619d047ab` | `cf1ffe0ec204cc51ecc532e4a95136f9177577d1` |
| Focused XML | 11 methods /144 assertions; 2 failed methods | 11 methods /142 assertions; all pass |
| Focused outer /child exits | 1 /1 | 0 /0 |
| Capability /Create | Not executed /not executed | Passed /passed; clean player and driver exits0 |
| Load | Not executed | Failed ending caption; player-1 /driver1, forced cleanup |
| Final original acceptance | False | False |
| Retained record | [attempt1](attempt1/README.md) | [attempt2](attempt2/README.md) |

All Godot and PowerShell execution was on the cloud Windows Server2022 runner with Godot4.6.3 standard GDScript. Local retention and independent verification use Python/source inspection only.

### The initial failure was real and remains visible

The first focused execution retained four generic engine ERROR lines for missing `dialogic_layout_node` metadata, two from the new fixture and two from the new runtime helper. The two new methods failed despite their explicit behavioral assertions succeeding. Export and all native modes were skipped after the strict focused gate rejected the attempt.

The corrected source adds an explicit metadata-presence guard before the runtime read and uses the fixture's already-captured presence flag before its saved-metadata read. No test body or assertion site, generic error rejection, deadline or external driver command was weakened. The retry controller differs from the initial controller only in candidate commit/tree pins. Both tiny source corrections were independently reviewed before dispatch.

## Corrected retry: what the original evidence establishes

The focused suite passes **11 tests and142 XML assertions**, zero failures/errors/skips, both process exits0 and no generic ERROR matches. Import, parser, the four original deadline checks and export validation also pass. Capability and Create complete with clean player/driver exits0.

Load still ends with the original refusal:

> `UIA_UNAVAILABLE_OR_TIMEOUT: TEST Seven-day ending.`

The original 30-second wait ends at **30.0222674 seconds**. The first successful native window acquisition finishes at **26.6995454 seconds**. Fourteen caption-action queries complete between **26.772564 and29.9762196 seconds**; every query returns zero matches. Player exit-1, driver exit1 and forced cleanup remain failures.

Only the primary Load stdout contributes to the publication timeline: **109,105 bytes**, SHA256 `4784bd05e387fe9c6e84790c99c86449a38c159153147955f0e2ef293be5af51`, **six** trace records and**112** profile records. The trace PID7264 matches the original Load process; the native driver separately records HWND524500. This does not map a Godot instance/RID to a UIA identifier.

The trace records show:

- At text start, the canonical caption layout is root index16 and EndingScene17.
- At every later retained boundary, the same layout is index15 and EndingScene16. Natural Canvas/caption notifications already have this intended order before the first original action query.
- The sampled Canvas is visible and unwithdrawn; its natural update writes hidden=false.
- Natural caption callbacks use a valid existing element/provider and the correct ending name and button role.
- At the retained settled samples, Next/bridge, caption-owned reading recovery, Pause, Load/History and timed hold are inactive. These samples do not establish continuous state or directly observe EndingScene recovery-panel visibility.
- The follow-up is2.012159 seconds after text-finished. Its counter records46 caption callbacks; only two were emitted. The cap deliberately prevents this from being a full notification history.

The later failure capture shows the exact ending caption plus six controls. The later unfiltered native dump contains23 descendants, begins with the existing Pause rows, and omits the ending caption. The screenshot, dump and in-budget action queries are sequential observations. They do not prove an atomic visual/provider state or a specific engine cause.

The adjustment was applied and the original native gate still failed. No further ordering or equivalent Raw/FindAll campaign is supported merely to restate that result.

## Save, recovery and qualification limits

Independent verification confirms equality of the six restored snapshot fields: narrative checkpoint, gameplay, scene, command receipts, applied effect transactions and applied variable transactions. The restore retains the run identity and creates the expected new branch. Retained Slot1 captures match Create's original bytes, and the restored-slot and before/after-witness Profile comparisons pass. The failed Load did not reach its final post-exit source-slot hash guard; continuous immutability is not newly certified.

The focused recovery tests protect their bounded behavior, and the original saved-data custody checks remain strict. This does not newly certify every interruption point or every recovery UI path.

The failed ending gate supplies no successful completed-autosave, final durable Gallery award, Title-return or normal Load-exit acceptance. The driver's future Gallery check concerns lifecycle/transaction/unlock state; it does not establish a Gallery UI visit. Broad CI remains unqualified. No new performance comparison was conducted in either order attempt; the earlier [receipt reconstruction comparison](../receipt_reconstruction_comparison_20261018/README.md) remains the sole matched experiment.

## Reproduce the independent checks

Both original ZIPs are retained unchanged:

| Archive | Bytes | SHA256 |
| --- | ---: | --- |
| [Attempt1 original-evidence.zip](attempt1/original-evidence.zip) | 760741 | `d47951af394a5433b5b923409ea5d45d55c5292fb4321facf7589e38d55e842e` |
| [Attempt2 original-evidence.zip](attempt2/original-evidence.zip) | 2566525 | `d3fe288fe60167a2dda044c7a2d8962b0c88c789a5044f4347cb9b78993544cc` |

The shared [verify.py](verify.py) is independently authored and peer-reviewed, SHA256 `052ee52a800693653a8a05d5de9889e6b2cce04f52976580c2cb3bc0747b8da6`. It accepts only the two pinned attempts and checks original byte/hash custody, exact source and controller identities, manifests, precise source-derived method census, positive assertions, both focused process exits, generic engine errors, native evidence completeness, original mode outcomes and the retained trace/save evidence.

From this directory:

```bash
python verify.py attempt1/original-evidence.zip attempt1/archive-receipt.json attempt1/verification.json
python verify.py attempt2/original-evidence.zip attempt2/archive-receipt.json attempt2/verification.json
```

The first command intentionally exits1 because its focused suite failed. The second exits0 because archive/source/harness/focused qualification passed; its separate **original_journey_passed=false** and **original_acceptance_passed=false** fields retain the failed native result. Verifier process success is not exported journey acceptance.

Attempt1 has76 hashed outer payload members plus its manifest and exact30+30 source snapshots. Attempt2 has240 hashed outer payload members plus its manifest,149 mode-manifest payloads (22 Capability /57 Create /70 Load), and exact30+30 source snapshots. Both retain complete controller/source evidence and the original final gate. The verifier distinguishes unexecuted modes from missing evidence for executed modes and requires original events plus redirected stdout/stderr for a launched player.

The separate executable artifact for attempt2 is `forward-profile-package-39155624496-1`, Actions artifact12146662424, expiring25 October UTC. Export receipts bind its inner99,457,801-byte ZIP to SHA256 `7c3053d2073fc3caee98dc5c038e720d5e860952375039d0db054dcd14812eb8`. That binary payload is not inside these evidence archives and was not independently rehashed locally. Attempt1 produced no executable package because its focused gate stopped execution.

## Decision and next boundary

Keep the reconstruction candidate and root-order candidate on their isolated branches. The conditional composed-controller draft was not dispatched and is unqualified. PR36 receives this evidence and handoff only.

The read-only [next publication boundary](next-publication-boundary.md) identifies the unobserved accessibility parent-child chain between active window root and current caption. Its source review is complete; actual emitted/retained edge evidence is missing. A later task must specify a new observation that distinguishes an incomplete submitted chain from adapter/provider omission while preserving the standard engine/cloud-only constraints and original acceptance gates. The current trace justifies neither an engine patch nor another guessed runtime fix.

Internal source and evidence reviews are complete for this checkpoint. External Coordinator C has not yet reviewed these new runs. B's two historical-fixture corrections remain queued behind the active ending boundary. The existing author guide/inventory remains canonical, and master/integration are unchanged.

