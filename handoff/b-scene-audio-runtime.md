# B scene audio — accepted successor and historical candidate

## Acceptance reconciliation — 15 October 2026

B's assigned scene-audio increment is complete in A's integrated successor
`fa965f7cb7b0c32cb7682758804cc9fc8eee3bc0`.
The original B runtime commit `2609e9f98515257254145347e36f8c09f265883a`
is historical: do not replay it over the corrected integration.

A corrected the initial-NewRun restore path to carry transient
`scene_audio_mode` (`entry` or `load`, default `load`) through prepare/apply.
Initial NewRun uses the entrance; explicit Load uses the authored anchor, even
for the same initial admission. This selector is not a durable saved field.
The original implementation record below predates this correction.

Retained acceptance evidence in PR #30:

- Owner lane: **62 tests / 624 XML assertions**, run38629834675,
  job116078528772; accepted candidate
  `4ba2802e9f9b4181d8b30b911cf4305fd6dfa28a`. A receipt6177430700.
- Canonical registration3 connected journey: **2 tests / 234 XML assertions**
  (133 creator, 101 fresh loader), run38634133827, job116092852508.
  Frozen candidate `7c12113cea1f64553f4186e39d6efb98ea112493`,
  tree `b3448749bcd99dfb4677105f8bf92f5c83476c62`.
  A's integration and original-evidence receipt:6178115787.
- The connected journey covers native start requests at entrance0ms and
  Load1000ms, computer continuity, real Save/fresh-process Load, preserved
  admission with changed branch, retained reading/Challenge/Profile/history
  checks, and a subsequent mine transition to authored silence with a new
  admission and no readiness restart.

B independently checked the successful connected job status and the integrated
AudioManager transient-mode source during reconciliation. Counts and archive
verification above are retained A evidence; B did not rerun Godot/PowerShell or
rehash the archive in this reconciliation.

This is functional TEST acceptance, not production soundtrack, listening,
export, latency, or whole-game acceptance. C's separate accepted pointer
Save/Load journey is composed in the integration; no combined pointer/audio
acceptance run is claimed. Save/recovery/history and legacy saved-context
guarantees remain in scope.

A's recorded next assignment is bounded TEST Contacts entry/return. B does not
duplicate that assignment. This update changes only B's historical handoff;
the pending language and 60-case estimate below describe the original candidate
and are superseded by the receipts above. No further B audio runtime change or
repeat acceptance run is required by the recorded results.

---

## Historical candidate record (superseded acceptance status)


15 October 2026 (Hong Kong). Implements accepted interface6176921937 and
Director6177016339, reserved in6177049145. Base:
`84b1424fbd7c12053f2d07a7f01cec8c909e4927`.

## Delivered behavior

AudioManifest validates the exact bounded catalogue and resolves immutable
scene selections using the canonical whole-registration digest. Returned data
is detached. Receipt-to-entry authority remains with A's scene ledger.

AudioManager obtains definitions from DialogicEntryManifest at runtime, checks
present resource source-byte digest/type/duration before mutation, and hands A
a detached transient `{snapshot: context}` plan. Apply re-resolves this semantic
input; caller-supplied offsets or streams are never trusted. The same complete
admission context is idempotent. New admissions start at the registered entrance;
explicit restore always uses the authored Load anchor. Missing registered media
adopts the same semantic selection with authored silence and a factual warning.
Wrong present media digest refuses before playback mutation.

Scene application clears the old long-lived music/ambience output, then installs
the bounded ambience or silence through existing port/player ownership. There
are no scene-local players or new managers. Existing physical capture/rollback
also covers tagged semantics and streams. Compensation failure latches the
existing fatal/shared recovery boundary. Settings restoration remains part of
the same compensated operation.

PlaybackPort.play accepts a defaulted position; existing one-argument calls
still start at zero. Negative/nonfinite positions refuse before mutation.
The existing fake records the requested position for owner assertions.

