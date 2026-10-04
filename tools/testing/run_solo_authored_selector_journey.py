#!/usr/bin/env python3
"""Prove authored selector Save/Load with real owners in two fresh cloud processes.

The prose catalogue is explicitly noncanonical. GameState, the board outcome,
native Dialogic, one-shot Next, Quick, Profile and restoration remain production
owners. This is independent evidence beside the unchanged eight-mode reading
journey; its files and process root never overlap that original receipt.
"""

from __future__ import annotations

from copy import deepcopy
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from uuid import uuid4

import run_cloud_journeys as cloud


SCRIPT = "res://tests/integration/verify_solo_authored_selector_journey.gd"
CATALOGUE = "tests/fixtures/dialogic/solo_authored_selector_catalogue.json"
EVIDENCE_FOLDER = "solo-authored-selector"
MODES = ("write", "read")
PRE = "dating.solo.priscilla.day1.pre_challenge"
POST = "dating.solo.priscilla.day1.post_challenge"
LINES = ("fixture.selector.pre.a", "fixture.selector.pre.b",
         "fixture.selector.post.a", "fixture.selector.post.b")
CAPTURES = (
    "01-title.png", "02-desktop.png", "03-minesweeper.png",
    "04-pre-history.png", "05-dating-board.png", "06-post-history.png",
    "07-post-save.png", "08-restored-history.png", "09-restored-line.png",
)
RETAINED_JSON = ("saved-quick.json", "saved-profile.json", "saved-next-source.json", "saved-next-destination.json")
READER_JSON = ("read-before-quick.json", "read-after-quick.json", "read-before-profile.json", "read-after-profile.json")
TRACE_KINDS = {
    "write": ("fixture_registered", "history_inspected", "pre_history", "committed_result_then_post_prose",
              "next_unseen_verified", "next_destination_verified", "history_inspected", "quick_committed"),
    "read": ("fresh_restore_prepared", "forged_checkpoint_refused", "history_inspected", "fresh_restore_verified"),
}


def require(condition: bool, detail: str) -> None:
    if not condition:
        raise RuntimeError(detail)


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

    result = json.loads(text, object_pairs_hook=object_pairs, parse_constant=invalid_constant)
    require(isinstance(result, dict), "JSON_OBJECT_REQUIRED")
    return result


def file_identity(path: Path) -> dict:
    raw = path.read_bytes()
    return {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}


def canonical_sha256(value: dict) -> str:
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True,
                                     separators=(",", ":"), allow_nan=False).encode("utf-8")).hexdigest()


def read_report(mode: str, evidence: Path, folder: Path, reports: dict, user_dir: Path) -> dict:
    path = cloud.contained_path(evidence, evidence / f"{mode}.json")
    report = strict_json(path.read_text(encoding="utf-8"))
    require(report["schema_version"] == 1 and report["mode"] == mode
            and Path(report["user_dir"]).is_absolute()
            and Path(report["user_dir"]).resolve() == user_dir, "REPORT_IDENTITY_MISMATCH")
    require(type(report["process_id"]) is int and report["process_id"] > 0
            and all(prior["process_id"] != report["process_id"] for prior in reports.values()),
            "EVERY_MODE_REQUIRES_A_FRESH_OS_PROCESS")
    reports[mode] = report
    shutil.copyfile(path, folder / path.name)
    return report


def select_programmes(repository: Path, frames: dict) -> dict:
    """Derive expected prose from retained Run frames, independently of reports."""
    catalogue = strict_json((repository / CATALOGUE).read_text(encoding="utf-8"))
    require(catalogue["schema_version"] == 2 and set(frames) == {PRE, POST},
            "EXACT_AUTHORED_PRE_POST_FRAMES_REQUIRED")
    programmes = {}
    for entry in catalogue["entries"]:
        entry_id = entry["entry_id"]
        fields = frames[entry_id]["fields"]
        selectors = {key: fields[key] for key in entry["selector_fields"]}
        matches = [row for row in entry["variants"] if row["selector_values"] == selectors]
        require(len(matches) == 1, f"EXACT_FINITE_SELECTOR_ROW_REQUIRED: {entry_id}")
        row = matches[0]
        beats = [{
            "beat_id": line["beat_id"], "line_id": line["line_id"], "owning_entry_id": entry_id,
            "presentation_signature": {
                "content_revision": line["revision"], "variant_id": line["variant_id"],
                "selectors": {key: selectors[key] for key in line["selector_fields"]},
            },
        } for line in row["lines"]]
        programmes[entry_id] = {
            "entry_id": entry_id, "content_version": entry["content_version"],
            "label": row["label"], "lines": row["lines"], "beats": beats, "selectors": selectors,
        }
    return programmes


