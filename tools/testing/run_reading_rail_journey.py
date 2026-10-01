#!/usr/bin/env python3
"""Prove one real Solo reading session across two isolated rendered processes.

Only the authored prose/catalogue is a noncanonical fixture. Startup, invitation,
Schedule, board outcome, History, Quick, storage and restoration use real owners.
The common cloud harness supplies containment, watchdog and strict log checks.
"""

from __future__ import annotations

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


SCRIPT = "res://tests/integration/verify_reading_rail_journey.gd"
CAPTURES = (
    "01-title.png", "02-desktop.png", "03-minesweeper.png",
    "04-pre-history.png", "05-dating-board.png", "06-post-history.png",
    "07-post-save.png", "08-restored-history.png", "09-restored-line.png",
)


def run() -> int:
    repository = Path(__file__).resolve().parents[2]
    output = cloud.make_directory(repository, repository / ".godot/ci/reading-rail")
    folder = cloud.make_directory(repository, output / str(uuid4()))
    isolation = cloud.make_directory(repository, repository / ".godot/phase2r_tests" / str(uuid4()))
    result = {
        "schema_version": 1,
        "fixture_scope": "Noncanonical English Solo Priscilla Day 1 prose only; real production owners and physical save files.",
        "started_at_utc": cloud.utc_now(), "ok": False, "failures": [], "processes": {},
        "isolation_root": str(isolation), "artifact_root": str(folder),
    }
    user_dir: Path | None = None
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
        for mode in ("write", "read"):
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
            marker = f"READING_RAIL_{mode.upper()}_PASS"
            if cloud.marker_count(stdout, marker) != 1:
                failures.append(f"REQUIRED_MARKER_COUNT: {marker}")
            if "READING_RAIL_FAIL:" in stdout or "READING_RAIL_FAIL:" in cloud.read_log(Path(process["stderr"])):
                failures.append("READING_RAIL_ASSERTION_FAILED")
            result["failures"].extend(failures)
            if failures:
                break
        evidence = cloud.contained_path(user_dir, user_dir / "evidence/reading-rail")
        reports = {}
        for mode in ("write", "read"):
            path = cloud.contained_path(user_dir, evidence / f"{mode}.json")
            if path.is_file():
                reports[mode] = json.loads(path.read_text(encoding="utf-8"))
                shutil.copyfile(path, folder / path.name)
        result["reports"] = reports
        if set(reports) != {"write", "read"}:
            raise RuntimeError("BOTH_PROCESS_REPORTS_REQUIRED")
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
        quick = cloud.contained_path(user_dir, evidence / "saved-quick.json")
        raw = quick.read_bytes()
        if len(raw) != written["quick_bytes"] or hashlib.sha256(raw).hexdigest() != written["quick_sha256"]:
            raise RuntimeError("RETAINED_QUICK_BYTES_MISMATCH")
        shutil.copyfile(quick, folder / quick.name)
        result["retained_quick"] = {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}
    except Exception as error:
        result["failures"].append(f"{type(error).__name__}: {error}")
    finally:
        if user_dir is not None:
            try:
                captures, failures = cloud.collect_captures(repository, user_dir, folder, {
                    "evidence_folder": "reading-rail", "captures": CAPTURES,
                })
                result["captures"] = captures
                result["failures"].extend(failures)
                trace = cloud.contained_path(user_dir, user_dir / "evidence/reading-rail/transactions.jsonl")
                if trace.is_file():
                    shutil.copyfile(trace, folder / trace.name)
            except Exception as error:
                result["failures"].append(f"EVIDENCE_COLLECTION_FAILED: {error}")
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
