# Unused native background and portrait layers

Remove layers 10 and 11 from the Witnessed Caption style. WitnessedArtLayer
(layer 12) and SceneArtView own current backgrounds, portraits, CGs and saved
Scene composition. Caption layer 13 and Choices layer 15 remain.

No current authored native background/character commands or application calls
populate these native holders. Hospital/dating presentation and previews use the
custom art owner. Keep addon Backgrounds/Portraits subsystems and example styles.
Current saves restore semantic Scene presentation, not native portrait snapshots.

The trimmed style does not support arbitrary native Dialogic background/character
commands or old native portrait snapshots. If such support is introduced, provide
appropriate holders first. No current player artwork or save field is deleted.
