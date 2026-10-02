#!/usr/bin/env python3
"""Run the isolated, explicitly noncanonical Hospital reading cloud proof.

The production startup, Schedule-Done ingress, Pause Save, restore transaction,
physical completion and next-day route owners execute in fresh Godot processes.
This runner retains their raw evidence and independently checks the connected
observations; it never manufactures a save, gameplay receipt or caption fixture.
"""

from __future__ import annotations

import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from uuid import uuid4

import run_cloud_journeys as cloud


SCRIPT = "res://tests/integration/verify_hospital_reading_journey.gd"
MODES = ("write", "read", "forge")
EVIDENCE_DIRECTORY = "evidence/hospital-reading"
HOSPITAL_ENTRY = "hospital.faint.day3"
HOSPITAL_LINES = ("fixture.hospital.a", "fixture.hospital.b")
CAPTURES = ("hospital-partial-history.png", "hospital-saved.png", "hospital-restored-history.png",
            "hospital-restored.png", "next-solo-history.png")
STAGES = {
    "write": ("prior_solo", "prior_retired", "hospital_a", "paused_b", "pause_cancelled", "availability",
              "pause_continued", "hospital-partial-history-entered", "hospital-partial-history-closed",
              "pause_reentered", "backup_entered", "saved"),
    "read": ("loaded", "hospital-restored-history-entered", "hospital-restored-history-closed",
             "completion_input", "settled", "next_solo", "next-solo-history-entered", "next-solo-history-closed"),
    "forge": ("forge-frame", "forge-caption"),
}
PRIMARY_FILES = {
    "slot": "saves/slot_3.json",
    "autosave": "saves/autosave.json",
    "quick": "saves/quicksave.json",
    "profile": "profile.json",
}


def strict_json(raw: str) -> dict:
    def pairs(items: list[tuple[str, object]]) -> dict:
        value = {}
        for key, item in items:
            if key in value:
                raise ValueError(f"DUPLICATE_JSON_KEY: {key}")
            value[key] = item
        return value

    def invalid_constant(value: str) -> None:
        raise ValueError(f"NONFINITE_JSON_NUMBER: {value}")

    def finite_float(value: str) -> float:
        parsed = float(value)
        if not math.isfinite(parsed):
            raise ValueError(f"NONFINITE_JSON_NUMBER: {value}")
        return parsed

    value = json.loads(raw, object_pairs_hook=pairs, parse_constant=invalid_constant, parse_float=finite_float)
    if not isinstance(value, dict):
        raise ValueError("JSON_OBJECT_REQUIRED")
    return value


def file_identity(path: Path) -> dict:
    raw = path.read_bytes()
    return {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}


def canonical(value: object) -> bytes:
    """Canonical hash domain used by the fixture's integer/string request facts."""
    return json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":"), allow_nan=False).encode("utf-8")


