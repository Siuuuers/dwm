#!/usr/bin/env python3
"""Join source-declared GUT coverage to the generic audit's exact selected XML.

Reads committed Git blobs and retained evidence only; no engines or PowerShell.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import xml.etree.ElementTree as ET

ACCEPTED_BASELINE = "5a581fc89121864aead5202e01d6a82423b1b52d"
ACCEPTED_CHANGE_BASE = "5a581fc89121864aead5202e01d6a82423b1b52d"
REGISTRY = "tools/testing/Invoke-CloudTests.ps1"
EXPECTED_NEW_TESTS = {
    'test_paused_settings_binding_capture_never_saves_and_requires_fresh_release',
    'test_paused_settings_option_popup_forwards_release_and_retires_same_frame_save',
    'test_paused_settings_pending_preference_commit_retires_save_until_release',
    'test_paused_settings_quick_load_remains_unavailable_and_cannot_wake_on_exit',
    'test_paused_settings_quick_save_keeps_host_focus_and_exact_canonical_source',
    'test_paused_settings_reset_window_forwards_contacts_without_saving_or_queued_replay',
}
EXPECTED_NEW_SCRIPT = "tests/unit/test_production_pause_controller.gd"
ACCEPTED_COUNTS = {"case_executions": 2280, "unique_cases": 2276,
                   "unique_scripts": 194, "script_executions": 195, "xml_count": 13}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read(path):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, f"DUPLICATE_JSON_KEY: {path}/{key}")
            result[key] = value
        return result
    def nonfinite(value):
        raise ValueError(f"NONFINITE_JSON: {path}/{value}")
    return json.loads(path.read_text(encoding="utf-8-sig"),
                      object_pairs_hook=pairs, parse_constant=nonfinite)


def identity(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def full_sha(value):
    if not re.fullmatch(r"[0-9a-f]{40}", value):
        raise argparse.ArgumentTypeError("a full lowercase 40-hex commit SHA is required")
    return value


def contained(root, name):
    relative = PurePosixPath(name)
    require(not relative.is_absolute() and ".." not in relative.parts and "\\" not in name,
            f"UNSAFE_EVIDENCE_PATH: {name}")
    path = (root / name).resolve()
    require(path.is_relative_to(root), f"EVIDENCE_ESCAPES_RUN: {name}")
    return path


class Source:
    def __init__(self, repo, commit):
        self.repo, self.commit, self.blobs, self.effective_cache = repo, commit, {}, {}
        self.paths = set(self.git("ls-tree", "-r", "--name-only", commit, "--", "tests").decode().splitlines())

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.repo)

    def blob(self, path):
        if path not in self.blobs:
            self.blobs[path] = self.git("show", f"{self.commit}:{path}")
        return self.blobs[path]

    def text(self, path):
        return self.blob(path).decode("utf-8")

    def declared(self, path):
        if path not in self.paths:
            return set()
        names = re.findall(r"^func (test_\w+)\s*\(", self.text(path), re.M)
        require(len(names) == len(set(names)), f"DUPLICATE_DECLARED_TEST: {path}")
        return set(names)

    def effective(self, path, ancestors=()):
        require(path not in ancestors, f"TEST_INHERITANCE_CYCLE: {path}")
        if path not in self.effective_cache:
            names = self.declared(path)
            parent = re.search(r"^extends [\"']res://(tests/[^\"']+\.gd)[\"']", self.text(path), re.M)
            if parent:
                names |= self.effective(parent[1], ancestors + (path,))
            require(names, f"REGISTERED_SCRIPT_HAS_NO_TESTS: {path}")
            self.effective_cache[path] = names
        return self.effective_cache[path]

    def suites(self):
        block = re.search(r"(?ms)^\$suites = @\{\r?\n(.*?)^\}", self.text(REGISTRY))
        require(block is not None, "CLOUD_SUITE_REGISTRY_NOT_RECOGNIZED")
        pattern = r"(?ms)^    (\w+) = @\(\r?\n(.*?)^    \)"
        suites = {}
        for name, body in re.findall(pattern, block[1]):
            require(name not in suites, f"DUPLICATE_REGISTERED_SUITE: {name}")
            paths = []
            for line in body.splitlines():
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                match = re.fullmatch(r"'(tests/[^']+\.gd)'", line)
                require(match is not None, f"UNRECOGNIZED_SUITE_MEMBER: {name}/{line}")
                paths.append(match[1])
            require(paths and len(paths) == len(set(paths)), f"EMPTY_OR_DUPLICATE_SUITE: {name}")
            suites[name] = paths
        residue = re.sub(pattern, "", block[1])
        require(suites and all(not line.strip() or line.lstrip().startswith("#")
                               for line in residue.splitlines()), "UNPARSED_SUITE_REGISTRATION")
        return suites

    def counts(self, suites):
        scripts = {path for paths in suites.values() for path in paths}
        return {"case_executions": sum(len(self.effective(path)) for paths in suites.values() for path in paths),
                "unique_cases": sum(len(self.effective(path)) for path in scripts),
                "unique_scripts": len(scripts), "script_executions": sum(map(len, suites.values())),
                "xml_count": len(suites)}


def selected_xml(root, generic, suites, source):
    rows = generic["gut"]["suites"]
    require(isinstance(rows, list) and rows, "GENERIC_XML_SELECTION_REQUIRED")
    require(len({row["path"] for row in rows}) == len(rows), "DUPLICATE_XML_SELECTION")
    excluded = {row["path"] for row in generic["gut"].get("negative_xml_exclusions", [])}
    observed, selected, execution_count, script_executions = {}, {}, 0, 0
    for row in rows:
        name = row["path"]
        require(name not in excluded and "storage-refusal" not in PurePosixPath(name).parts,
                f"NEGATIVE_PROBE_SELECTED: {name}")
        path = contained(root, name)
        require(identity(path) == {key: row[key] for key in ("bytes", "sha256")},
                f"SELECTED_XML_BYTES_CHANGED: {name}")
        suite_name = path.stem
        require(suite_name in suites and suite_name not in selected, f"UNKNOWN_OR_DUPLICATE_XML_SUITE: {name}")
        selected[suite_name] = name
        tree = ET.parse(path).getroot()
        require(tree.tag == "testsuites", f"UNEXPECTED_XML_ROOT: {name}")
        xml_scripts, case_count = set(), 0
        for script in tree.findall("testsuite"):
            script_name = script.attrib["name"].removeprefix("res://")
            require(script_name in suites[suite_name] and script_name not in xml_scripts,
                    f"UNKNOWN_OR_DUPLICATE_XML_SCRIPT: {name}/{script_name}")
            xml_scripts.add(script_name)
            cases = script.findall("testcase")
            names = [case.attrib["name"] for case in cases]
            require(len(names) == len(set(names)) and set(names) == source.effective(script_name),
                    f"DECLARED_XML_TEST_SET_MISMATCH: {name}/{script_name}")
            require(int(script.attrib["tests"]) == len(cases), f"XML_SCRIPT_COUNT_MISMATCH: {script_name}")
            for count in ("failures", "errors", "skipped"):
                require(int(script.get(count, "0")) == 0, f"XML_SCRIPT_NOT_PASSING: {script_name}/{count}")
            for case in cases:
                require(case.get("classname", "").removeprefix("res://") == script_name,
                        f"XML_CASE_SCRIPT_MISMATCH: {script_name}/{case.get('name')}")
                require(case.get("status") == "pass" and not any(
                    node.tag in ("failure", "error", "skipped") for node in case.iter()),
                    f"XML_CASE_NOT_PASSED: {script_name}/{case.get('name')}")
                observed.setdefault((script_name, case.attrib["name"]), []).append(name)
            case_count += len(cases)
        require(xml_scripts == set(suites[suite_name]), f"REGISTERED_SCRIPT_UNDISCOVERED: {suite_name}")
        require(int(tree.attrib["tests"]) == case_count == row["cases"]
                and len(xml_scripts) == row["scripts"], f"XML_TOTALS_MISMATCH: {name}")
        for count in ("failures", "errors", "skipped"):
            require(int(tree.get(count, "0")) == 0, f"XML_ROOT_NOT_PASSING: {name}/{count}")
        execution_count += case_count
        script_executions += len(xml_scripts)
    require(set(selected) == set(suites), "REGISTERED_SUITE_XML_MISSING")
    counts = {"case_executions": execution_count, "unique_cases": len(observed),
              "unique_scripts": len({script for script, _ in observed}),
              "script_executions": script_executions, "xml_count": len(selected)}
    for key, value in counts.items():
        require(generic["gut"][key] == value, f"GENERIC_GUT_COUNT_MISMATCH: {key}")
    require(all(generic["gut"][key] == 0 for key in ("failures", "errors", "skipped")), "GENERIC_GUT_NOT_PASSING")
    return observed, counts, rows


def audit(args):
    root, repo = args.run_root.resolve(), args.repo.resolve()
    run = read(root / "run.json")
    provenance = read(root / "audit/source-provenance.json")
    generic = read(root / "audit/generic-evidence-audit.json")
    require(generic.get("generic_audit_pass") is True, "PASSING_GENERIC_AUDIT_REQUIRED")
    require(type(run["id"]) is int and run["id"] > 0 and type(run["run_attempt"]) is int and run["run_attempt"] > 0,
            "EXACT_RUN_ID_ATTEMPT_REQUIRED")
    require(run["head_sha"] == provenance["source"] == args.source
            and provenance["tested_checkout"] == args.checkout, "SOURCE_PROVENANCE_IDENTITY_MISMATCH")
    require(generic["source_boundary"] == provenance, "GENERIC_SOURCE_PROVENANCE_MISMATCH")
    require(all(generic["run"][key] == run[key] for key in ("id", "run_number", "run_attempt", "head_sha", "status", "conclusion")),
            "GENERIC_RUN_IDENTITY_MISMATCH")
    require(run["status"] == "completed" and run["conclusion"] == "success", "SUCCESSFUL_FINAL_RUN_REQUIRED")
    for name, retained in generic["raw_metadata_identities"].items():
        require(identity(contained(root, name)) == retained, f"GENERIC_METADATA_CHANGED: {name}")
    baseline, change_base, source, checkout = (Source(repo, commit) for commit in
                                              (args.baseline, args.change_base, args.source, args.checkout))
    before_suites, after_suites = baseline.suites(), source.suites()
    before_counts, expected = baseline.counts(before_suites), source.counts(after_suites)
    change_base_counts = change_base.counts(change_base.suites())
    source.git("merge-base", "--is-ancestor", args.baseline, args.change_base)
    source.git("merge-base", "--is-ancestor", args.change_base, args.source)
    if args.baseline == ACCEPTED_BASELINE:
        require(before_counts == ACCEPTED_COUNTS, "ACCEPTED_BASELINE_STATIC_COUNTS_CHANGED")
    observed, actual, xml = selected_xml(root, generic, after_suites, source)
    require(actual == expected, "SOURCE_DECLARED_AND_OBSERVED_TOTALS_DIFFER")
    changed = source.git("diff", "--name-only", "--no-renames", args.change_base, args.source, "--", "tests").decode().splitlines()
    added, removed = [], []
    registered = {path for paths in after_suites.values() for path in paths}
    for path in changed:
        if not path.endswith(".gd"):
            continue
        before, after = change_base.declared(path), source.declared(path)
        for name in sorted(after - before):
            require(path in registered and (path, name) in observed, f"ADDED_TEST_UNDISCOVERED: {path}/{name}")
            added.append({"script": path, "test": name, "selected_xml": observed[(path, name)]})
        removed.extend({"script": path, "test": name} for name in sorted(before - after))
    new_scripts = sorted(path for path in source.paths - change_base.paths
                         if path.endswith(".gd") and source.declared(path))
    require(set(new_scripts) <= registered, "NEW_TEST_SCRIPT_UNREGISTERED")
    require(before_suites == after_suites == change_base.suites(), "SETTINGS_F5_INCREMENT_MUST_NOT_CHANGE_GUT_REGISTRATION")
    require(before_counts == change_base_counts, "RECORDS_BASE_MUST_PRESERVE_ACCEPTED_GUT_COUNTS")
    require({(row["script"], row["test"]) for row in added}
            == {(EXPECTED_NEW_SCRIPT, name) for name in EXPECTED_NEW_TESTS}
            and removed == [] and new_scripts == [], "EXACT_SIX_SETTINGS_F5_CASE_ADDITIONS_REQUIRED")
    expected_delta = {"case_executions": 6, "unique_cases": 6, "unique_scripts": 0,
                      "script_executions": 0, "xml_count": 0}
    require({key: expected[key] - before_counts[key] for key in expected} == expected_delta,
            "SETTINGS_F5_INCREMENT_AGGREGATE_DELTA_MISMATCH")
    verifier = "tests/integration/verify_solo_authored_selector_journey.gd"
    require(verifier in source.paths and verifier not in registered and not source.declared(verifier)
            and source.text(verifier).startswith('extends "res://tests/integration/verify_playable_startup.gd"'),
            "TWO_PROCESS_CLOUD_VERIFIER_MUST_BE_SEPARATE_FROM_GUT")
    checked_paths = sorted(set(source.blobs) | {REGISTRY})
    source_equivalence = []
    for path in checked_paths:
        blob = source.blob(path)
        require(blob == checkout.blob(path), f"TESTED_CHECKOUT_SOURCE_DIFFERS: {path}")
        source_equivalence.append({"path": path, "bytes": len(blob), "sha256": hashlib.sha256(blob).hexdigest()})
    renamed_candidates = []
    for old in removed:
        matches = [new for new in added if new["script"] == old["script"] and
                   re.sub(r"\d+", "#", new["test"]) == re.sub(r"\d+", "#", old["test"])]
        if len(matches) == 1:
            renamed_candidates.append({"script": old["script"], "before": old["test"], "after": matches[0]["test"],
                                       "basis": "Same script and test name differing only in numeric tokens; bodies are not claimed identical."})
    return {"schema_version": 1, "audit_complete": True, "run_id": run["id"], "run_number": run["run_number"],
            "run_attempt": run["run_attempt"], "source": args.source, "tested_checkout": args.checkout,
            "baseline": args.baseline, "increment_change_base": args.change_base,
            "added_count": len(added), "removed_count": len(removed),
            "net_declared_test_delta": len(added) - len(removed), "added_test_functions": added,
            "removed_test_functions": removed, "numeric_rename_candidate_count": len(renamed_candidates),
            "numeric_rename_candidates": renamed_candidates,
            "new_test_scripts": new_scripts, "all_added_functions_discovered_and_passed": True,
            "separate_non_gut_verifier": verifier, "verifier_excluded_from_gut_counts": True,
            "baseline_static_counts": before_counts, "expected_current_counts": expected, "observed_counts": actual,
            "increment_change_base_static_counts": change_base_counts,
            "aggregate_delta": {key: expected[key] - before_counts[key] for key in expected},
            "duplicate_case_executions": actual["case_executions"] - actual["unique_cases"],
            "duplicate_execution_identities": [{"script": path, "test": name, "selected_xml": files}
                                                for (path, name), files in sorted(observed.items()) if len(files) > 1],
            "selected_xml": xml, "source_checkout_test_equivalence": source_equivalence,
            "input_identities": {name: identity(root / name) for name in (
                "run.json", "audit/source-provenance.json", "audit/generic-evidence-audit.json")},
            "auditor_sha256": identity(Path(__file__))["sha256"],
            "limits": ["Static discovery handles top-level test_* functions and quoted test-script inheritance; XML must match those exact effective sets.",
                       "The Settings F5 increment is compared with accepted records head 5a581fc; exactly six named GUT cases are added, no historical cases are removed or renamed, and registrations are unchanged. Cloud journey verifiers and support probes remain outside GUT counts.",
                       "Execution evidence comes only from generic-audit-selected XML; negative storage probes and repeated artifact copies are excluded.",
                       "No Godot, PowerShell or other engine executes in this auditor."]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-root", type=Path, required=True)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--source", type=full_sha, required=True)
    parser.add_argument("--checkout", type=full_sha, required=True)
    parser.add_argument("--baseline", type=full_sha, default=ACCEPTED_BASELINE)
    parser.add_argument("--change-base", type=full_sha, default=ACCEPTED_CHANGE_BASE)
    args = parser.parse_args()
    target = args.run_root.resolve() / "audit/physical-selector-test-discovery.json"
    try:
        report = audit(args)
    except Exception as error:
        report = {"schema_version": 1, "audit_complete": False, "source": args.source,
                  "tested_checkout": args.checkout, "baseline": args.baseline,
                  "increment_change_base": args.change_base,
                  "failure": {"type": type(error).__name__, "message": str(error)}}
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(report, indent=2) + "\n")
        raise
    target.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"audit_complete": True, "output": str(target), "added": report["added_count"],
                      "removed": report["removed_count"], "observed_counts": report["observed_counts"]}))


if __name__ == "__main__":
    main()
