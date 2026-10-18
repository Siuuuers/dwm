#!/usr/bin/env python3
"""Bind prepared-graph observations to raw diagnostic-native process evidence.

No original result is changed. This is offline analysis, not a new player gate.
"""
import argparse
from bisect import bisect_left
from datetime import datetime, timezone
from decimal import Decimal
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

from prepare_package import BUILD_NAME, ENGINE_COMMIT, ENGINE_TREE, GAME_COMMIT, GAME_TREE, ORIGINAL

CAPTION = "TEST Seven-day ending."
TOOL_PREFIX = "tools/diagnostics/ending-publication-20261019/"
NATIVE_PATHS = {"drivers/accesskit/accessibility_driver_accesskit.cpp",
                "drivers/accesskit/accessibility_driver_accesskit.h"}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def utc_us(value):
    stamp = datetime.fromisoformat(value.replace("Z", "+00:00"))
    require(stamp.tzinfo is not None, "Native timestamp lacks a time zone")
    delta = stamp.astimezone(timezone.utc) - datetime(1970, 1, 1, tzinfo=timezone.utc)
    return delta.days * 86400000000 + delta.seconds * 1000000 + delta.microseconds


def bind_caption_clocks(trace_data, target_samples):
    """Reject inconsistent process-clock origins; do not certify clock accuracy."""
    anchors = []
    for row in map(json.loads, trace_data.decode("utf-8").splitlines()):
        for prefix in ["", "capture_start_", "capture_end_"]:
            if prefix + "ticks_us" in row:
                anchors.append((int(row[prefix + "ticks_us"]), int(row[prefix + "unix_us"]), row["seq"], prefix or "record_"))
    anchors.sort()
    ticks = [anchor[0] for anchor in anchors]
    checks = []
    for key, samples in sorted(target_samples.items()):
        require(len({sample["node_id"] for sample in samples}) == 1,
                "A caption window/RID changed its project node identity")
        for sample in samples:
            tick, wall = sample["snapshot_ticks_us"], int(sample["snapshot_unix_us"])
            require(type(tick) is int and 0 <= tick < (1 << 64) and
                    type(sample["callback_ticks_us"]) is int and 0 <= sample["callback_ticks_us"] <= tick,
                    "Caption callback/snapshot tick order is invalid")
            finished = sample["text_finished_ticks_us"]
            require(type(finished) is int and (finished == -1 or 0 <= finished <= tick),
                    "Caption text-completion tick is outside its snapshot history")
            index = bisect_left(ticks, tick)
            require(0 < index < len(anchors), "Caption snapshot lacks bracketing native clock observations")
            pair = anchors[index - 1:index + 1]
            offsets = [anchor[1] - anchor[0] for anchor in pair]
            # GDScript serializes Unix seconds as a floating-point JSON value.
            # This explicit consistency tolerance only rejects incompatible origins.
            # It neither moves a driver cutoff nor proves microsecond clock accuracy.
            require(min(offsets) - 2000 <= wall - tick <= max(offsets) + 2000,
                    "Caption/native clock origins are inconsistent")
            checks.append({"window_id": key[0], "rid": key[1], "caption_line": sample["line"],
                "snapshot_offset_us": str(wall - tick), "serialization_consistency_tolerance_us": 2000,
                "native_brackets": [{"ticks_us": str(anchor[0]), "unix_us": str(anchor[1]),
                    "record_seq": anchor[2], "sample": anchor[3]} for anchor in pair]})
    return checks


