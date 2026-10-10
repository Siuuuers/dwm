#!/usr/bin/env python3
"""Bounded noncanonical ordered-ending proof with two fresh rendered processes."""
from __future__ import annotations
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
from uuid import uuid4
import run_cloud_journeys as cloud
from run_hospital_reading_journey import strict_json, file_identity, snapshot_primary, copy_bytes, validate_writer_seal, retain_partial_evidence

SCRIPT = "res://tests/integration/verify_ending_reading_journey.gd"
CAPTURES = ("ending-boundary-before.png", "ending-boundary-successor.png", "ending-partial-pause.png", "ending-saved.png", "ending-saved-history.png", "ending-restored.png", "ending-restored-history.png")

def require(value: bool, detail: str) -> None:
    if not value:
        raise RuntimeError(detail)

def seal_writer(repository: Path, evidence: Path, folder: Path) -> dict:
    sealed = cloud.make_directory(repository, folder / "sealed-write")
    files = {}
    for source in sorted(evidence.iterdir()):
        source = cloud.contained_path(evidence, source)
        require(source.is_file(), "WRITER_EVIDENCE_MUST_BE_FILE")
        files[source.name] = copy_bytes(evidence, source, sealed, sealed / source.name)
    require({"write.json", "saved-ending-slot.json"}.issubset(files), "WRITER_REPORT_AND_RAW_SLOT_REQUIRED")
    seal = {"root": str(sealed), "files": files}
    cloud.write_json(folder / "write-seal.json", seal)
    return seal

def validate_restore_identity(restored: dict, saved: dict) -> None:
    remapped = {"branch_id", "desktop_timeline_generation", "causal_day_instance", "causal_day_instance_issuer_receipt", "restore_provenance"}
    require({key: value for key, value in restored.items() if key not in remapped}
            == {key: value for key, value in saved.items() if key not in remapped}, "ENDING_STORY_STATE_MUST_REMAIN_EXACT")
    provenance = restored["restore_provenance"]
    require(restored["branch_id"] != saved["branch_id"]
            and restored["desktop_timeline_generation"] > saved["desktop_timeline_generation"]
            and restored["causal_day_instance"] != saved["causal_day_instance"], "LOAD_REQUIRES_FRESH_CONTINUATION_IDENTITY")
    require(provenance["source_branch_id"] == saved["branch_id"]
            and provenance["source_desktop_timeline_generation"] == saved["desktop_timeline_generation"]
            and provenance["source_causal_day_instance"] == saved["causal_day_instance"]
            and provenance["source_issuer_observed_counter"] == saved["causal_day_instance_issuer_receipt"].get("counter", 0)
            and bool(provenance["restore_transaction_id"]), "RESTORE_PROVENANCE_MUST_BIND_SAVED_SOURCE")

