# Current and future feature plan

Updated: 28 October 2026, Hong Kong time.

This is the owner's current feature-selection record for Siuuuers/dwm.
Implementation priority is **2 → 3 → 9 → 1**: self-talk, its History integration,
Shop catalogue, then the pixel transition. Self-talk comes first.
This document records decisions; it does not claim that these changes are implemented.

## Sources and precedence

- [Original October 7 design amendment](https://github.com/Siuuuers/dwm/pull/1#issuecomment-6034620330).
- [October 25 inventory](2026-10-25-current-feature-status.md).
- [Accepted Save and Load review](../../handoff/ay-al-status-and-steam-build-20261027.md).
- [Deferred performance work](../../handoff/ax-save-load-improvement-backlog-20261027.md).
- Code audit baseline: [f04ff559](https://github.com/Siuuuers/dwm/tree/f04ff559ed66a1d3c6380dc7e8906110484fa79d).

The owner's October 28 decisions below supersede conflicting proposals in those
records within the stated scope. Preserve historical documents. Do not revive
retired requirements to satisfy an old checklist. Recheck current code before work.

## Feature disposition

Numbers retain the audit's identifiers so later discussions can refer to them.

| ID | Feature | Current decision |
| --- | --- | --- |
| 1 | Pixel/noise scene transition | Implement fourth; not urgent. Presentation details below. |
| 2 | Separate self-talk presentation | Implement first. |
| 3 | Ordered self-talk History and restoration | Implement second, using explicit self-talk labels and the existing reading owner. |
| 4 | DTL-driven notifications | Future work. Remove the current notification bar; no replacement notification surface is selected. |
| 5 | Old unified right-hand control-bar proposal | Retire. Do not move the interface to the old right-hand layout. The new bottom-bar request below replaces this proposal. |
| 6 | Right-center caption relocation | Retire. Keep the current mostly centered presentation. |
| 7 | Separate opening before Day 1 | Retire as a required feature. The opening was an example of flexible starting-point selection, not mandatory content. The owner considers existing start selection sufficient; do not add a prologue. |
| 8 | Notes desktop app | Future work; not part of the next Shop change. |
| 9 | Replacement Shop catalogue | Implement third. Three new items each have a cap of one per run. |
| 10 | Purchases unlocking nine per-run notes | Future work, deferred further. Do not wire note unlocks into the next Shop change. |
| 11 | Owned-keepsake ambient sounds | Future work. |
| 12 | Read-only dialogue library in Gallery | Future work; preserve the settled design below. |
| 13 | Production named checkpoints and overlay bindings | Future authoring. Existing engine support stays. |
| 14 | Second sustained route and second ending | Future story work. |
| 15 | Simultaneous two-language captions and History | Future work. |
| 16 | Current-story Contacts messages and replies | Future work. Retain existing Contacts functionality. |

Future work is not an instruction to add dormant controls, save fields or speculative
systems now. Retiring a proposal does not authorize indiscriminate deletion of
shared infrastructure.

## First priority: self-talk and History

Keep a distinct transparent, top-aligned self-talk region, driven by the main
scene. Do not invent new story prose or a second independently advancing timeline.
Use labeled sample content to prove mechanics before production authoring.

The owner proposes a self-talk label to identify the channel. Use explicit
authored identity; do not infer self-talk from punctuation or displayed prose.
A label can identify/route the text, but does not alone implement ordered publication
or persistence. Reuse the existing reading and History owner.

Required behavior:

- Scene A, triggered self-talk A, scene B appear in their actual order.
- A scene line without a trigger creates no self-talk row and consumes no self-talk.
- Self-talk does not get separate Advance, Auto or Skip controls.
- Opening the computer holds scene-dependent self-talk with the main reading.
- Repaint, return from the computer and Load do not duplicate History.
- Save/Load preserves or reconstructs the required self-talk position and display.
- Global read identity remains stable; UI animation does not create extra read marks.

Before implementation, settle the exact label syntax, whether to retain the earlier
separate-DTL source arrangement, and when a displayed thought clears or is replaced.
These are adapter/display decisions; no new narrative content is selected here.

## Additional current UI request

The owner requests a bottom bar rather than the retired right-hand arrangement:

- Put all six buttons at the bottom.
- Use a clickable upward caret `^` for the computer control, visually like the
  existing panel adjustment handle but pointing upward.
- Place it second from the left, attached to the six-button bar.
- Remove the clock and the current notification bar.
- Keep captions mostly centered.
- Keep an accessible name and usable hit target for the visually symbol-only caret.
- Do not restore a Pause menu. Current Scene play already bypasses it.
  Internal suspension code still supports Settings, Backup and Logout.

The exact six controls and their order have not been enumerated. Confirm whether
the caret is one of the six or an attached additional control before changing
navigation/focus. Do not guess the remaining five controls.

This UI request is accepted, but its position relative to 2 → 3 → 9 → 1 is not
specified. Keep self-talk first; coordinate geometry when building its region.

## Reported defect: Skip all does not skip

The owner reports that Skip fails even when configured to skip all text.
Status: reported, not yet reproduced or fixed.

Reproduce in the current Scene path on the cloud runner. Trace the selected
preference through Settings, the transport rail and actual reading progression.
Distinguish an incorrect setting/command path from a legitimate stop at a choice,
Challenge boundary, computer hold or other required interaction.

Acceptance must show actual advancement over both read and unread ordinary text
with Skip all selected. Preserve the distinct skip-read behavior and required
interaction boundaries. Include keyboard/pointer activation as applicable.
Do not treat a highlighted Skip button as proof that skipping works.

Triage alongside the reading work; the owner has not assigned it a new numbered
priority above self-talk.

## Third priority: Shop

Replace the old first-page products and Premium Care with the selected catalogue.
Keep the existing retained item rules unless explicitly changed.

| Order | Item | Price | Current rule |
| --- | --- | --- | --- |
| 1 | crystal stutters | 45 money | One purchase per run; effect not yet selected. |
| 2 | inked silk string | 45 money | One purchase per run; effect not yet selected. |
| 3 | letter with wax seal | 45 money | One purchase per run; effect not yet selected. |
| 4 | Lucky Charm | 1 coin | Preserve existing upgrade and cap. |
| 5 | Debug Key | 3 coins | Preserve existing upgrade and cap. |
| 6 | Bookend | 3 coins | Preserve existing keepsake ownership. |
| 7 | Metronome | 3 coins | Preserve existing keepsake ownership. |
| 8 | Pocket Calculator | 3 coins | Preserve existing keepsake ownership. |
| 9 | Secret Supportz | 45 money | Preserve secret eligibility/effect/caps; place last. |

The prices above retain the October 7 selection; only the three new caps change
from three to one. Preserve the exact spelling "crystal stutters".

Use existing per-run purchase/save ownership. Save/Load restores the saved count;
a genuinely new run resets it. Do not convert these purchases into Global unlocks.
Do not grant notes in this slice. Cap one does not approve a future automatic
return to cap three if Notes is reopened.

### Proposed cosmetic effects, not approved

Prefer optional visual treatments that do not change story rules, text readability,
button positions or caption geometry:

- crystal stutters: restrained glass-like edge highlights.
- inked silk string: a fine thread-like accent on existing panel boundaries.
- letter with wax seal: a small wax-seal detail on suitable existing paper surfaces.

These could become alternative theme treatments rather than three competing layout
systems. Do not implement forced layout shifts, flashing, or a new customization
manager merely to give the items an effect. Their selection, combination rules,
reversibility and scope still need an owner decision. Do not present an inert
purchase as a completed feature without selecting its purpose.

## Fourth priority: pixel transition

Settled in the interview:

- Trigger only at explicitly authored DTL transition markers.
- Dissolve background, character artwork and story captions together.
- Keep surrounding controls stable.
- Ignore Advance during the transition. Discard it rather than queue it.
- Holding Advance across completion must not skip the incoming caption.
- Do not let Auto/Skip outrun the transition or mark unread incoming text early.
- Prepare incoming resources before revealing them; visual effects do not remove
  blocking resource-loading cost.

The recovered October 7 design also selected a glossy right-hand Loading panel,
left dimming and a minimum one-second duration even when resources are cached.
The recent interview discussed a short dissolve and an immediate Reduced Motion
alternative without resolving those older details. Keep the glossy panel, text,
dimming, exact duration and Reduced Motion timing as open keep/amend/remove choices.
Do not silently implement either interpretation.

Reuse a single progress controller and shader/rank mask if appropriate.
Keep visual randomness separate from gameplay RNG. Do not create thousands of
individual cell nodes.

## Preserved future Gallery library design

This is separate from the per-run Notes app:

- Entry point: title screen, inside Gallery only.
- Read-only browsing, not a new replay or branch-exploration system.
- Use Global read records across loads and playthroughs.
- Group dialogue by named presentation checkpoint.
- Show only reached checkpoints; mask unread variants within them.
- Opening the library does not mark lines read or change the current run.
- Map choice/Challenge labels to localized condition descriptions.
- Show all required conditions and preserve actual AND/OR relationships.
- Use sample checkpoints first; author production placements later.

Checkpoint discovery and individual line discovery are separate facts.
A destination label alone may not encode the full path condition.

## Verification and continuation

Run Godot and PowerShell validation only in GitHub Actions. Reuse existing owners
and relevant tests. Add focused checks for ordered self-talk, exact Save/Load,
duplicate suppression, the selected Shop caps, Skip all behavior and transition
input behavior when those slices are implemented.

No runtime change, new cloud acceptance, timing improvement or Steam upload is
claimed by this record. Further Save/Load profiling stays deferred.

Update this same plan as decisions change. Record the implementation PR and
accepted evidence against each completed row; do not use a merged PR alone as
proof that every design item is complete.
