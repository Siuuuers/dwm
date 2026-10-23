# Window Mode output on shared Settings

This successor to `53829764cb4bdfc2f8a3d77bab073296205b8e96` connects the existing
Windowed and Borderless choices to the native main window. Windowed offers
1280 × 720, 1600 × 900 and 1920 × 1080 client-size presets. The picker disables
choices that do not fit the current monitor with ordinary frame space. A saved
size reopened on a smaller monitor is fitted proportionally without rewriting
the preference. Borderless uses the current display's usable rectangle without
exclusive fullscreen, retaining the selected Windowed size for the return trip. A rejected operation restores the prior physical window,
selected option, and meaningful focus, then presents the existing factual error.
Changes use immediate native readback and existing exact rollback; there is no
new confirmation timer, exclusive-resolution switch, or render-scale preference.

WindowModeManager owns platform output through WindowModePort. The shared
SettingsOutputTransactions coordinator retains one Profile prepare/commit/
publication sequence across audio, window changes, and preference resets.
AudioManager keeps its audio-facing API and the shared coordinator identity;
it does not own display APIs. Window ownership binds once to the same Profile
and coordinator. A failed initialization can retry only with those exact owners.

Window output captures mode, borderless flag, screen, position, and size. It
changes only those fields and verifies native readback. Rejection restores exact
captured geometry, including a resized Windowed state. A newer committed Profile
takes precedence over an older rollback target. Combined output compensation
runs window before audio; ambiguous compensation latches the shared fatal gate.

Bootstrap initializes the window owner immediately after Audio and before
restore participants. ProfileRestoreParticipant explicitly composes window
preparation, capture, silent apply, and rollback with Profile. It compensates its
own failed apply because the outer restore transaction only rolls back successful
participants. This preserves the existing eight ordinary journal participants
plus identity allocation, existing save format, and primitive profile receipts.

The native adapter currently proves Windows behavior. It uses synchronous
setters and actual native geometry getters, following Godot's
[Windows implementation](https://github.com/godotengine/godot/blob/4.6/platform/windows/display_server_windows.cpp).
Unverified backends and headless processes report unavailable. They do not supply
dummy success or native-window acceptance. Bootstrap retains logical readiness
there while omitting unavailable physical window composition; the Settings row
remains disabled. Other platform backends require their own completion and exact
rollback evidence before being enabled.

Earlier mode-only verification is recorded in
[the window evidence summary](../../../evidence/settings_window/summary.json).
That historical evidence predates the size picker. The extended native test
still needs execution on Windows for the new presets. Native tests use a
disposable Godot process, memory-only Profile storage, and
silent fake audio. They restore the entry window before exiting. Scene tests
exercise the actual shared Settings plate, error/focus restoration, unavailable
controls, and confirmed audio/window preference reset. The combined regression
also covers existing audio, localization, Controls, Profile migration, Pause,
save/restore, and desktop recovery behavior.

The native proof establishes geometry and one Profile commit. It is not a new
font/layout review, audible-quality assessment, or complete production gameplay
acceptance. Settings and the all-ten-family UI goal remain in progress. Missing
audio samples, native speech, other reading/accessibility consumers, gameplay
action wiring, and remaining production scene integration retain their existing
Beads ownership. There is no merge or push.