def validate_saved_state(reports: dict, repository: Path, evidence: Path, folder: Path) -> dict:
    written, restored = (reports[mode] for mode in MODES)
    for key in (
        "saved_checkpoint", "canonical_transcript", "current_line_id", "current_text",
        "physical_record", "authoritative_frames", "authoritative_entry_contexts",
        "selected_programmes", "quick_sha256", "quick_bytes", "profile_sha256", "profile_bytes", "witnesses",
    ):
        require(restored[key] == written[key], f"FRESH_RESTORE_MISMATCH: {key}")
    require(written["speech_admissions"] > 0 and restored["speech_admissions"] == 0,
            "LIVE_NATIVE_SPEECH_CONTROL_AND_ZERO_RESTORE_REPLAY_REQUIRED")
    require(written["history_observations"] >= 2 and restored["history_observations"] >= 1,
            "PRE_POST_AND_RESTORED_HISTORY_REQUIRED")
    require(restored["profile_unchanged"] is True and restored["quick_unchanged"] is True,
            "RESTORE_MUST_PRESERVE_PHYSICAL_PROFILE_AND_QUICK")
    require(all(report["next_active"] is False for report in reports.values()),
            "NEXT_TRANSPORT_MUST_BE_RETIRED")

    programmes = select_programmes(repository, written["authoritative_frames"])
    require(programmes == written["selected_programmes"], "REPORT_MUST_MATCH_AUTHORED_FRAME_SELECTION")
    selected_lines = [line for entry in (PRE, POST) for line in programmes[entry]["lines"]]
    beats = [beat for entry in (PRE, POST) for beat in programmes[entry]["beats"]]
    checkpoint = written["saved_checkpoint"]
    session = checkpoint["reading_session"]
    captions = session["ledger"]["captions"]
    require([row["beat"] for row in captions] == beats
            and [row["line_id"] for row in selected_lines] == list(LINES),
            "EXACT_FOUR_SELECTED_CAPTIONS_REQUIRED")
    require(len({row["publication_id"] for row in captions}) == 4
            and all(isinstance(row["publication_id"], str) and row["publication_id"] for row in captions),
            "FOUR_DISTINCT_SEMANTIC_PUBLICATIONS_REQUIRED")
    require(session["ledger"]["entry_contexts"] == written["authoritative_entry_contexts"],
            "READING_FRAMES_MUST_EQUAL_INDEPENDENT_RUN_AUTHORITY")
    for entry in (PRE, POST):
        require(written["authoritative_entry_contexts"][entry]["presentation"]
                == written["authoritative_frames"][entry], "ENTRY_CONTEXT_MUST_USE_INDEPENDENT_RUN_FRAME")
    require([row["line_id"] for row in written["canonical_transcript"]] == list(LINES)
            and [row["text"] for row in written["canonical_transcript"]]
            == [line["text"] for line in selected_lines], "EXACT_AUTHORED_HISTORY_WORDING_REQUIRED")
    require(written["current_line_id"] == LINES[-1] and written["current_text"] == selected_lines[-1]["text"]
            and session["boundary"] == "line"
            and session["frontier"] == {"line_id": LINES[-1], "publication_id": captions[-1]["publication_id"]},
            "SAVE_MUST_RETAIN_EXACT_SELECTED_POST_B_FRONTIER")
    for mode, report in reports.items():
        native = report["native_caption"]
        require(native["label"] == programmes[POST]["label"] and native["text"] == selected_lines[-1]["text"]
                and native["fully_visible"] is True, f"EXACT_NATIVE_SELECTED_CAPTION_REQUIRED: {mode}")

    physical = written["physical_record"]
    post_fields = written["authoritative_frames"][POST]["fields"]
    require(physical["phase"] == "post_challenge" and physical["outcome"] == "exploded"
            and physical["board"]["terminal"] is True and post_fields["board_result"] == "exploded"
            and post_fields["relationship_outcome"] == physical["relationship_outcome"]
            and post_fields["perfect_reasons"] == physical["perfect_reasons"]
            and post_fields["effect_receipt_id"]
            == physical["applied_result"]["receipt"]["terminal_fact"]["transaction_id"],
            "REAL_TERMINAL_BOARD_EFFECT_MUST_PRECEDE_SELECTED_POST_PROSE")
    retained = {}
    documents = {}
    for stem, name in (("quick", "saved-quick.json"), ("profile", "saved-profile.json")):
        path = cloud.contained_path(evidence, evidence / name)
        identity = file_identity(path)
        require(identity == {"bytes": written[f"{stem}_bytes"], "sha256": written[f"{stem}_sha256"]},
                f"RETAINED_PHYSICAL_BYTES_MISMATCH: {name}")
        documents[stem] = strict_json(path.read_text(encoding="utf-8"))
        retained[stem] = identity
        shutil.copyfile(path, folder / name)
        for phase in ("before", "after"):
            observed_name = f"read-{phase}-{stem}.json"
            observed = cloud.contained_path(evidence, evidence / observed_name)
            require(observed.read_bytes() == path.read_bytes(),
                    f"FRESH_READER_MUST_RETAIN_EXACT_WRITER_BYTES: {observed_name}")
            shutil.copyfile(observed, folder / observed_name)
    snapshot = documents["quick"]["current_snapshot"]["snapshot"]
    route = snapshot["gameplay"]["route_context"]
    require(snapshot["narrative_checkpoint"] == checkpoint
            and route["active_dating_challenge"] == physical
            and route["dating_frozen_contexts_v1"]["entries"] == written["authoritative_frames"],
            "PHYSICAL_QUICK_MUST_CONTAIN_EXACT_CHECKPOINT_AND_INDEPENDENT_RUN_FACTS")
    require(documents["profile"]["witnessed_caption_variants"] == written["witnesses"]
            and len(written["witnesses"]) == len(beats)
            and all(beat in written["witnesses"].values() for beat in beats),
            "FRESH_PHYSICAL_PROFILE_MUST_CONTAIN_ONLY_THE_FOUR_SELECTED_VARIANTS")
    require(documents["profile"]["preferences"]["reading"]["read_aloud_enabled"] is True,
            "READ_ALOUD_MUST_REMAIN_ENABLED_DURING_RESTORE_PROOF")
    return retained


