"""Independently verify the frozen ending-order evidence, without executing Godot or PowerShell.

Usage: python ending-order-verify.py ORIGINAL.zip RECEIPT.json REPORT.json
Exit 0 means archive/source custody, retained harness checks and the focused suite
qualified. An original
journey failure or an absent/bounded trace remains available in the report, and does
not turn authentic diagnostic evidence into a corrupt archive.
"""
import argparse
import collections
import hashlib
import io
import json
import math
from pathlib import Path, PurePosixPath
import re
import sys
import zipfile
import xml.etree.ElementTree as ET
from datetime import datetime

REFERENCE = "337c2d43e9ff508575f772b1c1b7cf5679be8d0f"
REFERENCE_TREE = "1e4e752bd8e532f2e731dfc483be40fcff3bd3fc"
REFERENCE_RUN = 39152708408
RUNTIME_PATH = "scripts/ui/EndingScene.gd"
TEST_PATH = "tests/scene/test_ending_recovery_localization.gd"
CHANGED_PATHS = [RUNTIME_PATH, TEST_PATH]
# Independent source/run pins, established before inspecting each run's outcomes.
# An unknown source is refused rather than trusted from the archived manifest.
ATTEMPTS = {
    "a25fae335247ba8074ea01d44990b3c6cd00f8ba": {
        "name": "initial-order-attempt",
        "tree": "6c44631f8f926461d86b44f29c25c970c22218e9",
        "controller": "fb8377d546b32542975b867e76de51a619d047ab",
        "controller_tree": "6245c3dec56a6ac626efe367288d1604795a6899",
        "controller_sha256": "ed689d71b8df6d22b677906b8935547cb1cd1fdf139079e0eb1d0f608b58f559",
        "run_id": 39155054285, "job_id": 117756447001,
        "candidate_overrides": {
            RUNTIME_PATH: ("6f4ebb80cef316aa4db0cee940a30eb38d08487d", 15872),
            TEST_PATH: ("babcce483346163a891c2a7c3ef36eabc6522835", 16616),
        },
    },
    "81847d8b1560340a3a7769223cee0b46c6bdc0f9": {
        "name": "guard-corrected-order-attempt",
        "tree": "4581a9f12d63684836c722f72cffd533491f3c06",
        "controller": "cf1ffe0ec204cc51ecc532e4a95136f9177577d1",
        "controller_tree": "738a6b7130652ddd6a14915aa542348389f2e44d",
        "controller_sha256": "fc5fd9d673033b9326ba592e3c5fb2dafe8c1216c146bc6ff39826041f35535c",
        "run_id": 39155624496, "job_id": 117758138682,
        "candidate_overrides": {
            RUNTIME_PATH: ("dec4979b1d6331a22aac268b4b2a926e70a601eb", 15926),
            TEST_PATH: ("0c09f6843e17e9f0611327519376c71248228656", 16640),
        },
    },
}
EXPECTED_METHODS = [
    "test_retry_copy_follows_locale_without_changing_the_pending_command",
    "test_normal_playback_exposes_no_return_action_or_error",
    "test_no_public_ending_title_is_added_by_the_recovery_host",
    "test_programmatic_pressed_cannot_submit_a_retry",
    "test_focused_keyboard_activation_submits_one_retry",
    "test_missing_localization_hides_the_whole_recovery_surface",
    "test_locale_change_retires_a_held_retry_contact",
    "test_registered_accessibility_preferences_update_the_recovery_material",
    "test_retry_focus_and_keyboard_replay_the_same_temporarily_failed_command",
    "test_later_playback_failure_keeps_retry_focus_and_replays_the_same_command",
    "test_deferred_order_refresh_ignores_retired_scene_and_freed_layout",
]
FOCUSED_SCOPE = "Headless scene integration with simulated input/focus; original exported journey remains native acceptance"
CONTROLLER_PATH = "ci/source/controller/scene-first-reveal-profile-diagnostic.yml"
ENGINE_EXE_SHA256 = "91724f15024a3a545e28ccd83134403d31ce2323a38e51c95e4dfa282f732ab6"
TEMPLATES_SHA256 = "3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8"
TRACE_MARKER = "DWM_ENDING_PUBLICATION_TRACE"
TRACE_GATE = {"DWM_SAVE_LOAD_PROFILE": "1", "DWM_SAVE_LOAD_CONTEXT": "exported-load-phase-diagnostic"}
LOAD_ENVIRONMENT = {**TRACE_GATE, "DWM_CHECKPOINT_PROFILE": "1"}
MODES = ("capability", "create", "load")
TRACE_LIMITS = {"caption_accessibility": 2, "canvas_accessibility": 2,
                "text_started_enter": 1, "text_finished": 1, "text_finished_followup": 1}
DEADLINE_CASES = {"late_root_refused_before_enumeration", "late_match_refused",
                  "timely_unique_match_accepted", "ambiguous_match_refused"}
COMMON = ["tools/testing/Invoke-ExportedGameplay.ps1", "tools/testing/Invoke-IsolatedGodot.ps1",
          "tools/testing/Invoke-WindowsExportValidation.ps1", "tests/tooling/Test-ExportedGameplayDeadline.ps1",
          "project.godot", "export_presets.cfg"]
