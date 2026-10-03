#!/usr/bin/env python3
"""Cloud-only bounded native hold/Pause/render proof; never a durable hold save.

The installed startup, Run, Bridge, Pause, input, audio, Profile and speech owners
execute with one explicitly injected DTL locator and a blank scene proxy. Native
completion-intent counting is a separate test; this proof preserves the installed
completion owner and claims no canonical contact or Hospital completion.
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


SCRIPT = "res://tests/integration/verify_timed_hold_journey.gd"
FIXTURE = "tests/fixtures/dialogic/timed_hold_journey.dtl"
CAPTURES = ("01-hold.png", "02-pause.png", "03-caption.png")
SILENT = ("hold", "after_inert_inputs", "paused", "paused_after_deadline", "resumed")
STAGES = SILENT + ("caption_held", "caption_released", "completed")
LIFETIME = re.compile(r"ObjectDB instances leaked|Leaked instance:|Resource still in use:|Orphan StringName:|"
                      r"resources still in use at exit", re.IGNORECASE)


def require(condition: bool, detail: str) -> None:
    if not condition:
        raise RuntimeError(detail)


def strict_json(raw: str) -> dict:
    def pairs(items: list[tuple[str, object]]) -> dict:
        value = {}
        for key, item in items:
            require(key not in value, f"DUPLICATE_JSON_KEY: {key}")
            value[key] = item
        return value

    def constant(value: str) -> None:
        raise ValueError(f"NONFINITE_JSON_NUMBER: {value}")

    def finite(value: str) -> float:
        number = float(value)
        require(math.isfinite(number), "NONFINITE_JSON_NUMBER")
        return number

    value = json.loads(raw, object_pairs_hook=pairs, parse_constant=constant, parse_float=finite)
    require(isinstance(value, dict), "JSON_OBJECT_REQUIRED")
    return value


def identity(path: Path) -> dict:
    raw = path.read_bytes()
    return {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}


def strict_process_failures(process: dict, log: Path) -> list[str]:
    failures = cloud.process_failures(process, log)
    for path in (Path(process["stdout"]), Path(process["stderr"]), log):
        if path.is_file():
            for line in cloud.read_log(path).splitlines():
                if LIFETIME.search(line) or "TIMED_HOLD_JOURNEY_FAIL:" in line:
                    failures.append(f"{path.name}: {line.strip()}")
    return list(dict.fromkeys(failures))


def audit_report(report: dict, folder: Path, user_dir: Path, process_identity: dict) -> dict:
    require(type(report["schema_version"]) is int and report["schema_version"] == 1, "REPORT_SCHEMA")
    require(type(report["process_id"]) is int and report["process_id"] > 0, "REAL_PROCESS_ID_REQUIRED")
    require(process_identity == {"process_id": report["process_id"], "user_dir": report["user_dir"]},
            "STDOUT_REPORT_IDENTITY_MISMATCH")
    require(Path(report["user_dir"]).is_absolute() and Path(report["user_dir"]).resolve() == user_dir.resolve(),
            "EXACT_ISOLATED_USER_DIR_REQUIRED")
    require(report["entry_id"] == "contact.ordinary.lavinia.day1"
            and report["line_id"] == "fixture.timed_hold.after", "EXACT_FIXTURE_IDENTITIES_REQUIRED")
    require(report["hold_seconds"] == 2.0 and report["pause_seconds"] == 2.4, "NONCANONICAL_DURATION")
    stages = report["stages"]
    require(set(stages) == set(STAGES), "EXACT_OBSERVATION_STAGE_SET")
    ticks = [stages[name]["tick_msec"] for name in STAGES]
    require(all(type(value) is int for value in ticks) and ticks == sorted(ticks), "MONOTONIC_STAGES")
    before = (folder / "profile-before.json").read_bytes()
    require(before == (folder / "profile-after-hold.json").read_bytes(), "PROFILE_BYTES_CHANGED_DURING_HOLD")
    require(strict_json(before.decode("utf-8")) == report["baseline_profile"], "RAW_PROFILE_REPORT_MISMATCH")
    require(report["baseline_profile"]["preferences"]["reading"]["auto_enabled"] is True,
            "LOGICAL_AUTO_ON_REQUIRED")
    require(report["baseline_native_history"] == [] and report["baseline_native_visits"] == {},
            "FRESH_EMPTY_NATIVE_HISTORY_REQUIRED")
    owner = report["baseline_completion_owner"]
    require(owner["instance_id"] == owner["bridge_owner_id"] and owner["instance_id"] > 0
            and owner["_status"] == "idle", "UNCHANGED_INSTALLED_COMPLETION_OWNER_REQUIRED")
    frontier = stages["hold"]["frontier"]
    require(frontier["kind"] == "timed_hold" and bool(frontier["execution_token"]), "OWNED_TIMED_HOLD_TOKEN")
    rail_geometry = None
    for name in SILENT:
        state = stages[name]
        projection = state["projection"]
        require(state["frontier"] == frontier, f"STABLE_OWNED_FRONTIER: {name}")
        native = state["native_pause_frontier"]
        require(native["ok"] is True and native["value"]["paused"] == state["native_paused"]
                and {key: value for key, value in native["value"].items() if key != "paused"} == frontier
                and state["native_timer_identity_matches"] is True, f"SAME_NATIVE_TIMER_AND_NORMALIZED_FRONTIER: {name}")
        require(projection["timed_hold"] is True and projection["caption_visible"] is False
                and projection["revealing"] is False and projection["leaf_rects"] == []
                and projection["visible_leaf_rects"] == [] and projection["caption_window"] == []
                and projection["caption_rect"]["width"] == 0 and projection["caption_rect"]["height"] == 0,
                f"CAPTIONLESS_PRESENTATION_REQUIRED: {name}")
        require(state["caption_text"] == "" and state["caption_focus"] is False
                and state["caption_visible"] is False and state["caption_revealing"] is False
                and state["retained"] == [] and state["scrollback"] == [] and state["background_filter"] == 2,
                f"NO_HIDDEN_TEXT_FOCUS_OR_APERTURE: {name}")
        require(state["text_counts"] == {"about": 0, "started": 0, "finished": 0}
                and state["speech_admissions"] == 0 and state["native_ends"] == 0 and state["wait_finishes"] == 0,
                f"ZERO_NATIVE_PUBLICATIONS_OR_COMPLETIONS: {name}")
        require(state["native_history"] == [] and state["native_visits"] == {}
                and state["reading_history"]["ok"] is False and state["reading_checkpoint"]["ok"] is False
                and state["speech_publication"]["ok"] is False
                and state["can_save_backup"] is False and state["can_capture_reading_checkpoint"] is False,
                f"NO_LEDGER_SAVE_OR_SPEECH: {name}")
        require(state["profile"] == report["baseline_profile"] and state["profile_bytes_equal"] is True
                and state["completion_owner"] == owner, f"NO_DURABLE_OR_CANONICAL_SIDE_EFFECT: {name}")
        rail = state["rail"]
        require([button["key"] for button in rail] == ["history", "skip", "auto", "save", "load", "next"]
                and all(button["disabled"] is True and button["focus_mode"] == 0
                        and button["focused"] is False for button in rail), f"SIX_DISABLED_RAIL_ACTIONS: {name}")
        geometry = [button["rect"] for button in rail]
        if rail_geometry is None:
            rail_geometry = geometry
        require(geometry == rail_geometry, f"STATIONARY_RAIL_GEOMETRY: {name}")
    paused, late, resumed = (stages[name] for name in ("paused", "paused_after_deadline", "resumed"))
    require(all(state["tree_paused"] is True and state["native_paused"] is True
                and state["pause_state"]["value"]["state"] == "Suspended"
                and state["can_load_backup"] is True for state in (paused, late)),
            "REAL_PAUSE_CUSTODY_REQUIRED")
    require(late["tick_msec"] - paused["tick_msec"] >= 2300
            and abs(late["elapsed_seconds"] - paused["elapsed_seconds"]) < 0.000001,
            "ACTUAL_TIMER_MUST_FREEZE_BEYOND_ORIGINAL_DURATION")
    require(resumed["tree_paused"] is False and resumed["native_paused"] is False
            and resumed["pause_state"]["value"]["state"] == "Active"
            and 0 <= resumed["elapsed_seconds"] - paused["elapsed_seconds"] < 0.15
            and 0 <= resumed["elapsed_seconds"] < 2.0, "RESUME_MUST_KEEP_REMAINING_DURATION")
    held, released = stages["caption_held"], stages["caption_released"]
    for name, state in (("caption_held", held), ("caption_released", released)):
        require(state["projection"]["timed_hold"] is False and state["caption_visible"] is True
                and state["caption_focus"] is True and state["caption_text"].startswith("The timed hold has finished.")
                and state["text_counts"]["about"] == state["text_counts"]["started"] == 1
                and state["wait_finishes"] == 1 and state["native_ends"] == 0
                and state["completion_owner"] == owner, f"HELD_INPUT_CANNOT_ACCEPT_REAL_CAPTION: {name}")
    require((held["tick_msec"] - resumed["tick_msec"]) / 1000 >= 2.0 - resumed["elapsed_seconds"] - 0.15,
            "NO_EARLY_TEXT_AFTER_RESUME")
    require(released["speech_admissions"] == 1 and released["speech_publication"]["ok"] is True,
            "REAL_CAPTION_POSITIVE_SPEECH_PUBLICATION")
    completed = stages["completed"]
    require(completed["native_ends"] == completed["wait_finishes"] == 1 and completed["completion_owner"] == owner
            and completed["text_counts"] == {"about": 1, "started": 1, "finished": 1}
            and completed["speech_admissions"] == 1, "ONE_NATIVE_END_AFTER_FRESH_INPUT")
    events = report["events"]
    require([event["sequence"] for event in events] == list(range(1, len(events) + 1)), "CONTIGUOUS_EVENT_TRACE")
    for kind in ("text_about", "text_started", "text_finished", "speech_admitted"):
        require(sum(event["kind"] == kind for event in events) == 1, f"EXACT_POSITIVE_EVENT_COUNT: {kind}")
    require(all(event["tick_msec"] >= resumed["tick_msec"] for event in events if event["kind"] != "stage"),
            "NO_TEXT_OR_SPEECH_BEFORE_RESUME")
    return {"status": "pass_bounded_ephemeral_hold", "process_id": report["process_id"],
            "execution_token": frontier["execution_token"], "profile_identity": identity(folder / "profile-before.json"),
            "pause_elapsed_seconds": (late["tick_msec"] - paused["tick_msec"]) / 1000,
            "timer_elapsed_before_pause": paused["elapsed_seconds"],
            "timer_elapsed_after_pause": late["elapsed_seconds"], "native_wait_finishes": 1, "native_timeline_ends": 1,
            "excluded": ["production authored duration", "semantic reading ledger admission", "mid-hold save/restore",
                         "canonical contact/Hospital completion", "native hardware input", "audible speech quality",
                         "OS accessibility-tree and screen-reader verification",
                         "cancel/replace old-deadline proof (separate native regression)"]}


def run() -> int:
    repository = Path(__file__).resolve().parents[2]
    output = cloud.make_directory(repository, repository / ".godot/ci/timed-hold")
    folder = cloud.make_directory(repository, output / str(uuid4()))
    isolation = cloud.make_directory(repository, repository / ".godot/phase2r_tests" / str(uuid4()))
    cloud.TIMEOUT_SECONDS = 180
    result = {"schema_version": 1, "ok": False, "started_at_utc": cloud.utc_now(),
              "artifact_root": str(folder), "isolation_root": str(isolation), "processes": {}, "failures": []}
    user_dir = None
    try:
        require(sys.platform == "linux" and os.environ.get("GITHUB_ACTIONS") == "true", "GITHUB_ACTIONS_LINUX_ONLY")
        configured = os.environ.get("GODOT_CONSOLE_PATH", "").strip()
        godot = shutil.which(configured) if configured else None
        xvfb = shutil.which("xvfb-run")
        require(godot is not None and xvfb is not None, "GODOT_CONSOLE_PATH_AND_XVFB_REQUIRED")
        result["checkout_sha"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repository, text=True).strip()
        result["workflow"] = {key: os.environ.get(key, "") for key in
                              ("GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT", "GITHUB_JOB", "GITHUB_SHA")}
        result["source_identity"] = {str(path.relative_to(repository)): identity(path) for path in (
            Path(__file__).resolve(), repository / "tools/testing/run_cloud_journeys.py", repository / FIXTURE,
            repository / SCRIPT.removeprefix("res://"), repository / "addons/dialogic/Modules/Wait/event_wait.gd",
            repository / "scripts/narrative/DialogicRuntimeAdapter.gd",
            repository / "scripts/ui/witnessed/WitnessedCaptionLayer.gd")}
        env = os.environ.copy()
        for key, suffix in (("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"),
                            ("XDG_CACHE_HOME", "cache"), ("DWM_TEST_ROOT", "test-root")):
            env[key] = str(cloud.make_directory(repository, isolation / suffix))
        env.update({"LIBGL_ALWAYS_SOFTWARE": "1", "GALLIUM_DRIVER": "llvmpipe"})
        result["isolated_environment"] = {key: env[key] for key in (
            "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "DWM_TEST_ROOT", "LIBGL_ALWAYS_SOFTWARE", "GALLIUM_DRIVER")}
        version = cloud.run_process([godot, "--version"], env, repository, folder, "engine-version")
        result["processes"]["engine-version"] = version
        version_text = cloud.read_log(Path(version["stdout"])).strip()
        require(version["exit_code"] == 0 and not version["timed_out"]
                and re.fullmatch(r"4\.6\.3\.stable\.official\.[0-9a-f]+", version_text) is not None
                and not cloud.read_log(Path(version["stderr"])).strip(), "GODOT_4_6_3_STANDARD_REQUIRED")
        result["engine_version"] = version_text
        proof_log = folder / "user-dir-proof.log"
        proof = cloud.run_process([godot, "--headless", "--path", str(repository), "--log-file", str(proof_log),
                                   "--script", "res://tools/evidence/print_user_dir.gd"], env, repository, folder, "user-dir-proof")
        result["processes"]["user-dir-proof"] = proof
        require(not strict_process_failures(proof, proof_log), "USER_DIR_PROOF_FAILED")
        markers = re.findall(r"^PHASE2R_USER_DIR=(.+)$", cloud.read_log(Path(proof["stdout"])), re.MULTILINE)
        require(len(markers) == 1 and Path(markers[0].strip()).is_absolute(), "EXACT_ABSOLUTE_USER_DIR_PROOF")
        user_dir = cloud.contained_path(isolation, Path(markers[0].strip()))
        cloud.contained_path(Path(env["XDG_DATA_HOME"]), user_dir)
        result["user_dir"] = str(user_dir)
        log = folder / "journey.log"
        process = cloud.run_process([xvfb, "-a", "-s", "-screen 0 1920x1080x24", godot,
            "--path", str(repository), "--verbose", "--rendering-method", "gl_compatibility",
            "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--log-file", str(log),
            "--script", SCRIPT, "--", "--phase2r-bootstrap-mode=final"], env, repository, folder, "journey")
        result["processes"]["journey"] = process
        failures = strict_process_failures(process, log)
        require(not failures, "JOURNEY_PROCESS_FAILED: " + "; ".join(failures))
        stdout = cloud.read_log(Path(process["stdout"]))
        require(cloud.marker_count(stdout, "TIMED_HOLD_JOURNEY_PASS") == 1, "ONE_PASS_MARKER_REQUIRED")
        markers = re.findall(r"^TIMED_HOLD_PROCESS: (.+)$", stdout, re.MULTILINE)
        require(len(markers) == 1, "ONE_GODOT_PROCESS_IDENTITY_REQUIRED")
        process_identity = strict_json(markers[0])
        evidence = cloud.contained_path(user_dir, user_dir / "evidence/timed-hold")
        for name in ("journey.json", "profile-before.json", "profile-after-hold.json"):
            source = cloud.contained_path(evidence, evidence / name)
            target = cloud.contained_path(folder, folder / name)
            shutil.copyfile(source, target)
            require(identity(source) == identity(target), f"EXACT_RAW_COPY_REQUIRED: {name}")
        report = strict_json((folder / "journey.json").read_text(encoding="utf-8"))
        result["audit"] = audit_report(report, folder, user_dir, process_identity)
        captures, failures = cloud.collect_captures(repository, user_dir, folder,
                                                   {"evidence_folder": "timed-hold", "captures": CAPTURES})
        result["captures"] = captures
        require(not failures, "CAPTURE_VALIDATION_FAILED: " + "; ".join(failures))
        require(all(capture["width"] == 1280 and capture["height"] == 720 for capture in captures),
                "EXACT_LOGICAL_RENDER_SIZE_REQUIRED")
        result["ok"] = True
    except Exception as error:
        result["failures"].append(str(error))
        print(f"TIMED_HOLD_RENDERED_FAIL: {error}", file=sys.stderr, flush=True)
    finally:
        if user_dir is not None:
            evidence = cloud.contained_path(user_dir, user_dir / "evidence/timed-hold")
            # Preserve original failed observations too; nothing retries inside this runner.
            for source in sorted(evidence.glob("*")):
                source = cloud.contained_path(evidence, source)
                if source.is_file() and source.suffix in (".json", ".png"):
                    target = cloud.contained_path(folder, folder / ("raw-" + source.name))
                    shutil.copyfile(source, target)
        result["ended_at_utc"] = cloud.utc_now()
        cloud.write_json(folder / "results.json", result)
        cloud.write_json(output / "results.json", result)
        cloud.write_json(folder / "file-manifest.json", {str(path.relative_to(folder)): identity(path)
                         for path in sorted(folder.rglob("*")) if path.is_file() and path.name != "file-manifest.json"})
    if result["ok"]:
        print("TIMED_HOLD_RENDERED_VERIFIED: one ephemeral native hold, actual Pause, real caption and fresh input", flush=True)
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(run())
