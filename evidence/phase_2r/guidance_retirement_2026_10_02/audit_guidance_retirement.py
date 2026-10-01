#!/usr/bin/env python3
"""Audit downloaded cloud guidance-retirement evidence; no engines or PowerShell."""
from __future__ import annotations

import argparse
import copy
from datetime import datetime
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET

BASELINE = "96f95c67db6c7358b5f846651fef5c88babfbf92"
RUNTIME_SOURCE = "900118a5dc16b89b82a4e5d946767c080083c750"
BEADS_SHA = "27097bbef59b4abfd9b2c0ed20c7bc5efc700f7c00ebcded55c04c7e700c1b20"
SCRIPT_NAMES = (
    "test_agent_workflow_validator", "test_agent_workflow_authority_resolver",
    "test_doc_frontmatter", "test_doc_validator", "test_design_authority_registry",
    "test_legacy_disposition", "test_phase2r_beads_manifest", "test_repository_tooling",
)
SCRIPTS = tuple("tests/unit/tooling/" + name + ".gd" for name in SCRIPT_NAMES)
CHANGES = {
    "CLAUDE.md": "D", "Prompt.md": "D", "README.md": "A",
    "docs/agent/2026-09-23-next-session-handoff.md": "M",
    "docs/agent/2026-09-29-continuation-audit.md": "M",
    "docs/agent/AGENT_WORKFLOW.md": "D",
    "prompt_docs/requirements/authority_context.md": "M",
    "prompt_docs/requirements/documentation_tooling.md": "M",
    "tests/tooling/Test-CodeGraphRemovalScripts.ps1": "M",
    "tests/unit/test_art_manifest.gd": "M",
    "tests/unit/tooling/test_agent_workflow_validator.gd": "M",
    "tools/docs/AgentWorkflowValidator.gd": "M",
    "tools/docs/validate_agent_workflow.gd": "M",
    "tools/docs/validate_docs.gd": "M",
    "tools/tooling/Verify-CodeGraphPrerequisites.ps1": "M",
}
RETIRED = ("Prompt.md", "CLAUDE.md", "docs/agent/AGENT_WORKFLOW.md")
PRESERVED = (
    ".beads", ".github", "addons", "art", "art_source", "assets", "autoload",
    "data", "dialogic", "evidence", "localization", "scenes", "schemas",
    "scripts", "story", "project.godot", "export_presets.cfg",
)
RUNTIME_TREES = (
    "addons", "art", "art_source", "assets", "autoload", "data", "dialogic",
    "localization", "scenes", "schemas", "scripts", "story",
    "project.godot", "export_presets.cfg",
)


