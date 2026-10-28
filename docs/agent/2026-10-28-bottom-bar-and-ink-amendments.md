# Bottom bar, computer and save-ink amendments

Date: 2026-10-28. Status: owner-selected requirements; implementation pending.
Code inspected at `76c39d0a4acb33f858fba18b6c2bc9ad7cdb24c4`. This handoff changes documentation only.

Read AGENTS.md and CLAUDE.md, then recheck the branch head before implementation. This record supersedes the caret-above-bar, six-control and active save-ink requirements in the current feature plan and earlier handoffs. Other accepted behavior stays in force.

## Requested result

1. Remove save-slot splash ink for now. Follow the [retirement record and preserved source](../retired-features/save-slot-ink/README.md). All saves are included; do not remove saved progress or ordinary save feedback.
2. Put the small computer tag **on/within the bottom bar**, not floating above it. Preserve its up-chevron when closed and down-chevron when open, accessible name and usable hit target. Retain its association with the second command (Save) from the existing selection. The tag is additional to the seven text commands, not an eighth evenly spaced command. Give it a distinct non-overlapping hit target from Save.
3. Align the bottom edge of the lowest rendered dialogue row with the **top of the visible computer tag**. Measure the rendered text row, not an arbitrary tall label container or the invisible enlarged hitbox. Keep this relationship through wrapping, supported text sizes, fonts and viewport scaling. Do not change the ordinary caption or self-talk history rules. Interpret dialogue here as the main bottom caption; self-talk retains its existing separate panel.
4. Add a seventh text command, **Settings**, that opens the computer and its existing Settings experience directly in one action. No intermediate launcher click, duplicate Settings implementation or visible Pause menu.
5. Give all seven commands equal-width bays/evenly spaced centers on the bottom bar. Recommended default order: **History → Save → Load → Skip → Auto → Next → Settings**. This preserves the existing six-command order; the owner did not explicitly select the new command's ordinal position. Localize Settings consistently with the existing app.
6. Visible Skip and Auto labels contain only their names, without On/Off suffixes. Preserve actual mode state, existing selected styling, accessible state/name and useful tooltip information. Shorter text must not change behavior.
7. While the computer is open, keep all seven labels drawn in place underneath it, but disable all seven commands. The computer is an overlay and may naturally cover some labels. Do not move labels above the computer or hide the whole rail. Disable mouse, keyboard, controller and shortcut activation; prevent click-through to dialogue. Keep the computer's own close control usable, and restore normal command admission after closing. Disable does not mean resetting Auto/Skip preferences.

## Findings that affect implementation

- SceneHost mounts ComputerMount and ChallengeMount on SceneControlsLayer (layer 20); it is an overlay over the scene. Preserve the existing retained session and reading hold.
- WitnessedCaptionLayer._sync_transport currently sets rail visibility to `not rehearsal and not _computer_caption_held()`. This explicitly hides it during computer hold. Decouple visibility from command admission for the new behavior; preserve unrelated rehearsal/ending rules.
- WitnessedTransportRail owns the six commands, fixed geometry, activation admission, focus and localized On/Off labels. Extend its existing owner, including focus traversal and retirement of held inputs.
- SceneHost draws a 32×24 visible tag centered within a 48×48 button. Its current scene rectangle is x295–343, y600–648. Use the visible tag edge for alignment and reposition its button coherently.
- ApplicationBootstrap.open_scene_settings currently **closes the computer** then calls the retained production-pause Settings route. The scene desktop's Settings external dispatch calls that same method. Merely wiring the seventh button to it will not meet the requested computer-plus-Settings presentation. Inspect ComputerDesktop, the existing Settings surface and suspension/return ownership; adapt that shared path without a second settings store. Preserve held Challenge/Home return, close/back behavior and reading custody. Do not start or resolve a Challenge just to open Settings.
- SaveDocumentSchema recognizes optional `ink_marks`; SaveManager produces/projects it, BackupPresentationPort and BackupApp carry it, BackupDrawer draws it. Preserve read compatibility with already-created ink-bearing saves while removing active decoration.

## Source navigation

- [scripts/ui/witnessed/WitnessedTransportRail.gd](https://github.com/Siuuuers/dwm/blob/76c39d0a4acb33f858fba18b6c2bc9ad7cdb24c4/scripts/ui/witnessed/WitnessedTransportRail.gd)
- [scripts/ui/witnessed/WitnessedCaptionLayer.gd](https://github.com/Siuuuers/dwm/blob/76c39d0a4acb33f858fba18b6c2bc9ad7cdb24c4/scripts/ui/witnessed/WitnessedCaptionLayer.gd)
- [scripts/ui/SceneHost.gd](https://github.com/Siuuuers/dwm/blob/76c39d0a4acb33f858fba18b6c2bc9ad7cdb24c4/scripts/ui/SceneHost.gd)
- [scenes/narrative/SceneHost.tscn](https://github.com/Siuuuers/dwm/blob/76c39d0a4acb33f858fba18b6c2bc9ad7cdb24c4/scenes/narrative/SceneHost.tscn)
- [autoload/ApplicationBootstrap.gd](https://github.com/Siuuuers/dwm/blob/76c39d0a4acb33f858fba18b6c2bc9ad7cdb24c4/autoload/ApplicationBootstrap.gd)
- [scripts/ui/ComputerDesktop.gd](https://github.com/Siuuuers/dwm/blob/76c39d0a4acb33f858fba18b6c2bc9ad7cdb24c4/scripts/ui/ComputerDesktop.gd)

## Suggested implementation sequence

1. Remove active ink and verify existing saves remain loadable.
2. Update seven-command rail geometry, compact mode labels, caret and caption alignment together.
3. Adapt direct Settings presentation and preserve the disabled visible rail under the computer.
4. Run focused cloud checks and inspect rendered screenshots, then record the implementation PR, tested SHA and accepted evidence here and in the feature plan.

Use small scoped changes. No new art is required. No unrelated save-system rewrite, story edits, Shop changes or deferred Gallery work are included.

## Cloud acceptance

Run Godot and PowerShell only in GitHub Actions. Reuse/extend existing scene-controls localization/rendering, computer-custody, Settings and save/load suites rather than building a new framework.

- Geometry: seven evenly spaced text commands, caret within the bar, separate caret/Save hit targets, lowest rendered caption row aligned to visible tag top. Inspect all supported locales/font styles/text sizes and relevant viewport scales; include wrapping and ending layout. Screenshots must accompany geometry checks.
- Direct Settings: one click from scene shows computer plus Settings, applies existing preferences, and exits through the existing intended close/back flow without advancing text or duplicating History/read marks. Include an available/held Challenge case and failed admission.
- Overlay: uncovered labels remain visibly drawn, covered labels are naturally occluded, all seven commands and their alternate inputs do nothing while held. Closing remains possible; held presses do not fire after closing. Test actual command effects, not only disabled properties.
- Skip/Auto: names alone visually, discernible selected mode and accessible state, existing skipping/auto behavior and required stops unchanged.
- Saves: numbered, Quick and Autosave work without splashes; existing files with and without ink metadata load; subsequent saves omit active ink data; failure/delete/reopen do not recreate decorations. Preserve text, timestamps, selection/focus, recovery behavior and saved run data.
- Regression: self-talk scrollback and paired reading, divider dragging, pixel dissolve input hold, and retained computer/Challenge navigation still work. Update layout-dependent transition masks if the moved tag/rail changes their exclusion geometry.

Documentation preparation verified the cited code and preserved the drawer source. No runtime implementation or new cloud test run is claimed by this handoff.