def validate(result: dict, folder: Path) -> dict:
    writer, reader = result["reports"]["write"], result["reports"]["read"]
    document = strict_json((folder / "write-output-slot.json").read_text())
    snapshot = document["current_snapshot"]["snapshot"]
    saved = writer["saved"]
    restored = reader["stages"]["restored"]
    checkpoint = snapshot["narrative_checkpoint"]
    reading = checkpoint["reading_session"]
    rows = reading["ledger"]["captions"]
    require(snapshot == writer["stages"]["saved_snapshot"], "RAW_SLOT_DIFFERS_FROM_REPORTED_SNAPSHOT")
    require(snapshot["route_id"] == "ending" and snapshot["lifecycle"]["state"] == "ENDING"
            and snapshot["lifecycle"]["ending_plan"]["next_step_index"] == 1, "SLOT_REQUIRES_ACTIVE_SECOND_ENDING_STEP")
    require(reading["schema_version"] == 3 and reading["family"] == "ending" and reading["boundary"] == "line", "ENDING_V3_LINE_REQUIRED")
    require([row["beat"]["line_id"] for row in rows] == ["fixture.ending.first", "fixture.ending.prior", "fixture.ending.boundary", "fixture.ending.second"]
            and len({row["publication_id"] for row in rows}) == 4, "ORDERED_DISTINCT_REAL_PUBLICATIONS_REQUIRED")
    require(checkpoint == saved["checkpoint"] == restored["checkpoint"] and saved["history"] == restored["history"]
            and saved["lifecycle"] == snapshot["lifecycle"], "FRESH_RESTORE_MUST_PRESERVE_EXACT_AUTHORITY_AND_HISTORY")
    frames = writer["transition_frames"]
    entries = writer["catalogue"]["entries"]
    before = [line["text"] for line in entries[0]["lines"]]
    after = before[-2:] + [entries[1]["lines"][0]["text"]]
    require(len(frames) >= 2 and frames[0]["texts"] == before and frames[-1]["texts"] == after
            and all(frame["valid"] and frame["texts"] in (before, after)
                    and all(leaf["contained"] and leaf["visible_ratio"] == 1.0
                            for leaf in frame["leaves"] if leaf["text"] in before[-2:]) for frame in frames), "CONTINUOUS_ORDERED_NATIVE_LEAVES_REQUIRED")
    require(all(a["frame"] < b["frame"] for a, b in zip(frames, frames[1:])), "STRICTLY_ORDERED_RENDER_FRAMES_REQUIRED")
    require(saved["visible_leaves"] == restored["visible_leaves"] == after, "EXACT_RESTORED_VISIBLE_WINDOW_REQUIRED")
    validate_restore_identity(restored["lifecycle"], saved["lifecycle"])
    require(writer["stages"]["first"]["history"]["session_id"] == saved["history"]["session_id"], "CROSS_STEP_SESSION_MUST_REMAIN_SINGLE")
    require(writer["stages"]["partial_pause"]["native"]["revealing"] is True
            and restored["native"]["revealing"] is False and restored["native"]["visible_ratio"] == 1.0, "PARTIAL_SAVE_AND_FULL_RESTORE_REQUIRED")
    require(restored["speech_admissions"] == 0 and len(writer["completions"]) == len(reader["completions"]) == 1,
            "EXACT_ONE_PHYSICAL_COMPLETION_PER_PROCESS_REQUIRED")
    require(all(line["text"] not in reader["text_starts"] for line in entries[0]["lines"]), "PRIOR_CAPTIONS_MUST_NOT_REPLAY")
    require(reader["stages"]["duplicate"] == {"ok": True, "unchanged": True}
            and reader["stages"]["forgery"]["unchanged"] is True
            and reader["stages"]["forgery"]["refusal"]["ok"] is False, "DUPLICATE_NEUTRALITY_AND_FORGERY_REFUSAL_REQUIRED")
    require(reader["stages"]["completed"]["lifecycle"]["state"] == "COMPLETED", "CHAIN_TERMINAL_SETTLEMENT_REQUIRED")
    return {"visible_boundary_continuity": True, "exact_saved_restore": True, "physical_boundary": True, "ordered_history": True, "silent_restore": True,
            "duplicate_neutral": True, "forgery_refused": True, "remaining_completion_once": True}

