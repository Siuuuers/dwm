import json
import re
import sys
from pathlib import Path

FIELDS = {
    "phase", "parent", "owner", "pc", "visible", "expected", "acknowledged",
    "applied", "blocked", "crossedBlocked", "staleAdvance", "last_event",
}
EVENTS = {
    "advance-NEXT_ADMITTING", "advance-NEXT_ACTIVE", "advance-AUTO", "advance-SKIP",
    "ack-from-NEXT_ADMITTING", "ack-from-AUTO", "ack-from-SKIP", "ack-from-IDLE",
    "next-coalesced", "next-conflict", "next-busy", "stale-refusal",
    "ordinary-refusal", "next-completion-signals",
}


def read_states(text):
    for block in re.split(r"^State \d+:\s*$", text, flags=re.MULTILINE):
        if not block.strip():
            continue
        state = {}
        for line in block.strip().splitlines():
            match = re.fullmatch(r"/\\ (\w+) = (.+)", line)
            if not match or match[1] in state:
                raise ValueError("Unexpected TLC state format: " + line)
            state[match[1]] = match[2]
        if state.keys() != FIELDS:
            raise ValueError("TLC state fields do not match StoryProgression")
        yield state


def check(text):
    events, projections = set(), set()
    completed, count = False, 0
    for state in read_states(text):
        count += 1
        events.add(json.loads(state.pop("last_event")))
        projections.add(tuple(sorted(state.items())))
        completed |= (state["visible"] == "3" and state["applied"] == "<<1, 1>>"
                      and state["phase"] == '"IDLE"' and state["owner"] == "{}"
                      and state["pc"] == '"idle"' and state["expected"] == "0")
    missing = EVENTS - events
    if missing or not completed:
        raise ValueError(f"Witness check failed: missing={sorted(missing)}, "
                         f"completed={completed}")
    return {"states": count, "production_projections": len(projections),
            "behavior_witnesses": len(EVENTS), "completed_and_released": completed}


if __name__ == "__main__":
    print(json.dumps(check(Path(sys.argv[1]).read_text())))