Legacy four-key contexts retain their own validation/restoration. While a tagged
scene selection is active, legacy context setters return `scene_audio_active`
rather than add legacy keys to its exact durable shape. An explicit legacy
restore can leave scene mode, and compensation restores the prior tagged state
and physical playhead. Legacy getters return empty IDs for tagged selections;
the canonical capture API returns the complete tagged context.

## Exact changed paths

- `autoload/AudioManager.gd`
- `scripts/data/AudioManifest.gd`
- `scripts/audio/AudioPlaybackPort.gd`
- `tests/support/FakeAudioPlaybackPort.gd`
- `tests/unit/test_scene_audio_manifest.gd`
- `tests/unit/test_scene_audio_manager.gd`
- `tests/unit/test_scene_audio_playback_port.gd`
- `tests/fixtures/audio/scene_test_bed.tres`
- `tests/fixtures/audio/README.md`
- this handoff

The two asset files are byte-identical to candidate14840403. No shared A/C files,
controller, registration/schema, integration branch or master changed.

## Review and actual verification

Manifest and playback-port implementation had separate internal owners; root B
implemented AudioManager and reviewed their diffs. The playback worker authored
manager tests independently of the manager code. A further read-only reviewer
checked all runtime changes and tests against A's accepted contract and found
no concrete blocker. This is source review, not engine acceptance.

Static `git diff --check`, exact source scope, test declaration census and retained
asset hashes checked. No Godot/PowerShell ran here. No generated test UIDs yet.

| New suite | Declared tests |
| --- | ---: |
| scene audio manifest | 13 |
| scene audio manager | 10 |
| scene audio playback port | 4 |

Manager tests override only the installed-registration reader with a fixed
unit fixture because A's registration3 hook is not in this candidate. They use
the actual synthetic resource for media loading/type/duration, with a fake
physical playback port. This is NOT canonical registration, checkpoint, saved
receipt authority or fresh-process Load proof. Port tests separately use real
Godot players and a silent seekable stream with 0.1-second position tolerance.
Those tests too remain unexecuted.

## Focused cloud command for A

Use standard Godot4.6.3, import first, then the existing isolation helper. The
proven isolated root selects manual test bootstrap; do not pass unsupported
custom bootstrap arguments through GUT. The three retained suites cover changed
legacy/restore/physical-suspension boundaries (23+4+6 cases). Combined expected
census is **60 cases**, not an executed result or assertion count.

```powershell
& tools/testing/Invoke-IsolatedGodot.ps1 -SuiteId scene-audio-owners -LogName scene-audio-owners.log -TimeoutSeconds 240 -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gconfig=','-gtest=res://tests/unit/test_scene_audio_manifest.gd,res://tests/unit/test_scene_audio_manager.gd,res://tests/unit/test_scene_audio_playback_port.gd,res://tests/unit/test_audio_manager.gd,res://tests/unit/test_save_manager_desktop_board_audio.gd,res://tests/unit/test_audio_pause_suspension.gd','-gexit','-glog=2','-gjunit_xml_file=res://.godot/ci/scene-audio-owners.xml')
```

Require exit0, exact census, zero failures/errors/skips and strict script-error
gates; retain original logs/XML, candidate identity and generated UIDs. A owns
any public API inventory reconciliation required by the existing gates.

## A's remaining composition

Use the accepted registration3/audio-context1 contract, not the test override.
Freeze target semantics before checkpoint commit and adopt playback only after
commit, before native captions. Cover initial and later scene admissions. The
normal Save checkpoint captures the active semantic audio. Fresh-process Load
uses the existing restore participant and must not be followed by a forward
readiness restart. Computer open/close must not call audio suspend/admit.
Authenticated receipt-to-entry binding is A-owned and is not conferred by this
manager's context validation.

Source-byte media hashing assumes the source .tres is available; the current
TEST source lane has it. No exported-package playback claim is made. A must
verify source retention/remapping before extending this to export acceptance.

A remains sole cloud/controller/integration writer. This candidate is ready for
review and a focused owner lane independently of Contacts; connected registration,
target checkpoint, real Save/fresh Load, and computer continuity need A's composed
candidate. Do not count unit overrides as that acceptance. No Beads closure,
production soundtrack/listening approval, whole-game result, merge or release.