def run() -> int:
    repository = Path(__file__).resolve().parents[2]
    output = cloud.make_directory(repository, repository / ".godot/ci/ending-reading")
    folder = cloud.make_directory(repository, output / str(uuid4()))
    isolation = cloud.make_directory(repository, repository / ".godot/phase2r_tests" / str(uuid4()))
    result = {"schema_version": 1, "ok": False, "failures": [], "reports": {}, "processes": {}, "primary_files": {},
              "fixture_scope": "Explicit test prose and seeded eligibility; actual physical ending, Save and Load owners.",
              "started_at_utc": cloud.utc_now(), "artifact_root": str(folder)}
    evidence = None
    seal = None
    try:
        godot = shutil.which(os.environ.get("GODOT_CONSOLE_PATH", ""))
        xvfb = shutil.which("xvfb-run")
        require(bool(godot and xvfb), "GODOT_AND_XVFB_REQUIRED")
        result["checkout_sha"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repository, text=True).strip()
        result["source_identity"] = {str(path.relative_to(repository)): file_identity(path) for path in (
            Path(__file__).resolve(), repository / SCRIPT.removeprefix("res://"),
            repository / "tests/fixtures/dialogic/ending_reading.dtl", repository / "tests/fixtures/dialogic/ending_reading_catalogue.json")}
        env = os.environ.copy()
        for key, suffix in (("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache"), ("DWM_TEST_ROOT", "test-root")):
            env[key] = str(cloud.make_directory(repository, isolation / suffix))
        env.update({"LIBGL_ALWAYS_SOFTWARE": "1", "GALLIUM_DRIVER": "llvmpipe"})
        proof_log = folder / "user-dir-proof.log"
        proof = cloud.run_process([godot, "--headless", "--path", str(repository), "--log-file", str(proof_log),
                                  "--script", "res://tools/evidence/print_user_dir.gd"], env, repository, folder, "user-dir-proof")
        require(not cloud.process_failures(proof, proof_log), "USER_DIR_PROOF_FAILED")
        markers = re.findall(r"^PHASE2R_USER_DIR=(.+)$", cloud.read_log(Path(proof["stdout"])), re.MULTILINE)
        require(len(markers) == 1 and Path(markers[0]).is_absolute(), "EXACT_USER_DIR_REQUIRED")
        user_dir = cloud.contained_path(isolation, Path(markers[0].strip()))
        cloud.contained_path(Path(env["XDG_DATA_HOME"]), user_dir)
        evidence = cloud.contained_path(user_dir, user_dir / "evidence/ending-reading")
        result["user_dir"] = str(user_dir)
        for mode in ("write", "read"):
            result["primary_files"][mode] = {"input": snapshot_primary(user_dir, folder, mode + "-input")}
            log = folder / (mode + ".log")
            process = cloud.run_process([xvfb, "-a", "-s", "-screen 0 1920x1080x24", godot,
                "--path", str(repository), "--verbose", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3",
                "--audio-driver", "Dummy", "--log-file", str(log), "--script", SCRIPT, "--",
                "--phase2r-bootstrap-mode=final", "--render-evidence", "--probe-dating", f"--ending-reading-mode={mode}"], env, repository, folder, mode)
            result["processes"][mode] = process
            result["primary_files"][mode]["output"] = snapshot_primary(user_dir, folder, mode + "-output")
            require(not cloud.process_failures(process, log), f"PROCESS_FAILED:{mode}")
            stdout = cloud.read_log(Path(process["stdout"]))
            require(cloud.marker_count(stdout, f"ENDING_READING_{mode.upper()}_PASS") == 1, f"EXACT_PASS_MARKER_REQUIRED:{mode}")
            require(all("ENDING_READING_FAIL:" not in cloud.read_log(path) for path in (log, Path(process["stdout"]), Path(process["stderr"]))), "ASSERTION_FAILED")
            identities = re.findall(r"^ENDING_READING_PROCESS: (.+)$", stdout, re.MULTILINE)
            require(len(identities) == 1, "ONE_PROCESS_IDENTITY_REQUIRED")
            identity = strict_json(identities[0])
            report = strict_json((evidence / (mode + ".json")).read_text())
            require(report["mode"] == mode and report["schema_version"] == 1 and report["process_id"] == identity["process_id"]
                    and identity["user_dir"] == report["user_dir"] and cloud.contained_path(isolation, Path(report["user_dir"])) == user_dir, "REPORT_IDENTITY_MISMATCH")
            require(type(report["process_id"]) is int and report["process_id"] > 0
                    and all(report["process_id"] != prior["process_id"] for prior in result["reports"].values()), "FRESH_PROCESS_REQUIRED")
            result["reports"][mode] = report
            if mode == "write":
                seal = seal_writer(repository, evidence, folder)
        result["validation"] = validate(result, folder)
        result["captures"] = {}
        for name in CAPTURES:
            path = cloud.contained_path(evidence, evidence / name)
            require(path.is_file() and path.stat().st_size > 0, "NONEMPTY_SCREENSHOT_REQUIRED:" + name)
            result["captures"][name] = file_identity(path)
        validate_writer_seal(seal, evidence, folder)
        result["writer_seal_verified"] = True
    except Exception as error:
        result["failures"].append(f"{type(error).__name__}: {error}")
    finally:
        if evidence is not None:
            try:
                result["raw_evidence"] = retain_partial_evidence(evidence, folder)
            except Exception as error:
                result["failures"].append("EVIDENCE_COLLECTION_FAILED:" + str(error))
        result["ok"] = not result["failures"] and "validation" in result and result.get("writer_seal_verified", False)
        result["ended_at_utc"] = cloud.utc_now()
        cloud.write_json(folder / "result.json", result)
        cloud.write_json(output / "result.json", result)
    print("ENDING_READING_CLOUD_RESULT: " + json.dumps({"ok": result["ok"], "failures": result["failures"], "artifact_root": str(folder)}), flush=True)
    return 0 if result["ok"] else 1

if __name__ == "__main__":
    raise SystemExit(run())
