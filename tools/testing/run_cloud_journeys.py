#!/usr/bin/env python3
"""Run isolated rendered Linux journeys; retain every case's failures and evidence.

Requires the imported project, GODOT_CONSOLE_PATH, xvfb-run and Mesa software GL.
The two Practice cases deliberately distinguish an empty canonical DTL from an
explicitly seeded historical compatibility record. Neither fixture earns an ending.
"""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import struct
import subprocess
import sys
import time
from datetime import datetime, timezone
from uuid import uuid4


TIMEOUT_SECONDS = 600
STARTUP_SCRIPT = "res://tests/integration/verify_playable_startup.gd"
REHEARSAL_SCRIPT = "res://tests/integration/verify_playable_rehearsal.gd"
BASE_CAPTURES = ("01-title.png", "02-desktop.png", "03-minesweeper.png")
PRACTICE_CAPTURES = (
    "01-title-with-explicit-milestone-fixture.png",
    "02-canonical-empty-date-board.png",
    "03-canonical-board-before-pause.png",
    "04-confirm-return-from-canonical-date.png",
)
CASES = (
    {
        "id": "seven-days-ending-gallery",
        "script": STARTUP_SCRIPT,
        "flags": ("--probe-seven-days", "--probe-ending", "--probe-gallery"),
        "markers": (
            "PLAYABLE_STARTUP_PASS", "PLAYABLE_DAY_PASS", "PLAYABLE_SEVEN_DAY_PASS",
            "PLAYABLE_ENDING_PASS", "PLAYABLE_GALLERY_PASS",
        ),
        "evidence_folder": "playable",
        "captures": BASE_CAPTURES + ("09-gallery.png",),
        "fixture_scope": "No prior ending or reached-presentation fixture.",
    },
    {
        "id": "seven-days-condition-ending",
        "script": STARTUP_SCRIPT,
        "flags": ("--probe-seven-days", "--probe-day7-condition"),
        "markers": (
            "PLAYABLE_STARTUP_PASS", "PLAYABLE_DAY_PASS", "PLAYABLE_SEVEN_DAY_PASS",
            "PLAYABLE_DAY7_CONDITION_PASS",
        ),
        "evidence_folder": "playable",
        "captures": BASE_CAPTURES,
        "fixture_scope": "No prior ending or reached-presentation fixture.",
    },
    {
        "id": "dating-reload",
        "script": STARTUP_SCRIPT,
        "flags": ("--probe-dating", "--probe-dating-reload"),
        "markers": ("PLAYABLE_STARTUP_PASS", "PLAYABLE_DATING_RELOAD_PASS", "PLAYABLE_DATING_PASS"),
        "evidence_folder": "playable",
        "captures": BASE_CAPTURES + ("04-dating-entry.png", "05-dating-board.png"),
        "fixture_scope": "No prior ending or reached-presentation fixture; empty DTL earns no signature.",
    },
    {
        "id": "practice-empty-dtl",
        "script": REHEARSAL_SCRIPT,
        "flags": ("--prior-ending-fixture",),
        "markers": ("PRACTICE_FIXTURE", "PLAYABLE_EMPTY_DTL_PRACTICE_PASS"),
        "forbidden_markers": ("PRACTICE_LEGACY_FIXTURE", "PLAYABLE_REHEARSAL_LEGACY_PASS"),
        "evidence_folder": "practice",
        "captures": PRACTICE_CAPTURES + ("05-empty-practice-picker.png",),
        "fixture_scope": "Prior-ending milestone only. Canonical empty DTL must leave Practice empty.",
    },
    {
        "id": "practice-legacy-compatibility",
        "script": REHEARSAL_SCRIPT,
        "flags": ("--prior-ending-fixture", "--legacy-reached-fixture"),
        "markers": ("PRACTICE_FIXTURE", "PRACTICE_LEGACY_FIXTURE", "PLAYABLE_REHEARSAL_LEGACY_PASS"),
        "forbidden_markers": ("PLAYABLE_EMPTY_DTL_PRACTICE_PASS",),
        "evidence_folder": "practice",
        "captures": PRACTICE_CAPTURES + (
            "05-practice-exact-reached-picker.png", "06-practice-board.png",
            "07-return-to-picker.png", "08-return-gallery.png",
        ),
        "fixture_scope": (
            "Explicit prior-ending and historical reached-signature fixtures. Private-board "
            "compatibility evidence only; never evidence that empty canonical DTL was witnessed."
        ),
    },
)
ERROR_PATTERN = re.compile(
    r"SCRIPT ERROR:|(?:^|\s)ERROR:|Unicode parsing error|Unexpected NUL character|"
    r"Parse Error:|\bPLAYABLE_[A-Z0-9_]*_FAIL:", re.MULTILINE,
)
ANSI_PATTERN = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def contained_path(root: Path, candidate: Path, *, strict: bool = True) -> Path:
    """Check lexical containment and every existing component before resolving links."""
    base = Path(os.path.abspath(root))
    path = Path(os.path.abspath(candidate))
    try:
        relative = path.relative_to(base)
    except ValueError as error:
        raise RuntimeError(f"PATH_OUTSIDE_ROOT: {path} is outside {base}") from error
    if strict and path == base:
        raise RuntimeError(f"PATH_NOT_STRICT_DESCENDANT: {path}")
    cursor = base
    for component in ("", *relative.parts):
        if component:
            cursor = cursor / component
        if cursor.is_symlink():
            raise RuntimeError(f"PATH_SYMLINK: {cursor}")
    return path


