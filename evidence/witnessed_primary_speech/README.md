# Shared Primary speech for Witnessed captions

2026-09-14; partial `dwm-vky.14` checkpoint based on
`835e50ee7b9227e2bc27a538f6827539bae42782`.
Integrated onto the other session's already-merged master checkpoint
`af9a43e14040f229a37cc13df1d19dad38702da9` before publication. All 28 files changed
by that session remain byte-identical; all 23 speech source/helper hashes also
remain unchanged. Only generated public source references required a refresh.

The mounted Witnessed caption now sends newly presented Primary text to one
shared OS speech coordinator. Settings uses the same owner for Read Aloud
capability, rate and Test/Stop. It chooses a compatible installed voice for the
actual content locale, including authored English fallback under Chinese UI.
Missing voices do not silently substitute another language. Speaker identities
are never prefixed.

Speech starts during reveal. Auto's existing 1/2/4-second foreground countdown
runs concurrently and waits at zero until the current utterance has retired.
Accept, transport, Pause/custody, focus loss, source replacement and preference
changes stop the owned utterance. Restore and uncover do not replay it. Appended
text speaks only a proven fresh suffix; a restored append keeps a suppressed
transient base so its next fresh suffix can speak. No speech identity becomes a
visited-history record, story receipt or save field.

The accepted uniform Game Mix duck is -12 dB with 120 ms down and 180 ms recovery.
It routes Music, Ambience, SFX, UI and the existing Voice bus through one temporary
mix without changing their gains, mute settings or persistent preferences.
Monotonic elapsed time prevents the creation frame's prior delta from shortening
a fade. Only a deliberate successful Settings TTS Stop produces the existing
restrained confirmation cue after recovery. Failure produces localized factual
status; the Witnessed notice is nonmodal, polite, noninteractive and outlined for
legibility over scene art. Per-port token tracking uses one increasing integer,
not a process-lifetime collection of every utterance.

Authority: [Witnessed scene, sections 8 and 15.2](../../docs/design/current-ui/witnessed-scene.md),
[reading apparatus](../../docs/design/2026-08-22-ordinary-witnessed-scene-reading-apparatus-standard-palette-and-state-disposition.md),
and [Acoustic Memory Atlas, section 8.3](../../docs/superpowers/specs/2026-08-14-acoustic-memory-atlas-audio-design.md).
The inactive lower-background row is removed from visible Settings; its legacy
profile field remains for compatibility. The duck is uniform and has no visible
preference.

## Verification

- Final integrated regression: **16 suites, 215/215 tests, 6,471 assertions,
  exit 0**, including the full speech/reading/Settings/audio set and both
  inventory/document tooling suites on the updated main baseline.
- Surrounding regression before the final outline/token simplification:
  **14 suites, 199/199 tests, 6,043 assertions, exit 0**.
- Final affected owner, port, duck, status, mounted caption, projection and
  Settings suites: **7 suites, 112/112 tests, 4,722 assertions, exit 0**.
  These include real installed Dialogic and production Settings integration,
  restored append continuity, stale ownership, reentrant failure recovery,
  concurrent Auto expiry, and failed status without caption/history mutation.
- Final visible-button and shared Settings host check: **41/41 tests,
  648 assertions, exit 0**, after adding the button-level assertions below.
- Windows native final probe: compatible `en_US`, `zh_CN`, `zh_HK` voices
  enumerated; actual English natural ENDED and explicit stop complete with
  restored game gain and original bus routing. Observed admission-to-dispatch
  times were 209.122 ms and 187.647 ms; recovery observations were 194.184 ms and
  257.274 ms. These are frame-observed native measurements, not exact scheduling
  or human audibility claims.
- Three visually inspected native 1280x720 captures at 150% in English,
  Simplified Chinese and Traditional Chinese. All status pixels fit its rectangle;
  zero changed pixels outside it, no stolen focus, unchanged current and retained
  captions. These are synthetic captions through the installed Witnessed style,
  not authored-story or human screen-reader acceptance.
- Both generated public inventories refresh source references only. Protected
  implementation and required public symbol contracts remain unchanged.
  The final inventory/document tooling gate passes **14/14 tests, 410 assertions**.

## Unsuccessful checks and limits

`runs.jsonl` and `logs/` retain every engine attempt, including RED and diagnostic
runs. Initial failures exposed absent owners/projection, restore append handling,
Settings stop/recovery behavior, a mounted Auto callback arity mismatch, and
reentrant recovery masking a failure. Fixture setup and GDScript Variant inference
errors were corrected before the passing runs. The first native speech probe
caught early Tween completion; the monotonic implementation passed subsequent
native checks. The first native status capture had a helper-only type inference
error; the corrected capture passes all three locales. Outline and bounded token
tracking each have recorded failing checks followed by passing checks.

`witnessed-primary-speech-caption-diagnosis-2` exits zero but reports **Nothing was
run** because GUT's test-name filter was supplied as a comma list. It is not passing
test evidence. An initial wrapper preflight rejected a redundant `--headless`
argument before starting an engine; it has no engine ledger entry. The initial
tooling failure identified stale generated references, not changed public contracts.

A final source-review suspicion that game volume disabled the TTS Test button
was withdrawn after checking the actual branch indentation. No production change
was made for it. The added test verifies the available button and activates its
normal signal, and separately verifies the missing-voice disabled state.

Existing Unicode NUL diagnostics and Dialogic orphan reports remain in the logs;
the 199-test and final 112-test runs each report 1,008 orphans. No warning-free,
leak-free, other-platform, Chinese pronunciation, or exported full-game claim is
made. Archived text logs normalize trailing whitespace and final newlines only.
`source-sha256.json` records verified source/helper bytes; `sha256.json` seals the
archived artifacts.

`dwm-vky.14` and the broader goal remain active. Semantic-session History,
Witnessed Save, exact-variant Next, broader reading arbitration/recovery and
Desktop Primary self-talk publication remain unfinished. History and Desktop
self-talk also require canonical durable owners in the excluded checkpoint/schema
work; transient caption or notification substitutes would violate Load continuity.
Title has no live self-talk producer by design. Witnessed Save likewise overlaps
excluded checkpoint/storage ownership. No `dwm-634*` Bead or owned
branch/worktree, GameState, SaveManager, DatingScene, storage/checkpoint/schema
implementation is modified by this increment.