# Frozen reference blobs from the independently reviewed 337 source tree.
# No archived manifest supplies these pins.
REFERENCE_PINS = {
    "tools/testing/Invoke-ExportedGameplay.ps1": ("e91f912d8351ba7e38401b261d0fb2f0aa3032dc", 52927),
    "tools/testing/Invoke-IsolatedGodot.ps1": ("14b379880b4ad26935ad953d141df8c19e399cf3", 19919),
    "tools/testing/Invoke-WindowsExportValidation.ps1": ("322d02bbe72d8e2e3c1e5b637fd9ac253ef31fff", 19523),
    "tests/tooling/Test-ExportedGameplayDeadline.ps1": ("436c73a380baec1a3bc6ba64d273ff052e316d78", 3023),
    "project.godot": ("b3e4ec92242535d81845bdc2dc7537e9e3ec122e", 14532),
    "export_presets.cfg": ("ccb9409ac1054d0b4b52e78df823c33f532e83fb", 1117),
    "scripts/domain/narrative/SceneEventContract.gd": ("30a65a65cab298b36e01eeee82362888339f2ed1", 80860),
    "scripts/domain/run/RunSnapshotSchema.gd": ("b9608a523f788b90f87d8e556f88d485394b6e8b", 74097),
    "scripts/application/run/SaveManagerCheckpointPort.gd": ("9306b21bd1e92e1c81c25a709c89470b4e2d8179", 59778),
    "scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd": ("5cb4ada73c8faa8ad22405447266ad566f1aa87e", 61503),
    "scripts/infrastructure/save/SaveDocumentSchema.gd": ("05be052983999d0757e16a942f38a6b7358286f7", 28931),
    "autoload/GameState.gd": ("f3ad6905609566025e356747f5873da7ad2290ba", 296738),
    "autoload/DialogicBridge.gd": ("6542701617c214f5de9486e7558da03c3c2b6787", 272465),
    "autoload/SaveManager.gd": ("319449c17e7d3859076d7ba20e362b775f096802", 189349),
    "scripts/application/backup/BackupPresentationPort.gd": ("4524984d3ef3e74bdcbab1c296232a603f0eb040", 10807),
    "scripts/ui/BackupApp.gd": ("69be339643d27ab6e35efb945e3505915ad2cbb1", 48775),
    "tools/testing/Probe-ExportedWindow.ps1": ("4d678892e911e205a498af5be21afe4ed0242e24", 11121),
    "tests/unit/test_save_manager_checkpoint_port.gd": ("899458c00949a5da0c56ea9f582fdfd89ce4e67e", 88364),
    "tests/unit/test_save_document_schema.gd": ("4d5eae755e49da9d14ed1b003b2ce8190b9b92e1", 49202),
    "tests/unit/test_backup_presentation.gd": ("3c5029d294bf29027e0cf662354d13c0b6ff209a", 18872),
    "tests/unit/test_scene_event_contract.gd": ("cde011002b3332325f58afe5c2f79f33af7b8468", 31847),
    "tests/unit/test_scene_receipt_validation.gd": ("089e33bcb42ddb9a01d20011166645c403331dd2", 10604),
    "tests/unit/test_scene_transition_identity.gd": ("2ce6e7d81a38eebac6d84328f3b6005583b11a4f", 10548),
    "tests/unit/test_scene_terminal_lifecycle.gd": ("64be622a49ca0d089787d410c107da652ee25680", 12094),
    "tests/integration/test_scene_saved_event_anchor.gd": ("4d41738a0d6d5f9c7790e0363ae7e427d0a02d82", 15119),
    "scripts/ui/witnessed/WitnessedCaptionLayer.gd": ("5c85ce306366917c995db06794e18cb4035b2711", 84211),
    "scripts/ui/witnessed/WitnessedAccessibleCaption.gd": ("c29b306199bf1b8f9ce4352872ff569e2b3f0bd4", 1485),
    "scripts/ui/witnessed/WitnessedSourceCanvas.gd": ("db11d71216b47004da8a3207acaac73e964cffa6", 1107),
}
REFERENCE_PINS.update({
    RUNTIME_PATH: ("ae9bf01b2692213cfadeea7ffde81c66db3120cf", 14766),
    TEST_PATH: ("d21e7cea1de6f5a7ec0cc384dc56b9981dec110a", 10040),
})
TRACE_PINS = {
    "scripts/ui/witnessed/WitnessedCaptionLayer.gd": ("5c85ce306366917c995db06794e18cb4035b2711", 84211),
    "scripts/ui/witnessed/WitnessedAccessibleCaption.gd": ("c29b306199bf1b8f9ce4352872ff569e2b3f0bd4", 1485),
    "scripts/ui/witnessed/WitnessedSourceCanvas.gd": ("db11d71216b47004da8a3207acaac73e964cffa6", 1107),
}


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def git_blob(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def safe_name(name):
    path = PurePosixPath(name)
    return bool(name) and name == path.as_posix() and not path.is_absolute() and ".." not in path.parts and "\\" not in name and ":" not in name


def finite_number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def parse_primary(raw):
    """Project only the canonical Load stdout, once; never merge secondary logs."""
    publication, profiles, errors, malformed_markers = [], [], [], []
    for number, line in enumerate(raw.decode("utf-8-sig", errors="replace").splitlines(), 1):
        match = re.search(r"(DWM_(?:CHECKPOINT_PROFILE|SAVE_LOAD_PROFILE|ENDING_PUBLICATION_TRACE)) (\{.*\})", line)
        if not match:
            if TRACE_MARKER in line:
                malformed_markers.append({"line": number, "text": line})
            continue
        try:
            record = {"line": number, "marker": match[1], "data": json.loads(match[2])}
            (publication if match[1] == TRACE_MARKER else profiles).append(record)
        except json.JSONDecodeError as error:
            errors.append({"line": number, "text": line, "error": str(error)})
    return publication, profiles, errors, malformed_markers


def focused_observations(members, document, check, candidate, problems):
    """Independently reconstruct focused results; a real failing suite is evidence."""
    failures = []
    test = members.get("ci/source/candidate/" + TEST_PATH, b"")
    source = members.get("ci/source/candidate/" + RUNTIME_PATH, b"")
    methods = re.findall(r"^func\s+(test_[A-Za-z0-9_]+)\s*\(", test.decode("utf-8-sig"), re.M)
    check(methods == EXPECTED_METHODS and len(set(methods)) == 11,
          "Candidate source does not declare the frozen eleven focused methods")
    expected_plan = {
        "id": "ending-recovery", "role": "candidate", "path": TEST_PATH,
        "source_commit": candidate, "source_path": RUNTIME_PATH,
        "expected_tests": 11, "expected_methods": methods, "timeout_seconds": 180,
        "headless": True, "scope": FOCUSED_SCOPE,
        "test_sha256": sha256(test), "source_sha256": sha256(source),
    }
    plan = document("ci/focused-plan.json")
    check(plan == expected_plan, "Focused plan differs from independent source/method/settings reconstruction")
    result_rows = document("ci/focused-results.json", kind=list, required=False)
    check(len(result_rows) == 1 and isinstance(result_rows[0], dict),
          "Focused result must retain exactly one suite result", failures)
    result = result_rows[0] if len(result_rows) == 1 and isinstance(result_rows[0], dict) else {}
    for key, value in expected_plan.items():
        if result:
            check(result.get(key) == value, f"Focused result plan/source binding mismatch: {key}")
    process = document("ci/ending-recovery-process.json", required=False)
    if process:
        for key, value in {"id": "ending-recovery", "source_commit": candidate, "timeout_seconds": 180}.items():
            check(process.get(key) == value, f"Focused outer process binding mismatch: {key}")
    check(bool(process) and process.get("exit_code") == 0 and not process.get("failure"),
          f"Focused outer process did not exit cleanly: {process.get('exit_code')}", failures)
    wrapper_rows = []
    wrapper_path = "ci/ending-recovery.jsonl"
    for number, line in enumerate(members.get(wrapper_path, b"").decode("utf-8-sig", errors="replace").splitlines(), 1):
        if not line.strip():
            continue
        try:
            row = json.loads(line)
            if not isinstance(row, dict):
                raise ValueError("wrapper record must be an object")
            wrapper_rows.append(row)
        except ValueError as error:
            failures.append(f"Invalid focused wrapper line {number}: {error}")
    check(len(wrapper_rows) == 1, "Expected exactly one isolated focused process record", failures)
    wrapper = wrapper_rows[0] if len(wrapper_rows) == 1 else {}
    check(wrapper.get("suite_id") == "ending-recovery" and wrapper.get("exit_code") == 0,
          f"Isolated focused process did not exit cleanly: {wrapper.get('exit_code')}", failures)
    argv = wrapper.get("argv", [])
    required_args = ["--headless", "-gconfig=", "-gexit", "-glog=2",
                     "-gtest=res://" + TEST_PATH,
                     "-gjunit_xml_file=res://.godot/ci/ending-recovery.xml"]
    check(isinstance(argv, list) and all(argv.count(arg) == 1 for arg in required_args)
          and [arg for arg in argv if isinstance(arg, str) and arg.startswith("-gtest=")] == [required_args[-2]]
          and [arg for arg in argv if isinstance(arg, str) and arg.startswith("-gjunit_xml_file=")] == [required_args[-1]],
          "Focused argv does not bind the isolated headless suite and XML output", failures)
    if wrapper:
        test_root, user_dir = wrapper.get("test_root", ""), wrapper.get("user_dir", "")
        check(isinstance(test_root, str) and bool(re.search(r"\\\.godot\\phase2r_tests\\[a-f0-9-]{36}$", test_root))
              and user_dir == test_root + "\\appdata\\Godot\\app_userdata\\DWM",
              "Focused process user data is not bound to its isolated fixture directory", failures)
        try:
            start = datetime.fromisoformat(wrapper["started_at_utc"])
            end = datetime.fromisoformat(wrapper["ended_at_utc"])
            check(0 <= (end - start).total_seconds()
                  and finite_number(process.get("elapsed_seconds"))
                  and (end - start).total_seconds() <= process["elapsed_seconds"] + 1,
                  "Focused child clock interval is inconsistent with the outer process duration", failures)
        except (KeyError, TypeError, ValueError) as error:
            failures.append(f"Focused wrapper clock receipt is incomplete: {error}")
    xml_path = "ci/ending-recovery.xml"
    xml_data = members.get(xml_path)
    xml_rows, method_assertions = [], {}
    counts = {"tests": 0, "failures": 0, "errors": 0, "skipped": 0, "assertions": 0}
    if xml_data is None:
        failures.append("Missing original focused XML")
    else:
        try:
            root = ET.fromstring(xml_data)
            cases = list(root.iter("testcase"))
            case_names = [case.get("name") for case in cases]
            check(len(cases) == 11 and len(set(case_names)) == 11 and set(case_names) == set(methods),
                  "Focused XML does not execute exactly the eleven source-derived methods", failures)
            for case in cases:
                try:
                    assertions = int(case.get("assertions", "0"))
                except (ValueError, TypeError):
                    assertions = 0
                name = case.get("name")
                check(assertions > 0, f"Focused XML method has no positive assertion count: {name}", failures)
                method_assertions[name] = assertions
                failure_nodes = list(case.iter("failure"))
                error_nodes = list(case.iter("error"))
                skipped_nodes = list(case.iter("skipped"))
                counts["failures"] += len(failure_nodes)
                counts["errors"] += len(error_nodes)
                counts["skipped"] += len(skipped_nodes)
                counts["assertions"] += assertions
                counts["tests"] += 1
                check(case.get("classname") == TEST_PATH, f"Focused XML class does not identify the selected suite: {name}", failures)
                if not (failure_nodes or error_nodes or skipped_nodes):
                    check(case.get("status") == "pass", f"Focused XML method status is not pass: {name}", failures)
                xml_rows.append({"name": name, "assertions": assertions, "status": case.get("status"),
                                 "failures": ["".join(node.itertext()) for node in failure_nodes],
                                 "errors": ["".join(node.itertext()) for node in error_nodes],
                                 "skipped": ["".join(node.itertext()) for node in skipped_nodes]})
            for suite in list(root.iter("testsuite")) + ([root] if root.tag == "testsuites" else []):
                descendants = list(suite.iter("testcase"))
                derived = {"tests": len(descendants),
                           "failures": sum(len(list(case.iter("failure"))) for case in descendants),
                           "errors": sum(len(list(case.iter("error"))) for case in descendants),
                           "skipped": sum(len(list(case.iter("skipped"))) for case in descendants)}
                for key, expected in derived.items():
                    check(int(suite.get(key, "0")) == expected,
                          f"Focused XML aggregate {key} disagrees with its actual testcase bodies", failures)
            check(not any(counts[key] for key in ("failures", "errors", "skipped")),
                  "Focused XML contains failed, errored or skipped methods", failures)
        except (ET.ParseError, ValueError) as error:
            failures.append(f"Invalid focused XML: {error}")
    log_path = "ci/focused-logs/ending-recovery.log"
    log = members.get(log_path, b"").decode("utf-8-sig", errors="replace")
    error_lines = [{"line": number, "text": line} for number, line in enumerate(log.splitlines(), 1)
                   if re.search(r"ERROR:|Unicode parsing error|Unexpected NUL character", line)]
    check(log_path in members and bool(log), "Missing original focused Godot log", failures)
    check(not error_lines, "Focused Godot log contains original script/engine error patterns", failures)
    if result:
        for key, value in counts.items():
            check(result.get(key) == value, f"Focused summary {key} disagrees with original XML")
        check(result.get("exit_code") == process.get("exit_code"), "Focused summary outer exit differs from original process")
        check(result.get("isolated_process") == wrapper, "Focused summary differs from original isolated process record")
        check(result.get("method_assertions") == method_assertions,
              "Focused summary per-method assertion counts differ from original XML")
        check(result.get("ok") is (not failures), "Focused summary Boolean differs from independently verified focused outcome")
        recorded_failures = result.get("verification_failures")
        check(isinstance(recorded_failures, list) and bool(recorded_failures) == bool(failures),
              "Focused summary verification-failure presence differs from original focused evidence")
    return {"passed": not failures, "status": "passed" if not failures else "failed",
            "failures": failures, "plan": plan, "original_result": result,
            "outer_process": process, "isolated_process": wrapper, "xml_counts": counts,
            "methods": xml_rows, "error_lines": error_lines,
            "xml_sha256": sha256(xml_data) if xml_data is not None else None,
            "log_sha256": sha256(members[log_path]) if log_path in members else None,
            "scope": FOCUSED_SCOPE}


def snapshot_observations(members, raw_outcomes, document, check, diagnostic_issues):
    """Check retained byte custody; report live observations without atomicity claims."""
    observations, semantics, semantic_failures = [], {}, []
    source_names = {"profile.json", "saves/slot_1.json", "saves/slot_2.json", "saves/autosave.json"}
    create, load = raw_outcomes.get("create", {}), raw_outcomes.get("load", {})
    for path in sorted(members):
        match = re.fullmatch(r"ci/exported-(capability|create|load)/(.+)-save-observations\.json", path)
        if not match:
            continue
        mode, prefix = match.groups()
        rows = document(path, kind=list)
        observed_sources = [row.get("source") for row in rows if isinstance(row, dict)]
        check(len(rows) == 4 and len(observed_sources) == 4 and set(observed_sources) == source_names,
              f"Live save observation receipt does not list the exact four source paths: {path}")
        projected_rows = []
        for row in rows:
            if not isinstance(row, dict):
                continue
            copied = dict(row)
            check(row.get("status") in ("copied", "missing", "error"), f"Unknown live save observation status: {path}")
            if row.get("status") == "copied":
                filename = prefix + "-" + str(row.get("source")).replace("/", "-")
                retained_path = f"ci/exported-{mode}/" + filename
                data = members.get(retained_path)
                check(row.get("file") == filename and data is not None and len(data) == row.get("bytes")
                      and sha256(data) == row.get("sha256"), f"Live save copy does not match its original byte receipt: {retained_path}")
                copied["retained_path"] = retained_path
                if mode == "load" and row.get("source") == "saves/slot_1.json" and create.get("source_slot_sha256"):
                    copied["source_slot_bytes_unchanged"] = sha256(data or b"") == create["source_slot_sha256"]
                    if not copied["source_slot_bytes_unchanged"]:
                        diagnostic_issues.append(f"Observed source slot differs from Create bytes at {retained_path}")
            projected_rows.append(copied)
        observations.append({"path": path, "mode": mode, "capture": prefix, "files": projected_rows})

    def observed_json(path):
        if path not in members:
            return None
        try:
            value = json.loads(members[path].decode("utf-8-sig"))
            if not isinstance(value, dict):
                raise ValueError("expected a JSON object")
            return value
        except (UnicodeError, ValueError) as error:
            diagnostic_issues.append(f"Retained save/profile JSON cannot be read: {path}: {error}")
            return None

    def snapshot(path):
        value = observed_json(path)
        if value is None:
            return None
        current = value.get("current_snapshot", {})
        result = current.get("snapshot") if isinstance(current, dict) else None
        if not isinstance(result, dict):
            diagnostic_issues.append(f"Retained save has no current_snapshot.snapshot object: {path}")
            return None
        return result

    def same_value(left, right):
        # Retain type-sensitive JSON equality (True must not silently equal 1).
        return json.dumps(left, sort_keys=True, ensure_ascii=False, allow_nan=False) == json.dumps(right, sort_keys=True, ensure_ascii=False, allow_nan=False)

    source_path, restored_path = "ci/exported-create/source-slot-1.json", "ci/exported-load/restored-slot-2.json"
    source, restored = snapshot(source_path), snapshot(restored_path)
    if source_path in members:
        check(sha256(members[source_path]) == create.get("source_slot_sha256"), "Retained source slot bytes differ from the original Create receipt")
        semantics["source_slot_sha256"] = sha256(members[source_path])
    if source is not None:
        frontier = source.get("narrative_checkpoint", {}).get("reading_session", {}).get("frontier", {}).get("line_id")
        semantics["source_frontier_line_id"] = frontier
        if frontier != "line.Day4.two":
            semantic_failures.append("Retained Create source does not contain the saved Day4 closing frontier")
    if create.get("ok") is True and source is None:
        semantic_failures.append("Successful Create has no readable retained source slot")
    if source is not None and restored is not None:
        fields = ("narrative_checkpoint", "gameplay", "scene", "command_receipts",
                  "applied_effect_transaction_ids", "applied_variable_transaction_ids")
        equal_fields = {key: key in source and key in restored and same_value(source[key], restored[key]) for key in fields}
        source_life, restored_life = source.get("lifecycle", {}), restored.get("lifecycle", {})
        run_matches = bool(source_life.get("run_id")) and source_life.get("run_id") == restored_life.get("run_id")
        branch_changes = bool(source_life.get("branch_id")) and bool(restored_life.get("branch_id")) and source_life["branch_id"] != restored_life["branch_id"]
        semantics["restoration"] = {"source_slot": source_path, "restored_slot": restored_path,
                                     "equal_fields": equal_fields, "same_run": run_matches, "new_branch": branch_changes,
                                     "source_run_id": source_life.get("run_id"), "source_branch_id": source_life.get("branch_id"),
                                     "restored_branch_id": restored_life.get("branch_id"), "restored_slot_sha256": sha256(members[restored_path])}
        if not (all(equal_fields.values()) and run_matches and branch_changes):
            semantic_failures.append("Retained restored slot does not preserve original fields and run/new-branch semantics")
    elif load.get("ok") is True:
        semantic_failures.append("Successful Load has no readable source/restored slot pair")
    profile_paths = {"create_after": "ci/exported-create/profile-after.json",
                     "load_before": "ci/exported-load/profile-before-load.json",
                     "load_after_witness": "ci/exported-load/profile-after-load.json",
                     "load_final": "ci/exported-load/profile-after.json"}
    profiles = {key: observed_json(path) for key, path in profile_paths.items()}
    semantics["profile_hashes"] = {key: sha256(members[path]) for key, path in profile_paths.items() if path in members}
    if create.get("ok") is True and profiles["create_after"] is None:
        semantic_failures.append("Successful Create has no readable retained final profile")
    for key in ("create_after", "load_before"):
        path = profile_paths[key]
        if path in members:
            check(sha256(members[path]) == create.get("source_profile_sha256"), f"Retained {key} profile differs from the original Create byte receipt")
    before, after_witness = profiles["load_before"], profiles["load_after_witness"]
    if before is not None and after_witness is not None:
        unchanged = same_value(before, after_witness)
        semantics["profile_unchanged_by_load_and_witness_save"] = unchanged
        if not unchanged:
            semantic_failures.append("Retained profile changed during Load or witness Save")
    elif load.get("ok") is True:
        semantic_failures.append("Successful Load has no readable before/after witness profile pair")
    completed = snapshot("ci/exported-load/completed-autosave.json")
    final_profile = profiles["load_final"]
    if completed is not None:
        life = completed.get("lifecycle", {})
        semantics["completion"] = {"state": life.get("state"), "playback_stage": life.get("ending_plan", {}).get("playback_stage"),
                                   "run_id": life.get("run_id"), "sha256": sha256(members["ci/exported-load/completed-autosave.json"])}
        if not (life.get("state") == "COMPLETED" and life.get("ending_plan", {}).get("playback_stage") == "GALLERY_RECORDED"):
            semantic_failures.append("Retained completed autosave does not show COMPLETED/GALLERY_RECORDED")
    elif load.get("ok") is True:
        semantic_failures.append("Successful Load has no retained completed autosave")
    if source is not None and before is not None and final_profile is not None:
        run_id = source.get("lifecycle", {}).get("run_id")
        gallery_key = "ending:" + str(run_id) + ":gallery:ending.alone"
        old = before.get("gallery_transaction_receipts", {})
        new = final_profile.get("gallery_transaction_receipts", {})
        valid_maps = isinstance(old, dict) and isinstance(new, dict)
        unchanged_prior = valid_maps and all(key in new and same_value(value, new[key]) for key, value in old.items())
        exactly_one = valid_maps and len(new) == len(old) + 1 and set(new) - set(old) == {gallery_key}
        receipt_matches = valid_maps and same_value(new.get(gallery_key), {"ending_id": "ending.alone", "unlocked": True})
        unlocked = "ending.alone" in final_profile.get("gallery_unlocks", [])
        semantics["durable_gallery"] = {"transaction_key": gallery_key, "exactly_one_new_transaction": exactly_one,
                                        "prior_receipts_unchanged": unchanged_prior, "receipt_matches": receipt_matches, "ending_unlocked": unlocked}
        if not (unchanged_prior and exactly_one and receipt_matches and unlocked):
            semantic_failures.append("Retained final profile does not preserve prior receipts plus exactly one correct ending Gallery award")
    elif load.get("ok") is True:
        semantic_failures.append("Successful Load has no readable profiles for durable Gallery verification")
    diagnostic_issues.extend(semantic_failures)
    create_contradiction = create.get("ok") is True and (source is None or profiles["create_after"] is None
        or semantics.get("source_frontier_line_id") != "line.Day4.two")
    load_contradiction = load.get("ok") is True and bool(semantic_failures)
    # A failed Load may retain unfinished state even when Create passed.
    check(not create_contradiction and not load_contradiction,
          "Retained save/profile witnesses contradict an original successful stage")
    return {"status": "observed" if observations or source is not None or restored is not None else "not_observed",
            "live_save_copies": observations, "semantics": semantics, "semantic_failures": semantic_failures,
            "scope": "Copied file bytes are independently bound to manifests and capture receipts. Live failure/quiet files were read separately and are not an atomic checkpoint. Restore checks compare retained original fields; success-only completion checks use completed-autosave.json and final profile receipts. Gallery UI opening is not part of this driver.",
            "final_slot_limit": "A successful original Load executes the unchanged driver's final source-slot hash guard. There is no separate final source-slot copy on success; retained live copies prove their individual observation times only."}


def trace_timeline(records, native_events):
    rows, issues, previous = [], [], {}
    for record in records:
        data = record["data"]
        if not isinstance(data, dict):
            continue
        scene, layer = data.get("scene", {}), data.get("layer", {})
        children, ancestors = data.get("root_children", []), data.get("caption_ancestors", [])
        if not all(isinstance(value, dict) for value in (scene, layer)) or not isinstance(children, list) or not isinstance(ancestors, list):
            issues.append(f"Trace line {record['line']} has malformed node snapshots")
            continue
        if not all(isinstance(node, dict) for node in children + ancestors):
            issues.append(f"Trace line {record['line']} contains a malformed node snapshot")
            continue
        ids = [child.get("id") for child in children]
        root = ancestors[-1] if ancestors else {}
        root_id = root.get("id")
        chain = all(child.get("parent_id") == parent.get("id") for child, parent in zip(ancestors, ancestors[1:]))
        root_rows_valid = (bool(root_id) and len(ids) == len(set(ids))
                          and all(child.get("parent_id") == root_id and child.get("index_including_internal") == index
                                  for index, child in enumerate(children)))
        ancestor_roots = [node for node in ancestors if node.get("id") in ids]
        caption_root = ancestor_roots[0] if len(ancestor_roots) == 1 else {}
        caption_root_id, scene_id = caption_root.get("id"), scene.get("id")
        scene_index = ids.index(scene_id) if scene_id in ids else None
        caption_root_index = ids.index(caption_root_id) if caption_root_id in ids else None
        order = ("unresolved" if scene_index is None or caption_root_index is None else
                 "after" if scene_index > caption_root_index else "before" if scene_index < caption_root_index else "same_node")
        scene_consistent = scene_index is not None and scene.get("parent_id") == root_id and scene.get("index_including_internal") == scene_index
        caption_consistent = bool(caption_root) and caption_root.get("class") == "CanvasLayer" and caption_root.get("index_including_internal") == caption_root_index
        layer_consistent = any(node.get("id") == layer.get("id") and node.get("parent_id") == layer.get("parent_id") for node in ancestors)
        if not (chain and root_rows_valid and scene_consistent and caption_consistent and layer_consistent):
            issues.append(f"Trace line {record['line']} has unresolved or inconsistent same-snapshot node custody")
        identity = f"{data.get('pid')}:{layer.get('id')}"
        earlier = previous.get(identity)
        common_sibling_order = None
        if earlier:
            excluded = {scene_id, earlier["scene_id"]}
            common = set(ids) & set(earlier["root_ids"]) - excluded
            common_sibling_order = [i for i in ids if i in common] == [i for i in earlier["root_ids"] if i in common]
            if not (finite_number(data.get("ticks_us")) and finite_number(earlier["ticks_us"]) and data["ticks_us"] >= earlier["ticks_us"]):
                issues.append(f"Trace line {record['line']} reverses the layer's original clock order")
        for kind, update in data.get("last_accessibility_updates", {}).items():
            if not isinstance(update, dict) or not isinstance(update.get("fields"), dict):
                issues.append(f"Trace line {record['line']} has malformed natural update evidence")
                continue
            expected_node = ancestors[0].get("id") if kind == "caption_accessibility" and ancestors else data.get("canvas", {}).get("id") if kind == "canvas_accessibility" else None
            fields = update["fields"]
            if fields.get("node_id") != expected_node or not (finite_number(update.get("ticks_us")) and finite_number(data.get("ticks_us")) and update["ticks_us"] <= data["ticks_us"]):
                issues.append(f"Trace line {record['line']} natural {kind} record does not bind its observed node/clock")
        row = {"line": record["line"], "event": data.get("event"), "pid": data.get("pid"),
               "ticks_us": data.get("ticks_us"), "unix_seconds": data.get("unix_seconds"), "process_frame": data.get("process_frame"),
               "scene_id": scene_id, "scene_parent_id": scene.get("parent_id"), "scene_index": scene_index,
               "caption_root_id": caption_root_id, "caption_root_index": caption_root_index,
               "caption_root": caption_root, "scene_relative_to_caption_root": order,
               "root_ids": ids, "root_names": [child.get("name") for child in children],
               "ancestor_chain_consistent": chain, "root_child_snapshot_consistent": root_rows_valid,
               "scene_snapshot_consistent": scene_consistent, "caption_owner_snapshot_consistent": caption_consistent and layer_consistent,
               "common_other_siblings_keep_relative_order": common_sibling_order,
               "layer_id": layer.get("id"), "caption_text": data.get("caption_text"),
               "state": data.get("state"), "natural_accessibility_updates": data.get("last_accessibility_updates")}
        rows.append(row)
        previous[identity] = row
    ending_events = []
    for index, event in enumerate(native_events):
        if not isinstance(event, dict) or not isinstance(event.get("data"), dict):
            continue
        data = event["data"]
        if ("Seven-day ending" in str(data.get("name", ""))
                or data.get("purpose") in ("finish ending", "request normal shutdown", "confirm normal shutdown")
                or str(data.get("stage", "")).startswith("ending")):
            ending_events.append({"index": index, **event})
    return {"project_rows": rows, "original_native_ending_events": ending_events,
            "scope": "Trace rows stay in the original stdout order; native records stay in original events.json order. Root order is reconstructed from same-record Godot node identities. The root CanvasLayer ancestor of the caption is observed; canonical layout metadata and EndingScene's local recovery-panel visibility are not explicit trace fields.",
            "timing_limit": "Godot ticks and native driver elapsed timers have different origins. Unix/UTC wall times provide approximate context only; no cross-clock duration or provider publication causality is inferred."}, issues


def trace_observations(records, player_pid):
    issues, layers = [], {}
    for record in records:
        data = record["data"]
        if not isinstance(data, dict):
            issues.append(f"Trace line {record['line']} is not a JSON object")
            continue
        layer = data.get("layer", {})
        key = f"{data.get('pid')}:{layer.get('id') if isinstance(layer, dict) else None}"
        observed = layers.setdefault(key, {"pid": data.get("pid"), "layer": layer, "records": [], "event_counts": {}})
        observed["records"].append(record)
        event = data.get("event")
        observed["event_counts"][event] = observed["event_counts"].get(event, 0) + 1
        if data.get("schema_version") != 1 or event not in TRACE_LIMITS:
            issues.append(f"Trace line {record['line']} has an unknown schema/event")
        if player_pid is None or data.get("pid") != player_pid:
            issues.append(f"Trace line {record['line']} does not bind to the original Load player PID")
        if data.get("followup_after_us") != 2000000 or data.get("natural_update_output_limit_per_kind") != 2:
            issues.append(f"Trace line {record['line']} has unexpected sampling bounds")
        if event == "text_finished_followup":
            now, anchor = data.get("ticks_us"), data.get("text_finished_ticks_us")
            if not (finite_number(now) and finite_number(anchor) and anchor >= 0 and now - anchor >= 2000000):
                issues.append(f"Trace line {record['line']} precedes its two-second text-finished follow-up boundary")
    summaries = []
    for key, observed in layers.items():
        rows = observed["records"]
        bounded = len(rows) <= 7 and all(count <= TRACE_LIMITS.get(event, 0) for event, count in observed["event_counts"].items())
        if not bounded:
            issues.append(f"Layer {key} exceeds the frozen seven-record/per-event bounds")
        last = rows[-1]["data"]
        counters = last.get("event_counts", {})
        suppressed = {event: count - observed["event_counts"].get(event, 0) for event, count in counters.items()
                      if finite_number(count) and count > observed["event_counts"].get(event, 0)} if isinstance(counters, dict) else {}
        summaries.append({"identity": key, "record_count": len(rows), "emitted_event_counts": observed["event_counts"],
                          "within_output_bounds": bounded, "first_line": rows[0]["line"], "last_line": rows[-1]["line"],
                          "first_ticks_us": rows[0]["data"].get("ticks_us"), "last_ticks_us": last.get("ticks_us"),
                          "latest_observed_event_counters": counters, "counters_above_emitted_records": suppressed,
                          "observed_followup": observed["event_counts"].get("text_finished_followup", 0) == 1,
                          "last_observed_state": last.get("state"), "last_observed_accessibility_updates": last.get("last_accessibility_updates"),
                          "scene": last.get("scene"), "layer": last.get("layer"), "caption_text": last.get("caption_text")})
    return summaries, issues


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("receipt", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    problems, qualification_failures, journey_failures, diagnostic_issues = [], [], [], []

    def check(condition, message, group=problems):
        if not condition:
            group.append(message)

    receipt = json.loads(args.receipt.read_text(encoding="utf-8-sig"))
    candidate = receipt.get("source", receipt.get("candidate"))
    if candidate not in ATTEMPTS:
        parser.error("The download receipt source has no independently frozen attempt pins")
    attempt = ATTEMPTS[candidate]
    CANDIDATE, TREE = candidate, attempt["tree"]
    CONTROLLER, CONTROLLER_SHA256 = attempt["controller"], attempt["controller_sha256"]
    for key in ("run_id", "job_id"):
        check(attempt[key] is not None and receipt.get(key) == attempt[key], f"Download receipt run identity mismatch or unpinned: {key}")
    raw = args.archive.read_bytes()
    check(len(raw) == receipt.get("bytes"), "Original ZIP byte count differs from the external download receipt")
    check(sha256(raw) == receipt.get("sha256"), "Original ZIP SHA256 differs from the external download receipt")
    for key, value in {"candidate": CANDIDATE, "source": CANDIDATE, "tree": TREE,
                       "controller": CONTROLLER, "reference": REFERENCE, "reference_tree": REFERENCE_TREE}.items():
        if key in receipt:
            check(receipt[key] == value, f"Download receipt pin mismatch: {key}")
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        names = archive.namelist()
        check(len(names) == len(set(names)), "Duplicate ZIP member names")
        check(all(safe_name(name) for name in names), "Noncanonical or unsafe ZIP member names")
        # These are ordinary file members; CRC is checked as each original member is read.
        members = {name: archive.read(name) for name in names}
    names = set(names)

    def document(path, kind=dict, group=problems, required=True):
        if path not in members:
            if required:
                group.append(f"Missing retained JSON: {path}")
            return kind()
        try:
            data = json.loads(members[path].decode("utf-8-sig"))
            if not isinstance(data, kind):
                raise ValueError(f"expected {kind.__name__}")
            return data
        except (UnicodeError, ValueError) as error:
            group.append(f"Invalid retained JSON {path}: {error}")
            return kind()

    outer = document("ci/retained-hashes.json")
    check(names == set(outer) | {"ci/retained-hashes.json"}, "Outer manifest does not cover exact ZIP membership")
    verified_outer = 0
    for path, item in outer.items():
        data = members.get(path)
        valid = isinstance(item, dict) and data is not None and len(data) == item.get("bytes") and sha256(data) == item.get("sha256")
        check(valid, f"Outer manifest hash/size mismatch: {path}")
        verified_outer += bool(valid)
    origin = document("ci/audit-origin.json")
    for key, value in {"reference": REFERENCE, "reference_tree": REFERENCE_TREE, "reference_run": REFERENCE_RUN,
                       "candidate": CANDIDATE, "tree": TREE, "controller": CONTROLLER}.items():
        check(origin.get(key) == value, f"Archived source origin mismatch: {key}")
    source_pins, source_changes = {}, []
    for role in ("reference", "candidate"):
        prefix = f"ci/source/{role}/"
        check({p.removeprefix(prefix) for p in names if p.startswith(prefix)} == set(REFERENCE_PINS), f"Expected exactly 30 {role} source snapshots")
        for path, reference_pin in REFERENCE_PINS.items():
            data = members.get(prefix + path, b"")
            expected = attempt["candidate_overrides"].get(path, reference_pin) if role == "candidate" else reference_pin
            actual = (git_blob(data), len(data))
            check(actual == expected, f"Pinned source blob/size mismatch: {role}/{path}")
            source_pins[f"{role}/{path}"] = {"git_blob": actual[0], "bytes": actual[1], "sha256": sha256(data)}
            if role == "candidate" and data != members.get("ci/source/reference/" + path):
                source_changes.append(path)
    check(set(source_changes) == set(CHANGED_PATHS), "Retained reference/candidate sources differ outside the exact runtime/test files")
    check({p for p in names if p.startswith("ci/source/controller/")} == {CONTROLLER_PATH}, "Unexpected controller snapshot coverage")
    controller = members.get(CONTROLLER_PATH, b"")
    check(sha256(controller) == CONTROLLER_SHA256, "Archived controller does not match independently pinned bytes")
    patch = members.get("ci/order-source-delta.patch", b"").decode("utf-8-sig", errors="replace")
    diff_paths = re.findall(r"^diff --git a/(\S+) b/(\S+)$", patch, re.M)
    check(len(diff_paths) == 2 and {old for old, new in diff_paths if old == new} == set(CHANGED_PATHS), "Retained delta patch does not describe exactly the runtime/test paths")

    harness = document("ci/diagnostic-harness.json")
    expected_settings = {"reference": REFERENCE, "candidate": CANDIDATE, "controller": CONTROLLER,
                         "runner": "windows-2022", "modes": ["Capability", "Create", "Load"],
                         "outer_timeout_minutes_per_mode": 10, "step_timeout_seconds": 30, "journey_timeout_seconds": 480,
                         "renderer": "ProjectDefault", "accessibility": "Always", "audio": "Dummy",
                         "trace_sources": list(TRACE_PINS), "trace_marker": TRACE_MARKER, "passive_trace_gate": TRACE_GATE,
                         "load_flags": ["ProfileSaveLoad", "ContinueAfterQuiet", "TraceDay5", "NativeReadyCaptions"],
                         "load_environment": LOAD_ENVIRONMENT, "source_snapshot_count_per_role": 30,
                         "changed_paths": sorted(CHANGED_PATHS)}
    for key, value in expected_settings.items():
        check(harness.get(key) == value, f"Frozen harness setting mismatch: {key}")
    shared = harness.get("shared_files", {})
    check(isinstance(shared, dict) and set(shared) == set(COMMON), "Expected exactly six unchanged driver/settings hashes")
    for path in COMMON:
        data = members.get("ci/source/reference/" + path, b"")
        check(data == members.get("ci/source/candidate/" + path), f"Original driver/settings bytes changed: {path}")
        check(isinstance(shared, dict) and shared.get(path) == {"sha256": sha256(data), "git_blob": git_blob(data)}, f"Shared driver/settings hash receipt mismatch: {path}")
    unchanged_trace = harness.get("unchanged_trace_files", {})
    check(isinstance(unchanged_trace, dict) and set(unchanged_trace) == set(TRACE_PINS),
          "Expected exactly three unchanged passive trace source receipts")
    for path in TRACE_PINS:
        data = members.get("ci/source/reference/" + path, b"")
        check(data == members.get("ci/source/candidate/" + path), f"Passive trace bytes changed: {path}")
        check(isinstance(unchanged_trace, dict) and unchanged_trace.get(path) == {"sha256": sha256(data), "git_blob": git_blob(data)},
              f"Passive trace source receipt mismatch: {path}")
    driver = members.get("ci/source/candidate/" + COMMON[0], b"").decode("utf-8-sig", errors="replace")
    check(re.search(r"\[int\]\$StepTimeoutSeconds\s*=\s*30\b", driver) is not None and re.search(r"\[int\]\$JourneyTimeoutSeconds\s*=\s*480\b", driver) is not None,
          "Original driver deadline defaults are not 30/480 seconds")
    # Exact controller bytes above bind the three independent ten-minute steps and
    # absence of deadline overrides. No YAML library or PowerShell execution is needed.
    parsed = document("ci/driver-parse.json", group=qualification_failures)
    check(parsed.get("ok") is True and parsed.get("errors") == [], "Cloud external-driver parser gate failed", qualification_failures)
    deadline = document("ci/deadline-tests.json", group=qualification_failures)
    cases = deadline.get("cases", [])
    check(isinstance(cases, list) and len(cases) == 4 and {c.get("name") for c in cases if isinstance(c, dict)} == DEADLINE_CASES
          and all(isinstance(c, dict) and c.get("ok") is True for c in cases) and deadline.get("ok") is True,
          "Cloud original-deadline evidence does not pass exactly the four expected cases", qualification_failures)
    import_log = members.get("ci/import.log", b"").decode("utf-8-sig", errors="replace")
    import_errors = re.findall(r"^.*(?:SCRIPT ERROR:|ERROR: Failed to load|Unicode parsing error|Unexpected NUL character).*$", import_log, re.M)
    check("Godot Engine v4.6.3.stable.official.7d41c59c4" in import_log and not import_errors,
          "Cloud Godot 4.6.3 import evidence is missing or contains the original script-error patterns", qualification_failures)
    focused = focused_observations(members, document, check, CANDIDATE, problems)
    check(harness.get("focused_suite") == focused["plan"], "Harness focused plan differs from its original plan")
    package = document("ci/windows-export/validation.json", required=False)
    if package:
        check(package.get("commit") == CANDIDATE, "Export validation source pin mismatch")
        check(package.get("ok") is True and package.get("engine") == "4.6.3.stable" and package.get("architecture") == "x86_64"
              and package.get("templates_sha256") == TEMPLATES_SHA256 and package.get("smoke", {}).get("ok") is True
              and package.get("pack_audit", {}).get("ok") is True, "Cloud export/package validation failed", qualification_failures)
    package_files = {item.get("path"): item for item in package.get("files", []) if isinstance(item, dict)}
    package_archive = package.get("archive", {})
    if package:
        check(re.fullmatch(r"[a-f0-9]{64}", str(package_archive.get("sha256"))) is not None and isinstance(package_archive.get("bytes"), int)
              and package_archive.get("bytes", 0) > 0, "Exported package hash/size receipt missing", qualification_failures)
        check(package_files.get("DWM.exe", {}).get("sha256") == ENGINE_EXE_SHA256, "Exported standard Godot executable hash changed")
    elif focused["passed"]:
        qualification_failures.append("Focused suite passed but no original export result was retained")

    outcomes, raw_outcomes, raw_events, verified_inner, mode_members, unexecuted_modes = {}, {}, {}, 0, {}, []
    for mode in MODES:
        folder = f"ci/exported-{mode}/"
        direct_files = {path.removeprefix(folder) for path in names if path.startswith(folder) and "/" not in path.removeprefix(folder)}
        if direct_files:
            inner = document(folder + "manifest.json", kind=list)
            rows = [row for row in inner if isinstance(row, dict)]
            listed = [row.get("file") for row in rows]
            check(len(rows) == len(inner) and len(listed) == len(set(listed)) and set(listed) == direct_files - {"manifest.json"},
                  f"Mode manifest does not cover exact top-level output membership: {mode}")
            for item in rows:
                path = item.get("file")
                data = members.get(folder + path) if isinstance(path, str) else None
                valid = isinstance(path, str) and safe_name(path) and "/" not in path and data is not None and len(data) == item.get("bytes") and sha256(data) == item.get("sha256")
                check(valid, f"Mode manifest hash/size mismatch: {mode}/{path}")
                verified_inner += bool(valid)
            mode_members[mode] = len(rows)
        result_path, process_path = folder + "result.json", f"ci/{mode}-process.json"
        result = document(result_path, required=False)
        process = document(process_path, required=False)
        raw_outcomes[mode] = result
        executed = bool(result or process or direct_files)
        if executed and not result:
            journey_failures.append(f"Missing original {mode} player result")
        if executed and not process:
            journey_failures.append(f"Missing original {mode} driver process result")
        if not executed:
            unexecuted_modes.append(mode)
        if result:
            for key, value in {"mode": mode.title(), "source_commit": CANDIDATE, "archive_sha256": package_archive.get("sha256"),
                               "accessibility_request": "Always", "audio_request": "Dummy", "renderer_request": "ProjectDefault",
                               "save_load_profile": mode == "load", "checkpoint_profile": mode == "load",
                               "executable_sha256": package_files.get("DWM.exe", {}).get("sha256"),
                               "pck_sha256": package_files.get("DWM.pck", {}).get("sha256")}.items():
                check(result.get(key) == value, f"Original {mode} source/package/settings mismatch: {key}")
        if process:
            check(process.get("mode") == mode.title() and process.get("expected_source") == CANDIDATE
                  and process.get("unchanged_result") == ".godot/" + result_path,
                  f"Original {mode} driver process source/result binding mismatch")
        raw_pass = result.get("ok") is True and result.get("clean_player_exit") is True and result.get("forced_cleanup") is False and result.get("exit_code") == 0
        process_pass = process.get("exit_code") == 0
        if executed:
            check(raw_pass and process_pass, f"Original {mode} gate failed (player={result.get('exit_code')}, driver={process.get('exit_code')}): {result.get('failure')}", journey_failures)
        required_native_files = [folder + "events.json"] if result else []
        if result.get("process") or result.get("ok") is True:
            required_native_files.extend([folder + "game.stdout.log", folder + "game.stderr.log"])
        missing_native_files = [path for path in required_native_files if path not in names]
        check(not missing_native_files,
              f"Original {mode} launched/result evidence is incomplete: {missing_native_files}", qualification_failures)
        events = document(folder + "events.json", kind=list, required=False)
        raw_events[mode] = events
        capture_receipts = []
        for event in events:
            if not isinstance(event, dict) or event.get("kind") != "capture" or not isinstance(event.get("data"), dict):
                continue
            data = event["data"]
            filename = data.get("file")
            captured = members.get(folder + filename) if isinstance(filename, str) else None
            check(isinstance(filename, str) and safe_name(filename) and "/" not in filename and captured is not None
                  and sha256(captured) == data.get("sha256"), f"Original {mode} screenshot differs from its capture receipt: {filename}")
            capture_receipts.append({"utc": event.get("utc"), **data})
        wait_events = [event for event in events if isinstance(event, dict) and event.get("kind") in
                       ("wait-deadline-expired", "native-caption-wait-start", "native-caption-wait-end")]
        for event in wait_events:
            if event.get("kind") == "native-caption-wait-start":
                check(event.get("data", {}).get("deadline_seconds") == 30, f"Original {mode} caption wait used another deadline", qualification_failures)
        mode_status = ("not_executed" if not executed else "incomplete_evidence" if not result or not process or missing_native_files
                       else "passed" if raw_pass and process_pass else "failed")
        outcomes[mode] = {"status": mode_status, "executed": executed, "result_path": result_path, "result": result, "driver_process": process,
                          "raw_player_gate_passed": raw_pass, "driver_process_passed": process_pass,
                          "required_original_files": required_native_files, "missing_original_files": missing_native_files,
                          "original_wait_events": wait_events, "capture_receipts": capture_receipts}
    if raw_outcomes["create"].get("capability"):
        check(raw_outcomes["create"]["capability"] == raw_outcomes["capability"],
              "Create's prerequisite receipt differs from the original Capability result")
    create_result, load_result = raw_outcomes["create"], raw_outcomes["load"]
    if create_result.get("process") and load_result.get("process"):
        check(create_result.get("user_root", "").lower() == load_result.get("user_root", "").lower(),
              "Original Create/Load results do not bind the same persistent user root")
        check((create_result["process"].get("pid"), create_result["process"].get("started_utc")) !=
              (load_result["process"].get("pid"), load_result["process"].get("started_utc")),
              "Original Create and Load do not identify distinct player processes")
    snapshots = snapshot_observations(members, raw_outcomes, document, check, diagnostic_issues)
    acceptance = document("ci/diagnostic-acceptance.json")
    acceptance_rows = acceptance.get("original_outcomes", [])
    check(isinstance(acceptance_rows, list) and len(acceptance_rows) == len([r for r in raw_outcomes.values() if r]), "Final gate summary does not cover the retained raw outcomes")
    summary_modes = []
    for row in acceptance_rows if isinstance(acceptance_rows, list) else []:
        if not isinstance(row, dict):
            problems.append("Invalid original outcome in final gate summary")
            continue
        mode = row.get("mode")
        summary_modes.append(mode)
        original = raw_outcomes.get(mode, {})
        check(bool(original) and row.get("result") == f".godot/ci/exported-{mode}/result.json"
              and all(row.get(key) == original.get(key) for key in ("ok", "exit_code", "clean_player_exit", "forced_cleanup")),
              f"Final gate summary differs from original player result: {mode}")
    check(len(summary_modes) == len(set(summary_modes)), "Duplicate raw-mode summaries in final gate")
    failures = acceptance.get("failures")
    check(isinstance(failures, list) and acceptance.get("ok") is (not failures), "Final acceptance Boolean differs from its retained failures")
    check(not (journey_failures or unexecuted_modes or not focused["passed"])
          or (acceptance.get("ok") is False and bool(failures)), "Final gate erased a failed or unexecuted required gate")
    if isinstance(failures, list) and package and "Diagnostic executable package retention failed" in failures:
        qualification_failures.append("Original final gate reports executable package retention failure")
    status = members.get("ci/final-status.txt", b"").decode("utf-8-sig", errors="replace")
    check("ci/final-status.txt" in names, "Missing final tracked-source status", qualification_failures)
    allowed = {".claude/skills/godot-prompter/1.10.0", ".claude/skills/superpowers/6.1.1"}
    tracked, generated = [], []
    for line in status.splitlines():
        if not line:
            continue
        (generated if line.startswith("?? ") else tracked).append(line)
        check(line.startswith("?? ") or (line[:2] in ("D ", " D") and line[3:] in allowed),
              f"Unexpected tracked source mutation after execution: {line}", qualification_failures)

    primary_path = "ci/exported-load/game.stdout.log"
    primary = members.get(primary_path, b"")
    publication, profiles, parse_errors, malformed = parse_primary(primary)
    projected = document("ci/ending-publication-trace.json")
    projection_values = {"candidate": CANDIDATE, "reference": REFERENCE, "primary_stream": "exported-load/game.stdout.log",
                         "passive_trace_gate": TRACE_GATE, "publication_records": publication, "profile_records": profiles,
                         "parse_errors": parse_errors, "publication_record_count": len(publication), "profile_record_count": len(profiles)}
    if primary_path in names:
        projection_values.update(primary_stream_bytes=len(primary), primary_stream_sha256=sha256(primary))
    for key, value in projection_values.items():
        check(projected.get(key) == value, f"Derived trace summary differs from original primary stdout: {key}")
    if parse_errors or malformed:
        diagnostic_issues.append("Primary stdout contains malformed trace/profile records; original text is retained")
    layer_observations, trace_issues = trace_observations(publication, raw_outcomes.get("load", {}).get("process", {}).get("pid"))
    diagnostic_issues.extend(trace_issues)
    timeline, timeline_issues = trace_timeline(publication, raw_events.get("load", []))
    diagnostic_issues.extend(timeline_issues)
    report = {
        "archive_verified": not problems, "harness_qualified": not qualification_failures,
        "focused_suite_passed": focused["passed"],
        "original_journey_passed": all(row["status"] == "passed" for row in outcomes.values()),
        "original_acceptance_passed": acceptance.get("ok") is True,
        "problems": problems, "qualification_failures": qualification_failures, "journey_failures": journey_failures,
        "native_modes_not_executed": unexecuted_modes, "focused_suite": focused,
        "diagnostic_observation_issues": diagnostic_issues,
        "archive": {"receipt": receipt, "observed_bytes": len(raw), "observed_sha256": sha256(raw)},
        "origin": origin, "independent_attempt_pins": attempt, "verified_outer_members": verified_outer, "verified_mode_members": verified_inner,
        "mode_member_counts": mode_members, "source_pins": source_pins, "retained_source_changes": source_changes,
        "controller_sha256": sha256(controller), "harness": harness,
        "cloud_checks": {"driver_parse": parsed, "original_deadline_cases": deadline, "import_error_lines": import_errors,
                         "import_native_exit": "Enforced by the pinned controller; no separate native exit receipt is included in this archive."},
        "package": {"status": "passed" if package.get("ok") is True else "failed" if package else "not_executed_or_no_result",
                    "validation": package, "custody_scope": "When export ran, validation and all mode hashes bind one source/package. Executable ZIP bytes are retained as a separate Actions artifact and are absent from this evidence ZIP."},
        "outcomes": outcomes, "original_acceptance": acceptance, "source_status": {"tracked": tracked, "untracked": generated},
        "save_snapshot_custody": snapshots,
        "diagnostic_observations": {
            "primary_stream": primary_path, "primary_stream_present": primary_path in names,
            "primary_stream_bytes": len(primary), "primary_stream_sha256": sha256(primary) if primary_path in names else None,
            "publication_record_count": len(publication), "profile_record_count": len(profiles), "layers": layer_observations,
            "ending_order_timeline": timeline,
            "publication_records": publication, "profile_records": profiles, "parse_errors": parse_errors, "malformed_trace_lines": malformed,
            "scope": "One canonical Load stdout only. No secondary stream is counted and no nested profile totals are added together.",
            "sampling": "At most seven records per layer: two natural notifications per kind, one text-start, one text-finish and one follow-up. Natural notifications remain eligible after follow-up. Missing/capped records do not prove absence of later events.",
            "identity_limit": "Godot window IDs, object IDs and accessibility RIDs are internal. No mapping to HWND or UIA RuntimeId is established by these records.",
            "interpretation_limit": "Game-side accessibility setter records show executed calls, not successful publication of a complete native provider subtree. The passive trace does not qualify original player gates or a fresh performance comparison."
        },
        "source_scope": "All 30 retained reference and candidate sources are independently pinned. Full repository ancestry/tree identity additionally relies on the externally reviewed commit pins and the pinned controller's checkout guards; this ZIP is not a complete Git object database.",
        "verifier_exit_scope": "Exit status qualifies archive/source custody, retained harness checks and the focused suite. Original native journey failure, unexecuted native modes and diagnostic observations remain separate; exit 0 does not mean native acceptance."
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    summary = {key: report[key] for key in ("archive_verified", "harness_qualified", "focused_suite_passed", "original_journey_passed", "original_acceptance_passed",
                                            "problems", "qualification_failures", "journey_failures", "diagnostic_observation_issues",
                                            "native_modes_not_executed", "verified_outer_members", "verified_mode_members", "mode_member_counts", "retained_source_changes")}
    summary["focused"] = {"xml_counts": focused["xml_counts"], "failures": focused["failures"], "error_lines": focused["error_lines"]}
    summary["trace"] = {"primary_stream_sha256": report["diagnostic_observations"]["primary_stream_sha256"],
                        "publication_record_count": len(publication), "profile_record_count": len(profiles),
                        "layer_event_counts": {row["identity"]: row["emitted_event_counts"] for row in layer_observations}}
    summary["report"] = str(args.output.resolve())
    print(json.dumps(summary, indent=2))
    return 0 if not problems and not qualification_failures and focused["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