def load_helper():
    spec = importlib.util.spec_from_file_location("cloud_evidence", Path(__file__).with_name("cloud_evidence.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def audit(args):
    c = load_helper()
    root = args.run_root.resolve()
    run = c.read(root / "run.json")
    c.require(run["status"] == "completed" and run["conclusion"] == "success", "SUCCESS_REQUIRED")
    c.require(run["run_attempt"] == 1 and run["event"] == "push", "SINGLE_PUSH_ATTEMPT_REQUIRED")
    c.require(run["head_branch"] == "codex/next-cloud-20261002", "GUIDANCE_HELPER_BRANCH_REQUIRED")
    c.require(run["head_sha"] != args.source, "WORKFLOW_HEAD_MUST_REMAIN_DISTINCT_FROM_TESTED_SOURCE")
    raw_jobs = c.read(root / "jobs.json")
    c.require(raw_jobs.get("total_count") == len(raw_jobs["jobs"]) == 1, "ONE_RAW_GUIDANCE_JOB_REQUIRED")
    raw_job = raw_jobs["jobs"][0]
    c.require(raw_job["run_id"] == run["id"] and all(raw_job[key] == run[key] for key in
              ("head_sha", "head_branch", "run_attempt")), "RAW_JOB_RUN_IDENTITY_MISMATCH")
    args.checkout, args.master, args.allow_source_diff = args.source, None, []
    jobs = c.job_audit(root, args.source, 1, [])
    c.require([j["name"] for j in jobs] == ["Windows / guidance retirement"], "EXACT_GUIDANCE_JOB_REQUIRED")
    inventory = c.artifact_inventory(root, args.attachments, {})
    artifact_name = f"guidance-retirement-{run['id']}-{run['run_attempt']}"
    c.require([a["name"] for a in inventory["artifacts"]] == [artifact_name]
              and not inventory["not_downloaded_artifacts"], "EXACT_GUIDANCE_ARTIFACT_REQUIRED")
    gut = c.xml_audit(root, run["id"], 1)
    c.require(gut["unique_scripts"] == gut["script_executions"] == 8, "EIGHT_GUT_SCRIPTS_REQUIRED")
    c.require(not gut["negative_xml_exclusions"], "NO_NEGATIVE_XML_EXPECTED")
    boundary = c.source_boundary(args)

    def git(*argv):
        return subprocess.check_output(["git", "-C", str(args.repo.resolve()), *argv])

    def blob(commit, path):
        return git("show", commit + ":" + path)

    def object_id(commit, path):
        return git("rev-parse", commit + ":" + path).decode().strip()

    def ident(raw):
        return {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}

    def source_paths(commit):
        return git("ls-tree", "-r", "--name-only", "-z", commit).decode().strip("\0").split("\0")

    c.require(git("rev-parse", BASELINE + "^{commit}").decode().strip() == BASELINE, "BASELINE_COMMIT_REQUIRED")
    subprocess.run(["git", "-C", str(args.repo), "merge-base", "--is-ancestor", BASELINE, args.source], check=True)
    changed = {}
    change_rows = []
    pieces = git("diff", "--raw", "--no-abbrev", "--no-renames", "-z", BASELINE, args.source).split(b"\0")
    for index in range(0, len(pieces) - 1, 2):
        fields, path = pieces[index].decode().split(), pieces[index + 1].decode()
        c.require(fields[1] == ("000000" if fields[4] == "D" else "100644"),
                  "REGULAR_RETIREMENT_SOURCE_FILE_REQUIRED: " + path)
        changed[path] = fields[4]
        change_rows.append({"path": path, "status": fields[4], "baseline_mode": fields[0][1:],
                            "source_mode": fields[1], "baseline_blob": fields[2], "source_blob": fields[3]})
    c.require(changed == CHANGES, "RETIREMENT_CHANGED_PATH_SCOPE_MISMATCH")
    trees = []
    for path in PRESERVED:
        before, after = object_id(BASELINE, path), object_id(args.source, path)
        c.require(before == after, "PRESERVED_TREE_OR_FILE_CHANGED: " + path)
        trees.append({"path": path, "baseline_and_source_object": before})
    runtime = []
    for path in RUNTIME_TREES:
        before, after = object_id(RUNTIME_SOURCE, path), object_id(args.source, path)
        c.require(before == after, "ACCEPTED_RUNTIME_CHANGED: " + path)
        runtime.append({"path": path, "accepted_runtime_and_current_object": before})
    comment_path = "tests/unit/test_art_manifest.gd"
    code_lines = lambda raw: [line for line in raw.decode("utf-8").splitlines() if not line.lstrip().startswith("#")]
    c.require(code_lines(blob(BASELINE, comment_path)) == code_lines(blob(args.source, comment_path)),
              "ART_MANIFEST_TEST_MUST_BE_COMMENT_ONLY")
    for path in ("prompt_docs/requirements/authority_context.md", "prompt_docs/requirements/documentation_tooling.md"):
        c.require(blob(BASELINE, path).split(b"---", 2)[1] == blob(args.source, path).split(b"---", 2)[1],
                  "REQUIREMENT_FRONTMATTER_CHANGED: " + path)

    inputs = c.read(args.inputs)
    c.require(inputs["base"] == BASELINE, "RETIREMENT_INPUT_BASELINE_MISMATCH")
    records = {r["path"]: r for r in inputs["files"]}
    c.require(len(records) == len(inputs["files"]) == 4
              and set(records) == {*RETIRED, ".beads/issues.jsonl"}, "EXACT_RETIREMENT_INPUTS_REQUIRED")
    current_paths = set(source_paths(args.source))
    for path, record in records.items():
        raw = blob(BASELINE, path)
        c.require(record == {"path": path, "git_blob": object_id(BASELINE, path), **ident(raw)},
                  "RETIRED_INPUT_IDENTITY_MISMATCH: " + path)
    c.require(not (set(RETIRED) & current_paths), "RETIRED_FILE_STILL_PRESENT")
    beads_raw = blob(args.source, ".beads/issues.jsonl")
    c.require(beads_raw == blob(BASELINE, ".beads/issues.jsonl")
              and ident(beads_raw)["sha256"] == BEADS_SHA, "BEADS_BYTES_CHANGED")
    beads = [c.strict_json(line) for line in beads_raw.decode("utf-8").splitlines() if line.strip()]
    c.require(len(beads) == len({r["id"] for r in beads}) == 191, "BEADS_RECORD_ID_COUNT_CHANGED")
    unfinished = sum(r.get("status") not in ("closed", "tombstone") for r in beads)
    c.require(unfinished == 23, "BEADS_UNFINISHED_COUNT_CHANGED")

    artifact = root / "artifacts" / artifact_name
    def unique_file(name):
        matches = list(artifact.rglob(name))
        c.require(len(matches) == 1 and matches[0].is_file() and not matches[0].is_symlink(),
                  "ONE_ARTIFACT_FILE_REQUIRED: " + name)
        return matches[0]

    snapshot_path = unique_file("guidance-beads-snapshot.json")
    snapshot = c.read(snapshot_path)
    snapshot_normalizations = []
    def same_json(left, right):
        if type(left) is not type(right):
            return False
        if isinstance(left, dict):
            return left.keys() == right.keys() and all(same_json(left[key], right[key]) for key in left)
        if isinstance(left, list):
            return len(left) == len(right) and all(same_json(a, b) for a, b in zip(left, right))
        return left == right

    if not same_json(snapshot, beads):
        # PowerShell's temporary JSON projection trims insignificant timestamp
        # precision. Admit only the one observed text pair at its exact issue/path;
        # physical export bytes remain guarded independently above and below.
        source_stamp = "2026-10-01T22:09:54.715100Z"
        projected_stamp = "2026-10-01T22:09:54.7151Z"
        c.require(isinstance(snapshot, list) and len(snapshot) == 191
                  and isinstance(snapshot[157], dict)
                  and beads[157]["id"] == snapshot[157].get("id") == "dwm-vky.14"
                  and beads[157].get("updated_at") == source_stamp
                  and snapshot[157].get("updated_at") == projected_stamp,
                  "UNEXPECTED_CLOUD_BEADS_SNAPSHOT_DIFFERENCE")
        source_instant = datetime.fromisoformat(source_stamp.replace("Z", "+00:00"))
        projected_instant = datetime.fromisoformat(projected_stamp.replace("Z", "+00:00"))
        c.require(source_instant == projected_instant, "SNAPSHOT_TIMESTAMP_INSTANT_CHANGED")
        comparable = copy.deepcopy(snapshot)
        comparable[157]["updated_at"] = source_stamp
        c.require(same_json(comparable, beads), "OTHER_CLOUD_BEADS_SNAPSHOT_DIFFERENCE")
        snapshot_normalizations.append({
            "path": "beads[157].updated_at", "issue_id": "dwm-vky.14",
            "source_export_text": source_stamp, "temporary_snapshot_text": projected_stamp,
            "utc_instant": source_instant.isoformat(),
            "kind": "lossless removal of fractional-second trailing zeros",
            "all_other_fields_equal": True,
            "raw_artifact_modified": False,
        })

    declared = {}
    declaration_rows = []
    for path in SCRIPTS:
        raw = blob(args.source, path)
        text = raw.decode("utf-8")
        c.require(re.search(r'^extends "res://addons/gut/test.gd"\s*$', text, re.M),
                  "UNSUPPORTED_TEST_INHERITANCE: " + path)
        tests = re.findall(r"^func (test_[A-Za-z0-9_]+)\(", text, re.M)
        c.require(tests and len(tests) == len(set(tests)), "DUPLICATE_OR_MISSING_DECLARED_TEST: " + path)
        declared[path] = set(tests)
        declaration_rows.append({"path": path, "git_blob": object_id(args.source, path), **ident(raw),
                                 "test_count": len(tests), "tests": sorted(tests)})
    c.require(len(declared[SCRIPTS[0]]) == 9, "NINE_NAVIGATION_TESTS_REQUIRED")
    xml_path = unique_file("guidance-retirement.xml")
    c.require(gut["suites"][0]["path"] == xml_path.relative_to(root).as_posix(), "SELECTED_XML_MISMATCH")
    xml = ET.parse(xml_path).getroot()
    suites = list(xml.iter("testsuite"))
    observed = {}
    for suite in suites:
        path = suite.get("name", "").removeprefix("res://")
        c.require(path in declared and path not in observed, "UNKNOWN_OR_DUPLICATE_XML_SCRIPT: " + path)
        cases = suite.findall("./testcase")
        names = [case.get("name") for case in cases]
        c.require(len(names) == len(set(names)) and set(names) == declared[path], "SOURCE_XML_DISCOVERY_MISMATCH: " + path)
        c.require(int(suite.get("tests", "-1")) == len(cases), "XML_SUITE_COUNT_MISMATCH: " + path)
        for case in cases:
            c.require(case.get("classname", "").removeprefix("res://") == path and case.get("status") == "pass",
                      "CASE_SOURCE_OR_STATUS_MISMATCH: " + str(case.attrib))
            c.require(not any(node.tag in ("failure", "error", "skipped") for node in case.iter()),
                      "CASE_NOT_PASSED: " + path + "/" + str(case.get("name")))
        observed[path] = set(names)
    expected_count = sum(map(len, declared.values()))
    c.require(observed == declared and gut["case_executions"] == gut["unique_cases"] == expected_count,
              "ALL_DECLARED_TESTS_MUST_RUN_EXACTLY_ONCE")
    c.require(int(xml.get("tests", "-1")) == expected_count, "XML_ROOT_COUNT_MISMATCH")

    receipt_path = unique_file("guidance-retirement.json")
    receipt = c.read(receipt_path)
    expected_receipt = {
        "source": args.source, "actual_checkout": args.source,
        "beads_sha256_before": BEADS_SHA, "beads_sha256_after": BEADS_SHA,
        "beads_records": 191, "unfinished": 23, "gut_cases": expected_count,
        "requested_scripts": ["res://" + path for path in SCRIPTS],
        "live_dolt_queried": False, "runtime_changed": False,
    }
    c.require(receipt == expected_receipt
              and type(receipt["live_dolt_queried"]) is bool and type(receipt["runtime_changed"]) is bool,
              "CLOUD_GUIDANCE_RECEIPT_MISMATCH")
    for key in ("beads_records", "unfinished", "gut_cases"):
        c.require(type(receipt[key]) is int, "CLOUD_RECEIPT_INTEGER_REQUIRED: " + key)
    job_lines = [c.clean(line) for line in (root / jobs[0]["log"]).read_text(encoding="utf-8-sig").splitlines()]
    receipt_lines = [line.removeprefix("GUIDANCE_RETIREMENT_PASS ") for line in job_lines
                     if line.startswith("GUIDANCE_RETIREMENT_PASS ")]
    c.require(len(receipt_lines) == 1 and c.strict_json(receipt_lines[0]) == receipt,
              "ACTUAL_GUIDANCE_PASS_LOG_RECEIPT_REQUIRED")
    c.require(job_lines.count("CODEGRAPH_ACTIVE_INSTRUCTION_FIXTURE: PASS") == 1, "CODEGRAPH_ACTUAL_PASS_MARKER_REQUIRED")

    source_packets = [path for path in current_paths if path.endswith(".md") and any(path.startswith(prefix) for prefix in
                      ("prompt_docs/phases/", "prompt_docs/requirements/", "prompt_docs/decisions/"))]
    design_records = c.strict_json(blob(args.source, "prompt_docs/metadata/design_authority_registry.v1.json").decode())["records"]
    markers = {
        "validate_docs": f"DOC_VALIDATION: PASS packets={len(source_packets)} design_authorities={len(design_records)} agent_workflow=1",
        "validate_agent_workflow": "AGENT_WORKFLOW_VALIDATION: PASS",
    }
    c.require('print("DOC_VALIDATION: PASS packets=%d design_authorities=%d agent_workflow=1"' in blob(args.source, "tools/docs/validate_docs.gd").decode(),
              "DOCS_CLI_OUTPUT_CONTRACT_CHANGED")
    c.require('print("AGENT_WORKFLOW_VALIDATION: PASS")' in blob(args.source, "tools/docs/validate_agent_workflow.gd").decode(),
              "NAVIGATION_CLI_OUTPUT_CONTRACT_CHANGED")
    processes = []
    roots = []
    for suite in ("guidance-retirement", "validate_docs", "validate_agent_workflow"):
        evidence = unique_file(suite + ".jsonl")
        rows = [c.strict_json(line) for line in evidence.read_text(encoding="utf-8-sig").splitlines() if line.strip()]
        c.require(len(rows) == 1, "ONE_PROCESS_RECEIPT_REQUIRED: " + suite)
        process = rows[0]
        c.require(process["suite_id"] == suite and type(process["exit_code"]) is int and process["exit_code"] == 0,
                  "SUCCESSFUL_PROCESS_RECEIPT_REQUIRED: " + suite)
        argv = process["argv"]
        c.require("--headless" in argv, "HEADLESS_CLOUD_PROCESS_REQUIRED: " + suite)
        if suite == "guidance-retirement":
            selector = "-gtest=" + ",".join("res://" + path for path in SCRIPTS)
            c.require(argv.count(selector) == 1 and "-gjunit_xml_file=res://.godot/ci/guidance-retirement.xml" in argv,
                      "EXACT_GUT_PROCESS_ARGUMENTS_REQUIRED")
        else:
            c.require(argv.count("res://tools/docs/" + suite + ".gd") == 1, "EXACT_CLI_PROCESS_ARGUMENT_REQUIRED: " + suite)
        log_path = unique_file("cloud-" + suite + ".log")
        c.require(process["log_path"].replace("\\", "/").endswith("/" + log_path.name),
                  "PROCESS_LOG_BINDING_MISMATCH: " + suite)
        lines = [c.clean(line) for line in log_path.read_text(encoding="utf-8-sig").splitlines()]
        if suite in markers:
            c.require(lines.count(markers[suite]) == 1, "ACTUAL_CLI_PASS_MARKER_REQUIRED: " + suite)
        root_path = process["test_root"].replace("\\", "/").rstrip("/")
        user_path = process["user_dir"].replace("\\", "/")
        c.require(user_path.casefold().startswith(root_path.casefold() + "/"), "ISOLATED_USER_ROOT_REQUIRED")
        roots.append(root_path.casefold())
        processes.append({"suite": suite, "receipt": evidence.relative_to(root).as_posix(), "receipt_identity": c.identity(evidence),
                          "argv": argv, "exit_code": 0, "test_root": process["test_root"], "user_dir": process["user_dir"],
                          "log": log_path.relative_to(root).as_posix(), "log_identity": c.identity(log_path),
                          "expected_marker": markers.get(suite), "actual_marker_verified": suite in markers})
    c.require(len(set(roots)) == 3, "THREE_DISTINCT_ISOLATED_PROCESSES_REQUIRED")
    docs_process = next(p for p in processes if p["suite"] == "validate_docs")
    snapshots = [s.removeprefix("--beads-snapshot=") for s in docs_process["argv"] if s.startswith("--beads-snapshot=")]
    c.require(len(snapshots) == 1 and snapshots[0].replace("\\", "/").endswith("/guidance-beads-snapshot.json"),
              "DOCS_CLI_RETAINED_SNAPSHOT_ARGUMENT_REQUIRED")

    retirement = {
        "schema_version": 1, "audit_complete": True, "baseline": BASELINE, "source": args.source,
        "tested_checkout": args.source, "run_id": run["id"], "run_number": run["run_number"],
        "exact_changed_paths": change_rows, "all_unlisted_paths_byte_identical": True,
        "preserved_trees_and_files": trees, "test_art_manifest_comment_only": True,
        "requirement_frontmatter_unchanged": True, "retirement_inputs": inputs,
        "retirement_inputs_identity": c.identity(args.inputs), "retired_files_absent": list(RETIRED),
        "beads": {**ident(beads_raw), "git_blob": object_id(args.source, ".beads/issues.jsonl"),
                  "records": 191, "unfinished": 23, "all_bytes_preserved": True, "live_dolt_queried": False},
        "source_test_discovery": declaration_rows, "all_source_declared_cases_discovered_and_passed": True,
        "cloud_receipt": receipt, "cloud_receipt_identity": c.identity(receipt_path),
        "retained_snapshot_identity": c.identity(snapshot_path),
        "temporary_snapshot_normalizations": snapshot_normalizations,
        "cloud_snapshot_matches_source_after_only_documented_normalization": True,
        "cloud_processes": processes,
        "codegraph_active_instruction_fixture_pass": True,
        "previous_runtime_acceptance": {"source": RUNTIME_SOURCE, "run_number": 114,
              "run_id": 36928901183, "rerun_by_this_job": False, "runtime_objects_unchanged": runtime},
    }
    limits = [
        "This one-job acceptance covers guidance retirement, documentation/authority tooling and preserved task records only.",
        "Runtime acceptance remains source " + RUNTIME_SOURCE + " / Run114; no gameplay, render, export or broad runtime suite ran in this guidance job.",
        "All 191 retained Beads records and 23 unfinished tasks are byte-preserved; the retained snapshot does not claim live Dolt query or synchronization.",
        "The temporary CLI snapshot may contain only the specifically audited lossless trailing-zero timestamp normalization; its raw bytes are retained, and it is not claimed byte-identical to the physical Beads export.",
        "Workflow head and actual tested source are distinct; every retained job log and cloud receipt binds the exact source checkout.",
        "No engines or PowerShell run during this local evidence audit or packaging.",
    ]
    generic = {
        "schema_version": 1, "generic_audit_pass": True, "audit_scope": __doc__,
        "run": {key: run[key] for key in ("id", "run_number", "run_attempt", "head_sha", "head_branch", "event", "html_url", "status", "conclusion")},
        "raw_metadata_identities": {name: c.identity(root / name) for name in ("run.json", "jobs.json", "artifacts-api.json")},
        "source_boundary": boundary, "jobs": jobs, "gut": gut, "reading": [],
        "artifact_inventory": inventory, "guidance_retirement": retirement, "limits": limits,
    }
    summary = {
        "schema_version": 1, "run_id": run["id"], "run_number": run["run_number"], "run_url": run["html_url"],
        "source_commit": args.source, "actual_checkout_merge": args.source, "master_parent": None,
        "workflow_run": {key: run[key] for key in ("run_attempt", "event", "head_sha", "status", "conclusion")},
        "scope": generic["audit_scope"], "overall_acceptance_pass": True, "overall_accepted": True,
        "expected_job_count": 1, "observed_job_count": 1, "jobs": jobs, "gut": gut, "source_boundary": boundary,
        "guidance_retirement": retirement, "limits": limits,
    }
    output = root / "audit"
    output.mkdir(exist_ok=True)
    for name, report in (("generic-evidence-audit.json", generic), ("source-provenance.json", boundary),
                         ("guidance-retirement-audit.json", retirement)):
        (output / name).write_bytes(c.encoded(report))
    (output / "guidance-retirement-inputs.json").write_bytes(args.inputs.read_bytes())
    (root / "acceptance-summary.json").write_bytes(c.encoded(summary))
    print(json.dumps({"guidance_retirement_pass": True, "run": run["run_number"], "jobs": 1,
                      "gut": {key: gut[key] for key in ("case_executions", "unique_cases", "unique_scripts")},
                      "beads_records": 191, "unfinished": 23, "retired_files": len(RETIRED)}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-root", type=Path, required=True)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--source", required=True)
    parser.add_argument("--attachments", type=Path, action="append", required=True)
    parser.add_argument("--inputs", type=Path, default=Path(__file__).with_name("guidance-retirement-inputs.json"))
    args = parser.parse_args()
    audit(args)


if __name__ == "__main__":
    main()
