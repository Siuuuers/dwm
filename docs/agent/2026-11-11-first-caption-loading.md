# Immediate New Game: first-caption loading

Base: `d5978b09fbc2584d977fc7dd7c4eba385a764a62` (PR #265).
Candidate runtime: `2cf7ce5e813e0deee67c9108f5a3005f8d4746ed`.

## Outcome and investigation

Reduce immediate New Game to the first usable authored caption. StartupLoader
owns queue scheduling; ApplicationBootstrap owns which resources must precede
full gameplay readiness. Existing scene, save, profile and recovery owners stay.

Before editing, trace title visibility, click, each active resource request,
bootstrap stages, presentation acknowledgement and complete/input-ready caption.
The probe uses the real shipped opening, fresh isolated user storage and normal
New Acc dispatch. It requires the expected full text, visible caption, completed
Dialogic text event and unblocked Inputs. Headless completion is not a rendered
or physical input-to-photon measurement.

One baseline diagnostic observed 3555 ms from click to runtime readiness, then
859 ms to the usable caption. GameState loading occupied about 1173 ms and
SceneRouter about 517 ms. Six later-use resources occupied roughly 576 ms of the
serialized queue. A separate click after readiness reached the caption in 802 ms.
These overlapping/nested spans must not be added to overall launch time.

## Small change

Move six paths out of RUNTIME_RESOURCES into BACKGROUND_RESOURCES. Queue that list
only after successful full runtime readiness, using the existing loader. Start
with ComputerDesktop so its scene can load while New Game completes.

| Resource | Actual first consumer |
| --- | --- |
| ComputerDesktop.tscn | Opening Computer |
| ContactsPresentationPort.gd | Computer/Contacts presentation |
| MinesweeperPanelPort.gd | Computer panel construction |
| ProvisionalCorrespondenceCatalog.gd | Contacts desktop configuration |
| SceneChallengePanel.gd | Opening the challenge Computer |
| ShopPresentationPort.gd | Computer shop construction |

No feature, resource, save validation, recovery stage, profile application or
Dialogic owner is removed. Later consumers retain their existing synchronous
load path if background preparation has not completed. No second queue, manager
or speculative fallback is introduced.

## Measured tradeoff

Godot 4.6.3, Linux headless. Fresh storage recreated at the same absolute path,
serial baseline/candidate/candidate/baseline; no disk-cache flushing. Final samples:

| Observation | Baseline | Candidate |
| --- | --- | --- |
| Click to usable caption, ms | 5135.354 / 3974.546 | 3500.503 / 3950.676 |
| Click to caption median, ms | 4554.950 | 3725.590 |
| Immediate Computer open, ms | 31.621 / 31.905 | 113.748 / 106.324 |

The observed caption median is 829 ms lower; there are only two samples per side
and visible host variation, so this is not a universal percentage or tail bound.
The extreme next-frame Computer click is about 78 ms slower at the median. This
is an explicit scheduling tradeoff: first caption is prioritized, while resources
remain available on demand and continue warming. The earlier helper-first queue
order made immediate Computer take 260 ms; putting the actual scene first reduced
that cost to about 110 ms. The same caption remains after opening Computer.
A forced test with optional processing paused also opens Computer successfully.

An earlier matched batch before this ordering refinement measured 4390 to 3689 ms
for first caption. One baseline teardown emitted an ObjectDB warning after the
measurement; final matched logs are clean. Main-thread new-game frame gaps remain;
this change is not a claim that all gameplay latency is removed.

## Focused validation

- Bootstrap integration and Menu lifecycle: 23 tests, 336 positive assertions.
- Required/background scheduling test: no optional request before readiness;
  the same queue receives the audited list afterward; lists do not overlap.
- Early Computer with background processing paused: same caption, successful open.
- Final matched runs: expected full caption, input-ready endpoint, clean logs.
- Exported Windows [run 42981603016](https://github.com/Siuuuers/dwm/actions/runs/42981603016)
  passes pack audit, fresh startup, New Game, immediate Computer, Save and fresh-
  process Load with exact restored state and clean player exits. Screenshots of
  the opening and Computer were reviewed. New Game to first observed caption was
  3126 ms in the early-action Create run (including UIA/provider/polling overhead).
  This is not a matched Windows baseline comparison. Forward+/D3D12 remains
  unchanged, with Microsoft Basic Render Driver, accessibility Always and Dummy
  audio. The final source is the candidate SHA above.

[Retained probe, runner, receipts and logs](../../tools/player_latency/evidence/2026-11-11-first-caption-loading/).
For reproduction, copy observe.gd.txt and measure.py.txt into
`.godot/ci/first-caption/` without the `.txt` suffix. Place an imported immutable
baseline checkout at `../dwm-caption-baseline`, then run the Python script from
the candidate root. The script recreates its isolated matched-user directory.

Skipped: unrelated matrices, renderer changes, destructive save simplification,
new caches, physical-GPU timing and audible-output qualification. Existing global
presentation/restore work was not bypassed without evidence.

## Remaining new-game setup: one diagnostic

On the unchanged baseline, after gameplay readiness, click to usable caption was
889 ms. Timed synchronous segments total 315 ms: identity 11.8, snapshot input
54.8, initial reading checkpoint 64.7, snapshot build 50.6, profile capture 0.1,
restore plans 78.2, and restore transaction until its pending return 55.3 ms.
The plans span includes narrative 71.2, profile 2.0 and localization 3.5 ms.
Those nested spans must not be added again.

This disproves the suggested priority of bypassing current-profile presentation
preparation: its measured cost is small. About 573 ms remains outside these
instrumented segments, including deferred activation and first-caption work;
that gap is not yet attributed to a single function. Baseline source bytes were
restored and its worktree diff was empty afterward. This diagnostic exited 0
with one ObjectDB teardown warning, so it is not clean acceptance evidence.

Windows artifact: `13837502855`, SHA256
`03525f334a78122f812c919d6ca4bc05ff9ae4f83ed9cdb6baab52511ca7f8c6`.
Release ZIP SHA256:
`b01f0b3af1c7d6ccf3cffe1108086a7430f3fb25652abfaf4cf606a567bb9355`.
Later evidence-only updates do not change the tested runtime.
