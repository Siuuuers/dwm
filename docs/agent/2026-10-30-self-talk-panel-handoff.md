# Persistent self-talk panel — implementation handoff

Date: 2026-10-30
Project: Siuuuers/dwm
Status: Agreed behavior and implementation guidance only. No runtime changes or fresh source inspection in this session. Start from the latest repository revision and read its AGENTS.md; do not assume earlier conversation commits remain current.

## Goal and confirmed decisions

Keep the existing self-talk panel frame visible during normal story reading, including captions without self-talk. The panel displays only the current caption's associated thought, not a scrolling log. Clear the previous thought when advancing to the next caption. If that caption has its own thought, show that new thought using the existing authored timing. Never carry a previous caption's thought forward.

Example: caption A + thought A → caption B without a thought + empty frame → caption C + thought C. Advancing from A directly to C replaces A's thought with C's, without requiring an artificial blank pause.

## Recommended visual treatment

Retain current placement and typography initially. Keep the frame and its reserved space stable when text is absent; do not collapse, flash, or shift surrounding controls. Use a restrained surface and border compatible with the current UI. Leave an empty text area without a “No thoughts” placeholder. No new animation, title, decoration, or user setting is necessary for this pass.

“Always visible” applies to the normal reading view. Preserve established full-screen overlays, deliberate UI-hide modes, scene transitions and menus; do not draw this frame above every screen. Inspect these cases before implementation and document any ambiguity.

## Behavior and implementation guidance

1. Trace current caption/self-talk association, reveal timing, panel visibility, History, and save restoration in the latest code. Record the actual files and starting commit in the PR.
2. Separate frame visibility from content availability. An empty thought must clear the text, not hide its container.
3. Clear stale thought content at the committed caption transition, before the new caption is presented. Rebind the current caption's thought through the existing presentation path. Guard against delayed callbacks from the previous caption repopulating the panel.
4. Preserve existing advance semantics. If an input only completes a typewriter reveal and does not advance to another caption, do not clear the thought prematurely. Preserve caption/self-talk ordering and attached-unit rules; do not change DTL syntax or authoring timing for this visual change.
5. Opening/closing an overlay, changing language/font/scale, resizing, or refreshing the same caption must not be treated as advancing. Preserve or reconstruct the correct current thought, including an empty state.
6. Save/Load should restore the thought state associated with the restored caption and existing reveal rules. A caption without a thought must load with an empty frame. Prefer deriving presentation from existing state; avoid a save-schema change unless investigation proves necessary.
7. Keep History behavior intact: clearing this live display must not remove existing historical entries or add duplicate/empty entries. Do not turn this panel into another History view.
8. Auto, Skip, branching, and a fresh run must obey the same rule and never leak an earlier thought. Preserve input/focus protections and avoid introducing focusable empty controls.

## Focused acceptance checks

| Journey | Expected result |
| --- | --- |
| Thought A → caption without thought | A clears; frame remains visible and stationary. |
| Thought A → caption with thought B | Only B is presented according to its authored timing; no stale A. |
| Several captions without thoughts | Empty frame persists without accumulating height or shifting layout. |
| Reveal-completion input without advance | Existing reveal behavior remains; no premature clearing. |
| Auto/Skip/branch transition | Same association and clearing rules; no delayed stale text. |
| Overlay return / language or scale change | Same caption retains its correct content or empty state; no accidental advance. |
| Save/Load with and without a thought | Correct content restored; no replayed cues or duplicate history. |
| New run after an existing run | No stale self-talk from the previous run. |

Use focused tests for the changed presentation lifecycle and relevant existing integration checks. Run repository-required checks. Broaden testing only if shared code or observed failures justify it; do not repeat unrelated purchase or asset tests solely for this panel change.

## Visual verification and deliverables

Review actual mounted gameplay at the agreed 1920 × 1080 target, recording actual client dimensions. Check 125% and 150%, supported languages and bilingual layouts, including a long thought. Verify clipping, artwork coverage, frame stability, and control clearance; use a representative smaller supported window as a regression check. Do not shrink text to force a fit.

Deliver a focused PR with before/after captures of a populated and empty panel, a concise test summary, and any limitations. Keep unrelated Shop/computer resizing and decoration work out of this change. If the present panel is visually too large when empty, provide a comparison before redesigning its placement; persistent visibility itself is already approved.

## Scope boundary

This handoff records the user's confirmed interaction design. It does not assert that the current implementation already supports it, identify unverified source files, or claim tests have run. No further design answer is needed to begin inspection and implementation.
