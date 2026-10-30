# Current-caption self-talk panel

Implements PR #174 on `efd71b93844744f1e0e1e69c01cfb0a7c069e4c1`.

The owner confirmed that previous thoughts are reviewed only in History. This supersedes the accumulated live window and panel scrollback decisions in the 28 October plan. A long current thought remains scrollable.

`SoloReadingSession.project_self_talk` projects only the current caption's encountered attached thought. The existing frontier and localization cache own refresh and Load; no new state, save schema, delayed callback, or DTL syntax is introduced. Completing reveal does not change this frontier. `DialogicBridge.get_reading_history` now includes the encountered thought rows in DTL order; the separate ordinary caption-memory filter remains.

`WitnessedSelfTalk` reserves a stable frame for empty and populated content. The caption layer owns visibility and input admission, including timed holds. Empty frames do not join keyboard focus. Existing canvas overlays and choice-control ownership remain. Mono thoughts reserve three font rows; bilingual thoughts use the existing bounded text region. Wheel/drag can read the current thought, never older thoughts.

## Focused evidence

The Linux lane shares one pinned Godot install/import across two unit scripts, two filtered mounted input tests, the paired reading journey, separate-process populated/empty Save/Load, Auto/Skip, and choices. The mounted journey opens the actual History log and checks order, reveal completion, empty/populated frames, 125%/150% reflow and bilingual text, actual 1920×1080 client dimensions, and a smaller window. Independent test data stays isolated; only the Save/Load pair shares storage.

The separate readability workflow remains applicable because reserved frame geometry changes. Unrelated purchase, full-week, persistence benchmark, API-inventory, and Windows export suites are not selected for this scoped diff. No native Windows/DPI acceptance or measured gameplay speedup is claimed.

Cloud results and screenshot artifacts are linked from the implementation PR. No baseline rerun is required to establish the behavior change: the old retained-window assertions are replaced by current-caption and History assertions.