def validate_saved_authority(document: dict) -> dict:
    """Derive Hospital authority from the raw saved Run, independently of reports."""
    snapshot = document["current_snapshot"]["snapshot"]
    checkpoint = snapshot["narrative_checkpoint"]
    reading = checkpoint["reading_session"]
    ledger = reading["ledger"]
    if snapshot["route_id"] != "hospital" or snapshot["lifecycle"]["day"] != 3 or (
        snapshot["lifecycle"]["state"] != "PLAYING"
        or snapshot["lifecycle"]["active_condition_hospital_plan"] is not None
        or snapshot["gameplay"]["pending_hospital"] is not True
        or checkpoint["entry_id"] != HOSPITAL_ENTRY or checkpoint["stage"] != "hospital"
        or type(reading["schema_version"]) is not int or reading["schema_version"] != 3 or reading["family"] != "hospital"
        or reading["boundary"] != "line"
        or set(reading) != {"schema_version", "family", "catalogue_fingerprint", "boundary", "ledger", "frontier"}
        or set(ledger) != {"session_token", "frozen_context", "entry_contexts", "captions"}
    ):
        raise RuntimeError("SAVED_SLOT_REQUIRES_DAY3_HOSPITAL_READING_FAMILY")
    route = snapshot["gameplay"]["route_context"]
    plan = snapshot["lifecycle"]["active_resolution_plan"]
    request = route["hospital_frozen_contexts_v1"]["requests"][plan["resolution_id"]]
    stages = [stage for stage in plan["stages"] if stage["stage_id"] == "hospital_if_triggered"]
    if len(stages) != 1 or stages[0]["state"] != "active" or (
        plan["source_day"] != 3 or request["context"]["day"] != 3
        or request["context"]["kind"] != "hospital" or request["route_id"] != "hospital"
        or request["timeline_id"] != "hospital.faint"
        or request["resolution_id"] != plan["resolution_id"]
        or request["resolution_issuer_receipt"] != plan["resolution_issuer_receipt"]
        or request["stage_id"] != stages[0]["transaction_id"]
    ):
        raise RuntimeError("SAVED_RUN_REQUIRES_ACTIVE_SCHEDULE_DONE_HOSPITAL_AUTHORITY")
    presentation = request["context"]["presentation"]
    fields = presentation["fields"]
    if fields["entry_id"] != HOSPITAL_ENTRY or fields["entry_role"] != "hospital" or (
        fields["day"] != 3 or fields["qualifying_cause"] != "schedule_done"
        or fields["sylvia_eligible"] is not True or fields["sylvia_witness_receipt_id"] is not None
        or fields["unfulfilled_record_ids"] != fields["accepted_record_ids"]
    ):
        raise RuntimeError("RECEIPT_PROVEN_SYLVIA_ELIGIBILITY_WITHOUT_EARLY_WITNESS_REQUIRED")
    schedule = [entry for entry in plan["committed_schedule"]["entries"] if entry["action_kind"] in ("solo", "group")]
    if not schedule or request["context"]["source_entry_ids"] != sorted(entry["schedule_entry_id"] for entry in schedule) or (
        fields["accepted_record_ids"] != sorted({entry["source_receipt_id"] for entry in schedule})
    ):
        raise RuntimeError("SAVED_HOSPITAL_MUST_BIND_COMMITTED_SCHEDULE_SOURCES")
    sources = snapshot["contacts"]["schedule_source_receipts"]
    sylvia = []
    for entry in schedule:
        source = sources[entry["source_receipt_id"]]
        if source["day"] != 3 or source["action_id"] != entry["action_id"] or source["participants"] != entry["participants"]:
            raise RuntimeError("SAVED_HOSPITAL_MUST_BIND_ACCEPTED_CONTACTS_RECEIPTS")
        if source["participants"] == ["sylvia"]:
            sylvia.append(source)
    if not sylvia:
        raise RuntimeError("SAVED_HOSPITAL_REQUIRES_REAL_SYLVIA_SCHEDULE_SOURCE")
    command_hash = hashlib.sha256(canonical(request)).hexdigest()
    completion_id = request["completion_transaction_id"]
    token = "narrative_presentation." + hashlib.sha256(canonical(completion_id + "|" + command_hash)).hexdigest()
    command = {**request, "command_sha256": command_hash, "physical_token": token}
    frame = {
        "expected_stage": "hospital", "playback_id": token + ":hospital", "role": "hospital",
        "transaction_id": completion_id + ":hospital", "presentation": presentation,
    }
    if ledger["session_token"] != completion_id or ledger["frozen_context"] != {
        "family": "hospital", "completion_transaction_id": completion_id, "entry_id": HOSPITAL_ENTRY,
    } or ledger["entry_contexts"] != {HOSPITAL_ENTRY: frame} or (
        checkpoint["frozen_context"] != frame or checkpoint["transaction_id"] != frame["transaction_id"]
    ):
        raise RuntimeError("SAVED_READING_FRAME_MUST_MATCH_INDEPENDENT_RUN_COMMAND")
    rows = ledger["captions"]
    if len(rows) != 2 or [row["beat"]["line_id"] for row in rows] != list(HOSPITAL_LINES) or any(
        row["beat"]["owning_entry_id"] != HOSPITAL_ENTRY for row in rows
    ) or len({row["publication_id"] for row in rows}) != 2 or reading["frontier"] != {
        "line_id": HOSPITAL_LINES[1], "publication_id": rows[-1]["publication_id"],
    }:
        raise RuntimeError("SAVED_HISTORY_REQUIRES_EXACT_PUBLISHED_AB_AND_STABLE_B_FRONTIER")
    return {"snapshot": snapshot, "checkpoint": checkpoint, "request": request, "command": command,
            "sylvia_sources": sylvia, "stage": stages[0]}


def copy_bytes(source_root: Path, source: Path, target_root: Path, target: Path) -> dict:
    """Keep the exact disk bytes, checking containment on both sides of the copy."""
    source = cloud.contained_path(source_root, source)
    target = cloud.contained_path(target_root, target)
    identity = file_identity(source)
    shutil.copyfile(source, target)
    if file_identity(source) != identity or file_identity(target) != identity:
        raise RuntimeError(f"RAW_EVIDENCE_COPY_MISMATCH: {source.name}")
    return {"source": str(source), "file": str(target), **identity}


def snapshot_primary(user_dir: Path, folder: Path, phase: str) -> dict:
    """Independently retain the actual primary files at each process boundary."""
    snapshot = {}
    for key, relative in PRIMARY_FILES.items():
        source = cloud.contained_path(user_dir, user_dir / relative)
        if source.exists() and not source.is_file():
            raise RuntimeError(f"PRIMARY_PATH_NOT_FILE: {relative}")
        record = {"source": str(source), "exists": source.is_file()}
        if record["exists"]:
            record.update(copy_bytes(user_dir, source, folder, folder / f"{phase}-{key}.json"))
            strict_json(Path(record["file"]).read_text(encoding="utf-8"))
        snapshot[key] = record
    cloud.write_json(folder / f"{phase}-primary-files.json", snapshot)
    return snapshot


