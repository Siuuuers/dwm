#!/usr/bin/env python3
"""Audit source-pinned selector cloud evidence; failed runs stay diagnostics.

No engines, PowerShell, network, Git mutation, or artifact repair is performed.
Expanded success covers this explicit evidence checklist, not visual review or
the required final canonical broad PR gate.
"""
from __future__ import annotations
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import xml.etree.ElementTree as ET
import zipfile

BASELINE = "900118a5dc16b89b82a4e5d946767c080083c750"
NEW_SCRIPTS = {
    "tests/unit/test_solo_reading_catalogue.gd": 9,
    "tests/integration/test_solo_authored_selector_witness.gd": 9,
    "tests/integration/test_solo_authored_selector_runtime.gd": 3,
}
EXPANDED = ["reading_delivery", "dating", "persistence", "settings", "checkpoint_diagnostics", "localization"]


def read(path):
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError("Duplicate JSON key: " + key)
            result[key] = value
        return result
    def constant(value):
        raise ValueError("Nonfinite JSON: " + value)
    return json.loads(path.read_text(encoding="utf-8-sig"), object_pairs_hook=pairs, parse_constant=constant)


def identity(path):
    with path.open("rb") as stream:
        return {"bytes": path.stat().st_size, "sha256": hashlib.file_digest(stream, "sha256").hexdigest()}


def clean(line):
    line = re.sub(r"\x1b\[[0-9;]*m", "", line)
    return re.sub(r"^\ufeff?\d{4}-\d\d-\d\dT\S+\s", "", line).strip()


def git_source(repo, revision, path):
    return subprocess.check_output(["git", "-C", str(repo), "show", revision + ":" + path])


def latest_artifact(root, run_id, family):
    matches = []
    for path in (root / "artifacts").glob(family + "-" + str(run_id) + "-*"):
        match = re.fullmatch(re.escape(family) + "-" + str(run_id) + r"-(\d+)", path.name)
        if match:
            matches.append((int(match[1]), path))
    if not matches:
        raise ValueError("Missing artifact family: " + family)
    return max(matches)[1]


def classify(job):
    if job.get("conclusion") == "success":
        return {"classification": "success", "failed_steps": []}
    failed = [s.get("name", "") for s in job.get("steps", []) if s.get("conclusion") in ("failure", "cancelled", "timed_out")]
    first = failed[0].lower() if failed else ""
    if job.get("conclusion") == "skipped":
        category = "skipped_unvalidated"
    elif "import" in first:
        category = "import"
    elif any(x in first for x in ("checkout", "set up", "install", "download", "prepare disposable", "speech service")):
        category = "setup"
    elif any(x in first for x in ("upload", "post ", "complete job")):
        category = "artifact_upload_or_cleanup"
    elif any(x in first for x in ("regression", "contract", "inventory", "surface", "exercise", "render", "audit", "test", "capture")):
        category = "tests_or_validation"
    else:
        category = "unclassified_failure_requires_log_review"
    return {"classification": category, "failed_steps": failed}


