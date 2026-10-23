#!/usr/bin/env python3
"""Derive a four-job paused-Settings F5 candidate gate from canonical cloud CI.

Without --source the task-local preview contains an explicit unfilled checkout
placeholder. Supply the exact frozen source SHA to produce a publishable gate.
This helper never runs Godot/PowerShell, edits the repository, or publishes refs.
"""
from __future__ import annotations

import argparse
from copy import deepcopy
import json
from pathlib import Path
import re

import yaml

import build_layout_workflow as diagnostic


PLACEHOLDER = "__FROZEN_SOURCE_COMMIT__"
SUITES = ("reading_delivery", "settings")
TARGETS = (
    "tests/unit/test_production_pause_controller.gd",
    "tests/unit/test_reading_pause_save.gd",
    "tests/scene/test_settings_reset_confirmation.gd",
)


def pin_checkout(job: dict, source: str) -> None:
    matches = [step for step in job["steps"] if step.get("uses") == "actions/checkout@v7"]
    if len(matches) != 1:
        raise ValueError("Expected exactly one canonical checkout per engine job")
    matches[0].setdefault("with", {}).update({"ref": source, "fetch-depth": 0})


def suite_census(repo: Path) -> dict:
    path = repo / "tools/testing/Invoke-CloudTests.ps1"
    raw = path.read_bytes()
    groups = {name: re.findall(r"'([^']+\.gd)'", body)
              for name, body in re.findall(r"^    (\w+) = @\((.*?)^    \)",
                                           raw.decode("utf-8-sig"), re.M | re.S)}
    census = {}
    for name in (*SUITES, "public_surfaces"):
        if not groups.get(name):
            raise ValueError(f"Canonical suite is absent or unparsable: {name}")
        scripts = []
        for relative in groups[name]:
            data = (repo / relative).read_bytes()
            names = re.findall(r"^func (test_\w+)\(", data.decode("utf-8-sig"), re.M)
            if len(set(names)) != len(names):
                raise ValueError(f"Duplicate static test function names: {relative}")
            scripts.append({"path": relative, "sha256": diagnostic.sha256(data),
                            "static_case_count": len(names)})
        census[name] = {"scripts": scripts, "script_count": len(scripts),
                        "static_case_count": sum(item["static_case_count"] for item in scripts)}
    owners = {target: [name for name, paths in groups.items() if target in paths]
              for target in TARGETS}
    if any(not owners[target] or not set(owners[target]).issubset(SUITES) for target in TARGETS):
        raise ValueError(f"Affected fixtures escaped selected canonical suites: {owners}")
    return {"suite_runner_path": str(path.resolve()),
            "suite_runner_sha256": diagnostic.sha256(raw), "affected_fixture_suites": owners,
            "suites": census,
            "predicted_case_executions": sum(item["static_case_count"] for item in census.values()),
            "predicted_script_executions": sum(item["script_count"] for item in census.values()),
            "limit": "Static definitions predict ordinary GUT counts; acceptance must audit actual cloud XML and reject failures, errors, skips or undiscovered scripts."}


