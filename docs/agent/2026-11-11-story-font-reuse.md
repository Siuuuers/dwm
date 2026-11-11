# Reuse the pixel story font

## Outcome and owner

Reduce first story-font setup without changing glyphs, fallback order, text size,
baselines or the shared UI face. UiTypography owns the font and story cache.
Base: master 62f93e31c4dde5a5c74b6125129972e36ba8247c (PR #266).

## Investigate before editing

The deferred activation audit found about fourteen repeated currentness checks.
Their measured total was about 10 ms; leave them intact. Native timeline startup
was about 4 ms. SceneHost presentation setup was about 87 ms in the attribution
run, of which duplicating the font took 81.959 ms. The hidden Home theme took
0.206 ms. Do not remove controls or recovery for these small costs.

The old story-font constructor duplicated a FontFile and immediately cleared its
cache. Pixel faces already disable system fallback. Use the existing FontVariation
pattern to retain that primary face and add the same explicit story fallbacks.
Readable fonts retain their old copy because they independently disable system
fallback. No saved data, activation protocol, scene content or UI is removed.

## Checks and limits

- Independent caller audit: production consumers accept Font. Updated the one
  existing test that assumed every story font was a FontFile.
- Focused suites: test_font_styles and test_witnessed_reading_rail, 18 tests,
  1,808 assertions, exit 0. Covers all 30 language/size/style tuples, fallback
  glyph, shared-face isolation, string width/height and separate ascent/descent.
- Uninstrumented New Game after runtime readiness, fresh profile each run,
  B/C/C/B: 808.927 / 1093.677 / 941.528 / 1289.777 ms. Baseline median
  1049.352 ms; candidate 1017.603 ms. Two samples per side on a variable cloud
  host do not establish a reliable end-to-end speedup. All reached the same
  acknowledged, visible, fully revealed first caption with input unblocked.
- Isolated first English 125% pixel story-font setup: baseline 146.864 ms,
  candidate 7.144 ms (includes fallback loading). Subsequent cache-reset setups:
  baseline 36.244–132.611 ms, candidate 0.012–0.070 ms. This measures font
  construction, not a complete player journey. Normal retained-cache reads
  remain shared in both versions.
- Evidence and probe sources: tools/player_latency/evidence/2026-11-11-story-font-reuse.
- Windows run [42984784764](https://github.com/Siuuuers/dwm/actions/runs/42984784764)
  passed on source cb1663e7e2063c726b7e78e7a32d76b9429e38e5. Export, pack audit,
  capability, opening, Computer, Save and fresh-process Load passed; player logs
  were clean and each process exited normally. Exact caption/checkpoint restored.
  Opening, Computer and restored screenshots reviewed; caption is legible with
  the same wrapping and placement. This is not a pixel comparison to the old build.
- Windows Create title: 7821.160 ms; early New Game to observed caption: 3746.055 ms;
  Load selected slot to caption: 667.306 ms. UIA upper bounds on Forward+/D3D12,
  Microsoft Basic Render Driver, Dummy audio, accessibility Always. These are
  acceptance observations, not a matched speed comparison with the previous run.
- Artifact 13839825034 SHA256:
  b0491e5710b6a0687c2a565bf8b812eb83c3c1b2a5e78513bf0ddd6d844b372b.
  Export ZIP SHA256:
  414381a574f72bc382ea4fb00f9332009f31e583073d379ad455d8bac3d5f5a6.
- No whole-game latency claim, full story replay, storage fault injection or
  unrelated suite matrix. Readable font construction remains unchanged.

## Next bounded investigation

Measure synchronous artwork publication: texture loading, get_image,
detect_alpha, split_changed and caption layout separately. The audit found
portrait alpha scans even for layouts that do not consume the result, but no
saving is established yet. A later two-portrait layout still needs correct
classification. Deferred reading-session refresh is outside this synchronous
publication span. Do not delete either behavior based on call count alone.
