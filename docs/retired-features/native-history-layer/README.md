# Unused native History widget

Removed layer 17 from the Witnessed Caption style on 12 November 2026.
The Dialogic example panel supplied a hidden History button, empty log, theme,
native open/close signal listeners and a per-frame callback. No current production
or test caller opens this native widget. The player-facing History belongs to
WitnessedCaptionLayer / WitnessedHistory and SceneRouter custody instead.

Retain the Dialogic History subsystem, its collections and the addon example
files used by other styles. No persisted fields or player History are removed.
Keep remaining layer IDs and the editor's monotonic latest-layer counter intact.
