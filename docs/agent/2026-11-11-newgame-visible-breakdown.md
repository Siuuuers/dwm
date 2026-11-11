# New Game visible latency investigation

Source: `08c3f0f43df9157ce4563c055573062b113057b5` (master after PR #273).
Outcome: identify the next avoidable New Game delay without changing runtime behavior.
Evidence: `tools/player_latency/evidence/2026-11-11-newgame-visible-breakdown/`.

## Complete operation

Godot 4.6.3, Linux headless, sequential fresh processes and user profiles.
New Game is clicked two seconds after mandatory runtime readiness. Success requires
exact opening caption, visible and fully revealed, native completion, presentation
acknowledgement and unblocked input. Opening Computer must preserve the caption.

Three uninstrumented runs: **430.285, 328.845, 447.146 ms**; median **430.285 ms**.
Computer: 25.189, 25.096, 32.463 ms. Host variation is large; do not infer a
regression from previous sessions. Six instrumented diagnostics also passed the
same checks. All nine runs completed without engine errors or warnings.
Headless readiness is not a physical first-paint measurement or Windows evidence.

## Attribution

These spans overlap and must not be added together.

| Owner / operation | Observed diagnostic cost | Interpretation |
| --- | ---: | --- |
| Menu busy presentation | about 27 ms | Two calls each yield two frames before preparation |
| SaveManager initial preparation | 94–115 ms | Includes authored programme parsing and initial configuration |
| Styles deferred mount | 66–77 ms | Includes 28–32 ms native timeline start; remaining mount about 37–45 ms |
| Artwork refresh | 44–55 ms | Two texture loads account for about 41–52 ms |
| Caption ready | 24–27 ms | Nested in mount; preference/theme setup about 10–12 ms |
| Deferred reading refresh | 14–24 ms | Includes caption projection and transport work |
| First text parsing | 37 ms in detailed trace | English catalogue loading/parsing accounts for 36 ms |
| Ordinary caption layout | below 1 ms | Not a leading target |

The 100 ms input guard overlaps other work. In two milestone traces, unblocking
followed the other readiness conditions by only about 3–4 ms. Removing it would
not recover 100 ms from these runs.

The later caption configuration changes dating mode from false to true; it is not
an identical repeated configuration. Fonts, locale and size remain unchanged.
Do not remove that configuration without preserving the mode transition.

## Best next experiment: shipped catalogue parser

`DialogicBridge._translate_story_text` checks the English reference catalogue
before translating. `StoryLocalization.catalog` currently parses it with the
scripted StrictJson reader. The detailed trace attributes 36.269 ms to this call.

A standalone matched parser comparison used each of the five shipped catalogue
strings, in strict/native then native/strict order. Both parsers produced identical
dictionaries with 1,682 entries for every locale. English strict parsing took
32.104–32.844 ms; native parsing took 2.428–4.989 ms. Other locales took about
66–92 ms strict versus 1.6–1.9 ms native. This excludes file I/O, uses preloaded
strings, and is not an end-to-end speedup claim.

The existing story catalogue validator passed for all locales. It rejects duplicate
keys and verifies the English catalogue against authored DTL. The next bounded
change should evaluate native JSON parsing only for these validated shipped
catalogues, retaining cache behavior, dictionary fallback, English source matching
and translation/markup semantics. Do not change StrictJson for saves or unknown data.

Before editing: inspect all StoryLocalization callers and the bilingual projection
checks. Acceptance: all five catalogue values remain equal; focused English and
translated/bilingual caption checks pass; alternating uninstrumented baseline and
candidate runs use the same usable-caption criterion. Preserve missing-catalogue
fallback. Add no new parser abstraction or dependency.

## Second candidate: menu frame waits

`MenuScene._present_new_acc_busy` is called for preparing and starting. Each call
waits two process frames. The boundary trace measured 13.291 and 13.478 ms.
Review whether one busy presentation is sufficient. Preserve visible feedback,
source-custody checks and single activation; verify the rendered click journey
before removing waits. Headless timing alone cannot establish correct feedback.

## Reproduction and limits

The evidence directory contains the probe sources, temporary instrumentation
scripts, raw compressed logs, extracted spans, run summary and SHA-256 manifest.
Instrumentation scripts restore source bytes in a finally block. Their print and
wrapper overhead makes them diagnostic only. Run engines sequentially.

For the standalone parser probe, create a minimal Godot project, copy the source
revision's `scripts/validation/StrictJson.gd` beside `catalog-probe.gd.txt` renamed
`probe.gd`, and run it with `DWM_SOURCE_ROOT` set to the repository absolute path:
`godot --headless --path <probe-project> --script res://probe.gd`.
Catalogue validation: `python tools/localization/validate_story_catalogs.py`.

No production code changed. No broad test matrix, fault injection or new Windows
export was run for this investigation. Existing artwork warming was already
rejected in PR #269; this evidence does not justify repeating that change.