def validate_next(written: dict, evidence: Path, folder: Path) -> dict:
    unseen = written["unseen_stop"]
    require(unseen["result"]["ok"] is True and unseen["result"]["code"] == "unseen_stop"
            and unseen["checkpoint_writes"] == []
            and unseen["before_checkpoint"] == unseen["after_checkpoint"],
            "PARTIAL_UNSEEN_NEXT_MUST_PRESERVE_CHECKPOINT_WITH_NO_NEXT_WRITES")
    before, after = unseen["native_before"], unseen["native_after"]
    require(before["line_id"] == LINES[2] and after["line_id"] == before["line_id"]
            and before["text"] == after["text"] and before["revealing"] is True
            and 0 <= before["visible_characters"] < before["total_characters"]
            and 0 <= before["visible_ratio"] < 1 and after["revealing"] is False
            and after["visible_ratio"] == 1
            and (after["visible_characters"] == -1 or after["visible_characters"] >= after["total_characters"]),
            "FIRST_NEXT_MUST_FINISH_LITERAL_PARTIAL_POST_A_WITHOUT_ADVANCING")
    proof = written["next"]
    require(proof["result"]["ok"] is True and proof["result"]["code"] == "next_complete"
            and proof["result"]["value"]["destination"] == "line"
            and proof["source_ack"]["was_visited_before_presentation"] is False
            and proof["destination_ack"]["was_visited_before_presentation"] is False,
            "NEXT_MUST_RETAIN_BOTH_PRE_PUBLICATION_UNSEEN_BASELINES")
    for phase, observations in (("unseen_stop", unseen["observations"]), ("next", proof["observations"])):
        expected_publications = 1 if phase == "next" else 0
        require(all(observations[key] == expected_publications for key in (
                    "text_started", "about_to_show_text", "caption_publications"))
                and observations["intermediate_checkpoint_admissions"] == 0
                and observations["exclusive_activations"] == (1 if phase == "next" else 0),
                f"NEXT_MUST_NOT_PUBLISH_INTERMEDIATE_NATIVE_TEXT_OR_CHECKPOINTS: {phase}")
    require(unseen["observations"]["speech_before"] == unseen["observations"]["speech_after"],
            "UNSEEN_STOP_MUST_NOT_REPLAY_CURRENT_SPEECH")
    require(unseen["observations"]["texts"] == [] and unseen["observations"]["publications"] == []
            and proof["observations"]["texts"] == [written["current_text"]]
            and len(proof["observations"]["publications"]) == 1,
            "SECOND_NEXT_MUST_PUBLISH_ONLY_THE_EXACT_NEW_POST_B_WORDING")
    publication = proof["observations"]["publications"][0]
    require(publication["ok"] is True and publication["value"]["duplicate"] is True
            and publication["value"]["ordinal"] == 3,
            "NATIVE_DESTINATION_PUBLICATION_MUST_REUSE_THE_FOURTH_SEMANTIC_CAPTION")
    session = written["saved_checkpoint"]["reading_session"]
    operation = session["next_operation"]
    plan = operation["plan"]
    source = unseen["after_checkpoint"]["reading_session"]
    require(session["schema_version"] == 2 and operation["schema_version"] == 1
            and operation == proof["operation"] and operation["phase"] == "destination"
            and operation["operation_id"] == canonical_sha256(plan)
            and plan["entry_id"] == POST and plan["source_ledger"] == source["ledger"]
            and plan["source_frontier"] == source["frontier"]
            and source["frontier"]["line_id"] == LINES[2]
            and plan["traversed_captions"] == [] and plan["destination"]["kind"] == "line"
            and plan["destination"]["caption"] == session["ledger"]["captions"][-1]
            and session["ledger"]["captions"] == source["ledger"]["captions"] + [plan["destination"]["caption"]],
            "NEXT_MUST_DURABLY_MOVE_EXACT_POST_A_TO_FIRST_UNSEEN_POST_B")
    writes = proof["checkpoint_results"]
    require([row["phase"] for row in writes] == ["source", "destination"],
            "EXACT_REAL_SOURCE_THEN_DESTINATION_CHECKPOINT_WRITES_REQUIRED")
    snapshots = []
    retained = {}
    for row in writes:
        require(row["result"]["ok"] is True and row["operation_id"] == operation["operation_id"],
                "NEXT_CHECKPOINT_WRITE_FAILED_OR_FOREIGN_OPERATION")
        expected = deepcopy(session)
        expected["next_operation"]["phase"] = row["phase"]
        if row["phase"] == "source":
            expected["ledger"] = plan["source_ledger"]
            expected["frontier"] = plan["source_frontier"]
        require(row["checkpoint"]["reading_session"] == expected,
                f"NEXT_DURABLE_ENDPOINT_MISMATCH: {row['phase']}")
        name = f"saved-next-{row['phase']}.json"
        path = cloud.contained_path(evidence, evidence / name)
        identity = file_identity(path)
        require(row["autosave"]["file"] == name
                and identity == {key: row["autosave"][key] for key in ("bytes", "sha256")},
                f"NEXT_AUTOSAVE_BYTES_MISMATCH: {row['phase']}")
        document = strict_json(path.read_text(encoding="utf-8"))
        snapshot = document["current_snapshot"]["snapshot"]
        receipt = row["result"]["receipt"]
        require(snapshot["narrative_checkpoint"] == row["checkpoint"]
                and snapshot["gameplay"]["route_context"]["active_dating_challenge"] == written["physical_record"]
                and snapshot["gameplay"]["route_context"]["dating_frozen_contexts_v1"]["entries"] == written["authoritative_frames"]
                and receipt["checkpoint_id"] == snapshot["checkpoint_id"] == row["result"]["value"]["checkpoint_id"]
                and row["result"]["value"]["duplicate"] is False
                and receipt["operation_id"] == operation["operation_id"] and receipt["phase"] == row["phase"]
                and receipt["narrative_fingerprint"] == canonical_sha256(row["checkpoint"]),
                f"NEXT_RECEIPT_MUST_MATCH_PHYSICAL_AUTOSAVE: {row['phase']}")
        snapshots.append(snapshot)
        retained[row["phase"]] = {**identity, "checkpoint_id": snapshot["checkpoint_id"],
                                  "checkpoint_sequence": snapshot["checkpoint_sequence"]}
        shutil.copyfile(path, folder / name)
    require(snapshots[0]["checkpoint_id"] != snapshots[1]["checkpoint_id"]
            and snapshots[0]["checkpoint_sequence"] < snapshots[1]["checkpoint_sequence"],
            "NEXT_SOURCE_AND_DESTINATION_REQUIRE_DISTINCT_ORDERED_PHYSICAL_CHECKPOINTS")
    return {"operation_id": operation["operation_id"], "first_activation_writes": 0,
            "second_activation_phases": [row["phase"] for row in writes],
            "source_line_id": LINES[2], "destination_line_id": LINES[3], "traversed_captions": 0,
            "retained_autosaves": retained}


