# A — Load caption memory correction, 17 October 2026

Load now restores preceding visible captions and older local scrollback from witnessed history within the active scene occurrence. The native saved current line remains fully revealed; no text replay, save-schema change, new history owner or story/effect advancement is introduced.

## Implementation
- SoloReadingSession.project_scene_caption_memory reuses the validated existing scene projection, joins by authenticated publication IDs and filters the exact active occurrence and entry. Re-entering the same entry cannot borrow earlier occurrence text. Full History remains unchanged.
- DialogicBridge.get_scene_caption_memory binds this projection to the exact live renderer proof (playback token, session and publication), rejecting stale proofs.
- WitnessedCaptionLayer's existing deferred session refresh rebuilds at most two preceding visible copies and all older same-occurrence scrollback. It caches the successful projection, restores local review to live on reconstruction, and leaves current native reveal and current speech ownership untouched. The existing short reprojection API retains its default behavior.
- The existing Day4 creator/loader is reused. A bounded Load-only selector stops after verifying and capturing Day4; it does not repeat Days5–7 or the ending.

## Verified result
[Windows cloud run153](https://github.com/Siuuuers/dwm/actions/runs/39031871204), job117393781308, passed all five selected cases and five isolated process exits. Godot4.6.3 standard GDScript; all engine/PowerShell execution cloud-only.

| Selected case | Testcase assertions |
| --- | ---: |
| Authentic repeated publications, pure projection and same-entry/new-occurrence filtering | 28 |
| Longer scrollback, three-caption window, live review restoration and current-speech preservation | 34 |
| Existing retained-caption reprojection and remeasurement regression | 232 |
| Existing normal Title → Day4 Save creator | 102 |
| Fresh-process Day4 Load-only check | 58 |
| Total | 454 |

The unit before_all adds one setup assertion to the textual log, so log total455 differs from testcase XML454. Counts above use the strict testcase census.

Fresh Load shows TEST Day4 opening above TEST Day4 closing. All eight witnessed history entries remain; the local window contains only Day4. Current line is fully revealed at Ready. Exact saved checkpoint/ledger, story/effect receipt collections and Profile are preserved. Repeated refresh leaves the native event index/checkpoint/window unchanged; a stale playback proof refuses. The longer-memory and re-entry checks are bounded detached-owner and mounted-layer checks, not another long saved-run journey.

Visually inspected both original source and restored992×558 English100% pixel captures. Both captions are legible and unobscured; ordinary clock/transport placement is retained. The final restored PNG is copied unchanged beside the archives for review. Ending projection/layout paths remain intact; no new ending qualification is claimed.

## Provenance and retained evidence
- Qualified source:21239126c2faa3bda37c74409b99cac5530696bc
- Exact tested tree:282650ee183366702f3449967b34e22e78921c9b
- Controller:e31013ff449b0ba5a4145edeee811de31394fbba
- Original qualification archive:231621 bytes; SHA256573a96abe91cf0be5f5297cd8a74a97be077f4af00eeaffa6608b734ff2d23c3.
- Downloaded Actions artifact12100835975:231950 bytes; SHA256e19a543c30764beea3a34891a131f22849e2f9c6f81f6b61497dc72e39fc1d73.
- Independently verified all33 manifest entries, retained source copies against the pinned commit, exact source-derived five-test XML census, clean logs and all five child exits.
- Initial run152/39031760428 on source1ecf0d1e145281a188492b81bd03fb476ff48d37 failed project import because Bridge's dynamic session call needed an explicit Dictionary return variable. No tests ran; it remains a failed attempt. The corrected source also preserves current speech during older-copy refresh, identified during source review.
- Original failed-import archive:137150 bytes; SHA25692a7370190e27a992e466497d37e3547257b580310d27b392f6f93256b2f47c9.

Archives are retained under evidence/phase_2r/load_caption_memory_20261017/. The evidence commit adds only this handoff, original archives and the copied restored PNG.

## Handoff
C can review the actual implementation and restored capture against6215647495. B's corrected PR37 partner-fork packet remains next: sole Yes selects Sylvia; manual/Auto boundary passage selects Lavinia; Auto continues normally and Computer-open freeze remains. Production placement/prose stay replaceable.

PR36 stays draft/unmerged. Broad CI, full-week requalification, arbitrary interruption coverage and performance are not claimed. No integration/master changes or release.
