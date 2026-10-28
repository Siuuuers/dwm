# Current and future feature plan

Updated: 28 October 2026, Hong Kong time.

This is the owner's current feature-selection record for Siuuuers/dwm.
Implementation priority is **2 → 3 → 9 → 1**: self-talk, its History integration,
Shop catalogue, then the pixel transition. Self-talk comes first.
Self-talk, panel-only thought scrollback, bottom controls, divider dragging and Skip all
are merged in [PR #140](https://github.com/Siuuuers/dwm/pull/140), accepted by
[cloud run 40592589829](https://github.com/Siuuuers/dwm/actions/runs/40592589829).
The Shop implementation is [PR #141](https://github.com/Siuuuers/dwm/pull/141).
Its twelve focused suites and rendered three-process journey pass in
[run 40640560154](https://github.com/Siuuuers/dwm/actions/runs/40640560154).
The PR records final export/UI acceptance and merge status.
Pixel transitions are complete in [PR #142](https://github.com/Siuuuers/dwm/pull/142),
accepted by [run 40650052235](https://github.com/Siuuuers/dwm/actions/runs/40650052235).


## Latest amendment: ink retirement and seven-command bottom bar

October 29 follow-up: retain the approved dialogue row bottom at y612; attach the computer tag to the visible Save face instead of aligning its top with the dialogue. See the attachment amendment in the [handoff](2026-10-28-bottom-bar-and-ink-amendments.md).

Implemented in [PR #147](https://github.com/Siuuuers/dwm/pull/147), which records merge status. Accepted revision `0f26deca7e522d3bffc3e51dc84a5e6e58859f44` passed [cloud run 40717838949](https://github.com/Siuuuers/dwm/actions/runs/40717838949): all 28 focused suites plus public/native contracts, Windows export and broader rendering (33 successful jobs; the unrelated matched startup/Load job intentionally skipped). The final acceptance-record update changes documentation only. The [October 28 playtest amendment handoff](2026-10-28-bottom-bar-and-ink-amendments.md) supersedes the older active-ink, six-command and above-bar-caret instructions below. Remove save splashes for now; preserve their [design and source](../retired-features/save-slot-ink/README.md). Place the computer tag on the bar, align the lowest dialogue row bottom to its visible top, add direct computer Settings as a seventh evenly spaced command, omit visible Skip/Auto On/Off suffixes, and retain disabled bar labels under the open computer overlay. Prior implementation and test records remain historical evidence, not completion of these new amendments.

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
| 1 | Pixel/noise scene transition | Complete in PR #142. Presentation details below. |
| 2 | Separate self-talk presentation | Complete in PR #140. |
| 3 | Ordered self-talk History and restoration | Complete in PR #140; thought scrollback stays inside the self-talk panel. |
| 4 | DTL-driven notifications | Future work. Remove the current notification bar; no replacement notification surface is selected. |
| 5 | Old unified right-hand control-bar proposal | Retire. Do not move the interface to the old right-hand layout. The new bottom-bar request below replaces this proposal. |
| 6 | Right-center caption relocation | Retire. Keep the current mostly centered presentation. |
| 7 | Separate opening before Day 1 | Retire as a required feature. The opening was an example of flexible starting-point selection, not mandatory content. The owner considers existing start selection sufficient; do not add a prologue. |
| 8 | Notes desktop app | Future work; not part of the next Shop change. |
| 9 | Replacement Shop catalogue | Implemented in PR #141. Three new items each have a cap of one per run; see PR for final acceptance. |
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

Reuse the former Angela stat-panel region/layout as the self-talk presentation
reference, with transparent background and top-aligned text. Locate the historical
implementation before adapting it; the owner's recollection that it predates PR #1
is a search lead, not a verified revision. Reuse geometry/component structure where
suitable, not Angela identity, stat bindings or the retired HUD.
Do not invent new story prose or a second independently advancing timeline.
Use labeled sample content to prove mechanics before production authoring.

Self-talk labels are in the SAME DTL as ordinary scene dialogue. This supersedes
the earlier separate-self-talk-DTL proposal. DTL order therefore supplies the
shared reading sequence; labels select the presentation destination.
Use explicit authored identity; do not infer self-talk from punctuation or prose.
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

The marker applies to one self-talk line in the same DTL, paired with the
preceding caption. Both appear together in one reading step, without an extra
Advance. The self-talk view fills from the top and shows at most THREE RENDERED
TEXT ROWS TOTAL, counting wrapping. New thought rows push oldest rows out.
A caption without attached self-talk retains the existing thoughts. Clear only
through an explicit clear, not automatically when ordinary dialogue resumes.
This differs from the current caption code's three-entry limit; do not silently
change ordinary caption behavior as part of this clarification.

The [separate self-talk implementation plan](2026-10-28-self-talk-implementation-plan.md)
owns the detailed handoff and cloud acceptance. Exact marker/clear spelling
remains an implementation detail. Preserve stable IDs, ordered History and
direct restoration; no new narrative content is selected here.

## Additional current UI request

The owner requests a bottom bar rather than the retired right-hand arrangement:

- Put all six buttons at the bottom.
- Use a clickable upward caret `^` for the computer control, visually like the
  existing panel adjustment handle but pointing upward.
- Place the caret ABOVE the second button from the left. It is an additional
  attached computer control, not a replacement for one of the six buttons.
- Remove the clock and the current notification bar.
- Keep captions mostly centered.
- Keep an accessible name and usable hit target for the visually symbol-only caret.
- Do not restore a Pause menu. Current Scene play already bypasses it.
  Internal suspension code still supports Settings, Backup and Logout.

Source inspection of WitnessedTransportRail.gd confirms six commands:
History, Save, Load, Skip, Auto and Next. Its current horizontal bay order is
History → Save → Load → Skip → Auto → Next, although the last three are raised
into an upper row. Preserve that horizontal order when flattening to the bottom
unless the owner requests another order; the caret then sits above Save.

Remove the duplicate top-left Scene control stack, including Computer,
Settings, Backup, Save and Load buttons. Preserve the functions through the
bottom rail and the computer's existing app access. Removing these buttons is
not deletion of Settings, Backup or their shared suspension/transaction owners.

Remove the visible left/right adjustment knobs. Resize panels by dragging the
divider line itself. Give the thin visible line a wider invisible interaction
strip, preserve reasonable minimum panel sizes, and ensure dragging cannot
advance dialogue. Retain keyboard/controller resizing access without requiring
a visible knob. Check resize, cancellation and text fitting in cloud tests.

Include this UI request in the self-talk/History implementation effort, before
Shop and the dissolve. Keep self-talk first, then integrate bottom controls,
computer caret and divider dragging in separately verified stages. The self-talk
handoff records combined acceptance; this does not require a single large commit.

## Reported defect: Skip all does not skip

The owner reports that Skip fails even when configured to skip all text.
Status: fixed in PR #140. Cloud acceptance covers advancement and required stops.

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
| 1 | crystal stutters | 45 money | One purchase per run; automatic computer decoration. |
| 2 | inked silk string | 45 money | One purchase per run; automatic computer decoration. |
| 3 | letter with wax seal | 45 money | One purchase per run; automatic computer decoration. |
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

### Cosmetic direction and code-only implementation proposal

Proceeding with the recommended defaults after the owner requested continuation:
automatic activation on purchase, stacked accents, and computer-only scope.
Visual treatments must not change story rules, text readability,
button positions or caption geometry:

- crystal stutters: restrained glass-like edge highlights.
- inked silk string: a fine thread-like accent on existing panel boundaries.
- letter with wax seal: a small wax-seal detail on suitable existing paper surfaces.

All three can be rendered entirely in code using a small custom Control:
short lines/polygons for glass highlights, a polyline for thread accents, and
layered irregular polygons/circles with a simple inset mark for a stylized wax seal.
No external image asset is required for these restrained graphic treatments.
Hand-painted texture, realistic glass/refraction or a detailed embossed emblem
would be optional additional art, not a requirement for the first version.
Prefer static cached drawing with redraws on ownership/theme/size changes,
not continuous animation or one node per decorative segment.

These could become alternative theme treatments rather than three competing layout
systems. Do not implement forced layout shifts, flashing, or a new customization
manager merely to give the items an effect. Ownership comes from the existing per-run inventory; Load restores it and a new
run clears it. Crystal highlights and silk accents frame the computer. The wax
letter sits on the desktop wallpaper and hides while an app is open. No separate
customization manager, Notes unlock, or saved cosmetic state is introduced.

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

The owner requested continuation with the recommended defaults on October 28:
250 ms pixel dissolve, no glossy Loading panel, no left dimming or forced minimum
wait, and an immediate prepared swap with Reduced Motion. These supersede the
older one-second Loading-panel proposal.

Implemented in PR #142: Bridge owns one transient presentation hold across
native layout replacement. The persistent SceneHost captures the outgoing frame
once; a deterministic pixel mask reveals the prepared destination. Rail, caret
and divider pixels are excluded. Incoming caption typing, speech, read marks,
Auto and Advance remain held until the effect completes. Both edges retire held
input. This introduces no saved transition phase, gameplay RNG, or per-frame
framebuffer copy. Initial admission and Load do not animate.

Cloud acceptance must prove discarded presses during the effect, release before
a fresh Advance, no hidden incoming read marks, Auto admission, Skip's marker
stop, Reduced Motion, and Save/Load at the completed destination. Screenshot
checks must cover content pixels and unchanged control regions. The existing
synchronous resource preparation still determines readiness; no loading-speed
improvement is claimed.

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

## Save-slot ink marks (retired by latest amendment; historical record)

Owner-selected behavior: all save types receive marks, including numbered manual
slots, Quick Save and Autosave. Each successful save adds a fresh splash at the
original colour/opacity. Older splashes on that same slot fade by a fixed
percentage per subsequent successful overwrite and may eventually disappear.
Age is measured in saves to that slot, not elapsed time or opening the save screen.

For old marks use alpha_new = q * alpha_old, with 0 < q < 1, then append
the fresh mark at alpha_0. A mark aged k overwrites has alpha_0 * q^k.
Keep the ink hue stable; fading means reduced opacity, not changing its meaning.

Proposed visual tuning, not an owner-selected constant: q = 0.65 (35% opacity
reduction per overwrite), discard marks below 5% of fresh opacity, and retain
at most eight marks including the fresh one. Tune against the actual slot surface.
Keep storage and drawing bounded; do not accumulate an unlimited splash history.

Use stable procedural shapes/seeds so reopening the screen does not reroll marks.
Only successful saves age/add marks; failures, repaint, Load, or repeated delivery
of the same completion must not do so. Marks belong to the destination slot,
not story chronology: loading an earlier run must not rewind the slot's visual
overwrite history. Choose the smallest persistence integration after inspecting
existing slot metadata; this plan does not select a second save journal or schema.

The mark is decorative. Keep slot text, thumbnails, focus and success/error
feedback legible. Do not imply a failed save succeeded. The feature is not tied
to a Shop purchase unless separately selected.

Code-only art can combine a smooth irregular radial blot, a few directional
streaks and sparse satellite droplets. Keep visual randomness separate from
gameplay RNG. New art assets are optional.

Current slice: save-slot ink marks, after the completed self-talk → History → Shop →
transition sequence. The owner selected **Delete clears the slot’s marks** on October 28.
Keep bounded integer seeds as optional destination-document metadata, outside restored
run snapshots; old files without marks remain supported. The existing Backup drawer
draws the decoration. Use the proposed 0.65 fading and eight-mark bound as the first
visual tuning, verified against text and focus readability in cloud rendering.
Implementation is [PR #143](https://github.com/Siuuuers/dwm/pull/143).
Completed in PR #143, accepted by [run 40653276347](https://github.com/Siuuuers/dwm/actions/runs/40653276347).
The combined runtime is uploaded as Steam BuildID **26265268**, source `5cc02fd`;
[the upload record](../steam/CLOUD_UPLOAD.md) distinguishes upload from live-branch
selection and installed-client testing.

## Verification and continuation

Run Godot and PowerShell validation only in GitHub Actions. Reuse existing owners
and relevant tests. Add focused checks for ordered self-talk, exact Save/Load,
duplicate suppression, the selected Shop caps, Skip all behavior and transition
input behavior when those slices are implemented.

Completed runtime slices and their cloud acceptance are recorded above. No timing
improvement is claimed. Further Save/Load profiling stays deferred.

Update this same plan as decisions change. Record the implementation PR and
accepted evidence against each completed row; do not use a merged PR alone as
proof that every design item is complete.

## Playtest corrections selected after Steam build 26265268

The owner reported missing self-talk in the shipped story, detached choice controls,
large/off-center computer caret, redundant Apps/Contacts buttons, and faint localized
save ink. The earlier self-talk acceptance proved synthetic paired content; shipped
DTL had no annotations. Engine completion did not establish production binding.

For this test build, explicitly route the existing line immediately before each
thought offer into self-talk without rewriting prose or changing its line ID.
This is a temporary presentation selection for playtesting, not final literary
classification. Keep both the caption and thought in the existing paired reading
step. Dialogue choices occupy one horizontally scrollable row in the same panel,
beneath the retained three thought-text rows.

Make the computer tag visually smaller with a centered up-chevron while closed and
a down-chevron while open. Remove external Apps/Contacts text shortcuts. A small
Home pictogram preserves return from the held Challenge to desktop apps; selecting
Minesweeper there returns to that same held Challenge. The standalone Challenge has
no clock strip; the desktop retains its existing header/clock. No clock is added.

Ink is darker, larger and more scattered across the slot paper, including a soft
smudge and additional droplets. Preserve stable seeds, destination-owned saves,
0.65 fading, text legibility and focus geometry.

PR #145 merged runtime commit `554bfd5f9a2bcb97c940b25c04c899b60729199e`.
Cloud acceptance [run 40676307856](https://github.com/Siuuuers/dwm/actions/runs/40676307856)
passed all 18 selected gameplay suites, public API contracts, Windows exported
startup, Linux rendering and Gallery checks (23 successful jobs; one unrelated
performance comparison skipped). The merge tree matches the accepted candidate.
Rendered review includes the shipped Day1 thought/Yes offer and its Save/Load,
large-text choice scrolling, held Challenge/Home return and whole-paper ink.

The ink pixel test measures the 0.65 rule on isolated paint because overlapping
translucent shapes do not have linear final-pixel contrast. The shared choice
Save/Load test waits for actual transport tap admission before clicking once.
No runtime timing workaround was introduced. All caption text, line IDs and
read-mark revisions remain unchanged across 92 registered entries.

Steam test upload [run 40677954412](https://github.com/Siuuuers/dwm/actions/runs/40677954412)
confirmed **BuildID 26268561**, AppID 5199120 / DepotID 5199121, from the merged
runtime above. Fresh `game.exe` / `game.pck` export and launch validation passed,
and SteamPipe preview produced its manifest before upload. No Steam branch was
set live. The upload workflow retains this exact source pin and returns to manual
dispatch after the one-time test trigger is removed.

This completes the requested playtest correction pass, not every deferred feature
or final literary classification of the 15 temporary thought bindings.
