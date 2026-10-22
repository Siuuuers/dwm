#!/usr/bin/env python3
"""Isolated rendered proof of Auto mode continuity across a manual ending seam."""
from __future__ import annotations
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
from uuid import uuid4
import run_cloud_journeys as cloud
from run_hospital_reading_journey import strict_json, file_identity, retain_partial_evidence
from run_ending_reading_journey import require

SCRIPT = "res://tests/integration/verify_ending_auto_journey.gd"


def run() -> int:
    repository = Path(__file__).resolve().parents[2]
    output = cloud.make_directory(repository, repository / ".godot/ci/ending-reading/auto")
    folder = cloud.make_directory(repository, output / str(uuid4()))
    isolation = cloud.make_directory(repository, repository / ".godot/phase2r_tests" / str(uuid4()))
    result = {"schema_version": 1, "ok": False, "failures": [], "started_at_utc": cloud.utc_now()}
    evidence = None
    try:
        godot = shutil.which(os.environ.get("GODOT_CONSOLE_PATH", ""))
        xvfb = shutil.which("xvfb-run")
        require(bool(godot and xvfb), "GODOT_AND_XVFB_REQUIRED")
        result["checkout_sha"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repository, text=True).strip()
        result["source_identity"] = {str(path.relative_to(repository)): file_identity(path) for path in (
            Path(__file__).resolve(), repository / SCRIPT.removeprefix("res://"),
            repository / "tests/support/EndingAutoTimelineCatalog.gd",
            repository / "tests/fixtures/dialogic/ending_auto.dtl")}
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
        log = folder / "auto.log"
        process = cloud.run_process([xvfb, "-a", "-s", "-screen 0 1920x1080x24", godot,
            "--path", str(repository), "--verbose", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3",
            "--audio-driver", "Dummy", "--log-file", str(log), "--script", SCRIPT, "--",
            "--phase2r-bootstrap-mode=final", "--render-evidence", "--probe-dating"], env, repository, folder, "auto")
        result["process"] = process
        require(not cloud.process_failures(process, log), "AUTO_PROCESS_FAILED")
        stdout = cloud.read_log(Path(process["stdout"]))
        require(cloud.marker_count(stdout, "ENDING_AUTO_PASS") == 1, "EXACT_AUTO_PASS_MARKER_REQUIRED")
        require(all("ENDING_READING_FAIL:" not in cloud.read_log(path) for path in (log, Path(process["stdout"]), Path(process["stderr"]))), "AUTO_ASSERTION_FAILED")
        identities = re.findall(r"^ENDING_AUTO_PROCESS: (.+)$", stdout, re.MULTILINE)
        require(len(identities) == 1, "ONE_AUTO_PROCESS_IDENTITY_REQUIRED")
        identity = strict_json(identities[0])
        report = strict_json((evidence / "auto.json").read_text())
        require(report["process_id"] == identity["process_id"] and report["user_dir"] == identity["user_dir"]
            and cloud.contained_path(isolation, Path(report["user_dir"])) == user_dir, "AUTO_PROCESS_IDENTITY_MISMATCH")
        frames = report["frames"]
        require(report["schema_version"] == 1 and report["mode"] == "auto"
            and 0 < report["departing_remaining"] <= report["delay_seconds"] - 0.4
            and report["terminal_seen_ms"] - report["successor_reveal_finished_ms"] >= report["delay_seconds"] * 1000 - 100
            and report["successor_reveal_finished_ms"] >= 0
            and report["stale_result"]["ok"] is False and len(report["completions"]) == 1, "AUTO_TIMING_AND_CUSTODY_PROOF_REQUIRED")
        require(len(frames) > 2 and all(a["frame"] < b["frame"] for a, b in zip(frames, frames[1:]))
            and all(frame["profile_auto"] and frame["layers"]
                and all(layer["auto_on"] and not layer["skip_on"]
                    and (not layer["handoff"] or not layer["armed"])
                    and (layer["line_id"] != "fixture.ending.second" or not layer["revealing"] or not layer["armed"])
                    for layer in frame["layers"]) for frame in frames), "DRAWN_AUTO_CONTINUITY_REQUIRED")
        require(any(layer["line_id"] == "fixture.ending.second" and layer["revealing"]
            for frame in frames for layer in frame["layers"]), "NATIVE_SUCCESSOR_REVEAL_REQUIRED")
        result["report"] = report
        result["captures"] = {}
        for name in ("ending-auto-before.png", "ending-auto-successor.png", "ending-auto-terminal.png"):
            path = cloud.contained_path(evidence, evidence / name)
            require(path.is_file() and path.stat().st_size > 0, "AUTO_SCREENSHOT_REQUIRED:" + name)
            result["captures"][name] = file_identity(path)
    except Exception as error:
        result["failures"].append(f"{type(error).__name__}: {error}")
    finally:
        if evidence is not None:
            try:
                result["raw_evidence"] = retain_partial_evidence(evidence, folder)
            except Exception as error:
                result["failures"].append("EVIDENCE_COLLECTION_FAILED:" + str(error))
        result["ok"] = not result["failures"] and "report" in result
        result["ended_at_utc"] = cloud.utc_now()
        cloud.write_json(folder / "result.json", result)
        cloud.write_json(output / "result.json", result)
    print("ENDING_AUTO_CLOUD_RESULT: " + json.dumps({"ok": result["ok"], "failures": result["failures"], "artifact_root": str(folder)}), flush=True)
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(run())
