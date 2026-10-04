# Automatic dating challenge flow

Owner decision: 2026-09-21. Bead: `dwm-cb1`.

The pre-challenge semantic DTL entry plays before the board. On its natural
completion the board opens without a Ready/Continue card. A cleared board settles
on the following frame, preserving the existing paint and persistence boundary.
An ordinary solo clear takes the former Continue result (`loved`); Perfect and
explosion effects keep their existing rules. The special mine is unavailable.

After settlement the matching semantic post-challenge DTL entry plays, and its
natural completion advances the existing sequence without a Done/Continue card.
Return-only entries complete automatically; their title, frame, or return does
not create a witnessed dialogue receipt. The existing Angela-absent pair
explosion cutoff skips post dialogue and grants no pair witness.

## Ownership and failures

`DatingPhysicalOwner` retains board/effect/checkpoint authority.
`DatingPresentationPort` admits the exact command and phase.
`DatingNarrativePlayback` binds the existing `DialogicBridge.start_entry` semantic
API to the exact phase, entry, playback token, and context fingerprint. It accepts
only the matching natural completion. The scene never selects an arbitrary DTL
path or computes a relationship result.

Routine confirmations are hidden. A failed preparation, playback start,
settlement, or checkpoint retains an explicit Retry and cannot spin every frame.
Held input is released before admitting the next dialogue or board, while the
durable terminal settlement itself is not delayed by focus or held input.

Legacy saved terminal-choice phases remain readable but admit only the former
Continue result. Already committed historical outcomes are preserved. No new
save schema or fabricated Observer evidence is introduced.

## Current content and recovery limits

Canonical pre/post recovery remains at the existing physical phase boundary.
This work does not add exact mid-line save/resume. Most authored dating entries
are still empty. Actual prose must still be authored and reviewed.

A successfully mounted replacement scene clears transient playback completion,
including when Load restores the same command and phase. A checkpoint Retry in
the existing scene retains completed playback, so it does not repeat the prose.
The playback adapter cancels only its own exact active entry token.

Private Rehearsal automatically completes only a verified return-only semantic
entry. It fails closed for future nonempty prose until that playback is composed
with its private narrative sandbox; it never borrows canonical progression.

The paused Observer interaction prototype and its original tests remain on
`archive/observer-interactions-2026-09-21`. Its current-build eligibility override
is documented in `observer-interactions-suspended-2026-09-21.md`.

## Evidence

Cloud coverage must include automatic ordinary clears; unchanged Perfect/loss
effects; old-choice save admission; exact-once retry and restore; natural DTL
completion and token refusal; held-input separation; no routine confirmation;
empty-entry truth; private Rehearsal isolation; and a real Bootstrap/Schedule
dating journey. Report the tested commit and retain failed runs.

The latency probe now observes the durable result and automatic date completion
instead of waiting on the removed terminal-choice click or placeholder title
draw. Those timing boundaries are named in its records and are not presented as
a controlled before/after performance improvement.
