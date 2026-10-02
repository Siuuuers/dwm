#!/usr/bin/env python3
"""Derive one source-pinned cloud layout diagnostic from canonical CI steps.

This only writes a workflow and provenance manifest. It never runs an engine,
executes PowerShell, changes Git refs, or publishes files.
"""
from __future__ import annotations

import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import re

import yaml


def required_step(job: dict, *, name: str | None = None, uses: str | None = None) -> dict:
    matches = [step for step in job["steps"]
               if (name is None or step.get("name") == name)
               and (uses is None or step.get("uses") == uses)]
    if len(matches) != 1:
        raise ValueError(f"Expected one canonical step: {name or uses}")
    return deepcopy(matches[0])


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def build(source: str, branch: str, canonical_path: Path) -> tuple[dict, dict]:
    if not re.fullmatch(r"[0-9a-f]{40}", source):
        raise ValueError("--source must be an exact lowercase 40-character Git SHA")
    if not re.fullmatch(r"codex/[A-Za-z0-9][A-Za-z0-9_/-]*", branch) or "//" in branch:
        raise ValueError("--branch must be an explicit codex/ branch without glob syntax")
    raw = canonical_path.read_bytes()
    canonical = yaml.safe_load(raw)
    journeys = canonical["jobs"]["rendered-journeys"]
    desktop = canonical["jobs"]["rendered-desktop"]
    if journeys["runs-on"] != "ubuntu-24.04":
        raise ValueError("Canonical journey runner changed; inspect before deriving")

    checkout = required_step(journeys, uses="actions/checkout@v7")
    checkout.setdefault("with", {}).update({"ref": source, "fetch-depth": 0})
    leading_names = (
        "Prepare disposable checkout for credential cleanup",
        "Install Godot and software display",
        "Start and verify native Linux speech service",
        "Upload native speech environment evidence",
        "Import project",
    )
    journey_names = (
        "Exercise real Solo reading Save and fresh-process Load",
        "Upload Solo reading reports, exact save bytes and screenshots",
    )
    ui_names = ("Audit all UI literal ownership", "Upload UI literal audit evidence")
    steps = [checkout, *(required_step(journeys, name=name) for name in leading_names)]
    steps.extend(required_step(journeys, name=name) for name in journey_names)
    # This canonical upload retains import.log on early failure. The broad
    # playable journey is deliberately not invoked by this diagnostic workflow.
    import_upload = required_step(journeys, name="Upload journey reports, logs and screenshots")
    import_upload["name"] = "Upload project import evidence"
    steps.append(import_upload)
    steps.extend(required_step(desktop, name=name) for name in ui_names)
    for step in steps:
        if step.get("uses", "").startswith("actions/upload-artifact@"):
            if step.get("if") != "always()" or not step["with"].get("include-hidden-files"):
                raise ValueError("Every evidence upload must run always and include hidden files")
    journey = next(step for step in steps if step.get("name") == journey_names[0])
    if journey["run"].strip() != "python3 tools/testing/run_reading_rail_journey.py":
        raise ValueError("Canonical eight-mode journey command changed")
    if source not in checkout["with"].values():
        raise ValueError("Exact checkout source is required")

    workflow = {
        "name": "Cold board-null Load layout diagnostic",
        "on": {"push": {"branches": [branch]}},
        "permissions": {"contents": "read"},
        "concurrency": {"group": "cold-layout-${{ github.ref }}", "cancel-in-progress": True},
        "jobs": {"cold-layout-journey": {
            "name": "Rendered cold board-null Load / reading journey and UI literal audit",
            "runs-on": journeys["runs-on"],
            "timeout-minutes": 55,
            "env": deepcopy(journeys["env"]),
            "steps": steps,
        }},
    }
    manifest = {
        "schema_version": 1,
        "source_checkout": source,
        "trigger_branch": branch,
        "canonical_workflow": str(canonical_path.resolve()),
        "canonical_workflow_sha256": sha256(raw),
        "workflow_repository_path": ".github/workflows/windows-tests.yml",
        "job_count": 1,
        "journey_command": journey["run"].strip(),
        "retained_journey_artifact_root": ".godot/ci/reading-rail/",
        "derived_steps": [step.get("name", step.get("uses")) for step in steps],
        "limits": [
            "Diagnostic only; not the canonical broad acceptance gate.",
            "Workflow head is auxiliary; engine checkout is source_checkout.",
            "Runs all original eight reading modes with the runner's existing sealing and byte checks.",
        ],
    }
    return workflow, manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True)
    parser.add_argument("--branch", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--canonical", type=Path,
                        default=Path(__file__).parent / "dwm/.github/workflows/windows-tests.yml")
    args = parser.parse_args()
    workflow, manifest = build(args.source, args.branch, args.canonical)
    output = yaml.safe_dump(workflow, sort_keys=False, width=120).encode("utf-8")
    # Check serialization did not change the trigger or pinned source. PyYAML's
    # dumper quotes 'on' to avoid YAML 1.1 boolean interpretation on reload.
    decoded = yaml.safe_load(output)
    if decoded != workflow:
        raise ValueError("Workflow YAML did not round-trip exactly")
    manifest["workflow_sha256"] = sha256(output)
    manifest_path = args.output.with_name(args.output.name + ".manifest.json")
    encoded_manifest = (json.dumps(manifest, indent=2, ensure_ascii=False) + "\n").encode()
    for path, content in ((args.output, output), (manifest_path, encoded_manifest)):
        if path.exists() and path.read_bytes() != content:
            raise FileExistsError(f"Refusing to overwrite different retained workflow: {path}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(output)
    manifest_path.write_bytes(encoded_manifest)
    print(json.dumps({"workflow": str(args.output.resolve()), "manifest": str(manifest_path.resolve()),
                      "source": args.source, "branch": args.branch, "jobs": 1,
                      "workflow_sha256": manifest["workflow_sha256"]}))


if __name__ == "__main__":
    main()
