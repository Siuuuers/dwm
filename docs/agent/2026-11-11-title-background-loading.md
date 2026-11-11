# Title-first startup

Base: `2d444d08988b6d6bf9e5f29ba97740718a5e4c83`.

## Observable outcome

Show the usable title with the saved language, font and text size before loading
unneeded gameplay resources. Finish those resources while the title remains
visible. An early destination click displays the localized animated Loading
status and runs once when its dependencies are ready.

StartupLoader owns one resource queue and installs the existing real root owners.
ApplicationBootstrap still owns recovery, initialization and final readiness.
MenuScene retains only the pending destination. No replacement profile parser,
proxy gameplay owner or second mutation gate is introduced.

## Required before title

Recover save/new-run storage, bind the authoritative profile, initialize its
language/typography, input, accessibility, audio and window mode. Preserve the
same identity issuer and mutation gate across both phases. Recovery validation
may still load gameplay script dependencies when historical storage needs them.

After the first title draw, load GameState, EffectResolver, SceneRouter, Dialogic
and runtime resources; install owners and advance bootstrap stages across frames.
Queue Settings, Load, Gallery and SceneHost resources for reuse. An early click
moves its queued dependencies ahead of work that has not started. Settings needs
only its resources and the title core; gameplay destinations also await final
runtime readiness. An active threaded load is not interrupted.

## Relevant failure and departure cases

- Save recovery fails: retain the existing recovery UI and retry contract.
- The player clicks twice: retain one action, using the existing transition gate.
- Settings has pending work: complete its existing departure protocol first.
- The title leaves: discard its pending action; the global loader owns requests.
- Quit during loading: finish only the in-flight request before engine teardown.
- Editor import: Dialogic must not re-register a second eager runtime owner.

## Validation

Runtime candidate: `3fe3baef830a7dffc0fcc0e58a117789e7fca48d`.
Windows source: `33990c3a8f5e0b8d101cb7f7593ab34099968c85`; the later commit
changes the pack-audit helper only. Final follow-up changes evidence, canonical
caller inventories and the manual startup probe, not production runtime bytes.

- Focused Bootstrap, Menu lifetime, recovery and route-publication suites:
  **49 tests, 663 positive assertions**, no failures or skips.
- Both canonical public-surface checks pass. Four existing caller references
  were missing from the inventories; regeneration changes no public signatures.
- Editor import preserves the sole StartupLoader registration.
- Actual Linux startup retains Traditional Chinese, readable font and 150% text.
  Early Settings, Gallery, Load and New Game clicks show Loading and complete;
  duplicate clicks do not dispatch twice. Early Quit exits cleanly. All final
  action logs have no engine errors or warnings.
- Windows [run 42971667173](https://github.com/Siuuuers/dwm/actions/runs/42971667173)
  passes pack audit, isolated release startup, opening, Computer, Save, and
  fresh-process Load with exact restored state and clean exits.
  Title and restored-opening screenshots were reviewed: labels, both artwork
  panels, caption and controls are visible.

### Timing and limits

Godot 4.6.3 Linux headless, serial baseline / candidate / candidate / baseline.
Restore the same saved profile bytes at the same absolute user path before each
process. The seed is created through the real preference owners. Disk caches are
not flushed. Retained [probe, runner and raw evidence](../../tools/player_latency/evidence/2026-11-11-title-background/)
allow reproduction in an imported baseline/candidate pair.

| Endpoint | Baseline samples / median | Candidate samples / median |
| --- | --- | --- |
| Title ready, ms | 7232.864 / 9165.975; **8199.420** | 5002.833 / 5181.440; **5092.137** |
| Full runtime ready, ms | 7160.688 / 9090.257; **8125.473** | 8663.536 / 8501.913; **8582.725** |

The title median is 3107 ms earlier in this small sample. Full gameplay readiness
is about 457 ms later: deferred loading moves work, rather than removing all of
it. Largest headless frame gaps during the two idle title runs were 65.7 and
27.0 ms; these are not rendered frame timings or a smooth-frame guarantee.
First Settings construction and New Game still contain synchronous work.
One extra baseline New Game run had a noisy 20-second pre-title delay; it is
retained but is not used to claim a complete-journey speedup. The Linux New Game
endpoint is SceneHost ready, not the first fully rendered caption.

Windows uses unchanged Forward+ / D3D12 on Microsoft Basic Render Driver,
accessibility Always and Dummy audio. External title observations were 6091 ms
(capability), 5795 ms (fresh Create), and 4431 ms (returning Load). Create clicked
at 5957 ms and observed Loading; its first caption followed the click by 3671 ms.
Load also observed Loading and restored the saved opening. UIA includes provider
and polling overhead; these are not input-to-photon measurements or a matched
Windows baseline comparison. The existing renderer is unchanged.

The first Windows attempt failed only after the pack audit had verified all 137
resources: the audit called quit before deferred startup finished. Its helper now
runs after owner installation and uses clean shutdown. Runtime Quit separately
drains the active resource request, preventing teardown-time preload errors.
No missing shipped font or pack exclusion was worked around. The editor/export
process retains its known ObjectDB exit warning; packaged player and pack-audit
logs are clean.

Release archive SHA256:
`f9c0fb6b0f1d7a99307ea9862503f43e55415d8e79f97d34f80c594d86de88b9`.

Skipped: renderer changes, unrelated gameplay refactors, broad language/layout
matrices, external-input injection campaigns, audio-output and physical-GPU
qualification. Existing boundary validation, recovery and accessibility remain.
