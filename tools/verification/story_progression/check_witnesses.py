import json
import re
import sys
from pathlib import Path

FIELDS = {
    "phase", "parent", "owner", "pc", "visible", "expected", "acknowledged",
    "applied", "blocked", "crossedBlocked", "staleAdvance", "fatal", "errorVisible", "last_event",
}
EVENTS = {
    "advance-NEXT_ADMITTING", "advance-NEXT_ACTIVE", "advance-AUTO", "advance-SKIP",
    "ack-from-NEXT_ADMITTING", "ack-from-AUTO", "ack-from-SKIP", "ack-from-IDLE",
    "next-coalesced", "next-conflict", "next-busy", "stale-refusal",
    "ordinary-refusal", "next-completion-signals",
    "ack-success", "ack-retryable", "ack-fatal", "fatal-error-visible",
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
    fatal_owned, fatal_visible = False, False
    for state in read_states(text):
        count += 1
        events.add(json.loads(state.pop("last_event")))
        projections.add(tuple(sorted(state.items())))
        completed |= (state["visible"] == "3" and state["applied"] == "<<1, 1>>"
                      and state["phase"] == '"IDLE"' and state["owner"] == "{}"
                      and state["pc"] == '"idle"' and state["expected"] == "0")
        fatal_owned |= (state["fatal"] == "TRUE" and state["errorVisible"] == "FALSE"
                        and state["owner"] != "{}" and state["pc"] == '"return"'
                        and state["acknowledged"] == "FALSE")
        fatal_visible |= (state["fatal"] == "TRUE" and state["errorVisible"] == "TRUE"
                          and state["phase"] == '"IDLE"' and state["owner"] == "{}"
                          and state["acknowledged"] == "FALSE")
    missing = EVENTS - events
    if missing or not completed or not fatal_owned or not fatal_visible:
        raise ValueError(f"Witness check failed: missing={sorted(missing)}, "
                         f"completed={completed}, fatal_owned={fatal_owned}, fatal_visible={fatal_visible}")
    return {"states": count, "production_projections": len(projections),
            "behavior_witnesses": len(EVENTS), "completed_and_released": completed,
            "fatal_before_release": fatal_owned, "fatal_error_after_release": fatal_visible}


if __name__ == "__main__":
    print(json.dumps(check(Path(sys.argv[1]).read_text())))
