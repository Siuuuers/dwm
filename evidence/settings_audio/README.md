# Audio preferences on shared Settings

This checkpoint enables volume preview/commit, mute, stereo/mono output, and
audio-aware preference resets on the shared Title/Desktop/injected-Pause
Settings surface. It starts from `448d4d8f046f8f1d8160081db40a00f1f4c3dfd6`.

[summary.json](summary.json) binds the final tested source bytes and exact
acceptance invocation. [invocations.jsonl](invocations.jsonl) records disposable
Godot user directories, exit codes, and all retained runs. The isolated harness
uses no player data.

Coverage includes:

- Native input through the actual Settings scene: pointer preview without disk
  writes, one release commit, five-percent keyboard step, mute/mono selection,
  Escape/departure cleanup, and confirmed scoped reset.
- Real Profile and storage transactions: stale handles/revisions, failed writes,
  synchronous publication callbacks, current-Profile compensation, focus changes
  during output application and settlement, and shared fatal custody.
- Real AudioServer output capture/readback/restore: exact paused stream/playback
  identity and playhead, retained crossfade tween/Pause capsule, owned mono
  effect, foreign effects, malformed capsules, and failed or false-success
  setters. The silent generator contains no sample audio.
- Combined existing Settings, Controls, localization, Profile upgrades, Pause,
  witnessed-caption, save schema, production restore adapter, desktop recovery,
  and Minesweeper persistence suites.

The retained first live run failed because a fixture clicked a checkbox outside
the visible scroll clip. Native focus plus Space corrected that interaction.
The first transaction run exposed a real fatal-gate diagnostic mismatch:
StringName-valued adapter details were rejected by the primitive-JSON gate.
The final code projects a primitive cause code to the shared gate and keeps full
diagnostics on the local audio warning.

Independent review found focus-settlement and Pause admission-order defects.
Both were corrected with direct regressions; the final bounded review reported
no remaining blocker. An unused dirty flag was removed because Profile revision,
snapshot, and focus generation already provide settlement evidence.

Sample Test buttons remain unavailable: there are no registered production
Music/Ambience/SFX sample bytes. This evidence does not establish audible quality,
native speech, production Pause mounting, or completion of Settings or all UI
families. No font/layout change or new GPU capture is part of this checkpoint.
The earlier shared Settings images remain in `../settings_shared`.

Logs retain existing Windows certificate-store, Unicode NUL, localization
warning, and Dialogic fixture orphan diagnostics. There is no leak-free claim.
No branch merge or push was performed.