def make_directory(root: Path, directory: Path) -> Path:
    directory = contained_path(root, directory)
    directory.mkdir(parents=True, exist_ok=True)
    return contained_path(root, directory)


def write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def stop_process_group(process: subprocess.Popen) -> None:
    """Retire Xvfb and Godot together so a timed-out case cannot affect its successor."""
    for sig in (signal.SIGTERM, signal.SIGKILL):
        try:
            os.killpg(process.pid, sig)
        except ProcessLookupError:
            return
        try:
            process.wait(timeout=5)
            # The leader can exit before a child. Retire any surviving group members.
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            return
        except subprocess.TimeoutExpired:
            continue
    raise RuntimeError("WATCHDOG_PROCESS_GROUP_DID_NOT_EXIT")


def run_process(argv: list[str], env: dict[str, str], repository: Path, folder: Path, phase: str) -> dict:
    stdout_path = folder / f"{phase}.stdout.txt"
    stderr_path = folder / f"{phase}.stderr.txt"
    receipt = {
        "argv": argv, "started_at_utc": utc_now(), "timeout_seconds": TIMEOUT_SECONDS,
        "stdout": str(stdout_path), "stderr": str(stderr_path), "timed_out": False,
    }
    started = time.monotonic()
    write_json(folder / f"{phase}.process.json", receipt)
    try:
        with stdout_path.open("wb") as stdout, stderr_path.open("wb") as stderr:
            process = subprocess.Popen(
                argv, cwd=repository, env=env, stdin=subprocess.DEVNULL,
                stdout=stdout, stderr=stderr, start_new_session=True,
            )
            try:
                receipt["exit_code"] = process.wait(timeout=TIMEOUT_SECONDS)
            except subprocess.TimeoutExpired:
                receipt["timed_out"] = True
                stop_process_group(process)
                receipt["exit_code"] = process.returncode
            except BaseException:
                stop_process_group(process)
                raise
    except Exception as error:
        receipt["process_error"] = str(error)
        raise
    finally:
        receipt["ended_at_utc"] = utc_now()
        receipt["elapsed_seconds"] = round(time.monotonic() - started, 3)
        write_json(folder / f"{phase}.process.json", receipt)
    return receipt


def read_log(path: Path) -> str:
    return ANSI_PATTERN.sub("", path.read_text(encoding="utf-8", errors="replace"))