def validate_forgery(restored: dict) -> None:
    forged = restored["forged_checkpoint"]
    require(forged["internally_valid"]["ok"] is True and forged["live_unchanged"] is True
            and forged["files_unchanged"] is True, "SELF_CONSISTENT_FORGERY_MUST_BE_READ_ONLY")
    for key in ("writer_authority_refusal", "route_authority_refusal"):
        refusal = forged[key]
        require(refusal["ok"] is False and refusal["code"] == "reading_context_invalid",
                f"INDEPENDENT_CONTEXT_AUTHORITY_MUST_REFUSE_FORGERY: {key}")
    refused = forged["restore_participant_refusal"]
    require(refused["ok"] is False and refused["code"] == "invalid_narrative_checkpoint"
            and refused["message"] == "reading_entry_context_mismatch"
            and forged["quick_sha256"] == restored["quick_sha256"]
            and forged["profile_sha256"] == restored["profile_sha256"],
            "ACTUAL_RESTORE_PARTICIPANT_MUST_REFUSE_WITHOUT_MUTATION")
    changed = forged["forged_checkpoint"]["reading_session"]
    original = restored["saved_checkpoint"]["reading_session"]
    require(changed["ledger"]["entry_contexts"][POST] == original["ledger"]["entry_contexts"][POST]
            and changed["ledger"]["entry_contexts"][PRE] != original["ledger"]["entry_contexts"][PRE]
            and changed["frontier"] == original["frontier"]
            and changed["next_operation"]["operation_id"] != original["next_operation"]["operation_id"]
            and changed["next_operation"]["operation_id"] == canonical_sha256(changed["next_operation"]["plan"]),
            "FORGERY_MUST_CHANGE_EARLIER_SELECTED_PROSE_WITH_A_COHERENT_NEXT_IDENTITY")


