# Witnessed caption and scrollbar targets

The mounted caption now reads `preferences.accessibility.large_click_targets` from the existing Profile owner at initial mount and on publication. Large Targets gives the interactive current caption a 64 logical pixel minimum height. Passive retained captions keep their existing measurements. Text remains at 20, 25 or 30 logical pixels for 100%, 125% or 150%.

The shared native scrollbar has a 48 logical pixel hit width and minimum thumb height ordinarily, or 64 with Large Targets. Its visible track remains 12 pixels wide and its thumb 4 pixels wide, inset inside the actual native pointer area. The field and transport reservation retain their fixed geometry; overflow text wraps within the remaining width. No overlapping invisible target or extra focus stop is introduced.

The Profile API continues to own validation and persistence. Invalid preference writes leave the live presentation intact. Geometry changes cancel a pending caption click and retire an active native scrollbar drag through its synchronous visibility reset. They retain native text/reveal/history identity and focus, and preserve feasible manual scroll. Colour-only changes keep their existing pending-contact behavior. A fresh drag works after release.

This checkpoint covers the current caption and shared scrollbar. It does not establish target-size compliance for the retained addon History launcher, unfinished transport, other modal layers, or arbitrarily clipped caption fragments while manually scrolling. The complete Witnessed family still requires its canonical History and transport integration, authored content, dual language and assistive-technology verification.

## Evidence

The initial regression run reproduced the missing preference and undersized scrollbar: 27 of 29 tests passed, with 78 failed assertions. After the change, actual native mouse input also verifies paging and short-thumb dragging from the widened control edge outside the drawn gutter.

Independent review identified a held native drag surviving a geometry change. The added regression failed with the scroll position jumping from 114.615 to 260.229 on the next held motion. After cancellation was added, the final eleven-suite run passed **174 tests / 5,244 assertions**, exit 0 (`witnessed-targets-final-20260906a`). It includes initial saved-preference application, invalid-write refusal, preservation across three locales and text sizes, cancellation during held caption clicks and native thumb drags, and successful fresh interaction. The installed addon fixture reports 768 known constructor orphans; no new script error remains.

The GPU renderer produced 24 primary captures and six unfocused references across English, Simplified Chinese and Traditional Chinese, all three text sizes, and both target modes. It exited 0. The existing protected-frame proof found zero changed glyph-interior pixels on focus changes. English and Chinese short captions at 100% meet the 64-pixel Large Target floor. Fixtures are explicitly synthetic; they do not demonstrate authored Hospital content.

Reproduce the visual checks through `tools/testing/Invoke-IsolatedGodot.ps1` with `tests/ui/render_witnessed_targets.gd`. Captures, measured geometry and invocation logs are retained in [evidence/witnessed_targets](../../../evidence/witnessed_targets). The native runtime regressions remain in `tests/integration/test_witnessed_caption_runtime.gd` and use temporary in-memory Profile storage, never player saves.