def process_failures(receipt: dict, log_path: Path) -> list[str]:
    failures = []
    if receipt["timed_out"]:
        failures.append(f"WATCHDOG_TIMEOUT: {TIMEOUT_SECONDS} seconds")
    if receipt["exit_code"] != 0:
        failures.append(f"PROCESS_EXIT: {receipt['exit_code']}")
    for path in (Path(receipt["stdout"]), Path(receipt["stderr"]), log_path):
        if not path.is_file():
            failures.append(f"LOG_MISSING: {path.name}")
            continue
        lines = read_log(path).splitlines()
        for index, line in enumerate(lines):
            if ERROR_PATTERN.search(line):
                # Preserve bounded engine locations/backtraces in supported job logs.
                # Artifact downloads may be unavailable to the diagnosing client.
                context = "\n    ".join(item.strip() for item in lines[index:index + 6])
                failures.append(f"{path.name}: {context}")
        resource_details = [line.strip() for line in lines if re.search(
            r"Leaked instance:|Resource still in use:|Orphan StringName:", line,
        )]
        if resource_details:
            failures.append(f"{path.name}: LIFETIME_DIAGNOSTICS count={len(resource_details)}\n    "
                            + "\n    ".join(resource_details[:80]))
    return list(dict.fromkeys(failures))


def marker_count(text: str, marker: str) -> int:
    return len(re.findall(r"^" + re.escape(marker) + r":", text, re.MULTILINE))


def collect_captures(repository: Path, user_dir: Path, folder: Path, case: dict) -> tuple[list[dict], list[str]]:
    source = contained_path(user_dir, user_dir / "evidence" / case["evidence_folder"])
    target = make_directory(repository, folder / "captures")
    captures, failures = [], []
    for path in sorted(source.glob("*.png")):
        path = contained_path(user_dir, path)
        raw = path.read_bytes()
        if len(raw) < 24 or raw[:8] != b"\x89PNG\r\n\x1a\n" or raw[12:16] != b"IHDR":
            failures.append(f"INVALID_PNG: {path.name}")
            continue
        width, height = struct.unpack(">II", raw[16:24])
        if width == 0 or height == 0:
            failures.append(f"EMPTY_PNG: {path.name}")
            continue
        destination = contained_path(repository, target / path.name)
        shutil.copyfile(path, destination)
        captures.append({
            "file": str(destination), "source": str(path), "width": width, "height": height,
            "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest(),
        })
    actual = {Path(capture["file"]).name for capture in captures}
    expected = set(case["captures"])
    failures.extend(f"CAPTURE_MISSING: {name}" for name in sorted(expected - actual))
    failures.extend(f"CAPTURE_UNEXPECTED: {name}" for name in sorted(actual - expected))
    return captures, failures


def run_case(repository: Path, output: Path, godot: str, xvfb: str, case: dict) -> dict:
    result = {"case_id": case["id"], "fixture_scope": case["fixture_scope"], "ok": False, "failures": []}
    folder = make_directory(repository, output / case["id"])
    isolation = make_directory(repository, repository / ".godot" / "phase2r_tests" / str(uuid4()))
    env = os.environ.copy()
    for key, suffix in (
        ("XDG_DATA_HOME", "data"), ("DWM_TEST_ROOT", "test-root"),
        ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache"),
    ):
        env[key] = str(make_directory(repository, isolation / suffix))
    env.update({"LIBGL_ALWAYS_SOFTWARE": "1", "GALLIUM_DRIVER": "llvmpipe"})
    result.update({"isolation_root": str(isolation), "environment": {
        key: env[key] for key in (
            "XDG_DATA_HOME", "DWM_TEST_ROOT", "XDG_CONFIG_HOME", "XDG_CACHE_HOME",
            "LIBGL_ALWAYS_SOFTWARE", "GALLIUM_DRIVER",
        )
    }})
    user_dir = None
    try:
        proof_log = folder / "user-dir-proof.log"
        proof = run_process([
            godot, "--headless", "--path", str(repository), "--log-file", str(proof_log),
            "--script", "res://tools/evidence/print_user_dir.gd",
        ], env, repository, folder, "user-dir-proof")
        result["user_dir_proof"] = proof
        proof_failures = process_failures(proof, proof_log)
        if proof_failures:
            raise RuntimeError("USER_DIR_PROOF_FAILED: " + "; ".join(proof_failures))
        markers = re.findall(r"^PHASE2R_USER_DIR=(.+)$", read_log(Path(proof["stdout"])), re.MULTILINE)
        if len(markers) != 1:
            raise RuntimeError(f"USER_DIR_MARKER_COUNT: {len(markers)}")
        raw_user_dir = Path(markers[0].strip())
        if not raw_user_dir.is_absolute():
            raise RuntimeError("USER_DIR_NOT_ABSOLUTE")
        contained_path(repository, isolation)
        user_dir = contained_path(isolation, raw_user_dir)
        contained_path(Path(env["XDG_DATA_HOME"]), user_dir)
        result["user_dir"] = str(user_dir)
        result["user_dir_strictly_contained"] = True
        # Gameplay is admitted only after a real Godot process proves this exact isolated user directory.
        log = folder / "journey.log"
        argv = [
            xvfb, "-a", "-s", "-screen 0 1920x1080x24", godot,
            "--path", str(repository), "--verbose", "--rendering-method", "gl_compatibility",
            "--rendering-driver", "opengl3", "--audio-driver", "Dummy",
            "--log-file", str(log), "--script", case["script"], "--",
            "--phase2r-bootstrap-mode=final", "--render-evidence", *case["flags"],
        ]
        process = run_process(argv, env, repository, folder, "journey")
        result["journey"] = process
        result["failures"].extend(process_failures(process, log))
        stdout = read_log(Path(process["stdout"]))
        result["markers"] = {marker: marker_count(stdout, marker) for marker in case["markers"]}
        for marker, count in result["markers"].items():
            if count != 1:
                result["failures"].append(f"REQUIRED_MARKER_COUNT: {marker} = {count}")
        for marker in case.get("forbidden_markers", ()):
            if marker_count(stdout, marker):
                result["failures"].append(f"WRONG_FIXTURE_BRANCH: {marker}")
    except Exception as error:
        result["failures"].append(f"{type(error).__name__}: {error}")
    finally:
        if user_dir is not None:
            try:
                contained_path(isolation, user_dir)
                result["captures"], capture_failures = collect_captures(repository, user_dir, folder, case)
                result["failures"].extend(capture_failures)
            except Exception as error:
                result["failures"].append(f"CAPTURE_COLLECTION_FAILED: {error}")
        result["ok"] = not result["failures"]
        write_json(folder / "result.json", result)
    return result