def validate_trace(reports: dict, evidence: Path) -> None:
    path = cloud.contained_path(evidence, evidence / "transactions.jsonl")
    entries = [strict_json(line) for line in path.read_text(encoding="utf-8").splitlines()]
    require([entry["mode"] for entry in entries] == [mode for mode in MODES for _ in TRACE_KINDS[mode]],
            "EXACT_TWO_PROCESS_TRANSACTION_TRACE_REQUIRED")
    for mode in MODES:
        observed = [entry for entry in entries if entry["mode"] == mode]
        require([entry["kind"] for entry in observed] == list(TRACE_KINDS[mode]),
                f"TRANSACTION_ORDER_MISMATCH: {mode}")
        for sequence, entry in enumerate(observed, 1):
            require(entry["sequence"] == sequence and entry["process_id"] == reports[mode]["process_id"],
                    f"TRANSACTION_PROCESS_OR_SEQUENCE_MISMATCH: {mode}/{sequence}")
            if entry["kind"] in ("next_unseen_verified", "next_destination_verified", "forged_checkpoint_refused"):
                key = {"next_unseen_verified": "unseen_stop", "next_destination_verified": "next",
                       "forged_checkpoint_refused": "forged_checkpoint"}[entry["kind"]]
                require(entry["value"] == reports[mode][key], f"TRACE_REPORT_MISMATCH: {entry['kind']}")
            if entry["kind"] in ("quick_committed", "fresh_restore_verified"):
                require(entry["value"]["checkpoint"] == reports[mode]["saved_checkpoint"],
                        f"TRACE_CHECKPOINT_MISMATCH: {entry['kind']}")
            if entry["kind"] == "pre_history":
                require(entry["value"]["history"]["captions"] == reports[mode]["canonical_transcript"][:2]
                        and entry["value"]["authoritative_frames"] == {PRE: reports[mode]["authoritative_frames"][PRE]},
                        "PRE_TRACE_MUST_HAVE_TWO_CAPTIONS_AND_NO_INVENTED_POST_FRAME")
            if entry["kind"] == "committed_result_then_post_prose":
                require(entry["value"]["history"]["captions"] == reports[mode]["canonical_transcript"][:3]
                        and entry["value"]["authoritative_frames"] == reports[mode]["authoritative_frames"]
                        and entry["value"]["physical_record"] == reports[mode]["physical_record"],
                        "POST_TRACE_MUST_BIND_THIRD_CAPTION_TO_ACTUAL_TERMINAL_EFFECT")


