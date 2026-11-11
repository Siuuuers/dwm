# One New Game busy presentation

Baseline: aa317bfde98df288df578b6c9bbe7bbbdca8b2d0 (PR #275).
Outcome: reach the same usable opening caption without the redundant preparation
status, while showing busy feedback before expensive commit work.

## Change

MenuScene no longer yields two frames to show "Preparing your account" before
SaveManager.prepare_new_run_action. That method checks readiness, ownership,
context, live replacement and autosave existence, and produces a token; it does
not construct the story scene. The subsequent starting feedback still gets two
frames before commit. Existing-account consent appears immediately after this
small preparation; commit still requires approval. Early-click loading feedback
and retry/recovery waits remain unchanged.

Seven runtime lines removed. The owner-validity recheck belonged to the removed
await; the preceding owner check now reaches prepare synchronously. Source checks
after Settings departure, before commit, after the remaining wait and on return
remain intact. No new abstraction or state was added.

## Focused evidence

Linux headless title lifetime suite: 11 tests, 71 assertions, all passing.
The replacement test checks immediate consent and no commit before approval.
The fresh-start test checks one preparation, starting feedback, suppressed mouse
and focus input, and one commit despite a duplicate signal. When rendered, it
also requires frame_post_draw to have occurred while starting feedback is visible
before commit. Existing lifecycle/early-loading checks remain in the same suite.

Six sequential fresh-user Linux journeys used B,C,C,B,C,B order, waiting two
seconds after mandatory runtime readiness. Exact fully revealed opening caption,
native completion, acknowledgement, unblocked input and unchanged caption after
opening Computer all passed.

| Revision | Click to usable caption (ms) | Median (ms) |
| --- | --- | --- |
| Baseline | 350.848, 295.169, 344.381 | 344.381 |
| Candidate | 275.331, 312.449, 333.237 | 312.449 |

Ranges overlap. The 31.932 ms median difference is not a reliable fixed speedup;
the deterministic change is two fewer frame yields. One baseline emitted an
ObjectDB shutdown warning; all candidates were clean and no run had engine errors.

The first new test incorrectly asserted Button.disabled. This title instead
suppresses mouse input and focus while retaining its visual button style. The
assertion was corrected to the actual input contract; the failed log is retained.
The local rendered attempt could not open an X11/Wayland display and ran no tests.
A dedicated temporary cloud branch runs only the rendered title suite; its
workflow is not part of the runtime change.

## Rendered Windows acceptance

[Run 43022018133](https://github.com/Siuuuers/dwm/actions/runs/43022018133)
succeeded on 4fbdc4ea949a06d4fc5ae042fd34324115cb0dfc. The exact runtime and test
files match this candidate; only the temporary verification workflow differs.
11 tests / 72 assertions passed, including the rendered-only busy-before-commit
assertion. The runner used ANGLE / Microsoft Basic Render Driver after an OpenGL
fallback warning. Import reported the existing nested audio prototype project
warning and an ObjectDB shutdown warning; rendered tests had no engine errors.
This is a rendered control/ordering check, not physical-GPU timing qualification.
Independent source-lifecycle review found no regression.

## Reproduction and omissions

Evidence: tools/player_latency/evidence/2026-11-11-newgame-busy-feedback. Copy
compare.py and observe.gd.txt (renamed observe.gd) into .godot/ci/busy-feedback.
Run compare.py from the repository root with Godot 4.6.3 and imported assets. It
swaps only MenuScene.gd and restores candidate bytes in finally. Use fresh user
folders and run engines sequentially. The focused GUT script is
res://tests/unit/test_new_acc_title_lifetime.gd with a DWM_TEST_ROOT under
.godot/phase2r_tests and -gconfig= -gexit.

No new injection tests, broad matrix, parser changes, save-format changes or new
export were needed. The remaining two-frame starting/retry waits were not trimmed;
this change removes one redundant presentation, not all rendering opportunities.
