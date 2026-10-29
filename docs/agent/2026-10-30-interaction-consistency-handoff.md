# Interaction consistency handoff

Date: 30 October 2026 (Hong Kong)
Status: implementation handoff approved by the owner; documentation only.
Scope: focus continuity, distinguishable control states, and focused interaction journeys.

## Baseline and working rules

PR #159 merged as acc6878dd6367838b2138779692cb2cc34cc60f2. It completes the preceding readability/editor work and already restores Shop focus to the selected item when its Buy button disappears. Preserve that behavior as a regression check.

Read repository AGENTS.md, CLAUDE.md and relevant current input, presentation and accessibility contracts before implementation. Recheck current master and existing tests; this handoff records a source review, not new rendered gameplay evidence or a whole-game audit.

Relevant owners:
- scripts/ui/witnessed/WitnessedTransportRail.gd
- scripts/ui/witnessed/WitnessedTransportButton.gd
- scripts/ui/SceneHost.gd
- scripts/ui/gallery/DialogueLibrary.gd
- scripts/ui/GalleryScene.gd
- Current Shop, Settings, History, Save/Load and overlay lifecycle owners discovered from their active callers.

Do not extend obsolete Schedule or old Pause-menu surfaces merely because searches find them.

## Findings and evidence strength

| Finding at reviewed baseline | Classification | Next action |
| --- | --- | --- |
| WitnessedTransportRail._apply_button_material gives disabled and pressed states the same fill, ink and four-pixel border treatment. | Confirmed source behavior; visual significance needs rendered review. | Make unavailable and pressed states distinguishable without making disabled text illegible. |
| Rail focus uses two outlines; SceneHost computer caret uses one outline. | Confirmed source difference, not inherently a defect. | Review side by side; use a coherent focus treatment adapted to control size rather than blindly copying geometry. |
| Rail project() releases focus when the focused command becomes unavailable; the component itself chooses no fallback. | Confirmed local behavior; end-to-end focus loss is unproven. | Trace the containing screen and reproduce before adding restoration. An overlay may already own the new focus. |
| DialogueLibrary.refresh() remembers whether a row had focus, then focus_first() restores the selected passage rather than necessarily the previously focused row. | Confirmed source distinction; reproduce with focus and selection on different passages. | Preserve the focused passage identity on refresh if still present, without changing selection. |
| Shop Buy disappearance returns focus to the selected item. | Already addressed by PR #159. | Retain and test, not an unfinished implementation task. |

Source review does not prove keyboard/controller journeys pass. Record reproduction results, including any finding that turns out already covered by a containing owner.

## Intended behavior

### Focus continuity

- Opening a modal/overlay assigns useful focus inside the active surface and prevents interaction with blocked underlying controls.
- Closing returns focus to its invoking control if that control is still visible, enabled and valid in the current screen.
- If it no longer exists or is unavailable, choose a meaningful fallback within the current active surface.
- Do not restore focus into a scene that has been replaced by Load or navigation.
- Restore only when the relevant surface owned focus; background refresh must not steal focus.
- If focus and selected item differ, preserve them independently. Use stable item/passage identity where available rather than index.
- Hidden/disabled controls must not remain actionable keyboard targets.
- Preserve scroll position where possible and reveal a restored offscreen control only as needed.
- Do not install a global focus manager unless concrete findings demonstrate the existing owners cannot handle the scoped corrections.

### State appearance

Establish a small coherent visual vocabulary using existing themes:
- Focus: clearly identifies keyboard/controller activation target.
- Hover: quieter pointer feedback; passing over a control does not itself move keyboard focus.
- Pressed: transient activation feedback.
- Selected/on: persistent mode or item state, distinguishable from focus.
- Unavailable: readable but visibly different from pressed and available controls.

Keep Skip/Auto's compact visible names. Preserve accessible On/Off wording and selected-state treatment. Keep bottom labels visible beneath the computer as already designed; they remain inactive while blocked.
Do not solve disabled-state distinction merely by making text extremely faint. Use restrained border/fill treatment as appropriate. Disabled and selected may coexist: ensure unavailable state is still understandable without falsely clearing the underlying mode.
Focus indication must remain visible at 125% and 150%, with both fonts and supported palettes. Avoid color-only distinctions where shape/outline/state semantics can communicate the difference.

### Input safety and navigation

