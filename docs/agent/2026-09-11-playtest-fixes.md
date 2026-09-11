# September 11 playtest fixes

The playtest batch preserves the existing scene-based DTL layout, board dimensions/mine rules, and provisional gameplay branches. Final dialogue and artwork remain separate work.

## Measured responsiveness

Matched local probes on Godot 4.6.3/Windows used a copied player-data snapshot and the same board actions. These are local measurements, not timing guarantees. The larger September 11 history and subsequent startup-frame fixes are covered in the [current-history follow-up](2026-09-11-current-history-latency.md); the table below records the earlier batch.

| Player action | Before | After |
| --- | ---: | ---: |
| Ordinary Reveal/Flag, median | 143 ms | 52 ms |
| First Reveal | 606 ms | 262 ms |
| Winning Reveal | 8.07 s | 1.80 s |
| Schedule Done, Day 1 to 2 | 2.41 s | 1.10 s |

Historical command results no longer keep a full board copy per input. The matched board snapshot fell from 249,503 to 38,976 bytes with all 41 receipt identities retained. The latest response and first-Reveal proof remain exact; older commands retain conflict detection and an already-applied acknowledgment.

Save construction validates its normalized document once. Issuer and continuation storage reuse validation only for a bounded window of exact, already-proven bytes; cold/external documents still receive normal validation. CheckpointJournal retains the current complete snapshot and two recent semantic fallbacks. Existing 32-line and 32-manual-save budgets remain, so dialogue/manual-heavy sessions can still contain more history.

The save before Hospital/dating presentations, final new-day save, and ending save remain durable. The redundant increment-day save is removed. A failed final day save can restart from the earlier presentation boundary and automatically finish the saved Schedule command once.

## Player-facing changes

- Title: DWM / Welcome! :) above the right-side art slot. Starting an account renders `.`, `..`, `...` while SaveManager yields between completed operations. The mutation lease blocks a second Start. Individual synchronous disk operations can still briefly stall a frame; this is not background-thread I/O.
- Supportz: remains the hidden blank ninth slot on Shop page 1. Eligibility refreshes after rounds, hover/focus makes the interaction usable, and activation opens the price-only $45 No/Yes sheet. Retained save failures keep the retry available.
- Contacts: a completed round can show the corner message notice; Go opens Contacts, and duplicate publication does not repeat the notice.
- Ordinary fainting: a short notice and Continue, preserving recovery effects. Proven Sylvia attendance still uses its Hospital DTL/art.
- Artwork preview: [F6 scene guide](../../tests/manual/dialogic_preview/README.md), covering all 32 Dating entries and seven Sylvia Hospital variants. [Artwork placement map](../../art/README.md).

## Verification

Relevant unit/integration suites passed, including save schema, receipt/coordinator replay, continuation/NewRun recovery, title lifetime, Hospital/desktop wiring, Shop purchase failure/retry, and day resolution. Native checks verified actual animated dots, blank Supportz pointer/focus behavior, message navigation, fainting save failure/retry, the actual Sylvia invitation/Schedule route, and all 39 preview DTLs with visible captions and fixed portraits at enlarged text sizes.

Nine isolated fresh-process recovery phases passed: completed and interrupted round write/read pairs; completed and interrupted Day 2 write/read pairs; copied legacy-save loading. The interrupted Day 2 check deliberately rejects the final day-start write, exits, then uses real Login to verify automatic continuation, completed stages, one money outcome, and a valid new Day 2 save. Legacy sidecars remain unchanged. A full seven-day Schedule journey also reached the Alone ending, unlocked its Gallery record, and loaded the completed Autosave back to the retired title without replay. No player's live save directory was used.

Local evidence is in `.godot/phase2r_logs/`: `board-latency-final-profile.log`, `day-timing-final-20260911.log`, `new-account-animation-20260911.log`, `startup-title-final-20260911.log`, `day-resolution-final-20260911.log`, `recovery-*-20260911.log`, and the native Hospital/Shop/preview logs. Some native test harnesses still report resource-cleanup warnings at exit; they are not a claim of a leak-free whole game.

## Remaining work

Long dialogue/manual-history stress and the remaining roughly 1-2 second outcome-save pauses remain performance follow-up (`dwm-634`). The previously reported intermittent ordinary-reply save failure remains tracked separately (`dwm-hsi`); this batch does not claim a new reproduction or fix. Dual-language simultaneous rendering remains deferred. Final story content, final art, and export/package verification are not completed by these playtest fixes.

The initial batch through `fab24be49` was pushed to the authorized `origin/master` destination. The earlier automatic approval block was resolved by the user's destination/payload approval.