def audit(a):
    root = a.run_root.resolve()
    errors = []
    result = {"schema_version": 1, "audit_scope": __doc__.strip(), "stage": a.stage,
              "source_commit": a.source, "accepted_contract_baseline": a.baseline,
              "workflow_acceptance": False, "component_checklist_pass": False,
              "whole_game_acceptance": False, "errors": errors}
    def check(condition, code):
        if not condition:
            errors.append(code)
        return bool(condition)
    def section(name, callback):
        try:
            result[name] = callback()
        except Exception as exc:
            errors.append(name.upper() + ": " + str(exc))
            result[name] = {"audit_incomplete": True, "reason": str(exc)}
    run = read(root / "run.json")
    api_jobs = read(root / "jobs.json")
    api_artifacts = read(root / "artifacts-api.json")
    result["run"] = {k: run.get(k) for k in ("id", "run_number", "run_attempt", "head_sha", "head_branch", "event", "status", "conclusion", "html_url")}
    result["metadata_identities"] = {p: identity(root / p) for p in ("run.json", "jobs.json", "artifacts-api.json")}
    check(re.fullmatch(r"[0-9a-f]{40}", a.source) is not None, "SOURCE_FULL_SHA_REQUIRED")
    check(run.get("event") == "push", "AUXILIARY_PUSH_RUN_REQUIRED")
    check(run.get("status") == "completed", "RUN_NOT_COMPLETED")
    check(run.get("conclusion") == "success", "RUN_NOT_SUCCESSFUL_DIAGNOSTIC_ONLY")
    check(len(api_jobs["jobs"]) == api_jobs.get("total_count", len(api_jobs["jobs"])), "JOBS_PAGINATION_INCOMPLETE")
    suites = ["reading_delivery"] if a.stage == "initial" else EXPANDED
    expected_jobs = {"Windows / public API surface contracts", *("Windows / " + s for s in suites)}
    if a.stage == "expanded":
        expected_jobs |= {"Rendered eight-process Solo reading and Next proof", "Rendered desktop and dialogue / Linux software OpenGL"}
    latest = {}
    for job in api_jobs["jobs"]:
        if "${{" in job["name"] and job.get("conclusion") == "skipped":
            continue
        before = latest.get(job["name"])
        if before is None or (job.get("run_attempt", 1), job["id"]) > (before.get("run_attempt", 1), before["id"]):
            latest[job["name"]] = job
    check(set(latest) == expected_jobs, "EXPECTED_JOB_SET_MISMATCH: " + json.dumps(sorted(latest)))
    job_results = []
    for job in sorted(latest.values(), key=lambda x: x["name"]):
        row = {k: job.get(k) for k in ("id", "name", "status", "conclusion", "run_attempt")}
        row.update(classify(job))
        check(job.get("status") == "completed" and job.get("conclusion") == "success", "JOB_NOT_SUCCESS: " + job["name"])
        # GitHub can alias a prior successful attempt into the current attempt.
        aliases = [j for j in api_jobs["jobs"] if all(j.get(k) == job.get(k) for k in ("name", "status", "conclusion", "started_at", "completed_at", "runner_id", "steps"))]
        execution = min(aliases, key=lambda x: (x.get("run_attempt", 1), x["id"]))
        row["execution_job_id"] = execution["id"]
        log = root / "logs" / (str(execution["id"]) + ".log")
        if log.is_file():
            lines = [clean(line) for line in log.read_text(encoding="utf-8-sig").splitlines()]
            shas = [lines[i + 1] for i, line in enumerate(lines[:-1]) if "log -1 --format=%H" in line and re.fullmatch(r"[0-9a-f]{40}", lines[i + 1])]
            row.update({"log": log.relative_to(root).as_posix(), "log_identity": identity(log), "actual_checkout_shas": shas})
            check(bool(shas) and all(s == a.source for s in shas), "ACTUAL_CHECKOUT_NOT_PROVEN: " + job["name"])
        else:
            check(False, "JOB_LOG_MISSING: " + job["name"])
        job_results.append(row)
    result["jobs"] = job_results

    def artifacts():
        records = read(root / "artifact-manifest.json")
        omissions = read(root / "omissions.json") if (root / "omissions.json").exists() else {}
        check(len(api_artifacts["artifacts"]) == api_artifacts.get("total_count", len(api_artifacts["artifacts"])), "ARTIFACT_PAGINATION_INCOMPLETE")
        downloads = {r["id"]: r for r in records}
        check(len(downloads) == len(records), "DUPLICATE_ARTIFACT_DOWNLOAD_RECORDS")
        report = []
        for item in api_artifacts["artifacts"]:
            check(item["workflow_run"]["id"] == run["id"] and item["workflow_run"]["head_sha"] == run["head_sha"], "ARTIFACT_RUN_HEAD_MISMATCH: " + item["name"])
            if item["id"] not in downloads:
                check(bool(omissions.get(str(item["id"]))), "ARTIFACT_NOT_RETAINED: " + item["name"])
                report.append({"id": item["id"], "name": item["name"], "omitted": omissions.get(str(item["id"]))})
                continue
            row = downloads[item["id"]]
            original = Path(row["local_zip"])
            digest = identity(original)
            check(digest == {"bytes": item["size_in_bytes"], "sha256": item["digest"].removeprefix("sha256:")}, "ZIP_IDENTITY_MISMATCH: " + item["name"])
            target = root / "artifacts" / item["name"]
            verified = 0
            with zipfile.ZipFile(original) as archive:
                members = [m for m in archive.infolist() if not m.is_dir()]
                names = {m.filename for m in members}
                check(len(names) == len(members), "DUPLICATE_ZIP_MEMBERS: " + item["name"])
                for member in members:
                    relative = PurePosixPath(member.filename)
                    if not check(not relative.is_absolute() and ".." not in relative.parts and "\\" not in member.filename and ":" not in member.filename and not stat.S_ISLNK(member.external_attr >> 16), "UNSAFE_ZIP_MEMBER"):
                        continue
                    path = target / member.filename
                    if not check(path.is_file() and not path.is_symlink(), "EXTRACTED_MEMBER_MISSING: " + member.filename):
                        continue
                    with archive.open(member) as stream:
                        member_sha = hashlib.file_digest(stream, "sha256").hexdigest()
                    if check(identity(path) == {"bytes": member.file_size, "sha256": member_sha}, "EXTRACTED_BYTES_MISMATCH: " + member.filename):
                        verified += 1
                check({p.relative_to(target).as_posix() for p in target.rglob("*") if p.is_file()} == names, "EXTRACTED_MEMBER_SET_MISMATCH: " + item["name"])
            report.append({"id": item["id"], "name": item["name"], "zip_identity": digest, "verified_extracted_members": verified})
        return report
    section("artifact_integrity", artifacts)

    def gut():
        runner = git_source(a.repo, a.source, "tools/testing/Invoke-CloudTests.ps1").decode()
        requested = {}
        for suite in ["public_surfaces", *suites]:
            block = re.search(r"(?m)^    " + re.escape(suite) + r" = @\(\n([\s\S]*?)^    \)", runner)
            if block is None:
                raise ValueError("Cannot read requested scripts: " + suite)
            requested[suite] = re.findall(r"'((?:tests/)[^']+[.]gd)'", block[1])
        reports, all_cases, all_scripts, new_cases = [], set(), set(), {}
        for suite in ["public_surfaces", *suites]:
            family = "public-surfaces" if suite == "public_surfaces" else "windows-" + suite
            folder = latest_artifact(root, run["id"], family)
            candidates = list(folder.rglob(suite + ".xml"))
            if len(candidates) != 1:
                raise ValueError("Exactly one ordinary suite XML required: " + suite)
            path = candidates[0]
            document = ET.parse(path).getroot()
            nodes = list(document.iter("testcase"))
            check(bool(nodes), "EMPTY_XML: " + suite)
            for node in document.iter():
                for attr in ("failures", "errors", "skipped", "disabled"):
                    check(int(node.get(attr, "0")) == 0, "NONZERO_XML_" + attr.upper() + ": " + suite)
                check(node.tag not in ("failure", "error", "skipped"), "NONPASS_XML_NODE: " + suite)
            actual_scripts = {}
            for script in document.iter("testsuite"):
                name = script.get("name", "").removeprefix("res://")
                cases = script.findall("./testcase")
                names = [c.get("name") for c in cases]
                check(name not in actual_scripts and len(set(names)) == len(names), "DUPLICATE_XML_SCRIPT_OR_CASE: " + name)
                check(int(script.get("tests", len(cases))) == len(cases), "SCRIPT_CASE_COUNT_MISMATCH: " + name)
                check(bool(cases), "EMPTY_SCRIPT: " + name)
                for case in cases:
                    check(case.get("status", "pass") in ("pass", "passed", "run"), "NONPASS_CASE: " + name + ":" + str(case.get("name")))
                    check(case.get("classname", name).removeprefix("res://") == name, "CASE_CLASSNAME_MISMATCH: " + name)
                    all_cases.add((name, case.get("name")))
                actual_scripts[name] = names
                all_scripts.add(name)
                if name in NEW_SCRIPTS:
                    new_cases[name] = names
            check(set(actual_scripts) == set(requested[suite]), "REQUESTED_REPORTED_SCRIPT_SET_MISMATCH: " + suite)
            check(int(document.get("tests", len(nodes))) == len(nodes), "XML_TOTAL_CASE_COUNT_MISMATCH: " + suite)
            reports.append({"suite": suite, "path": path.relative_to(root).as_posix(), **identity(path), "cases": len(nodes), "scripts": actual_scripts})
        for script, expected_count in NEW_SCRIPTS.items():
            declared = re.findall(r"(?m)^func (test_[A-Za-z0-9_]+)\(", git_source(a.repo, a.source, script).decode())
            check(len(declared) == expected_count, "NEW_SCRIPT_SOURCE_COUNT_CHANGED: " + script)
            check(len(new_cases.get(script, [])) == expected_count and set(new_cases.get(script, [])) == set(declared), "NEW_SCRIPT_DID_NOT_EXECUTE_EXACT_DECLARED_CASES: " + script)
        negatives = [{"path": p.relative_to(root).as_posix(), **identity(p), "reason": "Explicit negative storage-refusal fixture; excluded from ordinary GUT totals"} for p in (root / "artifacts").rglob("*.xml") if "storage-refusal" in p.parts]
        return {"xml_count": len(reports), "case_executions": sum(r["cases"] for r in reports), "unique_cases": len(all_cases), "unique_scripts": len(all_scripts), "new_script_cases": new_cases, "suites": reports, "negative_xml_exclusions": negatives}
    section("gut", gut)

    def inventory():
        folder = latest_artifact(root, run["id"], "public-surfaces")
        report = {}
        for name, count in (("game_state_surface.json", 236), ("save_manager_surface.json", 74)):
            found = list(folder.rglob(name))
            if len(found) != 1:
                raise ValueError("Exactly one generated inventory required: " + name)
            current = read(found[0])
            baseline = json.loads(git_source(a.repo, a.baseline, "evidence/phase_2r/runtime/" + name))
            check(current.get("ok") is True and current.get("errors") == [], "INVENTORY_NOT_PASSING: " + name)
            check(len(current["records"]) == count == len(baseline["records"]), "INVENTORY_RECORD_COUNT_CHANGED: " + name)
            def contracts(document):
                return [{k: v for k, v in row.items() if k != "call_sites"} for row in document["records"]]
            same = contracts(current) == contracts(baseline) and current["required"] == baseline["required"] and current["script"] == baseline["script"]
            check(same, "PUBLIC_CONTRACT_CHANGED: " + name)
            before = {r["symbol"]: r for r in baseline["records"]}
            changes = {}
            for row in current["records"]:
                old = before.get(row["symbol"], {}).get("call_sites", [])
                new = row.get("call_sites", [])
                if old != new:
                    old_paths = {re.sub(r":\d+$", "", p) for p in old}
                    new_paths = {re.sub(r":\d+$", "", p) for p in new}
                    changes[row["symbol"]] = {"added_paths": sorted(new_paths - old_paths), "removed_paths": sorted(old_paths - new_paths)}
            report[name] = {"path": found[0].relative_to(root).as_posix(), **identity(found[0]), "record_count": len(current["records"]), "contracts_unchanged": same, "changed_callsite_symbols": changes, "dynamic_references_changed": current["dynamic_references"] != baseline["dynamic_references"]}
        return report
    section("public_inventories", inventory)
    result["component_checklist_pass"] = not errors
    result["workflow_acceptance"] = not errors
    result["disposition"] = "focused_component_checklist_pass" if not errors else "diagnostic_only_not_acceptance"
    result["limits"] = ["Actual source checkout comes from each job log; auxiliary workflow head is distinct metadata.", "Inventory regeneration is for review and adoption; final canonical broad gate must use read-only committed inventories.", "No acceptance can be inferred from a failed, cancelled, skipped or incomplete workflow.", "Expanded rendered job success requires separate report/visual interpretation; this audit does not grant whole-game, production catalogue or native Windows graphics acceptance."]
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--run-root", type=Path, required=True)
    p.add_argument("--repo", type=Path, default=Path(__file__).with_name("dwm"))
    p.add_argument("--source", required=True)
    p.add_argument("--stage", choices=("initial", "expanded"), default="initial")
    p.add_argument("--baseline", default=BASELINE)
    p.add_argument("--output", type=Path)
    a = p.parse_args()
    result = audit(a)
    output = a.output or a.run_root / "selector-evidence-audit.json"
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"output": str(output), "disposition": result["disposition"], "workflow_acceptance": result["workflow_acceptance"], "source": a.source, "jobs": len(result["jobs"]), "gut_cases": result.get("gut", {}).get("case_executions"), "gut_scripts": result.get("gut", {}).get("unique_scripts"), "errors": result["errors"]}))
    raise SystemExit(0 if result["workflow_acceptance"] else 1)


if __name__ == "__main__":
    main()
