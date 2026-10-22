# Timed and art frontier audit — 2026-10-23

Read-only review of the composed scene Apps candidate. No Godot or PowerShell execution. This report concerns source reachability and contracts, not a native runtime pass.

## Current release reachability

The current `data/manifests/scene_story_registration.json` registers **92 entries**, all in `dialogic/timelines/authored_week/Day1.dtl` through `Day7.dtl`. Source inventory found **zero Wait directives and zero return-only registered entries**. `scripts/narrative/DialogicRuntimeAdapter.gd::_compile_scene_programme_source` accepts caption, label/control, jump, return and registered signal events; an actual `DialogicWaitEvent` falls through to `scene_executable_event_refused`.

Therefore timed-wait and art-only semantic checkpoint support is not a missing reachable step in the presently registered seven-day scene journey. Do not invent a new saved cursor or revive Hospital to cover it. Ordinary background/portrait artwork behind real captions continues using the caption checkpoint.

## Existing custody and limitations

- `DialogicRuntimeAdapter.gd::capture_pause_frontier` admits a finite, hidden, non-skippable native Wait only when its execution token, timeline generation and event index match the active invocation. The physical frontier intentionally excludes changing elapsed/remaining time.
- `addons/dialogic/Modules/Wait/event_wait.gd::_on_pause` pauses the existing tween; `_on_resume` resumes that same tween. Its execution-state query is explicitly ephemeral. No timer cursor is persisted.
- `autoload/DialogicBridge.gd::_capture_presentation_frontier` also supports an already-drawn art hold, identified by generation/token. `_try_begin_art_hold` only creates it for a return-only entry. None of the current registered scene entries meet that source condition.
- `DialogicBridge.gd::hold_computer_captions` freezes the admitted physical frontier while keeping the causal mutation gate usable; release rechecks the same source. This is in-memory custody, not a save format.
- `DialogicBridge.gd::can_capture_reading_checkpoint` admits scene line/control boundaries only, and `DialogicRuntimeAdapter.gd::can_capture_reading_frontier` requires the exact live caption event. A Wait cannot borrow the previous caption's semantic publication. An art-only hold before native execution has no caption publication to borrow.
- Shop and first-Reveal checkpoint sources ultimately need this semantic reading checkpoint (`DialogicBridge.gd::capture_scene_event_boundary`, `autoload/ApplicationBootstrap.gd` scene checkpoint provider and `scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd`). Simply allowing the physical hold does not qualify a persistent mutation during a hypothetical wait/art card.
- `tests/unit/test_scene_computer_suspension.gd::test_timed_and_art_frontier_identity_survives_repeat_open_without_reacquiring` uses injected physical frontiers. It does not prove native timer behavior, real art rendering or fresh-process Load.

## Future scope if such content is authored

A future authored silent hold needs an explicitly registered semantic node and restore contract, rather than fabricating a caption, replaying consequences or serializing a native event index. Cold-load policy would need to specify whether a timed hold resumes its remaining duration or restarts its authored duration. That decision is not required for the current registered content. A future art-only node similarly needs an authenticated pre-native boundary and restore proof.

## Reproducible inventory

Run from repository root with Python (read-only):

```python
import json
from pathlib import Path
registration = json.loads(Path('data/manifests/scene_story_registration.json').read_text())
entries = registration['entry_manifest']['entries']
paths = sorted({entry['locators']['en']['path'] for entry in entries})
print('registered entries', len(entries))
print('paths', paths)
for name in paths:
    lines = Path(name.replace('res://', '')).read_text().splitlines()
    print(name, 'wait directives', sum(line.strip().startswith('[wait') for line in lines))
return_only = []
for entry in entries:
    locator = entry['locators']['en']
    active = False
    for raw in Path(locator['path'].replace('res://', '')).read_text().splitlines():
        line = raw.strip()
        if not active:
            active = line == 'label ' + locator['label']
            continue
        if not line or line.startswith('#'):
            continue
        if line == 'return':
            return_only.append(entry['entry_id'])
        break
print('registered return-only entries', return_only)
```

Observed: registered entries `92`; seven authored-week paths; each reports `0` wait directives; return-only entries `[]`. Native compiler rejection supplies the stronger guard against other unsupported Wait syntax.
