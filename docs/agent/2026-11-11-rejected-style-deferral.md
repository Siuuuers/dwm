# Reject caption-style deferral as a startup optimization

Baseline: 24131a2596861e19820d02300d63fbb7aac78cf5 (PR #278).
Outcome required: earlier title without worsening launch to usable first caption.
Decision: **reject and revert the runtime experiment**. No production change.

## Fresh attribution

Workspace maintenance removed the previous checkout. Restore current master,
import with Godot 4.6.3, and restore project.godot after the editor's Dialogic scan.
Two fresh-user Linux headless traces measured bootstrap script/dependency loading
at 1.30–1.78 s and DialogueBridge script/dependency loading at 0.59–0.66 s. These
are inclusive dependency costs, not pure parsing or directly removable time.

## Candidate

DialogicBridge._prepare_witnessed_style preloads the full witnessed style, which
references packed caption, art, choices, history and other dialogue layers.
Replace that preload with a local load and add the style to the existing
ApplicationBootstrap.RUNTIME_RESOURCES queue. Keep resource identity validation,
CORE owners, Settings, save initialization and recovery order unchanged.

Read-only caller review found no ownership blocker: normal runtime resources
finish before runtime installation; early non-Settings title actions wait for
readiness; manual/recovery callers can synchronously load the same resource.
However, acceptable behavior alone does not establish a performance benefit.

## Matched evidence

Sequential fresh-profile Linux headless runs, same imported checkout. Six startup
runs use B,C,C,B,C,B; four immediate-title-click journeys use B,C,C,B. Titles are
ready-menu/button observations, not rendered first-paint timestamps.

| Measurement | Baseline | Candidate |
| --- | --- | --- |
| Title-ready median, 3 samples each | 3.679278 s | 3.575340 s |
| Runtime-ready median, 3 samples each | 5.835859 s | 5.744402 s |
| Launch to usable caption, early click sample 1 | 5.889686 s | 6.189132 s |
| Launch to usable caption, early click sample 2 | 6.093894 s | 6.212242 s |
| Click to usable caption, early sample 1 | 2.180078 s | 2.570284 s |
| Click to usable caption, early sample 2 | 2.369040 s | 2.672833 s |

All four early journeys reached the exact fully revealed opening caption with
native completion, acknowledgement and unblocked input. Opening Computer preserved
the caption. One baseline early run emitted an ObjectDB shutdown warning; the six
startup runs and all candidates had no warnings. No engine errors occurred.

Separate cache observations confirm the style and caption scene are already
cached at baseline title readiness, but neither is cached at candidate title
readiness. The intended deferral occurred. The small sample and cloud variability
do not establish a precise regression; they also do not establish the required
non-worsening full journey. A roughly 104 ms title-median reduction is insufficient
to accept it when both early-caption observations are later. Do not ship it.

## Reproduction and next boundary

Evidence: tools/player_latency/evidence/2026-11-11-rejected-style-deferral. The
rejected patch is retained compressed for reproduction, not applied. Copy scripts
and probes into .godot/ci/bridge-loading, renaming .gd.txt to .gd. Apply the rejected
patch before compare.py/early.py/cache.py so they capture candidate bytes; each
restores those bytes in finally. profile.py instruments the CURRENT source, so
choose the revision explicitly. Use fresh owned user/output folders and one
engine process at a time. Existing benchmark_player_startup.gd is unchanged.

Skipped new Windows export, Settings/recovery acceptance suites and broad tests:
the candidate failed its performance acceptance and was reverted before those
checks. No new fault injection or speculative startup manager was introduced.
The previous on-demand readable-font change remains on master.

Next investigations should prioritize removing repeated work over another simple
deferral of the same style. Save initialization remains required for recovery;
its measured cost alone is not grounds to remove its checks. Packaged Windows
launch timing remains a separate evidence gap before promising player savings.