- Preserve WitnessedTransportButton physical-contact admission, release requirements, generation retirement, accessibility activation and stale-input protections.
- Closing overlays, changing focus, reflowing text or returning from app focus must not accidentally advance dialogue or activate another command.
- Preserve existing keyboard/controller bindings; scope navigation to the active surface.
- Check forward and backward navigation and appropriate directional controls. Avoid inventing new bindings or imposing identical navigation on fundamentally different widgets.
- Respect established Back/Cancel behavior; do not redesign Escape or controller mapping without a concrete need.
- Do not add delays, synthetic clicks or unconditional grab_focus calls to hide a lifecycle problem.

### Spacing

Audit focus-outline clearance, hit-target separation and visibility of restored controls.
Change spacing only for reproduced overlap, ambiguity or reachability problems. Do not normalize every gap, move the accepted caption position, detach the Save/computer tag, or rebuild the seven-control bar.

## Five required journeys

1. Reading → History → close
   - Open using keyboard and pointer.
   - Focus enters History; scrolling does not advance dialogue.
   - Closing restores an appropriate target, with unchanged reading position and no duplicated History/read records.

2. Reading → Settings → language/font change → close computer
   - Use the direct Settings control and inspect its actual nested lifecycle.
   - Focus remains useful during reflow and returns at the correct layer when closing.
   - Verify 125/150%, both fonts and representative language changes.
   - No stale activation or unintended Advance; opening Settings still uses the computer as designed.

3. Save/Load → confirmation → cancel
   - Inspect actual existing confirmation paths; do not add a confirmation solely for this test.
   - Cancel returns to the originating slot/action where valid.
   - Check disabled/disappearing actions and the valid fallback.
   - A successful Load may replace the scene; never focus an obsolete invoker afterward.
   - Do not change save identities, format or existing transaction semantics.

4. Shop → purchase → Buy disappears
   - Preserve PR #159's selected-item focus fallback.
   - Confirm unavailable text remains readable and purchase feedback remains clear.
   - Test keyboard and pointer entry; no duplicate purchase or accidental activation of a neighboring item.

5. Gallery library → navigate without selecting → refresh
   - Select passage A, focus another existing passage B without activating it, then trigger a real supported refresh.
   - Retain selection A and focus B if both remain; preserve paper scroll appropriately.
   - Also cover focus in the passage document, removal/reset to empty, and a refresh while another surface owns focus.
   - No unintended discovery, read marks or disclosure of masked dialogue.

## Scope boundaries

Include only confirmed behavior fixes and the scoped state-appearance improvements.
Exclude:
- Glass, thread and wax decoration redesign.
- Broad UI layout redesign or new customization systems.
- New story features, dialogue changes, audio behavior changes or DTL editor expansion.
- Reopening completed readability/editor/default-borderless work unless a scoped regression is reproduced.
- Broad CI architecture changes.

The primary visual target remains 1920×1080. Retain relevant smaller-window and narrow-panel regression checks. Distinguish physical Windows display behavior from Linux rendered evidence; do not repeat native display tests unless changed code or a new concern requires them.

## Delivery and acceptance

1. Reproduce and document findings against current master with existing owners/tests.
2. Implement focused changes in small reviewable commits.
3. Run the five journeys and relevant rendered/accessibility/input regression tests.
4. Capture before/after state comparisons and record evidence.

Acceptance:
- Focus is useful and visible throughout the five journeys.
- Overlay focus does not leak into blocked underlying actions.
- Return focus does not point at freed/hidden/disabled controls or a replaced scene.
- Gallery preserves focus separately from selection when feasible and handles empty state.
- Disabled/pressed/focused/selected states are understandable at 125% and 150%.
- No accidental Advance, duplicate action, story progression change or reading-state loss.
- Existing Shop focus recovery remains correct.
- Any unconfirmed suspicion is reported as such, not marked fixed without reproduction or equivalent evidence.

Follow repository cloud-only Godot/PowerShell conventions. Reuse relevant tests; add targeted tests for reproduced defects rather than duplicating implementation. Retain affected layout, input, transition and accessibility checks. Group short suites only when setup sharing preserves isolated processes/data; do not claim performance gains without measurement.

Completion report must include source revision/PR, confirmed defects versus polish choices, tested journeys/configurations, screenshots, CI evidence and outstanding limitations. Documentation creation alone is not runtime completion.
