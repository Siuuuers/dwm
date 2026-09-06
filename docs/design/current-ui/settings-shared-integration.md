# Shared Settings on the witnessed UI lineage

Settings now uses the same seven-category content scene in Title, Desktop, and
the injected Pause host. The shared plate is 800 × 656. Its existing licensed
Source Sans / Source Han fonts support English, Simplified Chinese, and
Traditional Chinese at 100%, 125%, and 150%. Category and sheet scrolling remain
independent. Native dropdowns, binding capture, and reset confirmations retain
their own dismissal before Back can leave Settings.

This integration starts from `1275ab6343b2382f0034110cfb6dcc7747149d31` and
semantically adapts Settings and Controls from the pinned
`26de279be5f6490ff453db359b1964ec10596962` source. It is not a branch merge.
The current Pause, Backup, registered-line, history, and save/restore interfaces
remain the integration context.

## Saved preferences

Profile version 4 explicitly upgrades versions 1, 2, and 3. Its ten closed root
fields combine canonical Settings and Controls with migration receipts and an
inert `legacy_preferences_v1` archive. A validated version-one preference tree
is retained exactly in that archive; it is not read by current UI consumers.
Language aliases, volume and mute values, history, Gallery receipts, and
one-time migration records survive the upgrade. Retired numeric reading values
map to the nearest accepted delay; accessibility values use explicit size and
strength thresholds. Their original values remain in the archive.

Restore Preferences retains the complete language tuple, Controls, and the
existing capability-owned state. Reset Entire Profile restores the default
language and Controls. Reset operations retain migration receipts so older
sidecars cannot silently replay a consumed migration. Registered-line admission
continues to require the active registry and fingerprint.

Controls has keyboard and controller slots for the four accepted actions.
Legacy mappings remain provenance while import review is pending; they do not
become active InputMap bindings. Confirmed capture, conflict resolution, and
whole-map import publish through Profile and InputManager. Native UI actions
remain available during pending import.

## Runtime scope

Primary language, text size, reading reveal/auto preferences, and canonical
audio restoration are connected to their current consumers. Audio restoration
retains Pause suspension and supports the master bus and an owned mono effect
without replacing other Master effects.

Several Settings choices still need their runtime owners before this family
can be accepted as complete:

- Audio volume preview, samples, and reset settlement use a capability contract;
  the current AudioManager does not yet provide that Settings transaction API.
  The corresponding controls show unavailable and do not fall back to direct
  profile writes.
- Read-aloud requires a TTS owner. Its unavailable state preserves desired
  preferences without pretending speech is available.
- Publishing rebound gameplay actions does not yet connect Quick Save/Load or
  replace the remaining hardcoded Minesweeper commands.
- Window mode, dual-language reading, native skip policy, screen shake, and
  sound-detail presentation still require end-to-end runtime acceptance.
- The injected Pause host is tested separately from mounting Pause in production
  narrative playback. The remaining admission work is described in
  [the Pause Backup checkpoint](pause-backup-host.md).

Beads `dwm-eei.2`, `dwm-eei.3`, and `dwm-eei.5` track these remaining duties.
The all-family UI goal remains active. No merge or push is part of this checkpoint.

## Verification

The combined isolated Godot run passes 367 tests and 22,075 assertions across
38 suites. It covers profile upgrades, interrupted-file admission, deferred
publication, reset and restore behavior, Controls, shared hosts, Pause, and the
affected witnessed-caption consumers. Separate disposable-project Desktop,
Settings, and Title navigation suites also pass.

Eleven GPU captures cover the three locales at all three sizes plus Pause
preview and entered Settings. The rendered check found and fixed a category
label overflow at 150%; full font sizes are retained. The exact coverage and
measurements are in [the evidence summary](../../../evidence/settings_shared/summary.json)
and [render measurements](../../../evidence/settings_shared/measurements.json).

Retained logs include the Windows certificate-store and Unicode NUL diagnostics,
and 864 reported orphan objects from the native Dialogic fixtures. Passing this
run is not a claim that those fixtures are free of leaks, nor does it establish
screen-reader or full production-route acceptance.
