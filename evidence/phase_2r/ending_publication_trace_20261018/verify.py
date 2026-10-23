"""Independently verify the frozen ending-trace evidence, without executing Godot or PowerShell.

Usage: python ending-trace-verify.py ORIGINAL.zip RECEIPT.json REPORT.json
Exit 0 means archive/source custody and retained harness checks qualified. An original
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

REFERENCE = "4963a847f0a7e2da82a87f29d1a27a7b8256eae1"
REFERENCE_TREE = "588074015df4dec61b01941c4db08efd4d379911"
CANDIDATE = "337c2d43e9ff508575f772b1c1b7cf5679be8d0f"
TREE = "1e4e752bd8e532f2e731dfc483be40fcff3bd3fc"
CONTROLLER = "87c3b1303c457578ee57d9d77b7e4869153d0e78"
CONTROLLER_SHA256 = "e08b4d63eb3d6ff536229520b872bea53a30eb6843a1eb1f5d1cc4a52478c3f5"
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
# Frozen reference blobs: original 7d source index plus the two independently
# verified 4963 reconstruction overrides. No archived manifest supplies these pins.
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
    "scripts/ui/witnessed/WitnessedCaptionLayer.gd": ("22c28568d6c6ffcf5938b276327196442ca5fb1f", 78196),
    "scripts/ui/witnessed/WitnessedAccessibleCaption.gd": ("99539f8135a72ae24934a6088c3582239a30c36c", 795),
    "scripts/ui/witnessed/WitnessedSourceCanvas.gd": ("67b1a299d4d4e3f6f2076a460548f56a180f1f30", 724),
}
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
    for key, value in {"reference": REFERENCE, "reference_tree": REFERENCE_TREE, "reference_run": 39149704882,
                       "candidate": CANDIDATE, "tree": TREE, "controller": CONTROLLER}.items():
        check(origin.get(key) == value, f"Archived source origin mismatch: {key}")
    source_pins, source_changes = {}, []
    for role in ("reference", "candidate"):
        prefix = f"ci/source/{role}/"
        check({p.removeprefix(prefix) for p in names if p.startswith(prefix)} == set(REFERENCE_PINS), f"Expected exactly 28 {role} source snapshots")
        for path, reference_pin in REFERENCE_PINS.items():
            data = members.get(prefix + path, b"")
            expected = TRACE_PINS.get(path, reference_pin) if role == "candidate" else reference_pin
            actual = (git_blob(data), len(data))
            check(actual == expected, f"Pinned source blob/size mismatch: {role}/{path}")
            source_pins[f"{role}/{path}"] = {"git_blob": actual[0], "bytes": actual[1], "sha256": sha256(data)}
            if role == "candidate" and data != members.get("ci/source/reference/" + path):
                source_changes.append(path)
    check(set(source_changes) == set(TRACE_PINS), "Retained reference/candidate sources differ outside the exact three trace files")
    check({p for p in names if p.startswith("ci/source/controller/")} == {CONTROLLER_PATH}, "Unexpected controller snapshot coverage")
    controller = members.get(CONTROLLER_PATH, b"")
    check(sha256(controller) == CONTROLLER_SHA256, "Archived controller does not match independently pinned bytes")
    patch = members.get("ci/trace-source-delta.patch", b"").decode("utf-8-sig", errors="replace")
    diff_paths = re.findall(r"^diff --git a/(\S+) b/(\S+)$", patch, re.M)
    check(len(diff_paths) == 3 and {old for old, new in diff_paths if old == new} == set(TRACE_PINS), "Retained delta patch does not describe exactly the three trace paths")

    harness = document("ci/diagnostic-harness.json")
    expected_settings = {"reference": REFERENCE, "candidate": CANDIDATE, "controller": CONTROLLER,
                         "runner": "windows-2022", "modes": ["Capability", "Create", "Load"],
                         "outer_timeout_minutes_per_mode": 10, "step_timeout_seconds": 30, "journey_timeout_seconds": 480,
                         "renderer": "ProjectDefault", "accessibility": "Always", "audio": "Dummy",
                         "trace_sources": list(TRACE_PINS), "trace_marker": TRACE_MARKER, "passive_trace_gate": TRACE_GATE,
                         "load_flags": ["ProfileSaveLoad", "ContinueAfterQuiet", "TraceDay5", "NativeReadyCaptions"],
                         "load_environment": LOAD_ENVIRONMENT}
    for key, value in expected_settings.items():
        check(harness.get(key) == value, f"Frozen harness setting mismatch: {key}")
    shared = harness.get("shared_files", {})
    check(isinstance(shared, dict) and set(shared) == set(COMMON), "Expected exactly six unchanged driver/settings hashes")
    for path in COMMON:
        data = members.get("ci/source/reference/" + path, b"")
        check(data == members.get("ci/source/candidate/" + path), f"Original driver/settings bytes changed: {path}")
        check(isinstance(shared, dict) and shared.get(path) == {"sha256": sha256(data), "git_blob": git_blob(data)}, f"Shared driver/settings hash receipt mismatch: {path}")
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
    package = document("ci/windows-export/validation.json", group=qualification_failures)
    check(package.get("commit") == CANDIDATE, "Export validation source pin mismatch")
    check(package.get("ok") is True and package.get("engine") == "4.6.3.stable" and package.get("architecture") == "x86_64"
          and package.get("templates_sha256") == TEMPLATES_SHA256 and package.get("smoke", {}).get("ok") is True
          and package.get("pack_audit", {}).get("ok") is True, "Cloud export/package validation failed", qualification_failures)
    package_files = {item.get("path"): item for item in package.get("files", []) if isinstance(item, dict)}
    package_archive = package.get("archive", {})
    check(re.fullmatch(r"[a-f0-9]{64}", str(package_archive.get("sha256"))) is not None and isinstance(package_archive.get("bytes"), int)
          and package_archive.get("bytes", 0) > 0, "Exported package hash/size receipt missing", qualification_failures)
    check(package_files.get("DWM.exe", {}).get("sha256") == ENGINE_EXE_SHA256, "Exported standard Godot executable hash changed")

    outcomes, raw_outcomes, verified_inner, mode_members = {}, {}, 0, {}
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
        if not result:
            journey_failures.append(f"Missing original {mode} player result")
        if not process:
            journey_failures.append(f"Missing original {mode} driver process result")
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
        check(raw_pass and process_pass, f"Original {mode} gate failed (player={result.get('exit_code')}, driver={process.get('exit_code')}): {result.get('failure')}", journey_failures)
        events = document(folder + "events.json", kind=list, required=False)
        wait_events = [event for event in events if isinstance(event, dict) and event.get("kind") in
                       ("wait-deadline-expired", "native-caption-wait-start", "native-caption-wait-end")]
        for event in wait_events:
            if event.get("kind") == "native-caption-wait-start":
                check(event.get("data", {}).get("deadline_seconds") == 30, f"Original {mode} caption wait used another deadline", qualification_failures)
        outcomes[mode] = {"result_path": result_path, "result": result, "driver_process": process,
                          "raw_player_gate_passed": raw_pass, "driver_process_passed": process_pass,
                          "original_wait_events": wait_events}
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
    check(not journey_failures or (acceptance.get("ok") is False and bool(failures)), "Final gate erased an original player/driver failure")
    if isinstance(failures, list) and "Diagnostic executable package retention failed" in failures:
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
    report = {
        "archive_verified": not problems, "harness_qualified": not qualification_failures,
        "original_journey_passed": not journey_failures, "original_acceptance_passed": acceptance.get("ok") is True,
        "problems": problems, "qualification_failures": qualification_failures, "journey_failures": journey_failures,
        "diagnostic_observation_issues": diagnostic_issues,
        "archive": {"receipt": receipt, "observed_bytes": len(raw), "observed_sha256": sha256(raw)},
        "origin": origin, "verified_outer_members": verified_outer, "verified_mode_members": verified_inner,
        "mode_member_counts": mode_members, "source_pins": source_pins, "retained_source_changes": source_changes,
        "controller_sha256": sha256(controller), "harness": harness,
        "cloud_checks": {"driver_parse": parsed, "original_deadline_cases": deadline, "import_error_lines": import_errors,
                         "import_native_exit": "Enforced by the pinned controller; no separate native exit receipt is included in this archive."},
        "package": {"validation": package, "custody_scope": "Receipt and all mode hashes bind one source/package. Executable ZIP bytes are retained as a separate Actions artifact and are absent from this evidence ZIP."},
        "outcomes": outcomes, "original_acceptance": acceptance, "source_status": {"tracked": tracked, "untracked": generated},
        "diagnostic_observations": {
            "primary_stream": primary_path, "primary_stream_present": primary_path in names,
            "primary_stream_bytes": len(primary), "primary_stream_sha256": sha256(primary) if primary_path in names else None,
            "publication_record_count": len(publication), "profile_record_count": len(profiles), "layers": layer_observations,
            "publication_records": publication, "profile_records": profiles, "parse_errors": parse_errors, "malformed_trace_lines": malformed,
            "scope": "One canonical Load stdout only. No secondary stream is counted and no nested profile totals are added together.",
            "sampling": "At most seven records per layer: two natural notifications per kind, one text-start, one text-finish and one follow-up. Natural notifications remain eligible after follow-up. Missing/capped records do not prove absence of later events.",
            "identity_limit": "Godot window IDs, object IDs and accessibility RIDs are internal. No mapping to HWND or UIA RuntimeId is established by these records.",
            "interpretation_limit": "Game-side accessibility setter records show executed calls, not successful publication of a complete native provider subtree. The passive trace does not qualify original player gates or a fresh performance comparison."
        },
        "source_scope": "All 28 retained reference and candidate sources are independently pinned. Full repository ancestry/tree identity additionally relies on the externally reviewed commit pins and the pinned controller's checkout guards; this ZIP is not a complete Git object database.",
        "verifier_exit_scope": "Exit status qualifies archive/source custody and retained harness checks only; original journey failure and diagnostic observations are separate."
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    summary = {key: report[key] for key in ("archive_verified", "harness_qualified", "original_journey_passed", "original_acceptance_passed",
                                            "problems", "qualification_failures", "journey_failures", "diagnostic_observation_issues",
                                            "verified_outer_members", "verified_mode_members", "mode_member_counts", "retained_source_changes")}
    summary["trace"] = {"primary_stream_sha256": report["diagnostic_observations"]["primary_stream_sha256"],
                        "publication_record_count": len(publication), "profile_record_count": len(profiles),
                        "layer_event_counts": {row["identity"]: row["emitted_event_counts"] for row in layer_observations}}
    summary["report"] = str(args.output.resolve())
    print(json.dumps(summary, indent=2))
    return 0 if not problems and not qualification_failures else 1


if __name__ == "__main__":
    sys.exit(main())