def read_report(mode: str, evidence: Path, folder: Path, reports: dict, user_dir: Path) -> dict:
    source = cloud.contained_path(evidence, evidence / f"{mode}.json")
    report = strict_json(source.read_text(encoding="utf-8"))
    if report["mode"] != mode or type(report["schema_version"]) is not int or report["schema_version"] != 1:
        raise RuntimeError(f"REPORT_MODE_OR_SCHEMA_MISMATCH: {mode}")
    reported_dir = Path(report["user_dir"])
    if not reported_dir.is_absolute() or cloud.contained_path(user_dir.parent, reported_dir) != user_dir:
        raise RuntimeError(f"REPORT_USER_DIR_MISMATCH: {mode}")
    if type(report["process_id"]) is not int or report["process_id"] <= 0 or any(
        prior["process_id"] == report["process_id"] for prior in reports.values()
    ):
        raise RuntimeError(f"FRESH_PROCESS_REQUIRED: {mode}")
    copy_bytes(evidence, source, folder, folder / source.name)
    reports[mode] = report
    return report


def execute_mode(mode: str, godot: str, xvfb: str, repository: Path, folder: Path, env: dict, result: dict) -> None:
    log = folder / f"{mode}.log"
    argv = [
        xvfb, "-a", "-s", "-screen 0 1920x1080x24", godot,
        "--path", str(repository), "--verbose", "--rendering-method", "gl_compatibility",
        "--rendering-driver", "opengl3", "--audio-driver", "Dummy",
        "--log-file", str(log), "--script", SCRIPT, "--",
        "--phase2r-bootstrap-mode=final", "--render-evidence", "--probe-dating",
        f"--hospital-reading-mode={mode}",
    ]
    process = cloud.run_process(argv, env, repository, folder, mode)
    result["processes"][mode] = process
    failures = cloud.process_failures(process, log)
    marker = f"HOSPITAL_READING_{mode.upper().replace('-', '_')}_PASS"
    stdout = cloud.read_log(Path(process["stdout"]))
    identities = re.findall(r"^HOSPITAL_READING_PROCESS: (.+)$", stdout, re.MULTILINE)
    if len(identities) != 1:
        failures.append(f"EXACT_GODOT_PROCESS_IDENTITY_REQUIRED: {mode}")
    else:
        identity = strict_json(identities[0])
        if set(identity) != {"mode", "process_id", "user_dir"} or identity["mode"] != mode or (
            type(identity["process_id"]) is not int or identity["process_id"] <= 0
            or not Path(identity["user_dir"]).is_absolute()
        ):
            failures.append(f"INVALID_GODOT_PROCESS_IDENTITY: {mode}")
        result.setdefault("godot_process_identities", {})[mode] = identity
    count = cloud.marker_count(stdout, marker)
    result.setdefault("markers", {})[mode] = {marker: count}
    if count != 1:
        failures.append(f"REQUIRED_MARKER_COUNT: {marker} = {count}")
    for path in (Path(process["stdout"]), Path(process["stderr"]), log):
        if path.is_file() and re.search(r"HOSPITAL_READING_[A-Z0-9_]*FAIL:", cloud.read_log(path)):
            failures.append(f"HOSPITAL_READING_ASSERTION_FAILED: {path.name}")
    result["failures"].extend(failures)
    if failures:
        raise RuntimeError(f"MODE_FAILED: {mode}")


def seal_writer(repository: Path, evidence: Path, folder: Path) -> dict:
    sealed = cloud.make_directory(repository, folder / "sealed-write")
    files = {}
    for source in sorted(evidence.iterdir()):
        source = cloud.contained_path(evidence, source)
        if not source.is_file():
            raise RuntimeError(f"UNEXPECTED_WRITER_EVIDENCE_DIRECTORY: {source.name}")
        files[source.name] = copy_bytes(evidence, source, sealed, sealed / source.name)
    if not {"write.json", "transactions.jsonl", "saved-hospital-slot.json"}.issubset(files):
        raise RuntimeError("WRITE_REPORT_TRACE_AND_RAW_SLOT_REQUIRED")
    seal = {"sealed_after_mode": "write", "before_mode": "read", "root": str(sealed), "files": files}
    cloud.write_json(folder / "write-seal.json", seal)
    return seal


def validate_writer_seal(seal: dict, evidence: Path, folder: Path) -> None:
    sealed = cloud.contained_path(folder, Path(seal["root"]))
    for name, receipt in seal["files"].items():
        expected = {key: receipt[key] for key in ("bytes", "sha256")}
        retained = cloud.contained_path(sealed, sealed / name)
        source = cloud.contained_path(evidence, evidence / name)
        if file_identity(retained) != expected:
            raise RuntimeError(f"SEALED_WRITE_BYTES_CHANGED: {name}")
        if name == "transactions.jsonl":
            if not source.read_bytes().startswith(retained.read_bytes()):
                raise RuntimeError("LATER_PROCESS_CHANGED_WRITER_TRACE_PREFIX")
        elif file_identity(source) != expected:
            raise RuntimeError(f"LATER_PROCESS_CHANGED_WRITE_EVIDENCE: {name}")


def retain_partial_evidence(evidence: Path, folder: Path) -> dict:
    """Retain diagnostics even when the driver exits before its final report."""
    retained = {}
    if not evidence.exists():
        return retained
    destination = cloud.make_directory(folder, folder / "raw-evidence")
    for source in sorted(evidence.rglob("*")):
        source = cloud.contained_path(evidence, source)
        if source.is_dir():
            continue
        if not source.is_file():
            raise RuntimeError(f"EVIDENCE_PATH_NOT_REGULAR_FILE: {source}")
        relative = source.relative_to(evidence)
        target = cloud.contained_path(destination, destination / relative)
        if target.parent != destination:
            cloud.make_directory(destination, target.parent)
        retained[str(relative)] = copy_bytes(evidence, source, destination, target)
    cloud.write_json(folder / "raw-evidence-manifest.json", retained)
    return retained


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def core(observation: dict) -> dict:
    return {key: observation[key] for key in ("source", "native")}