def seal_writer(repository: Path, evidence: Path, folder: Path) -> dict:
    sealed = cloud.make_directory(repository, folder / "sealed-write")
    files = {}
    for name in ("write.json", *RETAINED_JSON, "transactions.jsonl", *CAPTURES[:7]):
        source = cloud.contained_path(evidence, evidence / name)
        target = cloud.contained_path(sealed, sealed / name)
        files[name] = file_identity(source)
        shutil.copyfile(source, target)
        require(file_identity(target) == files[name], f"WRITER_SEAL_COPY_MISMATCH: {name}")
    seal = {"sealed_after_mode": "write", "before_mode": "read", "root": str(sealed), "files": files}
    cloud.write_json(folder / "write-seal.json", seal)
    return seal


def verify_writer_seal(seal: dict, evidence: Path, folder: Path) -> None:
    sealed = cloud.contained_path(folder, Path(seal["root"]))
    for name, identity in seal["files"].items():
        source = cloud.contained_path(evidence, evidence / name)
        retained = cloud.contained_path(sealed, sealed / name)
        require(file_identity(retained) == identity, f"SEALED_WRITER_BYTES_CHANGED: {name}")
        if name == "transactions.jsonl":
            require(source.read_bytes().startswith(retained.read_bytes()), "READER_CHANGED_WRITER_TRACE_PREFIX")
        else:
            require(file_identity(source) == identity, f"READER_CHANGED_WRITER_EVIDENCE: {name}")


def execute_mode(mode: str, godot: str, xvfb: str, repository: Path, folder: Path, env: dict, result: dict) -> None:
    log = folder / f"{mode}.log"
    argv = [
        xvfb, "-a", "-s", "-screen 0 1920x1080x24", godot,
        "--path", str(repository), "--verbose", "--rendering-method", "gl_compatibility",
        "--rendering-driver", "opengl3", "--audio-driver", "Dummy",
        "--log-file", str(log), "--script", SCRIPT, "--",
        "--phase2r-bootstrap-mode=final", "--render-evidence", "--probe-dating",
        f"--solo-authored-selector-mode={mode}",
    ]
    process = cloud.run_process(argv, env, repository, folder, mode)
    result["processes"][mode] = process
    failures = cloud.process_failures(process, log)
    marker = f"SOLO_AUTHORED_SELECTOR_{mode.upper()}_PASS"
    if cloud.marker_count(cloud.read_log(Path(process["stdout"])), marker) != 1:
        failures.append(f"REQUIRED_MARKER_COUNT: {marker}")
    if any("SOLO_AUTHORED_SELECTOR_FAIL:" in cloud.read_log(path)
           for path in (Path(process["stdout"]), Path(process["stderr"]), log) if path.is_file()):
        failures.append("SOLO_AUTHORED_SELECTOR_ASSERTION_FAILED")
    result["failures"].extend(failures)
    require(not failures, f"MODE_FAILED: {mode}")