def main() -> int:
    repository = Path(__file__).resolve().parents[2]
    output = make_directory(repository, repository / ".godot" / "ci" / "playable-journeys")
    run_output = make_directory(repository, output / str(uuid4()))
    summary = {"started_at_utc": utc_now(), "run_output": str(run_output), "ok": False, "cases": []}
    try:
        if sys.platform != "linux":
            raise RuntimeError("This runner requires Linux and xvfb-run.")
        if not (repository / "project.godot").is_file():
            raise RuntimeError("PROJECT_ROOT_INVALID")
        configured = os.environ.get("GODOT_CONSOLE_PATH", "").strip()
        godot = shutil.which(configured) if configured else None
        xvfb = shutil.which("xvfb-run")
        if godot is None or xvfb is None:
            raise RuntimeError("GODOT_CONSOLE_PATH executable and xvfb-run are required.")
        for case in CASES:
            print(f"PLAYABLE_JOURNEY_BEGIN: {case['id']}", flush=True)
            try:
                result = run_case(repository, run_output, godot, xvfb, case)
            except Exception as error:
                result = {"case_id": case["id"], "fixture_scope": case["fixture_scope"],
                          "ok": False, "failures": [f"CASE_SETUP_FAILED: {error}"]}
            summary["cases"].append(result)
            with (output / "runs.jsonl").open("a", encoding="utf-8") as stream:
                stream.write(json.dumps(result, ensure_ascii=False) + "\n")
            status = "PASS" if result["ok"] else "FAIL"
            print(f"PLAYABLE_JOURNEY_{status}: {case['id']}", flush=True)
            for failure in result["failures"]:
                print(f"  {failure}", flush=True)
        summary["ok"] = len(summary["cases"]) == len(CASES) and all(case["ok"] for case in summary["cases"])
    except Exception as error:
        summary["setup_failure"] = str(error)
        print(f"PLAYABLE_JOURNEYS_SETUP_FAIL: {error}", file=sys.stderr, flush=True)
    finally:
        summary["ended_at_utc"] = utc_now()
        write_json(run_output / "results.json", summary)
        write_json(output / "results.json", summary)
    if summary["ok"]:
        print(f"PLAYABLE_JOURNEYS_VERIFIED: {len(CASES)} isolated rendered cases", flush=True)
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
