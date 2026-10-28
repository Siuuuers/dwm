# Save-slot ink retirement

Decision: 2026-10-28, owner playtest amendment.
Status: removal requested; this documentation commit does not remove runtime code.
Inspected master: `76c39d0a4acb33f858fba18b6c2bc9ad7cdb24c4`.

## Decision

Remove save-slot splash ink for now from all save types: numbered, Quick and Autosave. Preserve ordinary save feedback, slot paper, selection/focus, save contents and Load. Do not keep an enabled-by-default effect or dormant feature toggle. This does not retire the Shop's inked silk string decoration.

## Preserved implementation and design

[BackupDrawer.gd.txt](BackupDrawer.gd.txt) is the exact complete drawer source at the inspected revision, including the procedural splash drawing. It is historical non-executable source, not a replacement runtime file.

Original selection: successful saves append a fresh seed to destination-owned optional metadata; prior splashes fade by 0.65 per overwrite, maximum eight seeds, omit paint below 5% opacity. Delete clears that slot's marks. Opening, repainting and loading do not age marks. PR #143 implemented the effect; PR #145 enlarged/darkened it and spread it across the paper. These prior completions do not override this retirement.

Related source at the same revision:

- [autoload/SaveManager.gd](https://github.com/Siuuuers/dwm/blob/76c39d0a4acb33f858fba18b6c2bc9ad7cdb24c4/autoload/SaveManager.gd)
- [scripts/infrastructure/save/SaveDocumentSchema.gd](https://github.com/Siuuuers/dwm/blob/76c39d0a4acb33f858fba18b6c2bc9ad7cdb24c4/scripts/infrastructure/save/SaveDocumentSchema.gd)
- [scripts/application/backup/BackupPresentationPort.gd](https://github.com/Siuuuers/dwm/blob/76c39d0a4acb33f858fba18b6c2bc9ad7cdb24c4/scripts/application/backup/BackupPresentationPort.gd)
- [scripts/ui/BackupApp.gd](https://github.com/Siuuuers/dwm/blob/76c39d0a4acb33f858fba18b6c2bc9ad7cdb24c4/scripts/ui/BackupApp.gd)
- [scripts/ui/backup/BackupDrawer.gd](https://github.com/Siuuuers/dwm/blob/76c39d0a4acb33f858fba18b6c2bc9ad7cdb24c4/scripts/ui/backup/BackupDrawer.gd)

## Removal boundary for the next session

Remove splash generation, active metadata production/projection and drawing, plus newly orphaned ink-only helpers and tests. Trace every `ink_marks` consumer before editing. SaveDocumentSchema currently recognizes this optional field and uses strict key validation: deleting recognition alone can reject existing saves. Retain the smallest read compatibility needed to accept and ignore old decorative metadata; newly written saves should omit it. Do not migrate or erase player slots merely to remove decoration. Keep normal slot/focus drawing that uses variables named ink: that is theme text colour, not necessarily the splash feature.

Replace active ink expectations with focused no-splash and old-save compatibility checks. Keep historical evidence intact. Reopening the feature later requires a new decision; this archive does not schedule restoration.

Implementation handoff: [bottom-bar and ink amendments](../../agent/2026-10-28-bottom-bar-and-ink-amendments.md).
