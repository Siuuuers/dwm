# Pause custody checkpoint evidence

The final run `pause-accepted-20260907b` passed **317 tests / 7,733 assertions across 23 suites**, exit 0, with no script error. It includes the existing narrative admission, checkpoint, ending, restore, skip, effect, caption and audio tests, plus Pause surface, input, native audio, coordinator, caption-anchor, dialogue-recovery and combined native regressions. Fourteen coordinator tests include source changes inside both asynchronous ports and synchronous view callbacks.

The log reports 2,640 known Dialogic constructor fixture orphan objects and the existing Windows root-certificate/Unicode startup diagnostics. These are not represented as a clean environment or as fixed by this checkpoint. All invocations use isolated user-data roots and preserve the production player-data location.

`pause-gpu-20260907a` exited 0 using the native OpenGL renderer. The 144 ordinary Return combinations and 18 Large Targets comparisons plus Continue produce 163 measurements and 49 screenshots. The images are native 640×360 output, using the actual controls, fonts and locale catalogs. Representative English 100%/150%, Traditional Chinese 150%, Simplified Chinese high-contrast 150%, and Continue images were inspected directly. Measurements preserve original generated image paths as well as portable evidence-relative paths.

Diagnostic logs are retained as failures, not acceptance:

- `pause-dependencies-20260907a`: typed tween-track fixture rejected by native GDScript.
- `pause-components-20260907b`: inactive reserved audio players could not prove `stream_paused=true`; controller fixture lacked an Accept mapping.
- `pause-components-20260907c`: audio resume incorrectly compared `playing` across a suspension. The correction proves the same retained native playback object. The controller fixture now explicitly supplies and restores its semantic mapping.

Committed text logs use UTF-8/LF with trailing whitespace removed. Original raw log hashes are recorded in `summary.json`, with original paths and exact invocations in `invocations.jsonl`. GPU samples and synthetic prose do not establish authored Hospital content, production controller mappings, screen-reader traversal, TTS, hosted Backup/Settings, Return execution, or complete Pause. See the [implementation and integration limits](../../docs/design/current-ui/pause-custody-foundation.md).

`dwm-eei.3` and the all-ten-family UI goal remain in progress. This checkpoint is local; it includes no merge or push.
