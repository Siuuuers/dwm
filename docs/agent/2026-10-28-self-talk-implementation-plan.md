# Self-talk implementation plan

Updated: 28 October 2026, Hong Kong time.
Implementation and cloud acceptance: [PR #140](https://github.com/Siuuuers/dwm/pull/140).
The PR records merge status and final cloud checks. The row budget, retention,
instant thought reveal and caption-then-thought speech behavior are selected.
Parent: [Current and future feature plan](2026-10-28-current-and-future-feature-plan.md).

## Owner decisions

- Self-talk uses the SAME DTL as ordinary captions.
- A self-talk marker applies to exactly one dialogue line, not a section.
- That marked line belongs to the immediately preceding caption.
- The caption and attached self-talk appear together as one reading step.
  Do not require an extra Advance to reach the self-talk.
- Reuse the former Angela stat-panel region/layout, with transparent background
  and top-aligned text. Locate the historical component before reuse. Do not
  restore Angela identity, stats or a separate reading runtime.
- The self-talk window has a maximum of THREE RENDERED TEXT ROWS TOTAL.
  Wrapped text consumes multiple rows; this is not a three-DTL-entry limit.
  Fill from the top. Append new thought text below existing text and push the
  oldest rendered rows out at the top when the three-row budget is exceeded.
- Retain existing thoughts when the next caption has no attached self-talk.
  New thoughts push old rows out, or an explicit clear removes them. Do not
  invent an automatic clear merely because ordinary dialogue resumes.
- Do not add special handling for a single entry exceeding three wrapped rows
  in this slice, as requested by the owner.
- The self-talk panel supports scrolling back to previously displayed thoughts.
  Leaving the live three-row window does not delete a thought from scrollback.
- The caption uses the selected typewriter speed; its attached thought appears
  instantly when the paired step is presented.
- Read Aloud speaks the caption followed by the attached thought through the
  existing single speech owner. Retained older thoughts are not spoken again.
- Main reading controls own progression, including holding while the computer
  is open. Self-talk has no separate Advance, Auto or Skip controls.

These decisions supersede the earlier separate-DTL proposal and the suggestion
that self-talk consumes its own reading step.

## Exact caption rule found in current code

WitnessedCaptionLayer.gd retains two previous caption entries plus the current
entry. _caption_window returns that window, and _layout_stack assigns older,
previous and current labels. _measure_leaves measures their full wrapped heights.

Thus current code limits caption ENTRIES to three; it does not enforce a total
of three typographic rows after wrapping. The main caption stack is bottom-aligned.
The new self-talk stack must fill from the top as requested.

The owner has explicitly selected the stricter THREE RENDERED ROWS rule for
self-talk. Do not copy the current three-entry limit. This clarification alone
does not authorize changing the ordinary caption implementation.

Measure wrapping using the current panel width, font, text size and locale.
A two-row thought plus a one-row thought fills the window. Another one-row
thought pushes the oldest rendered row out. Visible clipping never deletes
source text or fragments its stable line identity in History.
Compute the full wrapped layout before typewriter reveal so reveal progress
does not repeatedly move existing rows. Reflow on divider/font/locale changes
without creating new publications or read marks.

## Self-talk scrollback

Thought scrollback is available only inside the self-talk panel. Players can
scroll there to review earlier thoughts and return to the latest thoughts. The three-rendered-row rule limits the visible
window, not the amount of previously encountered text available for review.

Reuse the existing encountered reading/History source, filtered to self-talk
identities in their original order. Follow the current caption history scope;
do not expose unvisited branches or turn this into the deferred Global Gallery
library. Do not introduce a second persistent transcript.

Scrolling is a presentation operation. It must not advance DTL, activate a
choice, restart typewriter reveal, duplicate History, change Global read marks,
or replay scene effects. Consume wheel/drag input inside the panel so it cannot
fall through to ordinary caption advancement or divider dragging.

Keep self-talk review position independent of ordinary caption scroll position.
Apply the existing caption review/return-to-live behavior where compatible;
inspect how it handles Auto/Skip and incoming publications before adapting it.
A return to the live view restores the latest thought window without advancing
the story. Preserve a stable text anchor when resizing or changing font/locale.

An explicit clear empties the live self-talk display; it does not delete already
encountered thoughts from History or prevent reviewing them through scrollback.
Any future change to historical scope or clear semantics needs an explicit decision.

## Suggested minimal implementation

1. Inspect AGENTS.md, CLAUDE.md, current reading/DTL compilation, stable IDs,
   publication, caption memory, save restoration and localization.
2. Locate the former panel layout. Reuse suitable layout code only.
3. Recognize a one-line self-talk marker using the existing authored parsing path.
   Exact spelling is an implementation proposal until selected.
4. Prepare the preceding caption and attached thought as one display step before
   publishing either. Do not visibly advance once and backfill the thought later.
   Inspect the following authored record without executing unrelated commands,
   choices, transitions or effects.
5. Route the two texts to separate views. Preserve their separate stable line IDs
   under the same paired step; do not concatenate prose to invent a new identity.
6. Publish History in DTL order: caption A, self-talk A, caption B, and so on.
   A caption without self-talk produces no fabricated thought record.
7. Reuse existing read-mark and persistence owners. Repaint, panel reopen,
   localization refresh and Load must not republish either line.
8. Restore the pair and visible self-talk window directly, without replaying
   story effects. A failed or partial publication must not silently lose one
   member or advance to the next pair.
9. Use explicitly synthetic fixture content first. Do not author story canon.

The pairing must also be reflected in Auto timing, Skip and instant reveal.
Thoughts are instant; Auto waits for the caption reveal and the existing speech
completion barrier, including the attached thought when Read Aloud is enabled.
Use one ordered speech stream, caption then thought.
No separate self-talk database, runtime or per-frame history reconstruction.

## Located historical layout

The former component is `scenes/shared/StatHud.tscn` at revision
`4321b520a3c4f16c32a4f6c90f044f3b75e0dd20` (20 September 2026).
`scenes/main/MainGameScene.tscn` mounted it under
`RootHBox/AngelaPanel/AngelaCanvas`, top aligned with 16 px top/left/right
insets. The left and computer panel stretch ratios were 3:5. Reuse the layout
reference only, without the old stat or character bindings.

## Coordinated scene UI work

Include the previously selected computer controls, bottom rail and divider changes
in the same implementation effort as self-talk. These share scene geometry,
wrapping, focus and input routing. Implement and verify in small stages rather
than one undifferentiated rewrite.

1. Establish the self-talk pair, History and scrollback behavior first.
2. Put History, Save, Load, Skip, Auto and Next in one bottom row, preserving that
   left-to-right order and the existing command owners.
3. Put the additional upward computer caret above Save, the second button.
   Preserve computer open/close, held reading, exact return and focus behavior.
4. Remove the duplicate top-left Scene button stack. Keep Settings and Backup
   reachable through the computer; preserve Save/Load via the bottom rail.
5. Remove the clock/current notification bar and visible panel adjustment knobs.
   Resize by dragging the divider line with a wider invisible hit target.
   Preserve non-pointer resizing access, minimum sizes and cancellation.
6. Run combined cloud journeys covering resized self-talk, scrollback, computer
   open/close and the six commands. Scroll/drag/caret clicks must not leak into
   dialogue advancement. Verify the three-row budget after resize.
7. Reproduce and fix the reported Skip-all defect through its actual owner if
   confirmed; test unread-text advancement, not just button appearance.

Use focused commits and tests for each behavior, followed by the integrated
journey. Keep self-talk the first priority. Do not couple acceptance of this UI
work to Shop, decorative ink marks, Gallery library or dissolve implementation.

## Selected authoring syntax

Use a standalone DTL comment `# self-talk` immediately before the thought text,
after its primary caption. Both text records retain their own `#id:` identity:

```text
TEST caption. #id:fixture.caption
# self-talk
TEST attached thought. #id:fixture.thought
```

`# self-talk-clear` immediately before an ordinary caption clears the live
thought window when that caption appears. It does not erase encountered IDs.
The marker is metadata, not an extra reading step. Only the selected contiguous
one-caption/one-thought case is supported; orphan and multiple attached thoughts
are authoring errors. Existing actionable `thought.options` and `thought.pass`
controls retain their separate meanings.

The ordinary caption remains the single command/save frontier. Its attached
thought has a separate authored identity in the existing encountered History
and Global read witnesses. No second persistent transcript or compact save
schema was introduced. Load preserves the saved encountered IDs.

Existing Gallery passage cards display caption then attached thought in the
same card. This preserves their existing paired step and read-only behavior;
it does not implement the deferred Global Gallery library.

## Cloud acceptance

Godot and PowerShell execution stays in GitHub Actions. The existing Windows
workflow includes the focused self-talk suites, actual Auto/Skip journeys and a
separate-process physical Load check. Its public-surface, export and rendered
regressions remain enabled. No standalone duplicate workflow is retained.

Skip-all was reproduced stopping during native caption replacement before the
new frontier settled. Its controller now checks admission before the next
mutation; required boundaries, explicit retirement and failures still stop it.
The unread-text regression passed in the diagnostic cloud run; use the PR checks
for acceptance of the complete final candidate.

- One Advance displays a caption and attached thought together; there is no
  extra self-talk progression step.
- A lone caption works; no false read marks or invented self-talk rows.
- One-row and two-row thought fixtures prove the total three-rendered-row budget,
  top-first fill and oldest-row eviction; do not test only three one-line entries.
- A caption without self-talk retains the existing thought window unchanged.
  Explicit clear removes the display without deleting History.
- Width/font/locale reflow preserves the three-row budget and stable read identity.
- Scroll back to thoughts displaced from the live window, then return to latest.
  Verify correct ordering, no unvisited text and no change to story/read state.
- Scroll input does not advance captions or activate controls; ordinary caption
  and self-talk review positions do not overwrite each other.
- Explicit clear empties the live view while earlier thoughts remain reviewable.
- Exercise review during Auto/Skip and incoming publications using the existing
  caption review contract, without duplicate publication or skipped paired steps.
- History has exact caption/thought order and no duplicates after refresh/reopen.
- Save/Load restores the pair and window without replaying effects.
- Auto, Skip, reveal completion and computer hold operate on the paired step.
- Marker routing preserves stable IDs and actual branch execution.
- Rendered fixtures check top alignment, centered-caption coexistence, text size,
  locales and divider resizing.
- Include the separately reported Skip-all defect when touching its owner, but
  do not claim it fixed until actual unread-text advancement passes.

Keep unrelated Shop, Gallery library and dissolve implementation out of this
first slice. Update this handoff with the selected policies, implementation PR
and cloud evidence when work proceeds.