def run() -> int:
    repository = Path(__file__).resolve().parents[2]
    output = cloud.make_directory(repository, repository / ".godot/ci" / EVIDENCE_FOLDER)
    folder = cloud.make_directory(repository, output / str(uuid4()))
    isolation = cloud.make_directory(repository, repository / ".godot/phase2r_tests" / str(uuid4()))
    result = {
        "schema_version": 1, "fixture_scope": "Noncanonical finite authored Solo Priscilla Day 1 selectors; real board, frozen Run frames, native prose, one-shot Next, physical Quick and Profile.",
        "started_at_utc": cloud.utc_now(), "ok": False, "failures": [], "processes": {}, "reports": {},
        "isolation_root": str(isolation), "artifact_root": str(folder),
    }
    user_dir: Path | None = None
    evidence: Path | None = None
    seal: dict | None = None
    try:
        require(sys.platform == "linux", "Rendered selector proof requires Linux with xvfb-run")
        godot = shutil.which(os.environ.get("GODOT_CONSOLE_PATH", "").strip())
        xvfb = shutil.which("xvfb-run")
        require(godot is not None and xvfb is not None, "GODOT_CONSOLE_PATH and xvfb-run are required")
        result["checkout_sha"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repository, text=True).strip()
        result["workflow"] = {key: os.environ.get(key, "") for key in (
            "GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT", "GITHUB_JOB", "GITHUB_SHA",
        )}
        env = os.environ.copy()
        for key, suffix in (("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"),
                            ("XDG_CACHE_HOME", "cache"), ("DWM_TEST_ROOT", "test-root")):
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
        require(not failures, "USER_DIR_PROOF_FAILED: " + "; ".join(failures))
        markers = re.findall(r"^PHASE2R_USER_DIR=(.+)$", cloud.read_log(Path(proof["stdout"])), re.MULTILINE)
        require(len(markers) == 1 and Path(markers[0].strip()).is_absolute(), "EXACT_ABSOLUTE_USER_DIR_PROOF_REQUIRED")
        user_dir = cloud.contained_path(isolation, Path(markers[0].strip()))
        cloud.contained_path(Path(env["XDG_DATA_HOME"]), user_dir)
        result["user_dir"] = str(user_dir)
        result["user_dir_strictly_contained"] = True
        evidence = cloud.contained_path(user_dir, user_dir / "evidence" / EVIDENCE_FOLDER)
        for mode in MODES:
            execute_mode(mode, godot, xvfb, repository, folder, env, result)
            read_report(mode, evidence, folder, result["reports"], user_dir)
            if mode == "write":
                seal = seal_writer(repository, evidence, folder)
                result["write_seal"] = seal
        result["retained_files"] = validate_saved_state(result["reports"], repository, evidence, folder)
        result["next_proof"] = validate_next(result["reports"]["write"], evidence, folder)
        validate_forgery(result["reports"]["read"])
        validate_trace(result["reports"], evidence)
        result["independent_frame_forgery_refused"] = True
    except Exception as error:
        result["failures"].append(f"{type(error).__name__}: {error}")
    finally:
        if user_dir is not None:
            try:
                if seal is not None:
                    verify_writer_seal(seal, evidence, folder)
                    result["write_seal_verified"] = True
                captures, failures = cloud.collect_captures(repository, user_dir, folder, {
                    "evidence_folder": EVIDENCE_FOLDER, "captures": CAPTURES,
                })
                result["captures"] = captures
                result["failures"].extend(failures)
            except Exception as error:
                result["failures"].append(f"EVIDENCE_COLLECTION_FAILED: {error}")
            try:
                for name in ("write.json", "read.json", *RETAINED_JSON, *READER_JSON, "transactions.jsonl"):
                    source = cloud.contained_path(evidence, evidence / name)
                    target = cloud.contained_path(folder, folder / name)
                    if source.is_file() and not target.exists():
                        shutil.copyfile(source, target)
            except Exception as error:
                result["failures"].append(f"PARTIAL_REPORT_COLLECTION_FAILED: {error}")
        result["ended_at_utc"] = cloud.utc_now()
        result["ok"] = not result["failures"]
        cloud.write_json(folder / "result.json", result)
        cloud.write_json(output / "result.json", result)
    for failure in result["failures"]:
        print(f"SOLO_AUTHORED_SELECTOR_CLOUD_FAIL: {failure}", flush=True)
    print("SOLO_AUTHORED_SELECTOR_CLOUD_RESULT: " + json.dumps({
        "ok": result["ok"], "artifact_root": str(folder),
        "checkout_sha": result.get("checkout_sha"), "failures": result["failures"],
    }), flush=True)
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(run())
