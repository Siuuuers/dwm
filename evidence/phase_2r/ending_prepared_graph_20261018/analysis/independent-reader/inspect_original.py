#!/usr/bin/env python3
"""Inspect the existing unchanged-reader result; never rerun a native process."""

import argparse
from bisect import bisect_left
from collections import Counter
from datetime import datetime, timezone
from decimal import Decimal
import hashlib
import json
from pathlib import Path
import re


CAPTION = "TEST Seven-day ending."
TRACE_SHA = "81f84fce785d9630ec2a29790804665285ad0fc05c0258fcff354573679ec337"
STDOUT_SHA = "d6606c4e601b60c105ec21c984ab2b6ecc39ee8fdf9f43c15285f3657c53f8b9"
READER_SHA = "b4c21e1cf4c344246191be00cb435a4b55f683df2ee3d169a14496e9cc023a4b"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def utc_ns(stamp):
    # Preserve all seven fractional digits in the original .NET timestamps.
    match = re.fullmatch(r"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.(\d{1,9}))?Z", stamp)
    assert match, stamp
    dt = datetime.strptime(match[1], "%Y-%m-%dT%H:%M:%S").replace(tzinfo=timezone.utc)
    return int(dt.timestamp()) * 1000000000 + int((match[2] or "").ljust(9, "0"))


