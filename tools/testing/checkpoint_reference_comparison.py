"""Attribute repeated checkpoint-reference work during the real passage transition.

The exported journey and all acceptance checks come from the passage comparison.
Only synchronous observation wrappers are added to disposable source copies.
"""
import argparse
import hashlib
import json
from pathlib import Path
from statistics import median

import passage_compilation_comparison as passage

BASELINE = "c531f3d487b6d213d4ef4a940832e09f0cf5f95a"

METHODS = {
    "scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd": (
        "commit_scene_event", "_commit_scene_event_autosave",
        "_scene_route_candidate_valid", "_scene_committed_reference",
        "_scene_candidate_reference", "_player_checkpoint_same", "_scene_control_source_matches"),
    "autoload/GameState.gd": ("_scene_player_checkpoint_same",),
    "scripts/narrative/SoloReadingSession.gd": ("project_player_checkpoint", "restore"),
}


def prepare(root, harness):
    passage.prepare(root, harness)
    receipt_path = root / "startup-variant.json"
    receipt = json.loads(receipt_path.read_text())
    for relative, names in METHODS.items():
        path = root / relative
        before = hashlib.sha256(path.read_bytes()).hexdigest()
        path.write_text(passage.history.wrap(path.read_text(), path.stem, names), encoding="utf-8")
        receipt["changes"].setdefault(relative, {"before": before})["after"] = hashlib.sha256(path.read_bytes()).hexdigest()
    receipt["checkpoint_reference_observer"] = (
        "Identical synchronous inclusive wrappers around checkpoint reference, equality, projection, "
        "restore and named caller phases. Existing saved-state validation wrapper is reused once.")
    receipt_path.write_text(json.dumps(receipt, indent=2), encoding="utf-8")


def summarize(root):
    passage.BASELINE = BASELINE
    passage.summarize(root)
    source = json.loads((root / "source.json").read_text(encoding="utf-8-sig"))
    assert source["baseline"] == BASELINE
    samples = []
    observed_methods = [f"{Path(path).stem}.{name}" for path, names in METHODS.items() for name in names]
    observed_methods += ["SoloReadingSession._validate_scene_saved", "SoloReadingSession._capture_scene"]
    for repetition in range(1, 5):
        for variant in ("baseline", "candidate"):
            name = f"r{repetition}-{variant}-load"
            report = json.loads((root / "measurements" / name / "results.json").read_text(encoding="utf-8-sig"))
            profile = report["observation"]["history_profile"].get("passage_transition", {})
            # Presence proves this real journey traversed the instrumented owner;
            # counts and reductions remain measurements, never acceptance targets.
            assert profile["SaveManagerNarrativeCheckpointPort._commit_scene_event_autosave"]["calls"] > 0
            assert profile["SaveManagerNarrativeCheckpointPort._scene_candidate_reference"]["calls"] > 0
            assert profile["SoloReadingSession.project_player_checkpoint"]["calls"] > 0
            metrics = {f"{method}.{field}": profile.get(method, {}).get(field, 0)
                       for method in observed_methods for field in ("calls", "elapsed_us", "max_us")}
            marks = report["milestones"]
            began = marks["passage_input"]["ticks_us"]
            metrics["input_to_first_correct_drawn_us"] = marks["passage_first_correct_drawn"]["ticks_us"] - began
            metrics["input_to_usable_us"] = marks["passage_usable"]["ticks_us"] - began
            metrics["max_frame_gap_us"] = report["max_frame_gap_us"].get("passage_transition", 0)
            samples.append({"sample": name, "variant": variant, "repetition": repetition, "metrics": metrics})
    keys = sorted(set().union(*(sample["metrics"] for sample in samples)))
    aggregates = {}
    for variant in ("baseline", "candidate"):
        rows = [sample["metrics"] for sample in samples if sample["variant"] == variant]
        aggregates[variant] = {key: {"samples": values, "median": median(values), "min": min(values), "max": max(values)}
            for key in keys if (values := [row.get(key, 0) for row in rows])}
    paired = []
    for repetition in range(1, 5):
        rows = {sample["variant"]: sample["metrics"] for sample in samples if sample["repetition"] == repetition}
        paired.append({"repetition": repetition, "candidate_minus_baseline": {
            key: rows["candidate"][key] - rows["baseline"][key] for key in keys}})
    result = {
        "scope": "Four matched first-new-passage transitions per variant, using the unchanged real-input passage journey and all inherited 24-process checks. Named caller phases, reference checks, checkpoint equality, player-checkpoint projection and restore are synchronous inclusive spans. Saved-state validation retains the existing observer, not a second wrapper. Nested costs overlap and must not be added. Counts are observed, not forced to the predicted reduction. Missing measured methods are zero. Full state, history, screenshots and hashes stay outside the passage timing interval; matched polling and wrapper overhead remain. One runner, AB/BA/AB/BA, no cold OS-cache or universal device claim.",
        "source": source, "samples": samples, "aggregates": aggregates, "paired_differences": paired,
    }
    (root / "checkpoint-reference-summary.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps({"checkpoint_reference_review": aggregates}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("extract", "prepare", "summarize"))
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--harness", type=Path)
    args = parser.parse_args()
    if args.action == "extract": passage.history.trusted.extract(args.root)
    elif args.action == "prepare": prepare(args.root, args.harness)
    else: summarize(args.root)
