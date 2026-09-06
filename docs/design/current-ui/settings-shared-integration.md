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

- Audio sample playback still needs registered production Music, Ambience, and
  SFX assets. The Test controls remain unavailable. Volume preview, mute,
  stereo/mono output, and preference-reset settlement now have their real owner
  transaction API; see the successor checkpoint below.
- Read-aloud requires a TTS owner. Its unavailable state preserves desired
  preferences without pretending speech is available.
- Publishing rebound gameplay actions does not yet connect Quick Save/Load or
  replace the remaining hardcoded Minesweeper commands.
- Dual-language reading, native skip policy, screen shake, and
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

## Audio preferences successor — 2026-09-07

Starting from `448d4d8f046f8f1d8160081db40a00f1f4c3dfd6`, the shared Settings
surface now enables four volume controls through AudioManager. A pointer drag
changes physical output without writing Profile; release commits once. Native
keyboard adjustment uses the existing five-percent step. Mute, output mode,
Restore Preferences, and Reset Entire Profile use the same physical settlement
boundary and existing Profile publication/reset rules.

The output capsule contains bus gains/mutes and the owner's mono effect. It
excludes players and crossfades, so cancellation and failed persistence preserve
playback identity, playhead, tween identity, and Pause suspension. Native
AudioServer readback proves settlement. Music and Ambience apply preference gain
once at their buses; player gain describes the crossfade only.

Transient handles retain their issuing holder and preference path. Cancel,
departure, focus loss, Pause entry/resume, and restore retire current previews
before the corresponding transition. A refused or repeated suspension request
preserves the current holder's preview. Deferred publication remains fenced
through synchronous callbacks; a changed Profile revision or focus generation
requires settlement against current state. Unprovable settlement latches both
the Audio owner and the shared mutation gate. Primitive gate diagnostics retain
the cause code; local audio warnings retain full adapter diagnostics.

No new audio asset is fabricated or repurposed. The active manifest's production
paths lack sample bytes, and the pinned reference catalogue has an empty assets
list. Dialogic's example typing sounds are not registered production samples.
This is preference-control acceptance, not audible quality or sample acceptance.
No layout or font changed in this successor.

The successor's exact source hashes, isolated invocations, retained initial
failures, final regression counts, and limitations are in
[the audio evidence summary](../../../evidence/settings_audio/summary.json).
The earlier 367-test report and GPU captures above describe the preceding shared
Settings checkpoint. Settings and the all-family UI goal remain in progress;
there is no merge or push.

The following [Window Mode successor](settings-window-output.md) connects native
window preferences and their combined reset/restore behavior on Windows.