def bind(out, reader):
    report = {"schema_version": 1, "binding_ok": False, "same_ending_failure_reproduced": False,
              "official_original_load_ok": False, "official_acceptance_established": False,
              "scope": "Prepared graph at recorded capture times; no adapter acceptance claim",
              "input_files": {}, "native_outcomes": {}, "errors": [], "selected_observations": [],
              "timing_note": "Capture end precedes row serialization/write/flush and factory return. Wall-clock values are observations, not a clock-accuracy attestation.",
              "coverage_note": "Missing footer permits complete-prefix observations only; no continuous or final-state guarantee."}

    def raw(name):
        data = (out / name).read_bytes()
        report["input_files"][name] = {"bytes": len(data), "sha256": sha(data)}
        return data

    def read(name):
        return json.loads(raw(name).decode("utf-8-sig"))

    try:
        origin = read("audit-origin.json")
        build = read("native-build/build-receipt.json")
        package = read("native-diagnostic/validation.json")
        require(origin["game_commit"] == GAME_COMMIT and origin["game_tree"] == GAME_TREE,
                "Game source identity mismatch")
        require(build["ok"] is True and build["source_commit"] == ENGINE_COMMIT and
                build["source_tree"] == ENGINE_TREE and build["build_name"] == BUILD_NAME,
                "Native source/build identity mismatch")
        require(package["ok"] is True and package["diagnostic"] is True and package["commit"] == GAME_COMMIT and
                package["original_package"] == ORIGINAL, "Diagnostic package provenance mismatch")
        files = {item["path"]: item for item in package["files"]}
        require(files["DWM.exe"]["sha256"] == build["template"]["sha256"] and
                files["DWM.pck"]["sha256"] == ORIGINAL["pck_sha256"], "Native/PCK receipt mismatch")
        require(sha(reader.read_bytes()) == origin["shared_source_pins"][TOOL_PREFIX + "replay/read_trace.py"]["sha256"],
                "Independent reader differs from pinned source")
        require(len(build["changed_files"]) == len(NATIVE_PATHS) and
                {change["path"] for change in build["changed_files"]} == NATIVE_PATHS,
                "Native changed-source census differs from the reviewed two files")
        for change in build["changed_files"]:
            for role, key in [("baseline", "base_sha256"), ("candidate", "candidate_sha256")]:
                name = TOOL_PREFIX + "native-probe/" + role + "/" + change["path"]
                require(sha(raw("source/" + name)) == change[key] == origin["shared_source_pins"][name]["sha256"],
                        "Native source bytes differ from build/tool receipt")
        patch_name = TOOL_PREFIX + "native-probe/publication-native-probe.patch"
        protocol_name = TOOL_PREFIX + "native-probe/PROTOCOL.md"
        require(sha(raw("source/" + patch_name)) == build["patch_sha256"] == origin["shared_source_pins"][patch_name]["sha256"] and
                sha(raw("source/" + protocol_name)) == build["protocol_sha256"] == origin["shared_source_pins"][protocol_name]["sha256"],
                "Patch/protocol receipt mismatch")
        modes = {}
        for mode in ["capability", "create", "load"]:
            result = read("exported-" + mode + "/result.json")
            process = read(mode + "-process.json")
            modes[mode] = result
            require(result["source_commit"] == GAME_COMMIT and result["archive_sha256"] == package["archive"]["sha256"] and
                    result["executable_sha256"] == build["template"]["sha256"] and
                    result["pck_sha256"] == ORIGINAL["pck_sha256"], "Original driver package hash mismatch: " + mode)
            require(result["renderer_request"] == "ProjectDefault" and result["accessibility_request"] == "Always" and
                    result["audio_request"] == "Dummy", "Original mode settings changed: " + mode)
            require(process["diagnostic_native"] is True and process["trace_enabled"] is (mode == "load"),
                    "Native trace mode custody mismatch: " + mode)
            report["native_outcomes"][mode] = {key: result.get(key) for key in
                ["ok", "exit_code", "failure", "clean_player_exit", "forced_cleanup", "source_commit",
                 "archive_sha256", "executable_sha256", "pck_sha256", "process"]}
            report["native_outcomes"][mode]["driver_exit_code"] = process["exit_code"]
            if mode != "load":
                require(result["ok"] is True and result["clean_player_exit"] is True and
                        result["forced_cleanup"] is False and result["exit_code"] == 0 and process["exit_code"] == 0,
                        "Prerequisite did not pass its original native gate: " + mode)
        load = modes["load"]
        report["same_ending_failure_reproduced"] = (load["ok"] is False and
            load.get("failure") == ORIGINAL["original_load_failure"] and load["clean_player_exit"] is False and
            load["forced_cleanup"] is True and load["exit_code"] == -1 and
            report["native_outcomes"]["load"]["driver_exit_code"] == 1)
        require(report["same_ending_failure_reproduced"], "Diagnostic native did not reproduce the original ending-caption failure boundary")
        boundary = read("exported-load/failure-boundary.json")
        require(boundary["failure"] == load["failure"] and boundary["process"] == load["process"],
                "Original failure cutoff/process mismatch")
        process = load["process"]
        pid, handle = str(process["pid"]), str(boundary["original_window_handle"])
        require(int(handle) > 0, "Original wait did not bind a native window")
        events = read("exported-load/events.json")
        starts = [r for r in events if r["kind"] == "native-caption-wait-start" and r.get("data", {}).get("name") == CAPTION]
        ends = [r for r in events if r["kind"] == "native-caption-wait-end" and r.get("data", {}).get("name") == CAPTION]
        require(len(starts) == len(ends) == 1 and starts[0]["data"]["deadline_seconds"] == 30,
                "Original ending wait identity/deadline differs")
        start_utc, cutoff = utc_us(starts[0]["utc"]), utc_us(ends[0]["utc"])
        require(start_utc < cutoff <= utc_us(boundary["utc"]), "Original ending cutoff order is invalid")
        report["original_wait"] = {"start": starts[0], "end": ends[0], "failure_boundary": boundary,
            "observational_cutoff_unix_us": str(cutoff),
            "cutoff_kind": "Logged original wait-end UTC; failure-observation interval, not independent proof of admission before the strict 30-second Stopwatch deadline"}
        zero_queries = [r for r in events if r["kind"] == "caption-action-enumeration" and
            r.get("data", {}).get("name") == CAPTION and r["data"].get("matches") == 0 and
            0 <= r["data"].get("started_seconds", -1) <= r["data"].get("finished_seconds", 31) < 30 and
            start_utc <= utc_us(r["utc"]) <= cutoff]
        responsive = [r for r in events if r["kind"] == "native-boundary" and
            r.get("data", {}).get("stage") == "caption-before-query: " + CAPTION and
            r["data"].get("responds") is True and str(r["data"].get("pid")) == pid and
            str(r["data"].get("handle")) == handle and start_utc <= utc_us(r["utc"]) <= cutoff]
        require(bool(zero_queries) and bool(responsive),
                "Ending timeout did not also reproduce in-budget zero queries on a responsive original window")
        report["zero_query_count"] = len(zero_queries)
        report["first_last_zero_queries"] = [zero_queries[0], zero_queries[-1]]
        report["responsive_window_sample_count"] = len(responsive)
        report["first_last_responsive_samples"] = [responsive[0], responsive[-1]]
        stdout = raw("exported-load/game.stdout.log").decode("utf-8-sig")
        expected_banner = "4.6.3.stable." + BUILD_NAME + "." + ENGINE_COMMIT[:9]
        require(stdout.splitlines()[0].startswith("Godot Engine v" + expected_banner + " - "),
                "Original Load stdout identifies a different native engine")
        renderer_lines = [line for line in stdout.splitlines() if " - Forward+ - Using Device" in line]
        require(len(renderer_lines) == 1 and renderer_lines[0].startswith("D3D12 ") and
                "Microsoft Basic Render Driver" in renderer_lines[0], "Diagnostic renderer differs from original D3D12 cloud path")
        report["observed_renderer"] = renderer_lines[0]
        captions, target_samples = [], {}
        for line_number, line in enumerate(stdout.splitlines(), 1):
            match = re.fullmatch(r"DWM_ENDING_PUBLICATION_TRACE (\{.*\})", line)
            if not match:
                continue
            data = json.loads(match[1])
            captions.append({"line": line_number, "data": data})
            require(str(data["pid"]) == pid and data["caption_text"] == CAPTION, "Caption trace process/text mismatch")
            latest = data.get("last_accessibility_updates", {}).get("caption_accessibility", {})
            fields = latest.get("fields", {})
            if not fields:
                continue
            require(fields.get("element_read") is True and fields.get("element_valid") is True and
                    fields.get("provider_valid") is True and fields.get("name_written") == CAPTION and
                    fields.get("role_written") == "button", "Caption trace has no valid intended registration")
            require(type(fields["element_id"]) is int and 0 <= fields["element_id"] < (1 << 64), "Caption RID is not a uint64")
            require(data["caption_ancestors"][0]["id"] == fields["node_id"], "Caption RID registration belongs to a different node")
            caption_node = data["caption_ancestors"][0]
            require(caption_node["inside_tree"] is True and caption_node["queued_for_deletion"] is False and
                    caption_node["visible_in_tree"] is True and data["canvas"]["inside_tree"] is True and
                    data["canvas"]["visible_in_tree"] is True and data["state"]["canvas_withdrawn"] is False,
                    "Sampled ending caption/Canvas is not live, visible and unwithdrawn")
            key = (data["window_id"], str(fields["element_id"]))
            target_samples.setdefault(key, []).append({"line": line_number, "callback_ticks_us": latest["ticks_us"],
                "snapshot_ticks_us": data["ticks_us"], "snapshot_unix_us": str(int(Decimal(str(data["unix_seconds"])) * 1000000)),
                "event": data["event"], "node_id": fields["node_id"], "text_finished_ticks_us": data["text_finished_ticks_us"]})
        require(bool(target_samples), "No current caption RID was observed by the unchanged project trace")
        (out / "ending-publication-trace.json").write_text(json.dumps({"primary_stream": "exported-load/game.stdout.log",
            "primary_stream_sha256": report["input_files"]["exported-load/game.stdout.log"]["sha256"],
            "publication_records": captions}, indent=2), encoding="utf-8")
        trace_name = "native-trace/trace-" + pid + ".jsonl"
        require(sorted(p.name for p in (out / "native-trace").glob("*.jsonl")) == ["trace-" + pid + ".jsonl"],
                "Native trace PID/file census mismatch")
        trace_data = raw(trace_name)
        replay_path = out / "prepared-graph-replay.json"
        command = [sys.executable, str(reader), "--trace", str(out / trace_name), "--output", str(replay_path)]
        for window, rid in sorted(target_samples):
            command += ["--target", str(window) + ":" + rid]
        executed = subprocess.run(command, capture_output=True, text=True, timeout=120)
        (out / "replay.stdout.log").write_text(executed.stdout, encoding="utf-8")
        (out / "replay.stderr.log").write_text(executed.stderr, encoding="utf-8")
        replay = read("prepared-graph-replay.json")
        report["replay_exit_code"] = executed.returncode
        session = replay["session"]
        require(replay["trace_sha256"] == sha(trace_data) and session["pid"] == pid and
                session["engine_hash"] == ENGINE_COMMIT and
                session["engine_version"] == "4.6.3.stable." + BUILD_NAME, "Native session/byte identity mismatch")
        require(utc_us(process["started_utc"]) <= int(session["unix_us"]) < start_utc,
                "Native session is not inside the original process lifetime before the ending wait")
        require(executed.returncode == 0 and replay["prefix_valid"] is True,
                "Prepared graph reader reports incomplete or unsupported capture")
        report["caption_native_clock_checks"] = bind_caption_clocks(trace_data, target_samples)
        report["trace_session"] = session
        report["replay_summary"] = {key: replay[key] for key in
            ["prefix_valid", "stream_closed", "coverage", "problems", "complete_update_count",
             "record_count", "target_coverage", "node_copy_us_total", "write_us_total_before_last_record"]}
        report["target_samples"] = [{"window_id": key[0], "rid": key[1], "samples": samples}
                                    for key, samples in sorted(target_samples.items())]
        for item in replay["observations"]:
            key = (item["window_id"], item["target_id"])
            first_callback = min(sample["callback_ticks_us"] for sample in target_samples[key])
            finished_samples = [sample["text_finished_ticks_us"] for sample in target_samples[key]
                                if sample["text_finished_ticks_us"] >= 0]
            if int(item["capture_start_ticks_us"]) < first_callback or not (
                    start_utc <= int(item["capture_start_unix_us"]) <= int(item["capture_end_unix_us"]) <= cutoff):
                continue
            require(item["native_handle"] == handle, "Selected graph belongs to a different native window")
            selected = dict(item)
            selected["after_text_finished"] = bool(finished_samples) and int(item["capture_start_ticks_us"]) >= max(finished_samples)
            selected["cutoff_minus_capture_end_us"] = str(cutoff - int(item["capture_end_unix_us"]))
            selected["any_path_node_hidden"] = any(node["hidden"] for node in item["path_nodes"])
            selected["actual_target_label"] = item["path_nodes"][-1]["label"] if item["path_nodes"] else None
            selected["actual_target_role"] = item["path_nodes"][-1]["role"] if item["path_nodes"] else None
            # Enum value 18 is ACCESSKIT_ROLE_BUTTON in the exact retained C header.
            selected["caption_label_and_button_role_match"] = (selected["actual_target_role"] == 18 and
                isinstance(selected["actual_target_label"], str) and selected["actual_target_label"].rstrip() == CAPTION)
            report["selected_observations"].append(selected)
        require(bool(report["selected_observations"]), "No complete captured update lies after caption registration and inside the original ending wait")
        require(any(item["after_text_finished"] for item in report["selected_observations"]),
                "No prepared-state observation follows ending text completion inside the original wait")
        require(all(item["prepared_graph_status"] != "unknown" for item in report["selected_observations"]),
                "Selected prepared graph state is unknown")
        report["binding_ok"] = True
    except Exception as exc:
        report["errors"].append(type(exc).__name__ + ": " + str(exc))
    counts = {}
    for item in report["selected_observations"]:
        status = item["prepared_graph_status"]
        counts[status] = counts.get(status, 0) + 1
    report["selected_status_counts"] = counts
    (out / "prepared-graph-binding.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({key: report[key] for key in ["binding_ok", "same_ending_failure_reproduced", "selected_status_counts", "errors"]}))
    return 0 if report["binding_ok"] else 2


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--reader", type=Path, required=True)
    args = parser.parse_args()
    args.evidence.mkdir(parents=True, exist_ok=True)
    raise SystemExit(bind(args.evidence, args.reader))