def inspect(args):
    inputs = {}

    def raw(name):
        data = (args.ci / name).read_bytes()
        inputs[name] = {"bytes": len(data), "sha256": digest(data)}
        return data

    def read(name):
        return json.loads(raw(name).decode("utf-8-sig"))

    trace_data = raw("native-trace/trace-6124.jsonl")
    stdout = raw("exported-load/game.stdout.log")
    assert digest(trace_data) == TRACE_SHA and len(trace_data) == 1252458
    assert digest(stdout) == STDOUT_SHA
    rows = [json.loads(line) for line in trace_data.splitlines()]
    replay_data = args.replay.read_bytes()
    replay = json.loads(replay_data)
    assert digest((args.replay.parent / "read_trace.py").read_bytes()) == READER_SHA
    assert replay["trace_sha256"] == TRACE_SHA and replay["prefix_valid"] and not replay["problems"]
    assert replay["session"]["pid"] == "6124"
    assert replay["session"]["engine_hash"] == "35e80b3a8822a9df9be390814b62f44c0a9c69e8"
    result = read("exported-load/result.json")
    driver = read("load-process.json")
    boundary = read("exported-load/failure-boundary.json")
    acceptance = read("diagnostic-acceptance.json")
    original_binding = read("prepared-graph-binding.json")
    events = read("exported-load/events.json")
    pid, handle = str(result["process"]["pid"]), str(boundary["original_window_handle"])
    assert pid == "6124" and handle == "524608" and boundary["process"] == result["process"]
    starts = [r for r in events if r["kind"] == "native-caption-wait-start" and r["data"]["name"] == CAPTION]
    ends = [r for r in events if r["kind"] == "native-caption-wait-end" and r["data"]["name"] == CAPTION]
    assert len(starts) == len(ends) == 1 and starts[0]["data"]["deadline_seconds"] == 30
    start_ns, end_ns = utc_ns(starts[0]["utc"]), utc_ns(ends[0]["utc"])
    assert utc_ns(result["process"]["started_utc"]) <= int(rows[0]["unix_us"]) * 1000 < start_ns
    assert start_ns < end_ns <= utc_ns(boundary["utc"])

    captions, registrations = [], []
    for number, line in enumerate(stdout.decode("utf-8-sig").splitlines(), 1):
        match = re.fullmatch(r"DWM_ENDING_PUBLICATION_TRACE (\{.*\})", line)
        if not match:
            continue
        data = json.loads(match[1])
        assert str(data["pid"]) == pid and data["caption_text"] == CAPTION and data["window_id"] == 0
        captions.append({"line": number, "data": data})
        access = data["last_accessibility_updates"].get("caption_accessibility", {})
        fields = access.get("fields")
        if fields:
            assert all(fields[key] is True for key in ("element_read", "element_valid", "provider_valid"))
            assert fields["name_written"] == CAPTION and fields["role_written"] == "button"
            assert type(fields["element_id"]) is int and 0 <= fields["element_id"] < (1 << 64)
            assert fields["node_id"] == data["caption_ancestors"][0]["id"]
            assert data["caption_ancestors"][0]["inside_tree"] and data["caption_ancestors"][0]["visible_in_tree"]
            assert not data["caption_ancestors"][0]["queued_for_deletion"]
            assert data["canvas"]["inside_tree"] and data["canvas"]["visible_in_tree"] and not data["state"]["canvas_withdrawn"]
            assert 0 <= access["ticks_us"] <= data["ticks_us"]
            assert data["text_finished_ticks_us"] == -1 or 0 <= data["text_finished_ticks_us"] <= data["ticks_us"]
            registrations.append({"line": number, "window_id": data["window_id"], "rid": str(fields["element_id"]),
                                  "node_id": fields["node_id"], "callback_ticks_us": access["ticks_us"],
                                  "text_finished_ticks_us": data["text_finished_ticks_us"]})
    assert {(r["window_id"], r["rid"], r["node_id"]) for r in registrations} == {(0, "108881715921047", 589916392131188)}
    first_callback = min(r["callback_ticks_us"] for r in registrations)
    finished = max(r["text_finished_ticks_us"] for r in registrations)

    anchors = sorted((int(row[p + "ticks_us"]), int(row[p + "unix_us"]), row["seq"], p or "record")
                     for row in rows for p in ("", "capture_start_", "capture_end_") if p + "ticks_us" in row)
    ticks = [a[0] for a in anchors]
    clocks = []
    for caption in captions:
        data = caption["data"]
        tick, wall = data["ticks_us"], int(Decimal(str(data["unix_seconds"])) * 1000000)
        index = bisect_left(ticks, tick)
        assert 0 < index < len(anchors)
        pair = anchors[index - 1:index + 1]
        low, high = min(a[1] - a[0] for a in pair), max(a[1] - a[0] for a in pair)
        consistent = low - 2000 <= wall - tick <= high + 2000
        assert consistent
        clocks.append({"line": caption["line"], "event": data["event"], "snapshot_ticks_us": str(tick),
                       "snapshot_unix_us": str(wall), "snapshot_offset_us": str(wall - tick),
                       "consistency_tolerance_us": 2000, "consistent": consistent,
                       "brackets": [{"ticks_us": str(a[0]), "unix_us": str(a[1]), "record_seq": a[2],
                                     "sample": a[3], "offset_us": str(a[1] - a[0])} for a in pair],
                       "snapshot_minus_logged_wait_end_ns": str(wall * 1000 - end_ns)})

    selected = []
    for original in replay["observations"]:
        if int(original["capture_start_ticks_us"]) < first_callback:
            continue
        if not start_ns <= int(original["capture_start_unix_us"]) * 1000 <= int(original["capture_end_unix_us"]) * 1000 <= end_ns:
            continue
        assert original["window_id"] == 0 and original["target_id"] == "108881715921047" and original["native_handle"] == handle
        selected.append({**original, "after_text_finished": int(original["capture_start_ticks_us"]) >= finished,
                         "wait_end_minus_capture_end_ns": str(end_ns - int(original["capture_end_unix_us"]) * 1000),
                         "any_path_node_hidden": any(node["hidden"] for node in original["path_nodes"])})
    queries = [r for r in events if r["kind"] == "caption-action-enumeration" and
               r["data"]["name"] == CAPTION and r["data"]["matches"] == 0 and
               0 <= r["data"]["started_seconds"] <= r["data"]["finished_seconds"] < 30 and start_ns <= utc_ns(r["utc"]) <= end_ns]
    responsive = [r for r in events if r["kind"] == "native-boundary" and
                  r["data"].get("stage") == "caption-before-query: " + CAPTION and
                  str(r["data"].get("pid")) == pid and str(r["data"].get("handle")) == handle and
                  r["data"].get("responds") is True and start_ns <= utc_ns(r["utc"]) <= end_ns]
    report = {
        "schema_version": 1, "scope": "Independent post-run inspection of prepared graph and original clock records",
        "native_acceptance_evaluated": False, "official_acceptance_established": False,
        "inputs": inputs, "replay": {"path": str(args.replay), "bytes": len(replay_data), "sha256": digest(replay_data), "reader_sha256": READER_SHA},
        "original_banner": stdout.decode("utf-8-sig").splitlines()[0],
        "original_load": result, "original_driver": driver, "original_acceptance": acceptance,
        "original_binding": {key: original_binding[key] for key in ("binding_ok", "same_ending_failure_reproduced", "official_acceptance_established", "errors")},
        "trace_summary": {key: replay[key] for key in ("prefix_valid", "problems", "record_count", "complete_update_count", "event_counts", "stream_closed", "coverage", "final_state_status", "node_copy_us_total", "write_us_total_before_last_record")},
        "window_lifecycle": [r for r in rows if r["event"] in {"window_open", "window_close", "stopped", "session_end"}],
        "initial_epochs": [{k: r[k] for k in ("update_seq", "window_id", "window_open_seq", "epoch", "root_id")} for r in rows if r["event"] == "update" and r["update_kind"] == "initial"],
        "all_observation_status_counts": dict(Counter(o["prepared_graph_status"] for o in replay["observations"])),
        "caption_records": captions, "registrations": registrations, "clock_checks": clocks,
        "first_callback_ticks_us": str(first_callback), "text_finished_ticks_us": str(finished),
        "original_wait": {"start": starts[0], "end": ends[0], "failure_boundary": boundary},
        "zero_queries_before_stopwatch_30_seconds": queries, "responsive_original_window_samples": responsive,
        "selected_count": len(selected), "after_text_finished_count": sum(o["after_text_finished"] for o in selected),
        "selected_status_counts": dict(Counter(o["prepared_graph_status"] for o in selected)),
        "selected_observations": selected,
        "limitations": ["Native capture ends before row serialization/write/flush and factory return; adapter consumption is not observed.",
                        "The logged wait-end UTC is the observed failure interval; it does not independently attest strict Stopwatch admission.",
                        "Clock-offset consistency uses the declared 2000-us tolerance; it is not an absolute clock-accuracy guarantee.",
                        "There is no stream footer; complete-prefix observations do not establish continuous or final-state coverage.",
                        "The dated-banner parser refusal and native ending timeout remain unchanged original outcomes."],
    }
    args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({"selected": report["selected_count"], "after_text_finished": report["after_text_finished_count"],
                      "statuses": report["selected_status_counts"], "clock_checks": len(clocks), "output": str(args.output)}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ci", type=Path, required=True)
    parser.add_argument("--replay", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    inspect(parser.parse_args())
