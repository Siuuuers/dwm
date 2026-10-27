"""Compare direct live-checkpoint conversion without full-ledger reconstruction.

Reuse the checkpoint-reference observer and complete 24-process native journey.
Observed counts, rather than predicted reductions, determine the final report.
"""
import argparse
import json
from pathlib import Path

import checkpoint_reference_comparison as reference

BASELINE = "d706fc3fe55484d8c8791c0781f7d258643c6449"


def summarize(root):
    # Each inherited summarizer forwards its baseline to its own parent.
    reference.BASELINE = BASELINE
    reference.summarize(root)
    result = json.loads((root / "checkpoint-reference-summary.json").read_text(encoding="utf-8"))
    result["experiment"] = "Construct the compact checkpoint from its owned live capture without reconstructing its full ledger; retain compact reference resolution."
    (root / "checkpoint-projection-summary.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    selected = (
        "SaveManagerNarrativeCheckpointPort._scene_candidate_reference.calls",
        "SaveManagerNarrativeCheckpointPort._scene_candidate_reference.elapsed_us",
        "SoloReadingSession.project_player_checkpoint.calls",
        "SoloReadingSession.project_player_checkpoint.elapsed_us",
        "SoloReadingSession._validate_scene_saved.calls",
        "SoloReadingSession._validate_scene_saved.elapsed_us",
        "SoloReadingSession.restore.calls", "SoloReadingSession.restore.elapsed_us",
        "input_to_first_correct_drawn_us", "input_to_usable_us", "max_frame_gap_us",
    )
    print(json.dumps({"checkpoint_projection_review": {
        variant: {key: metrics[key] for key in selected}
        for variant, metrics in result["aggregates"].items()}}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("extract", "prepare", "summarize"))
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--harness", type=Path)
    args = parser.parse_args()
    if args.action == "extract": reference.passage.history.trusted.extract(args.root)
    elif args.action == "prepare": reference.prepare(args.root, args.harness)
    else: summarize(args.root)