def validate_native(native: dict, *, partial: bool) -> None:
    require(native["line_id"] == HOSPITAL_LINES[1] and type(native["total_characters"]) is int
            and native["total_characters"] > 0 and type(native["visible_characters"]) is int,
            "NATIVE_STABLE_HOSPITAL_B_REQUIRED")
    if partial:
        require(native["revealing"] is True and 0 <= native["visible_ratio"] < 1
                and 0 <= native["visible_characters"] < native["total_characters"], "LITERAL_PARTIAL_B_REQUIRED")
    else:
        require(native["revealing"] is False and native["visible_ratio"] == 1
                and (native["visible_characters"] == -1 or native["visible_characters"] >= native["total_characters"]),
                "COMPLETE_STABLE_B_REQUIRED")


def validate_input(observed: dict, expected: tuple[str, ...], source_line: str) -> None:
    require(observed["packet_type"] == "InputEventKey" and observed["source_line"] == source_line
            and observed["contacts_after"] == {}, "FRESH_PHYSICAL_INPUT_PROTOCOL_REQUIRED")
    events = observed["events"]
    require(len(events) == len(expected) * 2, "EXACT_PHYSICAL_INPUT_EVENT_COUNT_REQUIRED")
    last_frame = -1
    last_generation = -1
    for index, event in enumerate(events):
        pressed = index % 2 == 0
        require(event["key"] == expected[index // 2] and event["pressed"] is pressed
                and type(event["frame"]) is int and event["frame"] > last_frame,
                "FRESH_INPUT_DOWN_UP_NEUTRAL_FRAMES_REQUIRED")
        if pressed:
            require(isinstance(event["contacts"], dict) and len(event["contacts"]) == 1,
                    "INPUT_DOWN_REQUIRES_ONE_PHYSICAL_CONTACT")
            generation = next(iter(event["contacts"].values()))
            require(type(generation) is int and generation > last_generation, "FRESH_INPUT_CONTACT_GENERATION_REQUIRED")
            last_generation = generation
        else:
            require(event["contacts"] == {}, "INPUT_RELEASE_REQUIRES_NEUTRAL_CONTACTS")
        last_frame = event["frame"]


def validate_history_pair(stages: dict, label: str, lines: list[str]) -> None:
    entered, closed = (stages[label + suffix] for suffix in ("-entered", "-closed"))
    require(core(entered) == core(closed), f"HISTORY_MUST_PRESERVE_LITERAL_SOURCE: {label}")
    require([row["line_id"] for row in entered["source"]["history"]["captions"]] == lines,
            f"HISTORY_EXACT_PUBLISHED_LINES_REQUIRED: {label}")
    ui, released = entered["ui"], closed["ui"]
    require(ui["tree_paused"] is True and ui["history_open"] is True and ui["history_focus"] is True
            and ui["bridge_suspension"]["ok"] is True and ui["bridge_suspension"]["value"]["state"] == "Suspended"
            and bool(ui["bridge_pause_handle"]) and bool(ui["focus_owner"]), f"HISTORY_SUSPENSION_AND_FOCUS_REQUIRED: {label}")
    require(released["tree_paused"] is False and released["history_open"] is False
            and released["history_button_focus"] is True and released["bridge_pause_handle"] == {}
            and released["bridge_suspension"]["value"]["state"] == "Active", f"HISTORY_MUST_RETURN_RAIL_FOCUS: {label}")


def validate_trace(reports: dict, evidence: Path) -> None:
    entries = [strict_json(line) for line in (evidence / "transactions.jsonl").read_text(encoding="utf-8").splitlines()]
    require([(entry["mode"], entry["kind"]) for entry in entries]
            == [(mode, stage) for mode in MODES for stage in STAGES[mode]], "EXACT_CONNECTED_TRANSACTION_ORDER_REQUIRED")
    for mode in MODES:
        report = reports[mode]
        require(set(report["stages"]) == set(STAGES[mode]), f"EXACT_REPORT_STAGE_SET_REQUIRED: {mode}")
        require(strict_json((evidence / f"{mode}-catalogues.json").read_text(encoding="utf-8")) == report["catalogues"],
                f"CATALOGUE_REPORT_MISMATCH: {mode}")
        for sequence, entry in enumerate((entry for entry in entries if entry["mode"] == mode), 1):
            value = report["stages"][entry["kind"]]
            require(type(entry["sequence"]) is int and entry["sequence"] == sequence
                    and entry["process_id"] == report["process_id"] and entry["value"] == value,
                    f"STAGE_TRACE_REPORT_PROCESS_MISMATCH: {mode}/{sequence}")
            path = cloud.contained_path(evidence, evidence / f"{mode}-{entry['kind']}.json")
            require(strict_json(path.read_text(encoding="utf-8")) == value, f"RAW_STAGE_REPORT_MISMATCH: {path.name}")


def validate_connected_proof(result: dict, evidence: Path, folder: Path) -> dict:
    reports = result["reports"]
    written, restored, forged = (reports[mode] for mode in MODES)
    validate_trace(reports, evidence)
    w, r = written["stages"], restored["stages"]
    catalogue = written["catalogues"]["hospital"]
    require(catalogue["kind"] == "hospital_reading_catalogue" and catalogue["schema_version"] == 1
            and len(catalogue["entries"]) == 1 and catalogue["entries"][0]["entry_id"] == HOSPITAL_ENTRY
            and [line["line_id"] for line in catalogue["entries"][0]["lines"]] == list(HOSPITAL_LINES),
            "EXPLICIT_NONCANONICAL_DAY3_HOSPITAL_AB_CATALOGUE_REQUIRED")
    for report in reports.values():
        require(report["catalogues"]["production_content"] is False and report["fixture"]["production_content"] is False
                and report["catalogues"]["hospital"] == catalogue and report["fixture"] == written["fixture"],
                "EXACT_NONCANONICAL_FIXTURE_SCOPE_REQUIRED")
    require(written["fixture"]["days"] == {"prior_solo": 1, "empty_schedule": 2, "hospital": 3, "next_solo": 4}
            and written["fixture"]["condition"] == {"health": 0, "pressure": 10, "condition_effects_today": ["sequela"]},
            "EXPLICIT_CONDITION_AND_CALENDAR_FIXTURE_REQUIRED")
    saved_path = cloud.contained_path(evidence, evidence / "saved-hospital-slot.json")
    saved_identity = file_identity(saved_path)
    require(saved_identity == {"bytes": written["slot_bytes"], "sha256": written["slot_sha256"]}, "RAW_SAVED_SLOT_REPORT_MISMATCH")
    raw = strict_json(saved_path.read_text(encoding="utf-8"))
    authority = validate_saved_authority(raw)
    snapshot, checkpoint, command = (authority[key] for key in ("snapshot", "checkpoint", "command"))
    require(written["saved_checkpoint"] == checkpoint == w["saved"]["source"]["checkpoint"]
            and written["hospital_command"] == command == w["saved"]["source"]["command"],
            "RAW_SAVE_MUST_BIND_OBSERVED_CHECKPOINT_AND_COMMAND")
    require(checkpoint["reading_session"]["catalogue_fingerprint"] == hashlib.sha256(canonical(catalogue)).hexdigest(),
            "SAVED_SESSION_MUST_BIND_INJECTED_CATALOGUE")
    for mode in MODES:
        for boundary in ("input", "output"):
            if mode == "write" and boundary == "input":
                continue
            actual = result["primary_files"][mode][boundary]["slot"]
            require(actual["exists"] is True and {key: actual[key] for key in ("bytes", "sha256")} == saved_identity,
                    f"ACTUAL_PRIMARY_SLOT_MISMATCH: {mode}/{boundary}")
    prior, first = w["prior_solo"]["source"], w["hospital_a"]["source"]
    require(prior["lifecycle"]["day"] == 1 and [row["line_id"] for row in prior["history"]["captions"]] == ["fixture.solo.pre.a"]
            and w["prior_retired"]["day"] == 2 and w["prior_retired"]["history"]["ok"] is False
            and w["prior_retired"]["contacts"]["solo_actions"]["solo:priscilla:day1"]["state"] == "RESOLVED_ATTENDED",
            "PRIOR_SOLO_MUST_BE_OBSERVED_BEFORE_LAWFUL_RETIREMENT")
    require(first["command"] == command and first["history"]["session_id"] != prior["history"]["session_id"]
            and [row["line_id"] for row in first["history"]["captions"]] == [HOSPITAL_LINES[0]]
            and w["hospital_a"]["deferred_pair_preview"]["ok"] is True
            and w["hospital_a"]["deferred_pair_preview"]["value"]["required"] is False,
            "FRESH_HOSPITAL_A_AND_ACTUAL_ABSENT_DEFERRED_PAIR_REQUIRED")
    partial = w["paused_b"]
    transport = partial["transport"]
    validate_input(transport, ("Enter", "Escape"), HOSPITAL_LINES[0])
    require(transport["accept_admitted"] is True and transport["back_admitted"] is True
            and transport["pause_source_admission"]["ok"] is True and transport["tree_paused"] is True
            and transport["admitted_frontier"] == checkpoint["reading_session"]["frontier"]
            and strict_json((evidence / "hospital-input.json").read_text(encoding="utf-8")) == transport,
            "REAL_PARTIAL_B_PAUSE_INPUT_AND_SOURCE_ADMISSION_REQUIRED")
    source = partial["source"]
    for name in ("paused_b", "pause_cancelled", "pause_continued", "hospital-partial-history-entered",
                 "hospital-partial-history-closed", "pause_reentered", "backup_entered", "saved"):
        stage = w[name]
        require(stage["source"] == source, f"PAUSE_HISTORY_OR_SAVE_CHANGED_CANONICAL_SOURCE: {name}")
        require(all(stage["native"][key] == partial["native"][key] for key in ("line_id", "caption_id", "text", "total_characters")),
                f"PAUSE_HISTORY_OR_SAVE_CHANGED_NATIVE_IDENTITY: {name}")
        validate_native(stage["native"], partial=name not in ("backup_entered", "saved"))
    require(core(w["pause_cancelled"]) == core(partial) == core(w["pause_continued"])
            and w["availability"]["observation"] == core(partial)
            and w["availability"]["pause_source"]["ok"] is True,
            "CANCEL_CONTINUE_AND_AVAILABILITY_MUST_BE_PURE")
    require(core(w["saved"]) == core(w["backup_entered"])
            and w["saved"]["native"]["reveal_generation"] == w["pause_reentered"]["native"]["reveal_generation"] + 1
            and written["hospital_completions"] == [] and written["physical_completions"] == []
            and written["speech_admissions"] > 0, "SAVE_MUST_COMPLETE_ONLY_CURRENT_B_WITHOUT_HOSPITAL_COMPLETION")
    for name in ("paused_b", "pause_cancelled", "availability", "pause_reentered", "backup_entered", "saved"):
        ui = w[name]["ui"]
        require(ui["tree_paused"] is True and ui["pause_visible"] is True and bool(ui["bridge_pause_handle"])
                and ui["bridge_suspension"]["ok"] is True and ui["bridge_suspension"]["value"]["state"] == "Suspended",
                f"RETAINED_LITERAL_PAUSE_SUSPENSION_REQUIRED: {name}")
    require(w["pause_cancelled"]["ui"]["bridge_pause_handle"] == partial["ui"]["bridge_pause_handle"],
            "CANCEL_MUST_KEEP_EXACT_SUSPENSION_HANDLE")
    validate_history_pair(w, "hospital-partial-history", list(HOSPITAL_LINES))
    loaded = r["loaded"]
    validate_native(loaded["native"], partial=False)
    input_profile = result["primary_files"]["read"]["input"]["profile"]
    profile = strict_json(Path(input_profile["file"]).read_text(encoding="utf-8"))
    require(restored["writer_process_id"] == written["process_id"]
            and restored["saved_checkpoint"] == checkpoint == loaded["source"]["checkpoint"]
            and restored["hospital_command"] == command == loaded["source"]["command"]
            and loaded["source"]["history"] == source["history"] and loaded["source"]["profile"] == profile
            and loaded["source"]["speech_admissions"] == 0 and loaded["source"]["hospital_completions"] == []
            and loaded["source"]["physical_completions"] == [], "FRESH_LOAD_MUST_RESTORE_EXACT_B_WITHOUT_SPEECH_WITNESS_OR_COMPLETION")
    require(all(started["text"] != catalogue["entries"][0]["lines"][0]["text"] for started in loaded["text_starts_during_restore"]),
            "FRESH_RESTORE_MUST_NOT_START_A")
    validate_history_pair(r, "hospital-restored-history", list(HOSPITAL_LINES))
    require(core(r["hospital-restored-history-entered"]) == core(loaded), "RESTORED_HISTORY_MUST_BE_READ_ONLY")
    completion_input = {key: value for key, value in r["completion_input"].items() if key != "ui"}
    validate_input(completion_input, ("Enter",), HOSPITAL_LINES[1])
    require(completion_input["admitted"] is True
            and strict_json((evidence / "hospital-completion-input.json").read_text(encoding="utf-8")) == completion_input,
            "COMPLETION_REQUIRES_RETAINED_FRESH_ORDINARY_INPUT")
    settled = r["settled"]
    auto_path = evidence / "settled-hospital-autosave.json"
    auto_identity = file_identity(auto_path)
    durable = strict_json(auto_path.read_text(encoding="utf-8"))["current_snapshot"]["snapshot"]
    require(auto_identity == {"bytes": settled["autosave_bytes"], "sha256": settled["autosave_sha256"]}
            and durable == settled["durable_snapshot"] and settled["day"] == 4 and durable["lifecycle"]["day"] == 4
            and durable["contacts"] == settled["contacts"] and settled["history"]["ok"] is False
            and settled["gameplay"]["pending_hospital"] is False
            and settled["contacts"]["solo_actions"]["solo:sylvia:day3"]["state"] == "RESOLVED_MISSED",
            "ACTUAL_COMPLETION_REQUIRES_DURABLE_DAY4_SETTLEMENT_AND_RETIRED_HISTORY")
    require(len(settled["hospital_completions"]) == len(settled["physical_completions"]) == 1
            and restored["hospital_completions"] == settled["hospital_completions"]
            and restored["physical_completions"] == settled["physical_completions"], "EXACTLY_ONE_NATIVE_AND_PHYSICAL_COMPLETION_REQUIRED")
    physical = settled["physical_completions"][0]
    require(settled["hospital_completions"][0] == {"command": command, "result": physical["result"]}
            and physical == {"owner_kind": "narrative", "physical_token": command["physical_token"],
                             "command_sha256": command["command_sha256"], "completion_transaction_id": command["completion_transaction_id"],
                             "status": "completed", "result": physical["result"]}, "PHYSICAL_RECEIPT_MUST_BIND_SAVED_COMMAND")
    completed_plan = durable["lifecycle"]["active_resolution_plan"]
    hospital_stages = [stage for stage in completed_plan["stages"] if stage["stage_id"] == "hospital_if_triggered"]
    require(completed_plan["resolution_id"] == command["resolution_id"] and len(hospital_stages) == 1
            and hospital_stages[0]["state"] == "completed", "DURABLE_COORDINATOR_HOSPITAL_COMPLETION_REQUIRED")
    completion = hospital_stages[0]["receipt"]["value"]["presentation_completion_receipt"]
    require(completion["physical_completion_receipt"] == physical and completion["receipt_id"] == command["completion_transaction_id"]
            and completion["physical_token"] == command["physical_token"] and completion["command_sha256"] == command["command_sha256"],
            "DURABLE_SETTLEMENT_MUST_RETAIN_EXACT_PHYSICAL_RECEIPT")
    witnesses = durable["contacts"]["sylvia_hospital_witness_receipts"]
    require(len(witnesses) == 1 and all(witness["resolution_kind"] == "schedule_done" and witness["care_followup_day"] == 4
            and witness["source_receipt_id"] in command["context"]["presentation"]["fields"]["accepted_record_ids"]
            for witness in witnesses.values()), "ACTUAL_HOSPITAL_COMPLETION_MUST_EARN_SYLVIA_WITNESS")
    next_source = r["next_solo"]["source"]
    require(next_source["lifecycle"]["day"] == 4 and next_source["history"]["session_id"] not in
            (source["history"]["session_id"], prior["history"]["session_id"])
            and [row["line_id"] for row in next_source["history"]["captions"]] == ["fixture.next.solo.pre.a"]
            and next_source["checkpoint"]["entry_id"] == "dating.solo.priscilla.day4.pre_challenge",
            "NEXT_CANONICAL_SOLO_REQUIRES_FRESH_HISTORY_WITHOUT_HOSPITAL_ROWS")
    validate_history_pair(r, "next-solo-history", ["fixture.next.solo.pre.a"])
    require(forged["genuine_admission"] == {"ok": True} and set(forged["cases"]) == {"frame", "caption"},
            "FORGERY_PROOF_REQUIRES_GENUINE_CONTROL_AND_BOTH_NEGATIVES")
    for kind, case in forged["cases"].items():
        candidate = strict_json((evidence / f"forge-{kind}-candidate.json").read_text(encoding="utf-8"))
        expected = json.loads(json.dumps(snapshot))
        forged_checkpoint = expected["narrative_checkpoint"]
        if kind == "frame":
            forged_checkpoint["frozen_context"]["presentation"]["fields"]["sylvia_eligible"] = False
            forged_checkpoint["reading_session"]["ledger"]["entry_contexts"][HOSPITAL_ENTRY] = json.loads(json.dumps(forged_checkpoint["frozen_context"]))
        else:
            forged_checkpoint["reading_session"]["ledger"]["captions"][0]["beat"]["owning_entry_id"] = "hospital.faint.day4"
        require(candidate == expected and case["before"] == case["after"]
                and case["independent"]["ok"] is False and bool(case["independent"]["code"])
                and case["admission"]["ok"] is False and case["admission"]["code"] == "invalid_narrative_checkpoint"
                and case["before"]["text_starts"] == [] and case["before"]["speech_admissions"] == 0
                and case["before"]["hospital_completions"] == [] and case["before"]["physical_completions"] == [],
                f"FORGERY_MUST_KEEP_RUN_AUTHORITY_AND_REFUSE_WITHOUT_INSTALLATION: {kind}")
    for key in PRIMARY_FILES:
        before, after = (result["primary_files"]["forge"][boundary][key] for boundary in ("input", "output"))
        require({field: before.get(field) for field in ("exists", "bytes", "sha256")}
                == {field: after.get(field) for field in ("exists", "bytes", "sha256")}, f"FORGERY_MUTATED_PRIMARY_FILE: {key}")
    captures, failures = cloud.collect_captures(Path(__file__).resolve().parents[2], Path(result["user_dir"]), folder,
                                               {"evidence_folder": "hospital-reading", "captures": CAPTURES})
    result["captures"] = captures
    require(not failures, "HOSPITAL_CAPTURES_INVALID: " + "; ".join(failures))
    return {"saved_slot": saved_identity, "settled_autosave": auto_identity, "hospital_entry": HOSPITAL_ENTRY,
            "command_sha256": command["command_sha256"], "physical_token": command["physical_token"],
            "process_ids": {mode: reports[mode]["process_id"] for mode in MODES},
            "independent_saved_run_forgeries_refused": ["frame", "caption"], "next_solo_day": 4}


def run() -> int:
    repository = Path(__file__).resolve().parents[2]
    output = cloud.make_directory(repository, repository / ".godot/ci/hospital-reading")
    folder = cloud.make_directory(repository, output / str(uuid4()))
    isolation = cloud.make_directory(repository, repository / ".godot/phase2r_tests" / str(uuid4()))
    result = {
        "schema_version": 1,
        "fixture_scope": (
            "Explicit noncanonical Hospital A/B and Solo prose; real Schedule-Done ingress, "
            "Pause Save, fresh restore, saved-Run forgery refusal, physical completion and next-day owners."
        ),
        "started_at_utc": cloud.utc_now(), "ok": False, "failures": [], "processes": {}, "reports": {},
        "primary_files": {}, "isolation_root": str(isolation), "artifact_root": str(folder),
    }
    user_dir = None
    evidence = None
    seal = None
    try:
        if sys.platform != "linux":
            raise RuntimeError("This rendered cloud proof requires Linux with xvfb-run")
        if not (repository / "project.godot").is_file():
            raise RuntimeError("PROJECT_ROOT_INVALID")
        configured = os.environ.get("GODOT_CONSOLE_PATH", "").strip()
        godot = shutil.which(configured) if configured else None
        xvfb = shutil.which("xvfb-run")
        if godot is None or xvfb is None:
            raise RuntimeError("GODOT_CONSOLE_PATH executable and xvfb-run are required")
        result["checkout_sha"] = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=repository, text=True).strip()
        result["source_identity"] = {
            str(path.relative_to(repository)): file_identity(path)
            for path in (Path(__file__).resolve(), repository / "tools/testing/run_cloud_journeys.py",
                         repository / SCRIPT.removeprefix("res://"))
        }
        result["workflow"] = {key: os.environ.get(key, "") for key in (
            "GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT", "GITHUB_JOB", "GITHUB_SHA",
        )}
        env = os.environ.copy()
        for key, suffix in (
            ("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"),
            ("XDG_CACHE_HOME", "cache"), ("DWM_TEST_ROOT", "test-root"),
        ):
            env[key] = str(cloud.make_directory(repository, isolation / suffix))
        env.update({"LIBGL_ALWAYS_SOFTWARE": "1", "GALLIUM_DRIVER": "llvmpipe"})
        result["isolated_environment"] = {key: env[key] for key in (
            "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "DWM_TEST_ROOT",
            "LIBGL_ALWAYS_SOFTWARE", "GALLIUM_DRIVER",
        )}
        proof_log = folder / "user-dir-proof.log"
        proof = cloud.run_process([
            godot, "--headless", "--path", str(repository), "--log-file", str(proof_log),
            "--script", "res://tools/evidence/print_user_dir.gd",
        ], env, repository, folder, "user-dir-proof")
        result["processes"]["user-dir-proof"] = proof
        failures = cloud.process_failures(proof, proof_log)
        if failures:
            raise RuntimeError("USER_DIR_PROOF_FAILED: " + "; ".join(failures))
        markers = re.findall(r"^PHASE2R_USER_DIR=(.+)$", cloud.read_log(Path(proof["stdout"])), re.MULTILINE)
        if len(markers) != 1 or not Path(markers[0].strip()).is_absolute():
            raise RuntimeError("EXACT_ABSOLUTE_USER_DIR_PROOF_REQUIRED")
        user_dir = cloud.contained_path(isolation, Path(markers[0].strip()))
        cloud.contained_path(Path(env["XDG_DATA_HOME"]), user_dir)
        result["user_dir"] = str(user_dir)
        result["user_dir_strictly_contained"] = True
        evidence = cloud.contained_path(user_dir, user_dir / EVIDENCE_DIRECTORY)
        for mode in MODES:
            result["primary_files"][mode] = {"input": snapshot_primary(user_dir, folder, f"{mode}-input")}
            try:
                execute_mode(mode, godot, xvfb, repository, folder, env, result)
            finally:
                result["primary_files"][mode]["output"] = snapshot_primary(user_dir, folder, f"{mode}-output")
            report = read_report(mode, evidence, folder, result["reports"], user_dir)
            identity = result["godot_process_identities"][mode]
            require(identity["process_id"] == report["process_id"]
                    and cloud.contained_path(isolation, Path(identity["user_dir"])) == user_dir,
                    f"STDOUT_REPORT_GODOT_PROCESS_IDENTITY_MISMATCH: {mode}")
            if mode == "write":
                seal = seal_writer(repository, evidence, folder)
                result["write_seal"] = seal
        result["validation"] = validate_connected_proof(result, evidence, folder)
    except Exception as error:
        result["failures"].append(f"{type(error).__name__}: {error}")
    finally:
        if evidence is not None:
            try:
                if seal is not None:
                    validate_writer_seal(seal, evidence, folder)
                    result["write_seal_verified"] = True
            except Exception as error:
                result["failures"].append(f"WRITE_SEAL_VALIDATION_FAILED: {error}")
            try:
                result["raw_evidence"] = retain_partial_evidence(evidence, folder)
            except Exception as error:
                result["failures"].append(f"EVIDENCE_COLLECTION_FAILED: {error}")
        result["ended_at_utc"] = cloud.utc_now()
        result["ok"] = not result["failures"] and "validation" in result and result.get("write_seal_verified", False)
        cloud.write_json(folder / "result.json", result)
        cloud.write_json(output / "result.json", result)
    for failure in result["failures"]:
        print(f"HOSPITAL_READING_CLOUD_FAIL: {failure}", flush=True)
    print("HOSPITAL_READING_CLOUD_RESULT: " + json.dumps({
        "ok": result["ok"], "artifact_root": str(folder),
        "checkout_sha": result.get("checkout_sha"), "failures": result["failures"],
    }), flush=True)
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(run())
