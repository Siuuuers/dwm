#!/usr/bin/env python3
"""Derive only public regeneration plus the complete F9 rendered journey.

This successor is for the source-bound Focus1 driver repair and regenerated
inventories. Ordinary Windows suites already supplied diagnostic evidence on the
unchanged production/test source; they remain required in the final broad gate.
No repository files, Git refs or remote resources are changed by this helper.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

import yaml

import build_paused_settings_f9_workflow as original


FOCUS1_SOURCE = "4b951a555202be25d231448797e8eb8b7bc99019"
FOCUS1_RUN = 36973252334
ALLOWED_DELTA = {
    "tests/integration/verify_reading_rail_journey.gd",
    "tools/testing/run_reading_rail_journey.py",
    "evidence/phase_2r/runtime/game_state_surface.json",
    "evidence/phase_2r/runtime/save_manager_surface.json",
}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, help="Exact frozen source commit")
    parser.add_argument("--prior-source", default=FOCUS1_SOURCE, help="Exact Focus1 diagnostic source")
    parser.add_argument("--repo", type=Path, default=Path(__file__).parent / "dwm")
    parser.add_argument("--branch", default=original.DEFAULT_BRANCH)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    original.require(re.fullmatch(r"[0-9a-f]{40}", args.prior_source), "Exact prior source SHA required")
    git = ["git", "-C", str(args.repo.resolve())]
    subprocess.run([*git, "merge-base", "--is-ancestor", args.prior_source, args.source], check=True)
    changed = subprocess.check_output([*git, "diff", "--name-only", args.prior_source, args.source], text=True).splitlines()
    original.require(set(changed) <= ALLOWED_DELTA,
                     "Successor changes production or ordinary tests; derive their affected Windows suites instead: " + repr(changed))
    original.require({original.RUNNER, original.JOURNEY} <= set(changed),
                     "This bounded successor requires the reviewed two-file driver/evidence repair")
    workflow, manifest = original.build(args.source, args.repo, original.DEFAULT_BASELINE, args.branch,
                                        original.DEFAULT_SUITES, original.DEFAULT_FIXTURES)
    del workflow["jobs"]["focused-tests"]
    # Each diagnostic job checks out the same exact source independently. The
    # rendered journey does not consume regenerated payloads from the Windows
    # job; both results are required before the candidate can be reviewed.
    rendered = workflow["jobs"]["paused-settings-reading"]
    original.require(rendered.get("needs") == "public-surfaces",
                     "Expected only the inherited canonical public dependency")
    del rendered["needs"]
    workflow["name"] = "Paused Settings F9 rendered successor"
    original.require(set(workflow["jobs"]) == {"public-surfaces", "paused-settings-reading"}, "Exact two-job successor required")
    manifest["job_count"] = 2
    manifest["job_definition_count"] = 2
    manifest["expected_ordinary_xml_count"] = 1
    manifest["focused_suites"] = []
    manifest["selected_suites"] = ["public_surfaces"]
    manifest["diagnostic_parallelism"] = {
        "removed_auxiliary_dependency": {"job": "paused-settings-reading", "needs": "public-surfaces"},
        "reason": "Independent exact-source checkouts; rendered validation consumes no generated public artifact. Run both diagnostic jobs concurrently to avoid serial regeneration delay.",
        "required_successful_jobs": ["public-surfaces", "paused-settings-reading"],
        "single_job_success_is_focus_acceptance": False,
        "canonical_workflow_changed": False,
        "job_steps_environments_timeouts_assertions_unchanged": True,
    }
    complete = manifest.pop("suite_census")
    manifest["deferred_ordinary_suite_census"] = complete
    public = complete["suites"]["public_surfaces"]
    manifest["suite_census"] = {
        "suite_runner": complete["suite_runner"],
        "suites": {"public_surfaces": public},
        "predicted_case_executions": public["static_case_count"],
        "predicted_script_executions": public["script_count"],
        "predicted_unique_cases": public["static_case_count"],
        "predicted_unique_scripts": public["script_count"],
        "limit": "Only public_surfaces GUT executes here. The retained full candidate census is explicitly deferred and is not an execution claim.",
    }
    manifest["derived_steps"].pop("focused-tests")
    manifest["diagnostic_predecessor"] = {
        "source": args.prior_source,
        "run_id": FOCUS1_RUN,
        "run_conclusion": "failure",
        "windows_diagnostic_case_executions": 914,
        "acceptance": False,
        "source_delta_paths": changed,
        "unchanged_production_and_ordinary_gut_sources": True,
    }
    manifest["scope"] = [
        "Regenerate exact public inventory payloads for source-bound stale-output review and later byte adoption.",
        "Execute the unchanged canonical reading-runner command with all original eight modes, the original F5 writer/reader and repaired independent Settings F9 process.",
        "Retain native Linux speech setup, UI literal ownership audit and all canonical evidence uploads.",
        "The two-file driver repair retains strict partial-reveal and all seven F9 stage assertions; it adds physical packet/frame/contact evidence without production changes.",
    ]
    manifest["limits"].extend([
        "The two auxiliary jobs run independently, but BOTH must succeed and their artifacts must pass source-bound review. A rendered pass after public failure is diagnostic only. Canonical broad dependencies remain unchanged.",
        "Reading_delivery, Settings and localization Windows suites do not execute in this successor. Focus1's 914 cases remain failed-run diagnostic evidence, not broad acceptance.",
        "Run129's stale public-surface refusal is not bypassed in the canonical workflow. This auxiliary regeneration mode obtains fresh payloads for review; the final broad gate must verify their committed bytes read-only.",
        "A successful two-job successor still requires the unchanged complete canonical broad gate on the final frozen source, including all ordinary Windows suites and physical catalogue-v2 proof.",
    ])
    raw = yaml.safe_dump(workflow, sort_keys=False, width=120).encode("utf-8")
    original.require(yaml.safe_load(raw) == workflow, "Workflow did not round-trip")
    manifest["workflow_sha256"] = hashlib.sha256(raw).hexdigest()
    helper_raw = Path(__file__).read_bytes()
    manifest["derivation_helpers"].append({"path": str(Path(__file__).resolve()), **original.identity(helper_raw)})
    manifest_path = args.output.with_name(args.output.name + ".manifest.json")
    encoded = (json.dumps(manifest, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
    for path, content in ((args.output, raw), (manifest_path, encoded)):
        original.require(not path.exists() or path.read_bytes() == content,
                         "Refusing to overwrite differing retained output: " + str(path))
    for path, content in ((args.output, raw), (manifest_path, encoded)):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
    print(json.dumps({"workflow": str(args.output.resolve()), "manifest": str(manifest_path.resolve()),
                      "source": args.source, "branch": args.branch, "jobs": 2, "expected_xml": 1,
                      "predicted_cases": public["static_case_count"], "publish_ready": manifest["publish_ready"],
                      "workflow_sha256": manifest["workflow_sha256"]}))


if __name__ == "__main__":
    main()
