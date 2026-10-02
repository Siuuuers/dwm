#!/usr/bin/env python3
"""Build source-pinned focused cloud proof; never run engines or publish refs."""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import re
import yaml

ROOT = Path(__file__).resolve().parent
DEFAULT_REPO = ROOT / "dwm"
DEFAULT_JOURNEY = Path("/workspace/scratch/28bd37023a95/next-workflow-9.yml")
EXPANDED_SUITES = ["reading_delivery", "dating", "persistence", "settings", "checkpoint_diagnostics", "localization"]


def build(repository: Path, source: str, branch: str, stage: str, journey_template: Path) -> tuple[str, dict]:
    if not re.fullmatch(r"[0-9a-f]{40}", source):
        raise ValueError("An immutable lowercase 40-character source SHA is required")
    if not re.fullmatch(r"codex/[A-Za-z0-9][A-Za-z0-9/_-]*", branch):
        raise ValueError("A codex/ auxiliary branch is required")
    path = repository / ".github/workflows/windows-tests.yml"
    canonical = path.read_bytes()
    base = yaml.safe_load(canonical)
    jobs = {}
    for name in ("public-surfaces", "focused-tests"):
        jobs[name] = copy.deepcopy(base["jobs"][name])
    jobs["focused-tests"]["strategy"]["matrix"] = {"suite": ["reading_delivery"] if stage == "initial" else EXPANDED_SUITES}
    public_steps = jobs["public-surfaces"]["steps"]
    generation = [s for s in public_steps if s.get("run", "").strip() in (
        "./tools/testing/Invoke-PublicSurfaceValidation.ps1",
        "./tools/testing/Invoke-PublicSurfaceValidation.ps1 -EmitPayloads",
    )]
    if len(generation) != 1:
        raise ValueError("Expected exactly one canonical read-only public-surface invocation")
    generation[0]["run"] = "./tools/testing/Invoke-PublicSurfaceValidation.ps1 -Regenerate -EmitPayloads"
    generation[0]["name"] = "Generate affected public inventories for review"
    if stage == "expanded":
        historical = yaml.safe_load(journey_template.read_bytes())
        jobs["reading-rail-journey"] = copy.deepcopy(historical["jobs"]["reading-rail-journey"])
        jobs["rendered-desktop"] = copy.deepcopy(base["jobs"]["rendered-desktop"])
        journey_runs = "\n".join(s.get("run", "") for s in jobs["reading-rail-journey"]["steps"])
        if journey_runs.count("python3 tools/testing/run_reading_rail_journey.py") != 1:
            raise ValueError("Journey must execute the current checked-out driver exactly once")
        desktop_runs = "\n".join(s.get("run", "") for s in jobs["rendered-desktop"]["steps"])
        if "res://tools/localization/UiLiteralAudit.gd" not in desktop_runs:
            raise ValueError("Expanded UI proof requires the canonical UI literal audit")
    for name, job in jobs.items():
        job.pop("needs", None)
        checkouts = [s for s in job["steps"] if s.get("uses", "").startswith("actions/checkout@")]
        if len(checkouts) != 1:
            raise ValueError(f"One explicit checkout required for {name}")
        checkouts[0].setdefault("with", {}).update({"ref": source, "fetch-depth": 0})
        runs = "\n".join(s.get("run", "") for s in job["steps"])
        for marker in ("4.6.3", "git restore -- project.godot"):
            if marker not in runs:
                raise ValueError(f"Missing preserved cloud guard {marker}: {name}")
    workflow = {
        "name": f"Authored selector {stage} cloud proof",
        "on": {"push": {"branches": [branch]}},
        "permissions": {"contents": "read"},
        "concurrency": {"group": "selector-cloud-${{ github.ref }}", "cancel-in-progress": True},
        "jobs": jobs,
    }
    result = yaml.safe_dump(workflow, sort_keys=False, allow_unicode=True, width=140)
    if path.read_bytes() != canonical:
        raise RuntimeError("Canonical workflow changed during generation")
    manifest = {
        "source": source, "branch": branch, "stage": stage,
        "logical_jobs": 2 if stage == "initial" else 9,
        "canonical_workflow_sha256": hashlib.sha256(canonical).hexdigest(),
        "generated_workflow_sha256": hashlib.sha256(result.encode()).hexdigest(),
        "suites": jobs["focused-tests"]["strategy"]["matrix"]["suite"],
        "job_definitions": list(jobs), "inventory_mode": "regenerate-for-review",
        "final_acceptance": "Unmodified canonical PR broad gate with read-only committed inventory checks",
    }
    return result, manifest


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("source")
    p.add_argument("output", type=Path)
    p.add_argument("--repo", type=Path, default=DEFAULT_REPO)
    p.add_argument("--branch", default="codex/selector-cloud-20261002")
    p.add_argument("--stage", choices=("initial", "expanded"), default="initial")
    p.add_argument("--journey-template", type=Path, default=DEFAULT_JOURNEY)
    a = p.parse_args()
    content, manifest = build(a.repo, a.source, a.branch, a.stage, a.journey_template)
    a.output.write_text(content, encoding="utf-8", newline="\n")
    a.output.with_suffix(a.output.suffix + ".manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(manifest))


if __name__ == "__main__":
    main()
