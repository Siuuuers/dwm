# Self-talk implementation plan

Updated: 28 October 2026, Hong Kong time.
Status: design handoff; runtime implementation has not started. Two display
questions below remain open.
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
- The self-talk window fills top, then middle, then bottom. Once full, append
  new self-talk at the bottom and remove the oldest visible entry from the top.
- The owner asks to reuse the caption maximum-three rule. Do not add special
  handling for a single entry exceeding three wrapped rows in this slice.
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

Confirm whether the owner means this three-entry behavior or a stricter total
three-rendered-row budget. Do not silently substitute one rule for the other.

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
Do not allow Auto to advance while the paired thought is still revealing.
Inspect existing read-aloud ownership: avoid overlapping two speech streams.
No separate self-talk database, runtime or per-frame history reconstruction.

## Questions to close

1. Does “three rows” mean three DTL entries (existing caption behavior), or three
   rendered text rows in total after wrapping?
2. When a following caption has no self-talk, do existing thoughts remain in their
   window, or does that window clear? Recommended: retain until an explicit clear
   or chosen scene boundary. Clearing policy is not selected yet.

Other bounded authoring details: exact marker spelling, malformed orphan-marker
handling, and whether multiple consecutive marked thoughts are permitted.
Support the selected one-caption/one-thought case first; do not infer that every
label or every thought choice is this display marker.

## Cloud acceptance

Godot and PowerShell execution stays in GitHub Actions.

- One Advance displays a caption and attached thought together; there is no
  extra self-talk progression step.
- A lone caption works; no false read marks or invented self-talk rows.
- Window fill and fourth-entry eviction match the selected maximum rule.
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
