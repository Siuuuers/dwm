#!/usr/bin/env python3
"""Join canonical cloud inventory validation to committed public contracts.

Reads exact Git blobs and retained cloud evidence; runs no engine or PowerShell.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

from cloud_evidence import clean, identity, read, require


def git(repo, revision, path):
    return subprocess.check_output(["git", "-C", str(repo), "show", revision + ":" + path])


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--run-root", type=Path, required=True)
    p.add_argument("--repo", type=Path, required=True)
    p.add_argument("--source", required=True)
    p.add_argument("--checkout", required=True)
    p.add_argument("--baseline", default="5a581fc89121864aead5202e01d6a82423b1b52d")
    a = p.parse_args()
    root = a.run_root.resolve()
    require(all(re.fullmatch(r"[0-9a-f]{40}", s) for s in (a.source, a.checkout, a.baseline)),
            "EXACT_SOURCE_CHECKOUT_BASELINE_REQUIRED")
    generic = read(root / "audit/generic-evidence-audit.json")
    source = read(root / "audit/source-provenance.json")
    run = read(root / "run.json")
    require(generic.get("generic_audit_pass") is True, "PASSING_GENERIC_AUDIT_REQUIRED")
    require(generic["source_boundary"] == source and source["source"] == a.source
            and source["tested_checkout"] == a.checkout and run["head_sha"] == a.source,
            "SOURCE_IDENTITY_MISMATCH")
    require(run["status"] == "completed" and run["conclusion"] == "success",
            "SUCCESSFUL_FINAL_RUN_REQUIRED")
    for name, expected in generic["raw_metadata_identities"].items():
        require(identity(root / name) == expected, "RAW_METADATA_CHANGED: " + name)
    jobs = read(root / "jobs.json")["jobs"]
    selected = [j for j in jobs if j["name"] == "Windows / public API surface contracts"
                and j["run_attempt"] == run["run_attempt"]]
    require(len(selected) == 1, "ONE_CURRENT_PUBLIC_JOB_REQUIRED")
    job = selected[0]
    require(job["status"] == "completed" and job["conclusion"] == "success", "PUBLIC_JOB_NOT_SUCCESSFUL")
    required_steps = ["Verify committed public inventories without regeneration",
                      "Verify public inventory drift and read-only contracts"]
    for name in required_steps:
        steps = [s for s in job["steps"] if s["name"] == name]
        require(len(steps) == 1 and steps[0]["conclusion"] == "success", "PUBLIC_STEP_NOT_PASSED: " + name)
    log = root / "logs" / (str(job["id"]) + ".log")
    lines = [clean(line) for line in log.read_text(encoding="utf-8-sig").splitlines()]
    shas = [lines[i + 1] for i, line in enumerate(lines[:-1]) if "log -1 --format=%H" in line
            and re.fullmatch(r"[0-9a-f]{40}", lines[i + 1])]
    require(shas and all(s == a.checkout for s in shas), "PUBLIC_ACTUAL_CHECKOUT_NOT_PROVEN")
    artifacts = read(root / "artifacts-api.json")["artifacts"]
    name = f"public-surfaces-{run['id']}-{run['run_attempt']}"
    selected_artifacts = [x for x in artifacts if x["name"] == name]
    require(len(selected_artifacts) == 1, "ONE_CURRENT_PUBLIC_ARTIFACT_REQUIRED")
    artifact = selected_artifacts[0]
    verified = [x for x in generic["artifact_inventory"]["artifacts"] if x["id"] == artifact["id"]]
    require(len(verified) == 1 and verified[0]["zip_and_extraction_verified"] is True,
            "ORIGINAL_PUBLIC_ARTIFACT_NOT_VERIFIED")
    files = {f["path"]: f for f in generic["artifact_inventory"]["files"]}
    folder = root / "artifacts" / name
    def retained(relative):
        path = folder / relative
        key = path.relative_to(root).as_posix()
        require(key in files and identity(path) == {k: files[key][k] for k in ("bytes", "sha256")},
                "VERIFIED_ARTIFACT_BYTES_CHANGED: " + key)
        return path
    inventories = {}
    for filename, count in (("game_state_surface.json", 236), ("save_manager_surface.json", 74)):
        path = retained("ci/public-surfaces/" + filename)
        source_path = "evidence/phase_2r/runtime/" + filename
        candidate = git(a.repo, a.source, source_path)
        tested = git(a.repo, a.checkout, source_path)
        require(path.read_bytes() == candidate == tested, "CLOUD_COMMITTED_INVENTORY_BYTES_DIFFER: " + filename)
        current = read(path)
        baseline_raw = git(a.repo, a.baseline, source_path)
        baseline = json.loads(baseline_raw)
        require(current["ok"] is True and current["errors"] == [], "INVENTORY_FAILED: " + filename)
        require(len(current["records"]) == len(baseline["records"]) == count, "RECORD_COUNT_CHANGED")
        def contracts(document):
            return [{k: v for k, v in row.items() if k != "call_sites"} for row in document["records"]]
        require(contracts(current) == contracts(baseline) and current["required"] == baseline["required"]
                and current["script"] == baseline["script"], "PUBLIC_CONTRACT_CHANGED: " + filename)
        old = {r["symbol"]: r for r in baseline["records"]}
        deltas = {}
        for record in current["records"]:
            before, after = old[record["symbol"]].get("call_sites", []), record.get("call_sites", [])
            if before != after:
                paths = lambda values: {re.sub(r":\d+$", "", value) for value in values}
                deltas[record["symbol"]] = {
                    "added_paths": sorted(paths(after) - paths(before)),
                    "removed_paths": sorted(paths(before) - paths(after)),
                    "before_reference_count": len(before), "after_reference_count": len(after)}
        inventories[filename] = {"path": path.relative_to(root).as_posix(), **identity(path),
            "baseline_sha256": hashlib.sha256(baseline_raw).hexdigest(), "record_count": count,
            "artifact_equals_source_and_tested_commit": True, "contract_declarations_unchanged": True,
            "changed_callsite_symbols": deltas,
            "dynamic_references_changed": current["dynamic_references"] != baseline["dynamic_references"]}
    retirement_path = retained("ci/public-surfaces/retirement-audit.json")
    retirement = read(retirement_path)
    require(retirement["checkout_ref"] == a.checkout and retirement["references"] == []
            and len(retirement["retired_symbols"]) == 10, "RETIREMENT_AUDIT_NOT_CLEAN")
    census_path = retained("ci/public-surfaces/fixture-version-census.json")
    census = read(census_path)
    require(census["checkout_ref"] == a.checkout, "FIXTURE_CENSUS_CHECKOUT_MISMATCH")
    output = root / "audit/physical-selector-public-surfaces-audit.json"
    report = {"schema_version": 1, "audit_complete": True, "run_id": run["id"],
        "run_attempt": run["run_attempt"], "source": a.source, "tested_checkout": a.checkout,
        "baseline": a.baseline, "public_job_id": job["id"], "job_log_identity": identity(log),
        "passed_read_only_steps": required_steps, "artifact": verified[0], "inventories": inventories,
        "retirement": {"identity": identity(retirement_path), **retirement},
        "fixture_census": {"identity": identity(census_path), "scanned_files": census["scanned_files"],
                           "matching_lines": len(census["matches"]), "policy": census["policy"]},
        "auditor_sha256": identity(Path(__file__))["sha256"],
        "limits": ["Contract declarations are unchanged; caller references and line numbers may change.",
                   "The fixture census is observational and does not classify every match as a migration defect.",
                   "Retirement evidence has its recorded search roots and does not prove arbitrary dynamic calls impossible.",
                   "No Godot or PowerShell executes in this auditor."]}
    output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"audit_complete": True, "output": str(output), "contracts": [236, 74],
                      "retired_symbols_without_references": 10}))


if __name__ == "__main__":
    main()
