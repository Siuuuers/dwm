#!/usr/bin/env python3
"""Replay the publication-native-v1 prepared graph, never native acceptance.

Usage: read_trace.py --trace original.jsonl --target WINDOW_ID:NODE_ID --output report.json
Repeat --target for additional nodes. Node IDs remain canonical uint64 strings.

The retaining harness must independently bind this file/session to the executable,
source/patch, PID/start time, HWND and original game caption/cutoff records. This
reader reports those identities and both clock domains; it does not invent that
binding. A complete update is a factory-prepared handoff, not proof of adapter
consumption or UIA exposure. A missing footer permits observations of the complete
prefix only. Exit 0 means a valid prefix with a qualified observation per target,
not a closed stream, a connected target, or a successful native journey.

Ordinary TreeId::ROOT semantics are pinned to accesskit 0.24.0 and consumer 0.35.0:
https://github.com/AccessKit/accesskit/blob/1bbcf100942bac96c2c3a4a91cb67b0b20201a24/consumer/src/tree.rs
The update loop (217-317) replaces nodes; removal (343-386) prunes detached
subtrees, preserving nodes reparented in the same update. Grafts and malformed
graphs are unsupported/unknown. An invalid consumer input is not emulated.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass, field
import hashlib
import json
from pathlib import Path
import re
from typing import Any


SOURCE_BASE = "35e80b3a8822a9df9be390814b62f44c0a9c69e8"
BOUNDARY = "completed-node-before-transfer/factory-prepared"
LIMITS = {"file_bytes": 67108864, "row_bytes": 4194304, "updates": 65536,
          "nodes_per_update": 4096, "edges_per_update": 16384,
          "label_bytes_per_node": 8192, "label_bytes_per_update": 1048576}
U64_MAX = (1 << 64) - 1


class Invalid(ValueError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Invalid(message)


def integer(value: Any, name: str, minimum: int = 0, maximum: int = U64_MAX) -> int:
    require(type(value) is int and minimum <= value <= maximum, f"invalid {name}")
    return value


def uid(value: Any, name: str) -> str:
    require(type(value) is str and re.fullmatch(r"0|[1-9][0-9]{0,19}", value) is not None,
            f"{name} must be a canonical uint64 string")
    require(int(value) <= U64_MAX, f"{name} exceeds uint64")
    return value


def unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result = {}
    for key, value in pairs:
        require(key not in result, f"duplicate JSON key: {key}")
        result[key] = value
    return result


def reject_constant(value: str) -> None:
    raise Invalid(f"non-JSON numeric constant: {value}")


def target_argument(value: str) -> tuple[int, str]:
    try:
        window, node = value.split(":", 1)
        require(re.fullmatch(r"0|[1-9][0-9]*", window) is not None, "invalid target window")
        return integer(int(window), "target window", maximum=(1 << 63) - 1), uid(node, "target")
    except (ValueError, Invalid) as exc:
        raise argparse.ArgumentTypeError(f"expected WINDOW_ID:UINT64_NODE_ID: {exc}") from exc


@dataclass
class Window:
    number: int
    open_seq: int
    root: str
    handle: str
    epoch: int = 0
    thread: str | None = None
    capture_lower_bound: int = 0
    nodes: dict[str, dict[str, Any]] = field(default_factory=dict)
    parents: dict[str, tuple[str, int]] = field(default_factory=dict)
    problem: str | None = None


def replacements(row: dict[str, Any]) -> dict[str, dict[str, Any]]:
    """Validate whole node replacements; an omitted child list is not a leaf."""
    nodes = row.get("nodes")
    require(type(nodes) is list, "nodes is not an array")
    require(len(nodes) <= LIMITS["nodes_per_update"], "node limit exceeded")
    require(integer(row.get("node_count"), "node_count") == len(nodes), "node count mismatch")
    result, edge_count, label_bytes = {}, 0, 0
    for node in nodes:
        require(type(node) is dict, "node is not an object")
        node_id = uid(node.get("id"), "node id")
        require(node_id not in result, f"duplicate node id {node_id}")
        children = node.get("children")
        require(type(children) is list, f"missing/invalid children for {node_id}")
        for child in children:
            uid(child, "child id")
        require(len(children) == len(set(children)), f"duplicate child id in {node_id}")
        edge_count += len(children)
        require(edge_count <= LIMITS["edges_per_update"], "edge limit exceeded")
        integer(node.get("role"), "role")
        require(type(node.get("hidden")) is bool, "invalid hidden flag")
        label = node.get("label")
        require("label" in node and (label is None or type(label) is str), "invalid label")
        size = len(label.encode("utf-8")) if label is not None else 0
        require(size <= LIMITS["label_bytes_per_node"], "node label limit exceeded")
        label_bytes += size
        require(label_bytes <= LIMITS["label_bytes_per_update"], "update label limit exceeded")
        require("tree_id" not in node and "graft" not in node, "unsupported graft")
        result[node_id] = {"id": node_id, "children": list(children), "role": node["role"],
                           "hidden": node["hidden"], "label": label,
                           "source_update_seq": row["update_seq"], "source_record_seq": row["seq"]}
    require(integer(row.get("edge_count"), "edge_count") == edge_count, "edge count mismatch")
    return result


def replace_graph(window: Window, row: dict[str, Any], initial: bool) -> tuple[int, int]:
    """Commit only a valid resulting ordinary rooted tree, then prune old nodes."""
    changed = replacements(row)
    candidate = {} if initial else dict(window.nodes)
    candidate.update(changed)
    root = window.root
    require(root in candidate, "root node missing")
    parents, visited = {}, set()
    pending = [root]
    while pending:
        node_id = pending.pop()
        require(node_id in candidate, f"dangling child id {node_id}")
        require(node_id not in visited, f"cycle or multiple parents at {node_id}")
        visited.add(node_id)
        children = candidate[node_id]["children"]
        for index, child in enumerate(children):
            require(child != root and child not in parents, f"cycle or multiple parents at {child}")
            parents[child] = (node_id, index)
        pending.extend(reversed(children))
    require(not (changed.keys() - visited), "replacement node is detached from the root")
    require(row["focus_id"] in visited, "focus id missing from resulting tree")
    removed = len(window.nodes.keys() - visited) if not initial else 0
    retained = len(visited - changed.keys())
    window.nodes = {node_id: candidate[node_id] for node_id in visited}
    window.parents = parents
    return removed, retained


def observation(window: Window, row: dict[str, Any], target: str,
                removed: int = 0, retained: int = 0) -> dict[str, Any]:
    result = {key: row[key] for key in (
        "seq", "update_seq", "update_kind", "window_id", "window_open_seq", "epoch",
        "capture_start_ticks_us", "capture_end_ticks_us", "capture_start_unix_us",
        "capture_end_unix_us", "capture_thread_id", "thread_id", "node_count", "edge_count",
        "ticks_us", "unix_us", "node_copy_us_total", "write_us_total_before_record", "previous_write_us")}
    result.update({"target_id": target, "root_id": window.root, "native_handle": window.handle,
                   "prepared_graph_status": "unknown", "root_to_target": [], "edges": [],
                   "path_nodes": []})
    if window.problem:
        result["reason"] = window.problem
        return result
    result.update({"prepared_graph_status": "connected" if target in window.nodes else "missing",
                   "retained_graph_nodes": len(window.nodes), "removed_nodes": removed,
                   "retained_nodes_not_replaced": retained,
                   "target_replaced_in_update": any(n["id"] == target for n in row["nodes"])})
    if target not in window.nodes:
        result["reason"] = "target absent from the complete reconstructed rooted tree"
        return result
    path = [target]
    while path[-1] != window.root:
        path.append(window.parents[path[-1]][0])
    path.reverse()
    result["root_to_target"] = path
    result["path_nodes"] = [{key: window.nodes[node_id][key] for key in
                             ("id", "role", "hidden", "label", "source_update_seq", "source_record_seq")}
                            for node_id in path]
    for parent, child in zip(path, path[1:]):
        result["edges"].append({"parent_id": parent, "child_id": child,
                                "child_index": window.parents[child][1],
                                "source_update_seq": window.nodes[parent]["source_update_seq"],
                                "source_record_seq": window.nodes[parent]["source_record_seq"]})
    return result


def replay(raw: bytes, targets: list[tuple[int, str]]) -> dict[str, Any]:
    """Parse original bytes, retaining qualified earlier states after later failure."""
    result: dict[str, Any] = {
        "schema": 1, "scope": BOUNDARY, "trace_bytes": len(raw),
        "trace_sha256": hashlib.sha256(raw).hexdigest(), "session": None,
        "targets": [{"window_id": w, "node_id": n} for w, n in targets],
        "external_run_binary_pid_hwnd_caption_cutoff_binding_verified": False,
        "native_acceptance_evaluated": False, "observations": [], "problems": [],
        "stream_closed": False, "stopped": False,
    }
    windows: dict[int, Window] = {}
    last_seq = last_update = normal_bytes = last_ticks = last_capture_cost = last_write_cost = 0
    event_counts: dict[str, int] = {}
    ended = False
    fatal = False
    # Normal output is capped at 64 MiB. The emitter reserves one small terminal row.
    if len(raw) > LIMITS["file_bytes"] + 65536:
        result["problems"].append({"reason": "file exceeds capture bound plus terminal reserve"})
        fatal = True
    for line_number, line in enumerate(raw.splitlines(keepends=True) if not fatal else [], 1):
        row: dict[str, Any] = {}
        try:
            require(line.endswith(b"\n"), "truncated JSONL record")
            require(b"\0" not in line, "NUL in JSONL")
            row = json.loads(line.decode("utf-8"), object_pairs_hook=unique_object, parse_constant=reject_constant)
            require(type(row) is dict, "record is not an object")
            require(not ended, "record after terminal event")
            require(type(row.get("schema")) is int and row["schema"] == 1, "unsupported schema")
            seq = integer(row.get("seq"), "seq", 1)
            require(seq == last_seq + 1, "record sequence gap or duplicate")
            event = row.get("event")
            require(type(event) is str and event in {"session", "window_open", "update", "window_close", "stopped", "session_end"},
                    "unsupported event")
            require(len(line) <= LIMITS["row_bytes"], "record byte limit exceeded")
            if event != "stopped":
                normal_bytes += len(line)
                require(normal_bytes <= LIMITS["file_bytes"], "normal file byte limit exceeded")
            ticks = int(uid(row.get("ticks_us"), "ticks_us"))
            uid(row.get("unix_us"), "unix_us")
            uid(row.get("thread_id"), "thread_id")
            capture_cost = int(uid(row.get("node_copy_us_total"), "node_copy_us_total"))
            write_cost = int(uid(row.get("write_us_total_before_record"), "write_us_total_before_record"))
            uid(row.get("previous_write_us"), "previous_write_us")
            require(ticks >= last_ticks, "record monotonic clock moved backwards")
            require(capture_cost >= last_capture_cost and write_cost >= last_write_cost,
                    "cumulative observation cost moved backwards")
            if event == "session":
                require(seq == 1 and result["session"] is None, "session is not first/unique")
                require(row.get("source_base_commit") == SOURCE_BASE, "source base mismatch")
                require(row.get("probe_id") == "publication-native-v1", "probe identity mismatch")
                require(row.get("boundary") == BOUNDARY, "capture boundary mismatch")
                require(row.get("tree_id") == "root" and row.get("grafts_supported") is False,
                        "unsupported tree/graft contract")
                require(row.get("limits") == LIMITS, "capture limits mismatch")
                require(all(type(value) is int for value in row["limits"].values()), "invalid capture limit type")
                uid(row.get("pid"), "pid")
                require(int(row["pid"]) > 0, "invalid process id")
                require(type(row.get("engine_version")) is str and bool(row["engine_version"]),
                        "missing engine version")
                require(type(row.get("engine_hash")) is str, "missing engine hash")
                result["session"] = dict(row)
            else:
                require(result["session"] is not None, "missing initial session")
            if event in {"window_open", "update", "window_close"}:
                window_id = integer(row.get("window_id"), "window_id", maximum=(1 << 63) - 1)
                open_seq = integer(row.get("window_open_seq"), "window_open_seq", 1)
            if event == "window_open":
                require(window_id not in windows, "window reopened without close")
                require(open_seq == seq, "window_open_seq does not identify its opening record")
                handle = uid(row.get("native_handle"), "native_handle")
                require(int(handle) > 0, "null native window handle")
                require(all(w.handle != handle for w in windows.values()), "native handle owned by two windows")
                windows[window_id] = Window(window_id, open_seq, uid(row.get("root_id"), "root_id"),
                                            handle, thread=row["thread_id"], capture_lower_bound=ticks)
            elif event in {"update", "window_close"}:
                require(window_id in windows and windows[window_id].open_seq == open_seq,
                        "missing/stale window ownership")
                window = windows[window_id]
                epoch = integer(row.get("epoch"), "epoch")
                if event == "window_close":
                    require(epoch == window.epoch, "window close epoch mismatch")
                    require(row["thread_id"] == window.thread, "window close thread mismatch")
                    del windows[window_id]
                else:
                    update_seq = integer(row.get("update_seq"), "update_seq", 1, LIMITS["updates"])
                    require(update_seq == last_update + 1, "update sequence gap or duplicate")
                    require(row.get("complete") is True, "incomplete update")
                    initial = row.get("update_kind") == "initial"
                    require(initial or row.get("update_kind") == "delta", "unsupported update kind")
                    require(epoch == (window.epoch + 1 if initial else window.epoch) and epoch > 0,
                            "initial/delta epoch mismatch")
                    require(uid(row.get("root_id"), "root_id") == window.root, "window root identity changed")
                    uid(row.get("focus_id"), "focus_id")
                    start = int(uid(row.get("capture_start_ticks_us"), "capture_start_ticks_us"))
                    end = int(uid(row.get("capture_end_ticks_us"), "capture_end_ticks_us"))
                    start_utc = int(uid(row.get("capture_start_unix_us"), "capture_start_unix_us"))
                    end_utc = int(uid(row.get("capture_end_unix_us"), "capture_end_unix_us"))
                    thread = uid(row.get("capture_thread_id"), "capture_thread_id")
                    require(start <= end <= ticks and start_utc <= end_utc, "invalid capture time bounds")
                    require(thread == row["thread_id"], "capture/emission thread mismatch")
                    # The emitter still owns the previous batch during its synchronous row write.
                    # Row ticks precede that write; they are only a necessary lower bound.
                    require(start >= window.capture_lower_bound, "capture precedes same-window open/previous row")
                    require(window.thread is None or thread == window.thread, "same-window thread changed")
                    window.epoch, window.thread, window.capture_lower_bound = epoch, thread, ticks
                    if initial:
                        window.problem = None
                    removed = retained = 0
                    try:
                        if window.problem is None:
                            removed, retained = replace_graph(window, row, initial)
                        else:
                            replacements(row)  # Still validate the trace after an invalid prior graph.
                    except (Invalid, UnicodeError) as exc:
                        window.problem = str(exc)
                        result["problems"].append({"line": line_number, "seq": seq,
                                                   "window_id": window_id, "epoch": epoch,
                                                   "reason": window.problem})
                    for query_window, target in targets:
                        if query_window == window_id:
                            result["observations"].append(observation(window, row, target, removed, retained))
                    last_update = update_seq
            elif event == "stopped":
                require(row.get("complete") is False, "stopped event must be incomplete")
                require(type(row.get("reason")) is str and bool(row["reason"]), "missing stop reason")
                require(integer(row.get("last_complete_record_seq"), "last_complete_record_seq") == last_seq,
                        "stop prefix count mismatch")
                require(integer(row.get("attempted_update_seq"), "attempted_update_seq") in
                        {last_update, last_update + 1}, "stop update count mismatch")
                result["stopped"] = True
                result["problems"].append({"line": line_number, "seq": seq, "reason": "capture stopped: " + row["reason"]})
                ended = True
            elif event == "session_end":
                require(row.get("complete") is True, "session ended during incomplete capture")
                require(integer(row.get("updates"), "updates") == last_update, "footer update count mismatch")
                require(integer(row.get("open_windows"), "open_windows") == len(windows),
                        "footer window count mismatch")
                result["stream_closed"] = True
                ended = True
            last_seq, last_ticks = seq, ticks
            last_capture_cost, last_write_cost = capture_cost, write_cost
            event_counts[event] = event_counts.get(event, 0) + 1
        except (Invalid, KeyError, UnicodeError, json.JSONDecodeError) as exc:
            result["problems"].append({"line": line_number, "seq": row.get("seq") if type(row) is dict else None,
                                       "reason": str(exc)})
            fatal = True
            break
    if result["session"] is None and not result["problems"]:
        result["problems"].append({"reason": "empty trace; no initial session"})
    qualified = [o for o in result["observations"] if o["prepared_graph_status"] != "unknown"]
    target_coverage = []
    for window_id, node_id in targets:
        observed = [o for o in result["observations"] if o["window_id"] == window_id and o["target_id"] == node_id]
        qualified_count = sum(o["prepared_graph_status"] != "unknown" for o in observed)
        target_coverage.append({"window_id": window_id, "node_id": node_id,
                                "observation_count": len(observed), "qualified_observation_count": qualified_count,
                                "coverage": "observed_updates" if qualified_count else "unknown"})
    result["stream_closed"] = result["stream_closed"] and not fatal
    result.update({"record_count": last_seq, "complete_update_count": last_update,
                   "event_counts": event_counts, "qualified_observation_count": len(qualified),
                   "target_coverage": target_coverage,
                   "prefix_valid": not result["problems"] and bool(targets) and
                                   all(t["qualified_observation_count"] > 0 for t in target_coverage),
                   "coverage": "closed_stream" if result["stream_closed"] and not fatal else "complete_prefix_only",
                   "node_copy_us_total": str(last_capture_cost), "write_us_total_before_last_record": str(last_write_cost),
                   "final_state_status": "unknown"})
    if not result["stream_closed"]:
        result["coverage_note"] = "No complete footer; do not infer state/absence after the last complete update."
    result["acceptance_note"] = "Prepared graph observations only. Original native result and official-binary acceptance remain separate."
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--trace", type=Path, required=True)
    parser.add_argument("--target", type=target_argument, action="append", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    report = replay(args.trace.read_bytes(), list(dict.fromkeys(args.target)))
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: report[key] for key in
                      ("prefix_valid", "stream_closed", "complete_update_count", "qualified_observation_count")}))
    return 0 if report["prefix_valid"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