def build(source: str | None, branch: str, canonical_path: Path) -> tuple[dict, dict]:
    # The shared builder deliberately accepts exact SHAs only. Its intermediate
    # zero value is replaced in every checkout and manifest before serialization.
    draft = source is None
    pin = PLACEHOLDER if draft else source
    workflow, manifest = diagnostic.build("0" * 40 if draft else source, branch, canonical_path)
    canonical = yaml.safe_load(canonical_path.read_bytes())
    public = deepcopy(canonical["jobs"]["public-surfaces"])
    focused = deepcopy(canonical["jobs"]["focused-tests"])
    for job in (public, focused):
        if job["runs-on"] != "windows-2022" or job["defaults"]["run"]["shell"] != "pwsh":
            raise ValueError("Canonical Windows runner or shell changed; inspect before deriving")
        pin_checkout(job, pin)
    matrix = focused["strategy"]["matrix"]
    if set(matrix) != {"suite"} or not set(SUITES).issubset(matrix["suite"]):
        raise ValueError("Affected suites must exist in the canonical single-axis matrix")
    matrix["suite"] = list(SUITES)
    if focused.get("needs") != "public-surfaces":
        raise ValueError("Canonical public-surface gate dependency changed")
    regeneration = [step for step in public["steps"]
                    if step.get("run", "").strip()
                    == "./tools/testing/Invoke-PublicSurfaceValidation.ps1 -EmitPayloads"]
    if len(regeneration) != 1:
        raise ValueError("Expected one canonical public inventory validation command")
    regeneration[0]["name"] = "Generate affected public inventories for review"
    regeneration[0]["run"] = "./tools/testing/Invoke-PublicSurfaceValidation.ps1 -Regenerate -EmitPayloads"
    linux = workflow["jobs"].pop("cold-layout-journey")
    pin_checkout(linux, pin)
    linux["name"] = "Rendered paused Settings F5 / original reading journey and UI literal audit"
    linux["timeout-minutes"] = canonical["jobs"]["rendered-journeys"]["timeout-minutes"]
    linux["needs"] = canonical["jobs"]["rendered-journeys"]["needs"]
    if linux["needs"] != "public-surfaces":
        raise ValueError("Canonical rendered-journey public-surface dependency changed")
    workflow["name"] = "Paused Settings F5 focused candidate"
    workflow["concurrency"]["group"] = "paused-settings-f5-${{ github.ref }}"
    workflow["jobs"] = {"public-surfaces": public, "focused-tests": focused,
                        "paused-settings-reading": linux}
    for job in workflow["jobs"].values():
        checkout = diagnostic.required_step(job, uses="actions/checkout@v7")
        if checkout["with"].get("ref") != pin or checkout["with"].get("fetch-depth") != 0:
            raise ValueError("Every engine checkout must be pinned with full ancestry")
        for step in job["steps"]:
            if step.get("uses", "").startswith("actions/upload-artifact@"):
                if step.get("if") != "always()" or not step["with"].get("include-hidden-files"):
                    raise ValueError("Evidence uploads must run always and include hidden files")
    manifest.update({
        "source_checkout": pin, "source_pending": draft, "publish_ready": not draft,
        "job_count": 4, "job_definition_count": 3, "expected_ordinary_xml_count": 3,
        "focused_suites": list(SUITES),
        "public_inventory_mode": "Regenerate EmitPayloads",
        "public_inventory_command": regeneration[0]["run"],
        "reading_supplement": {"modes": ["settings-write", "settings-read"],
                               "parent_result_key": "settings_quick_save",
                               "artifact_subdirectory": "settings-quick/",
                               "original_eight_mode_proof_retained": True},
        "suite_census": suite_census(canonical_path.parents[2]),
        "derivation_helper": str(Path(diagnostic.__file__).resolve()),
        "derivation_helper_sha256": diagnostic.sha256(Path(diagnostic.__file__).read_bytes()),
        "derived_steps": {job_id: [step.get("name", step.get("uses")) for step in job["steps"]]
                          for job_id, job in workflow["jobs"].items()},
        "limits": [
            "Focused candidate gate only; final frozen production source still needs the canonical broad gate.",
            "Generated public inventories require review and adoption before committed-inventory verification.",
            "The auxiliary workflow branch must advance by fast-forward; it is distinct from the PR source branch.",
            "A preview with the explicit frozen-source placeholder is not publish-ready.",
            "The unchanged reading runner command owns all original eight modes, their seal, and the nested independent Settings writer/reader proof.",
            "The separate physical catalogue-v2 journey is retained by the final broad gate and is not added to this focused candidate.",
        ],
    })
    return workflow, manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", help="Exact lowercase 40-character frozen Git source SHA")
    parser.add_argument("--branch", default="codex/paused-settings-f5-cloud-20261002")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--canonical", type=Path,
                        default=Path(__file__).parent / "dwm/.github/workflows/windows-tests.yml")
    args = parser.parse_args()
    workflow, manifest = build(args.source, args.branch, args.canonical)
    raw = yaml.safe_dump(workflow, sort_keys=False, width=120).encode("utf-8")
    if yaml.safe_load(raw) != workflow:
        raise ValueError("Workflow YAML did not round-trip exactly")
    manifest["workflow_sha256"] = diagnostic.sha256(raw)
    manifest_path = args.output.with_name(args.output.name + ".manifest.json")
    encoded = (json.dumps(manifest, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
    for path, content in ((args.output, raw), (manifest_path, encoded)):
        if path.exists() and path.read_bytes() != content:
            raise FileExistsError(f"Refusing to overwrite different retained workflow: {path}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(raw)
    manifest_path.write_bytes(encoded)
    print(json.dumps({"workflow": str(args.output.resolve()), "manifest": str(manifest_path.resolve()),
                      "source": manifest["source_checkout"], "branch": args.branch, "jobs": 4,
                      "publish_ready": manifest["publish_ready"],
                      "predicted_cases": manifest["suite_census"]["predicted_case_executions"],
                      "workflow_sha256": manifest["workflow_sha256"]}))


if __name__ == "__main__":
    main()
