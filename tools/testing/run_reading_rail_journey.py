#!/usr/bin/env python3
"""Prove real Solo reading and durable exact-beat witnesses across fresh processes.

Only the authored prose/catalogue is a noncanonical fixture. Startup, invitation,
Schedule, ordinary Pause/Backup Save, board outcome, History, Quick, storage and
restoration use real owners.
The original WRITE/READ proof is sealed before supplemental New Account sessions.
The common cloud harness supplies containment, watchdog and strict log checks.
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


SCRIPT = "res://tests/integration/verify_reading_rail_journey.gd"
CAPTURES = (
    "01-title.png", "02-desktop.png", "03-minesweeper.png",
    "04-pre-history.png", "05-dating-board.png", "06-post-history.png",
    "07-post-save.png", "08-restored-history.png", "09-restored-line.png",
)
PAUSE_STAGES = (
    "ordinary_pause_entered", "ordinary_pause_cancelled", "ordinary_pause_continued",
    "ordinary_pause_reentered", "ordinary_backup_previewed", "ordinary_backup_entered",
    "ordinary_pause_save_committed", "ordinary_pause_save_continued",
)
MODES = ("write", "read", "repeat", "variant", "witness-read")
NEXT_MODES = ("next-unseen", "next", "next-read")
SETTINGS_MODES = ("settings-write", "settings-read")
NEXT_CAPTURES = ("01-next-unseen.png", "02-next-board.png", "03-next-restored-board.png")
TRACE_KINDS = {
    "write": (
        "fixture_registered", *PAUSE_STAGES, "history_inspected", "pre_history",
        "automatic_board_handoff", "committed_result_then_post_prose", "quick_committed",
        "history_inspected", "reading_quick_load_cancelled", "stale_candidate_refused",
    ),
    "read": ("fresh_restore_prepared", "history_inspected", "fresh_restore_verified"),
    "repeat": ("witness_repeat_entered", "witness_repeat_verified"),
    "variant": (
        "witness_variant_refused", "witness_neutrality_verified", "witness_retry_committed",
        "history_inspected", "witness_unseen_stop_verified",
    ),
    "witness-read": ("witness_restart_verified",),
    "next-unseen": ("next_auto_off_refused", "history_inspected", "next_unseen_verified"),
    "next": ("next_challenge_verified",),
    "next-read": ("next_restart_verified",),
    "settings-write": (
        "settings_pause_entered", "settings_host_entered", "settings_quick_committed", "settings_continue_verified",
    ),
    "settings-read": ("settings_restore_prepared", "history_inspected", "settings_restore_verified"),
}


def strict_json(text: str) -> dict:
    def object_pairs(pairs: list[tuple[str, object]]) -> dict:
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"DUPLICATE_JSON_KEY: {key}")
            result[key] = value
        return result

    def invalid_constant(value: str) -> None:
        raise ValueError(f"NONFINITE_JSON_NUMBER: {value}")

    value = json.loads(text, object_pairs_hook=object_pairs, parse_constant=invalid_constant)
    if not isinstance(value, dict):
        raise ValueError("JSON_OBJECT_REQUIRED")
    return value


def validate_pause_save(written: dict, evidence: Path, folder: Path) -> dict:
    proof = written["ordinary_pause_save"]
    first = proof[PAUSE_STAGES[0]]
    source = first["source"]
    native = first["native"]
    if proof["foreign_handle_refused"] is not True:
        raise RuntimeError("REAL_BRIDGE_FOREIGN_HANDLE_REFUSAL_REQUIRED")
    if proof["slot_locator"] != "slot:3" or native["line_id"] != "fixture.solo.pre.a":
        raise RuntimeError("ORDINARY_PAUSE_SAVE_WRONG_FRONTIER_OR_SLOT")
    for stage in PAUSE_STAGES:
        observation = proof[stage]
        if observation["source"] != source:
            raise RuntimeError(f"ORDINARY_PAUSE_MUTATED_SOURCE: {stage}")
        for key in ("line_id", "caption_id", "text", "total_characters"):
            if observation["native"][key] != native[key]:
                raise RuntimeError(f"ORDINARY_PAUSE_CHANGED_NATIVE_IDENTITY: {stage}/{key}")
    for stage in PAUSE_STAGES[:5]:
        view = proof[stage]["native"]
        if view["reveal_generation"] != native["reveal_generation"] or view["revealing"] is not True or not (
            0 <= view["visible_characters"] < view["total_characters"] and 0 <= view["visible_ratio"] < 1
        ):
            raise RuntimeError(f"LITERAL_PARTIAL_REVEAL_REQUIRED: {stage}")
    if proof[PAUSE_STAGES[1]] != first or proof[PAUSE_STAGES[2]] != first:
        raise RuntimeError("CANCEL_AND_CONTINUE_MUST_RETAIN_EXACT_PARTIAL_REVEAL")
    if proof[PAUSE_STAGES[3]] != proof[PAUSE_STAGES[4]]:
        raise RuntimeError("BACKUP_FOCUS_PREVIEW_MUTATED_PARTIAL_REVEAL")
    full = proof["ordinary_backup_entered"]
    for stage in PAUSE_STAGES[5:]:
        view = proof[stage]["native"]
        if proof[stage] != full or view["reveal_generation"] != native["reveal_generation"] + 1 or view["revealing"] is not False or not (
            view["visible_ratio"] == 1 and (view["visible_characters"] == -1 or view["visible_characters"] >= view["total_characters"])
        ):
            raise RuntimeError(f"BACKUP_SAVE_AND_CONTINUE_MUST_RETAIN_FULL_SAME_LINE: {stage}")
    checkpoint = proof["saved_checkpoint"]
    session = checkpoint["reading_session"]
    captions = session["ledger"]["captions"]
    if checkpoint != source["checkpoint"] or session["frontier"]["line_id"] != native["line_id"] or (
        len(captions) != 1 or captions[0]["beat"]["line_id"] != native["line_id"]
        or len(session["ledger"]["entry_contexts"]) != 1
    ):
        raise RuntimeError("ORDINARY_PAUSE_SAVE_CHECKPOINT_MISMATCH")
    saved = cloud.contained_path(evidence, evidence / "saved-pause-slot.json")
    raw = saved.read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    if len(raw) != proof["slot_bytes"] or digest != proof["slot_sha256"]:
        raise RuntimeError("RETAINED_ORDINARY_PAUSE_SLOT_BYTES_MISMATCH")
    snapshot = strict_json(raw.decode("utf-8"))["current_snapshot"]["snapshot"]
    if snapshot["narrative_checkpoint"] != checkpoint or (
        snapshot["gameplay"]["route_context"]["active_dating_challenge"] != source["physical_record"]
    ):
        raise RuntimeError("PHYSICAL_ORDINARY_PAUSE_SLOT_SOURCE_MISMATCH")
    shutil.copyfile(saved, folder / saved.name)
    return {"bytes": len(raw), "sha256": digest, "slot_locator": proof["slot_locator"]}


def validate_trace(reports: dict, evidence: Path, modes: tuple[str, ...]) -> None:
    path = cloud.contained_path(evidence, evidence / "transactions.jsonl")
    entries = [strict_json(line) for line in path.read_text(encoding="utf-8").splitlines()]
    expected_modes = [mode for mode in modes for _ in TRACE_KINDS[mode]]
    if [entry["mode"] for entry in entries] != expected_modes:
        raise RuntimeError("EXACT_PROCESS_MODE_TRACE_REQUIRED")
    for mode in modes:
        kinds = TRACE_KINDS[mode]
        observed = [entry for entry in entries if entry["mode"] == mode]
        if [entry["kind"] for entry in observed] != list(kinds):
            raise RuntimeError(f"EXACT_TRANSACTION_TRACE_REQUIRED: {mode}")
        for sequence, entry in enumerate(observed, 1):
            if entry["sequence"] != sequence or entry["process_id"] != reports[mode]["process_id"]:
                raise RuntimeError(f"TRACE_PROCESS_OR_SEQUENCE_MISMATCH: {mode}/{sequence}")
            if entry["kind"] in PAUSE_STAGES and entry["value"] != reports["write"]["ordinary_pause_save"][entry["kind"]]:
                raise RuntimeError(f"PAUSE_TRACE_REPORT_MISMATCH: {entry['kind']}")
            if entry["kind"] in (
                "witness_repeat_verified", "witness_unseen_stop_verified", "witness_restart_verified",
                "next_unseen_verified", "next_challenge_verified", "next_restart_verified",
            ) and entry["value"] != reports[mode]:
                raise RuntimeError(f"WITNESS_TRACE_REPORT_MISMATCH: {mode}")


def file_identity(path: Path) -> dict:
    raw = path.read_bytes()
    return {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}


def seal_original_evidence(repository: Path, evidence: Path, folder: Path, captures: list[dict]) -> dict:
    sealed = cloud.make_directory(repository, folder / "sealed-write-read")
    names = ("write.json", "read.json", "saved-quick.json", "saved-pause-slot.json", "transactions.jsonl", *CAPTURES)
    files = {}
    for name in names:
        source = cloud.contained_path(evidence, evidence / name)
        destination = cloud.contained_path(sealed, sealed / name)
        identity = file_identity(source)
        shutil.copyfile(source, destination)
        if file_identity(destination) != identity:
            raise RuntimeError(f"WRITE_READ_SEAL_COPY_MISMATCH: {name}")
        files[name] = identity
    for capture in captures:
        if files[Path(capture["file"]).name] != {key: capture[key] for key in ("bytes", "sha256")}:
            raise RuntimeError("WRITE_READ_CAPTURE_SEAL_MISMATCH")
    manifest = {"sealed_after_mode": "read", "before_mode": "repeat", "root": str(sealed), "files": files}
    cloud.write_json(folder / "write-read-seal.json", manifest)
    return manifest


def validate_original_seal(seal: dict, evidence: Path, folder: Path) -> None:
    sealed = cloud.contained_path(folder, Path(seal["root"]))
    for name, identity in seal["files"].items():
        retained = cloud.contained_path(sealed, sealed / name)
        source = cloud.contained_path(evidence, evidence / name)
        if file_identity(retained) != identity:
            raise RuntimeError(f"SEALED_WRITE_READ_BYTES_CHANGED: {name}")
        if name == "transactions.jsonl":
            if not source.read_bytes().startswith(retained.read_bytes()):
                raise RuntimeError("SUPPLEMENTAL_TRACE_CHANGED_WRITE_READ_PREFIX")
        elif file_identity(source) != identity:
            raise RuntimeError(f"SUPPLEMENTAL_MODE_CHANGED_WRITE_READ_EVIDENCE: {name}")
        if name in CAPTURES:
            if file_identity(cloud.contained_path(folder, folder / "captures" / name)) != identity:
                raise RuntimeError(f"RETAINED_WRITE_READ_CAPTURE_CHANGED: {name}")
        elif name != "transactions.jsonl" and file_identity(cloud.contained_path(folder, folder / name)) != identity:
            raise RuntimeError(f"RETAINED_WRITE_READ_EVIDENCE_CHANGED: {name}")


def execute_mode(mode: str, godot: str, xvfb: str, repository: Path, folder: Path, env: dict, result: dict) -> None:
    log = folder / f"{mode}.log"
    argv = [
        xvfb, "-a", "-s", "-screen 0 1920x1080x24", godot,
        "--path", str(repository), "--verbose", "--rendering-method", "gl_compatibility",
        "--rendering-driver", "opengl3", "--audio-driver", "Dummy",
        "--log-file", str(log), "--script", SCRIPT, "--",
        "--phase2r-bootstrap-mode=final", "--render-evidence", "--probe-dating",
        f"--reading-rail-mode={mode}",
    ]
    process = cloud.run_process(argv, env, repository, folder, mode)
    result["processes"][mode] = process
    failures = cloud.process_failures(process, log)
    stdout = cloud.read_log(Path(process["stdout"]))
    marker = f"READING_RAIL_{mode.upper().replace('-', '_')}_PASS"
    if cloud.marker_count(stdout, marker) != 1:
        failures.append(f"REQUIRED_MARKER_COUNT: {marker}")
    if "READING_RAIL_FAIL:" in stdout or "READING_RAIL_FAIL:" in cloud.read_log(Path(process["stderr"])):
        failures.append("READING_RAIL_ASSERTION_FAILED")
    result["failures"].extend(failures)
    if failures:
        raise RuntimeError(f"MODE_FAILED: {mode}")


def read_report(mode: str, evidence: Path, folder: Path, reports: dict, user_dir: Path) -> dict:
    path = cloud.contained_path(evidence, evidence / f"{mode}.json")
    report = strict_json(path.read_text(encoding="utf-8"))
    if report["mode"] != mode or Path(report["user_dir"]).resolve() != user_dir:
        raise RuntimeError(f"REPORT_MODE_OR_USER_DIR_MISMATCH: {mode}")
    if not isinstance(report["process_id"], int) or report["process_id"] <= 0 or any(
        prior["process_id"] == report["process_id"] for prior in reports.values()
    ):
        raise RuntimeError(f"EVERY_MODE_REQUIRES_A_FRESH_PROCESS: {mode}")
    reports[mode] = report
    shutil.copyfile(path, folder / path.name)
    return report


def validate_witnesses(reports: dict, evidence: Path, folder: Path) -> dict:
    repeated, variant, restarted = (reports[mode] for mode in MODES[2:])
    saved_ledger = reports["write"]["saved_checkpoint"]["reading_session"]["ledger"]
    original_beat = saved_ledger["captions"][0]["beat"]
    original_session = saved_ledger["frozen_context"]["completion_transaction_id"]
    sessions = {original_session}
    for report in (repeated, variant):
        if report["prior_session_id"] != original_session or not report["current_session_id"] or report["current_session_id"] in sessions:
            raise RuntimeError("WITNESS_REQUIRES_DISTINCT_CAUSAL_SESSIONS")
        sessions.add(report["current_session_id"])
        if report["first_line_id"] != "fixture.solo.pre.a" or report["beat"]["line_id"] != report["first_line_id"]:
            raise RuntimeError("WITNESS_REQUIRES_SAME_STABLE_FIRST_LINE")
        if report["seen_after"] is not True or report["skip_result"]["ok"] is not True:
            raise RuntimeError("WITNESS_PUBLICATION_OR_SKIP_RESULT_NOT_ADMITTED")
        for key in ("profile_before_sha256", "profile_after_sha256"):
            if re.fullmatch(r"[0-9a-f]{64}", report[key]) is None:
                raise RuntimeError(f"INVALID_PROFILE_DIGEST: {report['mode']}/{key}")
        before, after = report["witnesses_before"], report["witnesses_after"]
        if not isinstance(before, dict) or not isinstance(after, dict) or any(after.get(key) != value for key, value in before.items()):
            raise RuntimeError("WITNESS_LEDGER_MUST_PRESERVE_PRIOR_CREDIT")
        if report["beat"] not in after.values():
            raise RuntimeError("EXACT_PUBLISHED_BEAT_ABSENT_FROM_WITNESS_LEDGER")
    if repeated["beat"] != original_beat or repeated["seen_before"] is not True or (
        repeated["acknowledgement_receipt"]["was_visited_before_presentation"] is not True
        or repeated["skip_result"]["value"]["advance"] is not True
        or repeated["resulting_line_id"] != "fixture.solo.pre.b"
        or repeated["witnesses_before"] != repeated["witnesses_after"]
        or original_beat not in repeated["witnesses_before"].values()
    ):
        raise RuntimeError("EXACT_REPEAT_MUST_REMAIN_SEEN_ACROSS_NEW_ACCOUNT")
    beat = variant["beat"]
    if set(beat) != set(original_beat) or any(beat[key] != original_beat[key] for key in ("beat_id", "line_id", "owning_entry_id")) or (
        set(beat["presentation_signature"]) != set(original_beat["presentation_signature"])
        or beat["presentation_signature"]["variant_id"] != original_beat["presentation_signature"]["variant_id"]
        or beat["presentation_signature"]["content_revision"] == original_beat["presentation_signature"]["content_revision"]
    ):
        raise RuntimeError("VARIANT_MUST_CHANGE_EXACT_REVISION_OF_SAME_STABLE_BEAT")
    added = {key: value for key, value in variant["witnesses_after"].items() if key not in variant["witnesses_before"]}
    if variant["witnesses_before"] != repeated["witnesses_after"] or list(added.values()) != [beat] or (
        beat in variant["witnesses_before"].values() or variant["seen_before"] is not False
        or variant["acknowledgement_receipt"]["was_visited_before_presentation"] is not False
        or variant["skip_result"]["value"]["advance"] is not False
        or variant["resulting_line_id"] != variant["first_line_id"]
    ):
        raise RuntimeError("FIRST_VARIANT_PUBLICATION_MUST_PRESERVE_UNSEEN_SKIP_BASELINE")
    failure = variant["write_failure"]
    if variant["write_faults"] != 1 or failure["ok"] is not False or not failure["code"] or failure.get("fatal", False) is not False or (
        variant["failed_profile_sha256"] != variant["profile_before_sha256"]
        or variant["profile_after_sha256"] == variant["profile_before_sha256"]
        or variant["neutrality_before_retry"] is not True
        or variant["history_after_retry_neutral"] is not True
    ):
        raise RuntimeError("RECOVERABLE_PROFILE_WRITE_FAILURE_AND_NEUTRAL_RETRY_PROOF_REQUIRED")
    profile = cloud.contained_path(evidence, evidence / "witness-profile.json")
    identity = file_identity(profile)
    if identity != {"bytes": variant["profile_bytes"], "sha256": variant["profile_sha256"]} or identity["sha256"] != variant["profile_after_sha256"]:
        raise RuntimeError("RETAINED_WITNESS_PROFILE_BYTES_MISMATCH")
    if strict_json(profile.read_text(encoding="utf-8"))["witnessed_caption_variants"] != variant["witnesses_after"]:
        raise RuntimeError("PHYSICAL_PROFILE_WITNESS_LEDGER_MISMATCH")
    if restarted["beat"] != beat or restarted["witnessed"] is not True or restarted["profile_unchanged"] is not True or (
        restarted["witnesses"] != variant["witnesses_after"]
        or {"bytes": restarted["profile_bytes"], "sha256": restarted["profile_sha256"]} != identity
    ):
        raise RuntimeError("FRESH_PROCESS_MUST_READ_EXACT_DURABLE_VARIANT_PROFILE")
    shutil.copyfile(profile, folder / profile.name)
    return {**identity, "repeat_seen": True, "same_line_new_revision_unseen": True,
            "profile_write_faults": variant["write_faults"], "fresh_process_witnessed": True}


def validate_next(reports: dict, evidence: Path, folder: Path) -> dict:
    unseen, written, restored = (reports[mode] for mode in NEXT_MODES)
    for report in (unseen, written):
        if report["replacement_confirmations"] != 1 or report["witnesses_before"] != report["witnesses_after"]:
            raise RuntimeError("NEXT_REQUIRES_REAL_NEW_ACCOUNT_AND_NO_TRAVERSAL_WITNESS_CREDIT")
        for key in ("observations", "refusal_observations") if report is unseen else ("observations",):
            observation = report[key]
            if any(observation[field] != 0 for field in (
                "text_started", "about_to_show_text", "caption_publications", "intermediate_checkpoint_admissions",
            )) or observation["speech_before"] != observation["speech_after"]:
                raise RuntimeError(f"NEXT_INTERMEDIATE_PRESENTATION_OR_FRONTIER_EXPOSURE: {report['mode']}/{key}")
    source = unseen["source_checkpoint"]["reading_session"]
    stopped = unseen["checkpoint"]["reading_session"]
    if unseen["acknowledgement_receipt"]["was_visited_before_presentation"] is not False or (
        unseen["beat"]["presentation_signature"]["content_revision"] != "fixture-next-unseen-v1"
        or unseen["auto_off_refusals"] != 1 or unseen["auto_off_matching_writes"] != 2
        or unseen["auto_enabled_after"] is not False or unseen["current_line_complete"] is not True
        or unseen["history_observations"] != 1 or source["ledger"] != stopped["ledger"]
        or source["frontier"] != stopped["frontier"] or stopped["frontier"]["line_id"] != "fixture.solo.pre.a"
        or unseen["refused_profile_sha256"] == unseen["profile_after_sha256"]
    ):
        raise RuntimeError("NEXT_UNSEEN_REQUIRES_REFUSED_AUTO_OFF_AND_EXACT_CURRENT_LINE_RETRY")
    session = written["checkpoint"]["reading_session"]
    operation = session.get("next_operation", {})
    plan = operation.get("plan", {})
    if session["schema_version"] != 2 or operation.get("schema_version") != 1 or (
        operation.get("phase") != "destination"
        or re.fullmatch(r"[0-9a-f]{64}", operation.get("operation_id", "")) is None
        or plan.get("destination") != {"kind": "completion", "caption": None}
        or plan.get("source_ledger") != written["source_checkpoint"]["reading_session"]["ledger"]
        or plan.get("source_frontier") != written["source_checkpoint"]["reading_session"]["frontier"]
        or [row["beat"]["line_id"] for row in plan.get("traversed_captions", [])] != ["fixture.solo.pre.b"]
        or session["ledger"]["captions"] != plan["source_ledger"]["captions"] + plan["traversed_captions"]
        or written["observations"]["exclusive_activations"] != 1
        or unseen["refusal_observations"]["exclusive_activations"] != 0
    ):
        raise RuntimeError("NEXT_REQUIRES_ONE_EXCLUSIVE_VERSIONED_OPERATION_WITH_EXACT_SOURCE_AND_SUFFIX")
    if written["acknowledgement_receipt"]["was_visited_before_presentation"] is not True or (
        session["boundary"] != "between_entries" or session["frontier"] != {}
        or [caption["line_id"] for caption in written["history"]["captions"]]
        != ["fixture.solo.pre.a", "fixture.solo.pre.b"]
        or written["physical_record"]["phase"] != "challenge"
        or len(session["ledger"]["entry_contexts"]) != 1
    ):
        raise RuntimeError("NEXT_MUST_REACH_EXACT_CHALLENGE_WITH_ONLY_CANONICAL_PRE_HISTORY")
    for key in ("checkpoint", "history", "physical_record", "autosave_sha256", "autosave_bytes"):
        if restored[key] != written[key]:
            raise RuntimeError(f"NEXT_FRESH_RESTORE_MISMATCH: {key}")
    if restored["speech_admissions"] != 0 or restored["profile_unchanged"] is not True or restored["next_active"] is not False:
        raise RuntimeError("NEXT_FRESH_RESTORE_MUST_NOT_REPLAY_OR_RESTART_TRANSPORT")
    autosave = cloud.contained_path(evidence, evidence / "next-autosave.json")
    identity = file_identity(autosave)
    if identity != {"bytes": written["autosave_bytes"], "sha256": written["autosave_sha256"]}:
        raise RuntimeError("NEXT_RETAINED_AUTOSAVE_BYTES_MISMATCH")
    snapshot = strict_json(autosave.read_text(encoding="utf-8"))["current_snapshot"]["snapshot"]
    if snapshot["narrative_checkpoint"] != written["checkpoint"] or (
        snapshot["gameplay"]["route_context"]["active_dating_challenge"] != written["physical_record"]
    ):
        raise RuntimeError("NEXT_PHYSICAL_AUTOSAVE_DOES_NOT_CONTAIN_PROVEN_BOUNDARY")
    shutil.copyfile(autosave, folder / autosave.name)
    return {**identity, "auto_off_refusals": unseen["auto_off_refusals"],
            "unseen_current_completed_without_advance": True, "silent_witnessed_traversal": True,
            "fresh_process_challenge_and_history": True}


def validate_challenge_layout(reports: dict, evidence: Path, folder: Path) -> dict:
    """Check painted title containment without asking Godot to remeasure text."""
    result = {}
    for mode in ("next", "next-read"):
        path = cloud.contained_path(evidence, evidence / f"layout-{mode}.json")
        observation = strict_json(path.read_text(encoding="utf-8"))
        if observation["mode"] != mode or observation["process_id"] != reports[mode]["process_id"] or (
            observation["complete"] is not True or observation["measurement_mode"] != "geometry_only"
            or observation["events_dropped"] != 0 or observation["required_visible_samples"] != 120
            or observation["visible_samples"] != {"process": 120, "post_draw": 120}
        ):
            raise RuntimeError(f"COMPLETE_PASSIVE_CHALLENGE_OBSERVATION_REQUIRED: {mode}")
        checked = {}
        for stream in ("process", "post_draw"):
            samples = [sample for sample in observation["samples"]
                       if sample["kind"] == stream and sample["challenge_visible"]]
            frame_key = "process_frame" if stream == "process" else "drawn_frame"
            frames = [sample[frame_key] for sample in samples]
            if len(samples) != 120 or frames != sorted(set(frames)):
                raise RuntimeError(f"DISTINCT_CHALLENGE_FRAME_SEQUENCE_REQUIRED: {mode}/{stream}")
            for sample in samples:
                title = sample["controls"]["ChallengeTitle"]
                rect, clip = title["rect"], title["clip"]
                if any(len(box) != 4 or any(type(v) not in (int, float) or not math.isfinite(v) for v in box)
                       or box[2] <= 0 or box[3] <= 0 for box in (rect, clip)):
                    raise RuntimeError(f"FINITE_NONEMPTY_CHALLENGE_GEOMETRY_REQUIRED: {mode}")
                contained = all(rect[axis] >= clip[axis] - 0.01
                                and rect[axis] + rect[axis + 2] <= clip[axis] + clip[axis + 2] + 0.01
                                for axis in (0, 1))
                if sample["phase"] != "challenge" or title["visible_in_tree"] is not True or not contained:
                    raise RuntimeError(f"CHALLENGE_TITLE_CLIPPED: {mode}/{stream}/{sample[frame_key]}")
            checked[stream] = {"frames": len(samples), "first_frame": frames[0], "last_frame": frames[-1],
                               "first_title_rect": samples[0]["controls"]["ChallengeTitle"]["rect"],
                               "last_title_rect": samples[-1]["controls"]["ChallengeTitle"]["rect"]}
        shutil.copyfile(path, folder / path.name)
        result[mode] = {"observation": file_identity(path), "checked": checked,
                        "title_fully_inside_clip": True}
    return result


def validate_settings_quick(reports: dict, evidence: Path, folder: Path) -> dict:
    written, restored = (reports[mode] for mode in SETTINGS_MODES)
    entered, hosted, saved, continued = (written[key] for key in ("entered", "hosted", "saved", "continued"))
    native = entered["native"]
    if hosted != entered or not (
        native["line_id"] == "fixture.solo.pre.a" and native["revealing"] is True
        and 0 <= native["visible_characters"] < native["total_characters"]
        and written["speech_admissions"] == entered["source"]["speech_admissions"] > 0
    ):
        raise RuntimeError("SETTINGS_ENTRY_MUST_RETAIN_LITERAL_PARTIAL_READING")
    full = saved["native"]
    if saved["source"] != entered["source"] or continued != saved or any(
        full[key] != native[key] for key in ("line_id", "caption_id", "text", "total_characters")
    ) or not (
        full["reveal_generation"] == native["reveal_generation"] + 1
        and full["revealing"] is False and full["visible_ratio"] == 1
        and (full["visible_characters"] == -1 or full["visible_characters"] >= full["total_characters"])
    ):
        raise RuntimeError("SETTINGS_F5_MUST_COMPLETE_ONLY_CURRENT_REVEAL")
    host = written["host_before"]
    if host != written["host_after"] or not (
        host["tree_paused"] is True and host["visible"] is True and host["entered_action"] == "settings"
        and host["selected_category"] == "reading" and host["host_id"] > 0 and host["focus_id"] > 0
        and host["focus_path"] and not host["focus_path"].startswith("..") and host["suspension"]
    ):
        raise RuntimeError("SETTINGS_F5_MUST_RETAIN_EXACT_HOST_FOCUS_AND_SUSPENSION")
    before, after = written["disk_before"], written["disk_after"]
    for state in (before, after, restored["disk_before"], restored["disk_after"]):
        if set(state) != {"quick", "autosave", "profile"}:
            raise RuntimeError("SETTINGS_EXACT_DISK_FAMILIES_REQUIRED")
        for key, identity in state.items():
            if identity["exists"] is True:
                if not isinstance(identity["bytes"], int) or identity["bytes"] <= 0 or not re.fullmatch(r"[0-9a-f]{64}", identity["sha256"]):
                    raise RuntimeError(f"SETTINGS_EXACT_DISK_IDENTITY_REQUIRED: {key}")
            elif key != "quick" or identity != {"exists": False, "sha256": "", "bytes": 0}:
                raise RuntimeError(f"SETTINGS_REQUIRED_DISK_FILE_MISSING: {key}")
    if before["quick"]["exists"] is not False or after["quick"]["exists"] is not True or any(
        before[key] != after[key] for key in ("autosave", "profile")
    ) or restored["disk_before"] != after or restored["disk_after"] != after:
        raise RuntimeError("SETTINGS_QUICK_ONLY_DISK_CHANGE_REQUIRED")
    family = {"quicksave.json", "quicksave.json.next", "quicksave.json.txn.json", "quicksave.json.bak", "quicksave.json.revision-prior"}
    candidates = []
    for sequence, receipt in enumerate(written["mutations"], 1):
        if receipt["sequence"] != sequence or receipt["owner"] != "saves" or receipt["ok"] is not True or (
            receipt["operation"] not in ("write", "flush", "rename", "remove") or receipt["path"] not in family
            or (receipt["operation"] == "rename" and receipt.get("destination") not in family)
        ):
            raise RuntimeError("SETTINGS_NON_QUICK_FILE_MUTATION")
        if receipt["operation"] == "write" and receipt["path"] == "quicksave.json.next":
            candidates.append({key: receipt[key] for key in ("bytes", "sha256")})
    quick_identity = {key: after["quick"][key] for key in ("bytes", "sha256")}
    if candidates != [quick_identity]:
        raise RuntimeError("SETTINGS_ONE_EXACT_QUICK_CANDIDATE_REQUIRED")
    checkpoint = written["saved_checkpoint"]
    session = checkpoint["reading_session"]
    if checkpoint != entered["source"]["checkpoint"] or not (
        session["frontier"]["line_id"] == native["line_id"]
        and len(session["ledger"]["captions"]) == 1 and len(session["ledger"]["entry_contexts"]) == 1
        and written["canonical_transcript"] == entered["source"]["history"]["captions"]
        and written["physical_record"] == entered["source"]["physical_record"]
    ):
        raise RuntimeError("SETTINGS_CANONICAL_SOURCE_MISMATCH")
    if any(written[key] != restored[key] for key in ("saved_checkpoint", "physical_record", "canonical_transcript", "desktop_context")) or not (
        restored["history"] == entered["source"]["history"] and restored["current_line_complete"] is True
        and restored["speech_admissions"] == 0 and restored["history_observations"] == 1
        and restored["profile_unchanged"] is True
    ):
        raise RuntimeError("SETTINGS_FRESH_EXACT_RESTORE_WITHOUT_SPEECH_REQUIRED")
    quick = cloud.contained_path(evidence, evidence / "saved-settings-quick.json")
    if file_identity(quick) != quick_identity:
        raise RuntimeError("SETTINGS_RETAINED_QUICK_BYTES_MISMATCH")
    snapshot = strict_json(quick.read_text(encoding="utf-8"))["current_snapshot"]["snapshot"]
    if snapshot["narrative_checkpoint"] != checkpoint or snapshot["route_id"] != "dating" or (
        snapshot["active_app_id"] != written["desktop_context"]["active_app_id"]
        or written["desktop_context"]["active_app_id"] != "schedule"
        or snapshot["gameplay"]["route_context"]["active_dating_challenge"] != written["physical_record"]
    ):
        raise RuntimeError("SETTINGS_TRANSIENT_HOST_ENTERED_CANONICAL_SAVE")
    validate_trace(reports, evidence, SETTINGS_MODES)
    trace = [strict_json(line) for line in (evidence / "transactions.jsonl").read_text(encoding="utf-8").splitlines()]
    expected_values = (
        entered, {"reading": hosted, "host": host},
        {"reading": saved, "host": host, "disk": after, "mutations": written["mutations"]}, written,
        {"disk": after, "speech_admissions": 0},
        {"label": "settings-restored-history", "history": restored["history"]}, restored,
    )
    if [entry["value"] for entry in trace] != list(expected_values):
        raise RuntimeError("SETTINGS_TRACE_REPORT_BINDING_MISMATCH")
    shutil.copyfile(quick, folder / quick.name)
    return {"retained_quick": quick_identity, "physical_quick_candidates": 1,
            "partial_reveal_retained_until_f5": True, "settings_and_focus_retained": True,
            "only_quick_family_mutated": True, "fresh_restore_speech_admissions": 0,
            "profile_and_autosave_unchanged": True}


def run_settings_quick(repository: Path, parent_folder: Path, godot: str, xvfb: str, original: dict) -> dict:
    folder = cloud.make_directory(repository, parent_folder / "settings-quick")
    isolation = cloud.make_directory(repository, repository / ".godot/phase2r_tests" / str(uuid4()))
    result = {"schema_version": 1, "ok": False, "failures": [], "processes": {}, "reports": {},
              "checkout_sha": original["checkout_sha"], "workflow": original["workflow"],
              "isolation_root": str(isolation), "artifact_root": str(folder), "started_at_utc": cloud.utc_now()}
    evidence: Path | None = None
    seal: dict | None = None
    try:
        env = os.environ.copy()
        for key, suffix in (("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"),
                            ("XDG_CACHE_HOME", "cache"), ("DWM_TEST_ROOT", "test-root")):
            env[key] = str(cloud.make_directory(repository, isolation / suffix))
        env.update({"LIBGL_ALWAYS_SOFTWARE": "1", "GALLIUM_DRIVER": "llvmpipe"})
        result["isolated_environment"] = {key: env[key] for key in (
            "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "DWM_TEST_ROOT")}
        proof_log = folder / "user-dir-proof.log"
        proof = cloud.run_process([godot, "--headless", "--path", str(repository), "--log-file", str(proof_log),
                                   "--script", "res://tools/evidence/print_user_dir.gd"],
                                  env, repository, folder, "user-dir-proof")
        result["processes"]["user-dir-proof"] = proof
        failures = cloud.process_failures(proof, proof_log)
        if failures:
            raise RuntimeError("SETTINGS_USER_DIR_PROOF_FAILED: " + "; ".join(failures))
        markers = re.findall(r"^PHASE2R_USER_DIR=(.+)$", cloud.read_log(Path(proof["stdout"])), re.MULTILINE)
        if len(markers) != 1 or not Path(markers[0].strip()).is_absolute():
            raise RuntimeError("SETTINGS_EXACT_USER_DIR_PROOF_REQUIRED")
        user_dir = cloud.contained_path(isolation, Path(markers[0].strip()))
        cloud.contained_path(Path(env["XDG_DATA_HOME"]), user_dir)
        if user_dir == Path(original["user_dir"]).resolve() or str(isolation) == original["isolation_root"]:
            raise RuntimeError("SETTINGS_REQUIRES_SEPARATE_ISOLATED_PROFILE")
        result["user_dir"] = str(user_dir)
        evidence = cloud.contained_path(user_dir, user_dir / "evidence/reading-rail")
        execute_mode("settings-write", godot, xvfb, repository, folder, env, result)
        read_report("settings-write", evidence, folder, result["reports"], user_dir)
        sealed = cloud.make_directory(repository, folder / "sealed-settings-write")
        names = ("settings-write.json", "saved-settings-quick.json", "transactions.jsonl")
        seal = {"sealed_after_mode": "settings-write", "before_mode": "settings-read", "root": str(sealed), "files": {}}
        for name in names:
            source = cloud.contained_path(evidence, evidence / name)
            destination = cloud.contained_path(sealed, sealed / name)
            identity = file_identity(source)
            shutil.copyfile(source, destination)
            if file_identity(destination) != identity:
                raise RuntimeError(f"SETTINGS_WRITE_SEAL_COPY_MISMATCH: {name}")
            seal["files"][name] = identity
        result["write_seal"] = seal
        cloud.write_json(folder / "settings-write-seal.json", seal)
        execute_mode("settings-read", godot, xvfb, repository, folder, env, result)
        read_report("settings-read", evidence, folder, result["reports"], user_dir)
        result["validation"] = validate_settings_quick(result["reports"], evidence, folder)
    except Exception as error:
        result["failures"].append(f"{type(error).__name__}: {error}")
    finally:
        if evidence is not None:
            try:
                if seal is not None:
                    for name, identity in seal["files"].items():
                        retained = cloud.contained_path(folder, Path(seal["root"]) / name)
                        source = cloud.contained_path(evidence, evidence / name)
                        if file_identity(retained) != identity or (
                            not source.read_bytes().startswith(retained.read_bytes()) if name == "transactions.jsonl"
                            else file_identity(source) != identity
                        ):
                            raise RuntimeError(f"SETTINGS_SEALED_WRITE_BYTES_CHANGED: {name}")
                    result["write_seal_verified"] = True
                for name in ("settings-write.json", "settings-read.json", "settings-read-observation.json", "saved-settings-quick.json", "transactions.jsonl"):
                    source = cloud.contained_path(evidence, evidence / name)
                    destination = cloud.contained_path(folder, folder / name)
                    if source.is_file() and not destination.exists():
                        shutil.copyfile(source, destination)
            except Exception as error:
                result["failures"].append(f"SETTINGS_EVIDENCE_COLLECTION_FAILED: {error}")
        result["ended_at_utc"] = cloud.utc_now()
        result["ok"] = not result["failures"] and "validation" in result and result.get("write_seal_verified", False)
        cloud.write_json(folder / "result.json", result)
    return result


def run() -> int:
    repository = Path(__file__).resolve().parents[2]
    output = cloud.make_directory(repository, repository / ".godot/ci/reading-rail")
    folder = cloud.make_directory(repository, output / str(uuid4()))
    isolation = cloud.make_directory(repository, repository / ".godot/phase2r_tests" / str(uuid4()))
    result = {
        "schema_version": 3,
        "fixture_scope": "Noncanonical English Solo Priscilla Day 1 prose and explicit revision variants; real production owners, physical saves, Profile FileOps and one-shot Next.",
        "started_at_utc": cloud.utc_now(), "ok": False, "failures": [], "processes": {},
        "isolation_root": str(isolation), "artifact_root": str(folder),
    }
    user_dir: Path | None = None
    evidence: Path | None = None
    seal: dict | None = None
    reports: dict = {}
    result["reports"] = reports
    try:
        if sys.platform != "linux":
            raise RuntimeError("This rendered proof requires Linux with xvfb-run")
        godot = shutil.which(os.environ.get("GODOT_CONSOLE_PATH", "").strip())
        xvfb = shutil.which("xvfb-run")
        if godot is None or xvfb is None:
            raise RuntimeError("GODOT_CONSOLE_PATH and xvfb-run are required")
        result["checkout_sha"] = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=repository, text=True).strip()
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
        evidence = cloud.contained_path(user_dir, user_dir / "evidence/reading-rail")
        for mode in MODES[:2]:
            execute_mode(mode, godot, xvfb, repository, folder, env, result)
            read_report(mode, evidence, folder, reports, user_dir)
        written, restored = reports["write"], reports["read"]
        if written["process_id"] == restored["process_id"]:
            raise RuntimeError("RESTORE_MUST_USE_A_FRESH_PROCESS")
        for field in ("canonical_transcript", "current_line_id", "physical_record", "quick_sha256", "quick_bytes"):
            if written[field] != restored[field]:
                raise RuntimeError(f"FRESH_RESTORE_MISMATCH: {field}")
        if restored["speech_admissions"] != 0:
            raise RuntimeError("LOAD_OR_HISTORY_REPEATED_SPEECH")
        if written["speech_admissions"] < 1:
            raise RuntimeError("SPEECH_CONTROL_NEVER_ADMITTED_A_LIVE_LINE")
        if written["history_observations"] < 2 or restored["history_observations"] < 1:
            raise RuntimeError("PRE_POST_AND_RESTORED_HISTORY_PROOF_REQUIRED")
        result["retained_pause_slot"] = validate_pause_save(written, evidence, folder)
        validate_trace(reports, evidence, MODES[:2])
        quick = cloud.contained_path(user_dir, evidence / "saved-quick.json")
        raw = quick.read_bytes()
        if len(raw) != written["quick_bytes"] or hashlib.sha256(raw).hexdigest() != written["quick_sha256"]:
            raise RuntimeError("RETAINED_QUICK_BYTES_MISMATCH")
        shutil.copyfile(quick, folder / quick.name)
        result["retained_quick"] = {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}
        captures, failures = cloud.collect_captures(repository, user_dir, folder, {
            "evidence_folder": "reading-rail", "captures": CAPTURES,
        })
        result["captures"] = captures
        result["failures"].extend(failures)
        if failures:
            raise RuntimeError("WRITE_READ_CAPTURES_REQUIRED_BEFORE_SUPPLEMENTAL_MODES")
        seal = seal_original_evidence(repository, evidence, folder, captures)
        result["write_read_seal"] = seal
        for mode in MODES[2:]:
            execute_mode(mode, godot, xvfb, repository, folder, env, result)
            read_report(mode, evidence, folder, reports, user_dir)
        validate_trace(reports, evidence, MODES)
        result["retained_witness_profile"] = validate_witnesses(reports, evidence, folder)
        for mode in NEXT_MODES:
            execute_mode(mode, godot, xvfb, repository, folder, env, result)
            read_report(mode, evidence, folder, reports, user_dir)
        validate_trace(reports, evidence, MODES + NEXT_MODES)
        result["retained_next_autosave"] = validate_next(reports, evidence, folder)
        result["challenge_layout"] = validate_challenge_layout(reports, evidence, folder)
        next_folder = cloud.make_directory(repository, folder / "next")
        captures, failures = cloud.collect_captures(repository, user_dir, next_folder, {
            "evidence_folder": "reading-rail/next", "captures": NEXT_CAPTURES,
        })
        result["next_captures"] = captures
        result["failures"].extend(failures)
        if not result["failures"]:
            result["settings_quick_save"] = run_settings_quick(repository, folder, godot, xvfb, result)
            if not result["settings_quick_save"]["ok"]:
                result["failures"].append("PAUSED_SETTINGS_QUICK_PROOF_FAILED: " + "; ".join(result["settings_quick_save"]["failures"]))
    except Exception as error:
        result["failures"].append(f"{type(error).__name__}: {error}")
    finally:
        if user_dir is not None:
            try:
                if seal is not None:
                    validate_original_seal(seal, evidence, folder)
                    actual_captures = {path.name for path in evidence.glob("*.png")}
                    if actual_captures != set(CAPTURES):
                        raise RuntimeError("SUPPLEMENTAL_MODE_CHANGED_ORIGINAL_CAPTURE_SET")
                    result["write_read_seal_verified"] = True
                elif "captures" not in result:
                    captures, failures = cloud.collect_captures(repository, user_dir, folder, {
                        "evidence_folder": "reading-rail", "captures": CAPTURES,
                    })
                    result["captures"] = captures
                    result["failures"].extend(failures)
            except Exception as error:
                result["failures"].append(f"EVIDENCE_COLLECTION_FAILED: {error}")
            if any(mode in result["processes"] for mode in NEXT_MODES) and "next_captures" not in result:
                try:
                    next_folder = cloud.make_directory(repository, folder / "next")
                    captures, failures = cloud.collect_captures(repository, user_dir, next_folder, {
                        "evidence_folder": "reading-rail/next", "captures": NEXT_CAPTURES,
                    })
                    result["next_captures"] = captures
                    result["failures"].extend(failures)
                except Exception as error:
                    result["failures"].append(f"NEXT_EVIDENCE_COLLECTION_FAILED: {error}")
            try:
                # Retain partial failure evidence too, without overwriting sealed files.
                source_root = cloud.contained_path(user_dir, user_dir / "evidence/reading-rail")
                for name in (
                    "transactions.jsonl", "witness-profile.json", "next-autosave.json",
                    "layout-next.json", "layout-next-read.json",
                    "layout-next-minimums.json", "layout-next-read-minimums.json",
                    *(f"{mode}.json" for mode in MODES + NEXT_MODES),
                ):
                    source = cloud.contained_path(source_root, source_root / name)
                    destination = cloud.contained_path(folder, folder / name)
                    if source.is_file() and not destination.exists():
                        shutil.copyfile(source, destination)
            except Exception as error:
                result["failures"].append(f"REPORT_OR_TRACE_COLLECTION_FAILED: {error}")
        result["ended_at_utc"] = cloud.utc_now()
        result["ok"] = not result["failures"]
        cloud.write_json(folder / "result.json", result)
        cloud.write_json(output / "result.json", result)
    for failure in result["failures"]:
        print(f"READING_RAIL_CLOUD_FAIL: {failure}", flush=True)
    print("READING_RAIL_CLOUD_RESULT: " + json.dumps({
        "ok": result["ok"], "artifact_root": str(folder),
        "checkout_sha": result.get("checkout_sha"), "failures": result["failures"],
    }), flush=True)
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(run())
