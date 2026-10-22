"""Verify retained comparison evidence without running project or driver code."""
import argparse
import collections
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import sys
import xml.etree.ElementTree as ET
import zipfile

BASELINE = "7d427a8bd2ef94210662c3dbfa0b1c3b958f1ab1"
CANDIDATE = "4963a847f0a7e2da82a87f29d1a27a7b8256eae1"
TREE = "588074015df4dec61b01941c4db08efd4d379911"
CONTROLLER = "fc798c47bf124e0d7a482e1231f58b75091e4e09"
CONTROLLER_SHA256 = "c5f1b652a16bbf4e619b00861b516b3361560ea1493c8ad8d3a6d659def5c38e"
BASELINE_PACKAGE_SHA256 = "61b04151e54ccb379de9cb0e199715c83002ab0cf7025c7ccfeeb2340ef820f3"
CONTRACT = "scripts/domain/narrative/SceneEventContract.gd"
OVERRIDES = {
    CONTRACT: ("30a65a65cab298b36e01eeee82362888339f2ed1", 80860),
    "tests/unit/test_scene_event_contract.gd": ("cde011002b3332325f58afe5c2f79f33af7b8468", 31847),
}
SUITES = {
    "event-contract": ("tests/unit/test_scene_event_contract.gd", 28, True),
    "receipt-validation": ("tests/unit/test_scene_receipt_validation.gd", 9, True),
    "transition-identity": ("tests/unit/test_scene_transition_identity.gd", 7, False),
    "terminal-lifecycle": ("tests/unit/test_scene_terminal_lifecycle.gd", 5, False),
    "scene-splice": ("tests/integration/test_scene_saved_event_anchor.gd", 8, False),
}
COMMON = [
    "tools/testing/Invoke-ExportedGameplay.ps1", "tools/testing/Invoke-IsolatedGodot.ps1",
    "tools/testing/Invoke-WindowsExportValidation.ps1", "tests/tooling/Test-ExportedGameplayDeadline.ps1",
    "project.godot", "export_presets.cfg",
]
SOURCES = COMMON + [
    CONTRACT, "scripts/domain/run/RunSnapshotSchema.gd", "scripts/application/run/SaveManagerCheckpointPort.gd",
    "scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd", "scripts/infrastructure/save/SaveDocumentSchema.gd",
    "autoload/GameState.gd", "autoload/DialogicBridge.gd", "autoload/SaveManager.gd",
    "scripts/application/backup/BackupPresentationPort.gd", "scripts/ui/BackupApp.gd",
    "tools/testing/Probe-ExportedWindow.ps1", "tests/unit/test_save_manager_checkpoint_port.gd",
    "tests/unit/test_save_document_schema.gd", "tests/unit/test_backup_presentation.gd",
] + [row[0] for row in SUITES.values()]


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def git_blob(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def timing_fields(value, path=""):
    if isinstance(value, dict):
        for key, member in value.items():
            yield from timing_fields(member, f"{path}.{key}" if path else key)
    elif isinstance(value, (int, float)) and not isinstance(value, bool) and (path.endswith("_us") or "_us_" in path):
        yield path, value


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument("receipt", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--baseline-index", type=Path, default=Path(__file__).with_name("diagnostic-tree-index.json"))
    args = parser.parse_args()
    problems, qualification_failures, journey_failures, analysis_notes = [], [], [], []

    def check(condition, message):
        if not condition:
            problems.append(message)

    def qualify(condition, message):
        if not condition:
            qualification_failures.append(message)

    def journey(condition, message):
        if not condition:
            journey_failures.append(message)

    receipt = json.loads(args.receipt.read_text(encoding="utf-8-sig"))
    raw = args.archive.read_bytes()
    check(len(raw) == receipt["bytes"], "Original archive byte count differs from download receipt")
    check(sha256(raw) == receipt["sha256"], "Original archive SHA256 differs from download receipt")
    archive = zipfile.ZipFile(io.BytesIO(raw))
    names = archive.namelist()
    check(len(names) == len(set(names)), "Duplicate ZIP member names")
    check(all(not PurePosixPath(p).is_absolute() and ".." not in PurePosixPath(p).parts for p in names), "Unsafe archive member path")

    def doc(path):
        return json.loads(archive.read(path).decode("utf-8-sig"))

    outer = doc("ci/retained-hashes.json")
    check(set(names) == set(outer) | {"ci/retained-hashes.json"}, "Outer manifest does not cover exact archive membership")
    for path, item in outer.items():
        data = archive.read(path)
        check(len(data) == item["bytes"] and sha256(data) == item["sha256"], f"Outer hash mismatch: {path}")
    origin = doc("ci/audit-origin.json")
    for key, expected in {"candidate": CANDIDATE, "tree": TREE, "controller": CONTROLLER, "baseline": BASELINE,
                          "baseline_tree": "c11bcd745193342bbc3270cb103a5be7ce90e234"}.items():
        check(origin.get(key) == expected, f"Origin mismatch: {key}")
    baseline_index = {item["path"]: (item["sha"], item["size"]) for item in json.loads(args.baseline_index.read_text())}
    pins = {}
    for role in ("baseline", "candidate"):
        prefix = f"ci/source/{role}/"
        check({p.removeprefix(prefix) for p in names if p.startswith(prefix)} == set(SOURCES), f"Unexpected {role} source snapshot coverage")
        for path in SOURCES:
            data = archive.read(prefix + path)
            expected = OVERRIDES[path] if role == "candidate" and path in OVERRIDES else baseline_index[path]
            actual = (git_blob(data), len(data))
            check(actual == expected, f"Source blob mismatch: {role}/{path}")
            pins[f"{role}/{path}"] = {"git_blob": actual[0], "bytes": actual[1], "sha256": sha256(data)}
    controller = archive.read("ci/source/controller/scene-first-reveal-profile-diagnostic.yml")
    check(sha256(controller) == CONTROLLER_SHA256, "Archived controller does not match pinned controller bytes")
    harness = doc("ci/comparison-harness.json")
    for key, expected in {"baseline": BASELINE, "candidate": CANDIDATE, "controller": CONTROLLER,
                          "order": ["baseline", "candidate"], "step_timeout_seconds": 30,
                          "journey_timeout_seconds": 480, "runner": "windows-2022",
                          "renderer": "ProjectDefault", "accessibility": "Always", "audio": "Dummy"}.items():
        check(harness.get(key) == expected, f"Comparison settings mismatch: {key}")
    check(set(harness["shared_files"]) == set(COMMON), "Shared comparison-driver coverage mismatch")
    for path in COMMON:
        old = archive.read("ci/source/baseline/" + path)
        new = archive.read("ci/source/candidate/" + path)
        check(old == new, f"Comparison driver changed: {path}")
        check(harness["shared_files"][path] == {"sha256": sha256(old), "git_blob": git_blob(old)}, f"Driver receipt mismatch: {path}")

    focused = doc("ci/focused-results.json")
    focused_by_id = {item["id"]: item for item in focused}
    expected_ids = {f"candidate-{key}" for key in SUITES} | {f"baseline-contract-{key}" for key, row in SUITES.items() if row[2]}
    qualify(set(focused_by_id) == expected_ids and len(focused) == len(expected_ids), "Focused suite result coverage differs from seven expected runs")
    xml_results = {}
    for role in ("baseline-contract", "candidate"):
        for name, (source, expected_count, shared) in SUITES.items():
            if role == "baseline-contract" and not shared:
                continue
            suite_id = f"{role}-{name}"
            if suite_id not in focused_by_id or f"ci/{suite_id}.xml" not in names or f"ci/{suite_id}.jsonl" not in names:
                qualify(False, f"Missing focused result/XML/process evidence: {suite_id}")
                continue
            record = focused_by_id[suite_id]
            source_bytes = archive.read("ci/source/candidate/" + source)
            methods = re.findall(r"^func\s+(test_[A-Za-z0-9_]+)\s*\(", source_bytes.decode(), re.M)
            xml = ET.fromstring(archive.read(f"ci/{suite_id}.xml"))
            cases = list(xml.iter("testcase"))
            method_counts = {case.attrib["name"]: int(case.attrib.get("assertions", 0)) for case in cases}
            qualify(len(methods) == expected_count and sorted(method_counts) == sorted(methods) and len(cases) == expected_count,
                  f"XML/source test-method mismatch: {suite_id}")
            errors = sum(len(list(xml.iter(tag))) for tag in ("failure", "error", "skipped"))
            qualify(errors == 0, f"Failed, errored or skipped XML cases: {suite_id}")
            qualify(all(count > 0 for count in method_counts.values()), f"Zero-assertion method: {suite_id}")
            wrapper_records = [json.loads(line) for line in archive.read(f"ci/{suite_id}.jsonl").decode("utf-8-sig").splitlines() if line.strip()]
            qualify(len(wrapper_records) == 1, f"Focused suite contains unexpected repeated executions: {suite_id}")
            wrapper = wrapper_records[-1] if wrapper_records else {}
            qualify(wrapper.get("suite_id") == suite_id and wrapper.get("exit_code") == 0, f"Isolated Godot did not exit cleanly: {suite_id}")
            qualify(f"-gtest=res://{source}" in wrapper.get("argv", []), f"Isolated Godot argv targets another suite: {suite_id}")
            contract_role = "baseline" if role == "baseline-contract" else "candidate"
            check(record.get("contract_sha256") == pins[f"{contract_role}/{CONTRACT}"]["sha256"], f"Executed contract hash mismatch: {suite_id}")
            check(record.get("test_sha256") == sha256(source_bytes), f"Executed test hash mismatch: {suite_id}")
            qualify(record.get("tests") == expected_count and record.get("expected_tests") == expected_count and record.get("timeout_seconds") == 180,
                  f"Focused counts or original timeout changed: {suite_id}")
            qualify(record.get("ok") is True and record.get("exit_code") == 0 and all(record.get(key) == 0 for key in ("failures", "errors", "skipped")),
                  f"Focused suite gate failed: {suite_id}")
            xml_results[suite_id] = {"tests": len(cases), "assertions": sum(method_counts.values()), "methods": method_counts,
                                     "exit_code": wrapper.get("exit_code"), "test_root": wrapper.get("test_root")}
    qualify(len({item["test_root"] for item in xml_results.values()}) == len(xml_results), "Focused test roots were reused")
    for name, (_, _, shared) in SUITES.items():
        if shared and f"baseline-contract-{name}" in xml_results and f"candidate-{name}" in xml_results:
            qualify(xml_results[f"baseline-contract-{name}"]["methods"] == xml_results[f"candidate-{name}"]["methods"],
                  f"Shared test assertion counts changed: {name}")

    package = doc("ci/windows-export/validation.json")
    check(package.get("ok") is True and package.get("commit") == CANDIDATE and package.get("engine") == "4.6.3.stable", "Candidate package source/engine gate failed")
    baseline_package = doc("ci/baseline-export/validation.json")
    check(baseline_package.get("ok") is True and baseline_package.get("commit") == BASELINE and baseline_package.get("archive", {}).get("sha256") == BASELINE_PACKAGE_SHA256,
          "Baseline package receipt mismatch")
    outcomes, raw_outcomes, profiles, inner_count = {}, {}, {}, 0
    for role, prefix, commit in (("baseline", "baseline", BASELINE), ("candidate", "exported", CANDIDATE)):
        package_hash = BASELINE_PACKAGE_SHA256 if role == "baseline" else package["archive"]["sha256"]
        for mode in ("capability", "create", "load"):
            folder = f"ci/{prefix}-{mode}/"
            if folder + "result.json" not in names:
                journey(False, f"Missing original player outcome: {role}-{mode}")
                continue
            result = doc(folder + "result.json")
            raw_outcomes[f"{prefix}-{mode}"] = result
            inner = doc(folder + "manifest.json")
            check(len({item["file"] for item in inner}) == len(inner), f"Duplicate mode manifest rows: {role}-{mode}")
            for item in inner:
                data = archive.read(folder + item["file"])
                check(len(data) == item["bytes"] and sha256(data) == item["sha256"], f"Mode manifest mismatch: {role}-{mode}/{item['file']}")
                inner_count += 1
            check(result.get("source_commit") == commit and result.get("archive_sha256") == package_hash, f"Original player source/package mismatch: {role}-{mode}")
            journey(result.get("ok") is True and result.get("clean_player_exit") is True and result.get("forced_cleanup") is False and result.get("exit_code") == 0,
                  f"Original player gate failed: {role}-{mode}")
            process_path = f"ci/{role}-{mode}-process.json"
            process = doc(process_path) if process_path in names else {}
            journey(process.get("exit_code") == 0, f"Original driver process failed or unrecorded: {role}-{mode}")
            if process:
                check(process.get("expected_source") == commit and process.get("unchanged_result") == ".godot/" + folder + "result.json",
                      f"Original driver process source/result binding changed: {role}-{mode}")
            outcomes[f"{role}-{mode}"] = {key: result.get(key) for key in ("ok", "failure", "elapsed_seconds", "exit_code", "clean_player_exit", "forced_cleanup", "checkpoint_profile", "archive_sha256")}
            outcomes[f"{role}-{mode}"]["driver_process"] = process
            events_path = folder + "events.json"
            events = doc(events_path) if events_path in names else []
            outcomes[f"{role}-{mode}"]["deadline_failures"] = [event for event in events if event.get("kind") == "wait-deadline-expired"]
            if mode != "load":
                continue
            if result.get("checkpoint_profile") is not True:
                analysis_notes.append(f"Primary Load profiling flag absent: {role}")
            log_path = folder + "game.stdout.log"
            records, sums = [], {}
            for number, line in enumerate(archive.read(log_path).decode("utf-8-sig", errors="replace").splitlines(), 1):
                match = re.search(r"\b(DWM_(?:CHECKPOINT|SAVE_LOAD)_PROFILE) (\{.*\})", line)
                if not match:
                    continue
                data = json.loads(match[2])
                records.append({"line": number, "marker": match[1], "data": data})
                group = match[1] + "|" + "|".join(f"{key}={data[key]}" for key in ("scope", "action", "operation", "op", "context", "mode") if key in data)
                totals = sums.setdefault(group, collections.Counter())
                totals.update(dict(timing_fields(data)))
            if not records:
                analysis_notes.append(f"No primary Load timing records: {role}")
            profiles[role] = {"source": log_path, "records": records, "microsecond_sums_by_field": sums,
                              "scope": "Each field summed separately within its original scope/action from this primary stdout only; nested scopes and overlapping phase fields are not added together."}
    acceptance = doc("ci/comparison-acceptance.json")
    journey(acceptance.get("ok") is True and acceptance.get("failures") == [], "Original comparison acceptance gate failed")
    journey(len(acceptance.get("original_outcomes", [])) == 6, "Original comparison gate did not retain all six player outcomes")
    for item in acceptance.get("original_outcomes", []):
        original = raw_outcomes.get(f"{item['role']}-{item['mode']}")
        check(original is not None and all(item.get(key) == original.get(key) for key in ("ok", "exit_code", "clean_player_exit", "forced_cleanup")),
              f"Comparison gate summary differs from original outcome: {item['role']}-{item['mode']}")
    status = archive.read("ci/final-status.txt").decode("utf-8-sig")
    allowed = {".claude/skills/godot-prompter/1.10.0", ".claude/skills/superpowers/6.1.1"}
    qualify(all(line[:2] == "??" or line[3:] in allowed for line in status.splitlines() if line), "Unexpected tracked source mutation after execution")
    report = {"archive_verified": not problems, "focused_qualified": not qualification_failures,
              "original_journeys_passed": not journey_failures, "problems": problems,
              "qualification_failures": qualification_failures, "journey_failures": journey_failures,
              "analysis_notes": analysis_notes, "archive": receipt, "origin": origin,
              "verified_outer_members": len(outer), "verified_mode_members": inner_count, "source_pins": pins,
              "xml": xml_results, "outcomes": outcomes, "profiles": profiles, "comparison_acceptance": acceptance, "final_status": status}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    summary = {key: value for key, value in report.items() if key not in ("profiles", "source_pins", "xml")}
    summary["xml"] = {name: {key: row[key] for key in ("tests", "assertions", "exit_code")} for name, row in xml_results.items()}
    print(json.dumps(summary, indent=2))
    # A preserved failing E2E outcome is evidence, not an archive-authenticity failure.
    return 0 if not problems and not qualification_failures else 1


if __name__ == "__main__":
    sys.exit(main())
