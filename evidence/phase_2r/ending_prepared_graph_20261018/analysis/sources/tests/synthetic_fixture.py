"""Deterministic synthetic wire data for the offline binder integration tests.

No executable, PCK, original run evidence, or engine execution is represented by
these generated files. They deliberately imitate the input schemas only.
"""

from datetime import datetime, timedelta, timezone
import hashlib
import json


SYNTHETIC = "SYNTHETIC TEST ONLY: not native evidence"
GAME_COMMIT = "81847d8b1560340a3a7769223cee0b46c6bdc0f9"
GAME_TREE = "4581a9f12d63684836c722f72cffd533491f3c06"
ENGINE_COMMIT = "35e80b3a8822a9df9be390814b62f44c0a9c69e8"
ENGINE_TREE = "499fa231ee5d21878988a4a9cb881749def3946d"
BUILD_NAME = "dwm_publication_probe_v1"
PREFIX = "tools/diagnostics/ending-publication-20261019/"
CAPTION = "TEST Seven-day ending."
PID, HWND, TARGET = 4242, 524501, "9007199254740993"
NATIVE_PATHS = ["drivers/accesskit/accessibility_driver_accesskit.cpp",
                "drivers/accesskit/accessibility_driver_accesskit.h"]
BASE = datetime(2026, 10, 18, 20, tzinfo=timezone.utc)
BASE_US = int(BASE.timestamp()) * 1000000
ORIGINAL = {
    "run": 39155624496, "artifact_id": 12146662424,
    "archive_file": "DWM-windows-x86_64-validation.zip", "archive_bytes": 99457801,
    "archive_sha256": "7c3053d2073fc3caee98dc5c038e720d5e860952375039d0db054dcd14812eb8",
    "executable_sha256": "91724f15024a3a545e28ccd83134403d31ce2323a38e51c95e4dfa282f732ab6",
    "pck_bytes": 66433104,
    "pck_sha256": "1bbe3794a2febb54960929984556421e04df621f0e21a095f71ea25603147d26",
    "engine_banner": "4.6.3.stable.official.7d41c59c4",
    "original_load_ok": False,
    "original_load_failure": "UIA_UNAVAILABLE_OR_TIMEOUT: TEST Seven-day ending.",
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def utc(offset_us):
    return (BASE + timedelta(microseconds=offset_us)).isoformat().replace("+00:00", "Z")


def node(node_id, children=(), label=None, role=1):
    return {"id": node_id, "children": list(children), "role": role,
            "hidden": False, "label": label}


def fixture(reader):
    """Return literal wire documents; this function implements no replay logic."""
    sources, changes, pins = {}, [], {}
    for path in NATIVE_PATHS:
        change = {"path": path}
        for role, key in [("baseline", "base_sha256"), ("candidate", "candidate_sha256")]:
            name = PREFIX + "native-probe/" + role + "/" + path
            sources[name] = ("// " + SYNTHETIC + " " + role + " " + path + "\n").encode()
            change[key] = digest(sources[name])
            pins[name] = {"sha256": change[key]}
        changes.append(change)
    for name in ["publication-native-probe.patch", "PROTOCOL.md"]:
        path = PREFIX + "native-probe/" + name
        sources[path] = (SYNTHETIC + " " + name + "\n").encode()
        pins[path] = {"sha256": digest(sources[path])}
    pins[PREFIX + "replay/read_trace.py"] = {"sha256": digest(reader.read_bytes())}
    template_sha = digest((SYNTHETIC + " template metadata placeholder").encode())
    archive_sha = digest((SYNTHETIC + " archive metadata placeholder").encode())
    process = {"pid": PID, "started_utc": utc(0), "synthetic_fixture": True}
    documents = {
        "audit-origin.json": {"game_commit": GAME_COMMIT, "game_tree": GAME_TREE,
                              "shared_source_pins": pins},
        "native-build/build-receipt.json": {
            "ok": True, "source_commit": ENGINE_COMMIT, "source_tree": ENGINE_TREE,
            "build_name": BUILD_NAME, "template": {"sha256": template_sha}, "changed_files": changes,
            "patch_sha256": pins[PREFIX + "native-probe/publication-native-probe.patch"]["sha256"],
            "protocol_sha256": pins[PREFIX + "native-probe/PROTOCOL.md"]["sha256"]},
        "native-diagnostic/validation.json": {
            "ok": True, "diagnostic": True, "commit": GAME_COMMIT, "original_package": ORIGINAL,
            "files": [{"path": "DWM.exe", "sha256": template_sha},
                      {"path": "DWM.pck", "sha256": ORIGINAL["pck_sha256"]}],
            "archive": {"sha256": archive_sha}},
        "exported-load/failure-boundary.json": {
            "failure": ORIGINAL["original_load_failure"], "process": dict(process),
            "original_window_handle": HWND, "utc": utc(31500000)},
        "exported-load/events.json": [
            {"utc": utc(1000000), "kind": "native-caption-wait-start",
             "data": {"name": CAPTION, "deadline_seconds": 30}},
            {"utc": utc(2900000), "kind": "native-boundary", "data": {
                "stage": "caption-before-query: " + CAPTION, "pid": PID,
                "handle": HWND, "responds": True, "elapsed_seconds": 1.9}},
            {"utc": utc(3000000), "kind": "caption-action-enumeration", "data": {
                "name": CAPTION, "matches": 0, "started_seconds": 1.9, "finished_seconds": 2.0}},
            {"utc": utc(31000000), "kind": "native-caption-wait-end",
             "data": {"name": CAPTION, "elapsed_seconds": 30.0}},
        ],
    }
    for mode in ("capability", "create", "load"):
        failed = mode == "load"
        documents["exported-" + mode + "/result.json"] = {
            "source_commit": GAME_COMMIT, "archive_sha256": archive_sha,
            "executable_sha256": template_sha, "pck_sha256": ORIGINAL["pck_sha256"],
            "renderer_request": "ProjectDefault", "accessibility_request": "Always", "audio_request": "Dummy",
            "ok": not failed, "exit_code": -1 if failed else 0, "clean_player_exit": not failed,
            "forced_cleanup": failed, "failure": ORIGINAL["original_load_failure"] if failed else None,
            "process": dict(process, pid=PID if failed else PID + len(mode))}
        documents[mode + "-process.json"] = {
            "diagnostic_native": True, "trace_enabled": failed, "exit_code": 1 if failed else 0}
    for value in documents.values():
        if isinstance(value, dict):
            value["synthetic_fixture"] = True
        else:
            for event in value:
                event["synthetic_fixture"] = True

    caption = {
        "synthetic_fixture": True, "pid": PID, "window_id": 0, "caption_text": CAPTION,
        "event": "text_finished_followup", "ticks_us": 1700000,
        "unix_seconds": str((BASE_US + 1700000) // 1000000) + ".700000",
        "text_finished_ticks_us": 1500000,
        "caption_ancestors": [{"id": 101, "parent_id": 102, "inside_tree": True,
                               "queued_for_deletion": False, "visible_in_tree": True}],
        "canvas": {"id": 102, "inside_tree": True, "queued_for_deletion": False, "visible_in_tree": True},
        "state": {"canvas_withdrawn": False},
        "last_accessibility_updates": {"caption_accessibility": {"ticks_us": 1600000, "fields": {
            "element_id": int(TARGET), "element_read": True, "element_valid": True,
            "provider_valid": True, "name_written": CAPTION, "role_written": "button", "node_id": 101}}},
    }

    rows = []

    def row(event, ticks, **fields):
        rows.append({"synthetic_fixture": True, "schema": 1, "event": event, "seq": len(rows) + 1,
                     "ticks_us": str(ticks), "unix_us": str(BASE_US + ticks), "thread_id": "7",
                     "node_copy_us_total": "0", "write_us_total_before_record": "0", "previous_write_us": "0",
                     **fields})

    row("session", 1000, source_base_commit=ENGINE_COMMIT, probe_id="publication-native-v1",
        engine_hash=ENGINE_COMMIT, engine_version="4.6.3.stable." + BUILD_NAME, pid=str(PID),
        boundary="completed-node-before-transfer/factory-prepared", tree_id="root", grafts_supported=False,
        limits={"file_bytes": 67108864, "row_bytes": 4194304, "updates": 65536,
                "nodes_per_update": 4096, "edges_per_update": 16384,
                "label_bytes_per_node": 8192, "label_bytes_per_update": 1048576})
    row("window_open", 2000, window_id=0, window_open_seq=2, root_id="7", native_handle=str(HWND))
    for number, kind, start, end, written, nodes in [
        (1, "initial", 3000, 3500, 4000,
         [node("7", ["8"]), node("8", [TARGET]), node(TARGET, label="previous caption", role=18)]),
        (2, "delta", 2000000, 2010000, 2011000, [node(TARGET, label=CAPTION, role=18)]),
    ]:
        row("update", written, update_kind=kind, update_seq=number, window_id=0,
            window_open_seq=2, epoch=1, root_id="7", focus_id="7", capture_thread_id="7", complete=True,
            capture_start_ticks_us=str(start), capture_end_ticks_us=str(end),
            capture_start_unix_us=str(BASE_US + start), capture_end_unix_us=str(BASE_US + end),
            nodes=nodes, node_count=len(nodes), edge_count=sum(len(n["children"]) for n in nodes))
    # Forced cleanup can leave a complete prefix. Deliberately omit session_end.
    return {"documents": documents, "sources": sources, "caption": caption, "native_rows": rows}


def write_fixture(folder, data):
    def write(name, value):
        path = folder / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(value)

    write("SYNTHETIC_NOT_NATIVE_EVIDENCE.txt", (SYNTHETIC + "\n").encode())
    for name, value in data["documents"].items():
        write(name, (json.dumps(value, indent=2) + "\n").encode())
    for name, value in data["sources"].items():
        write("source/" + name, value)
    banner = data.get("banner", "Godot Engine v4.6.3.stable." + BUILD_NAME + "." + ENGINE_COMMIT[:9] + " - https://godotengine.org")
    renderer = "D3D12 synthetic - Forward+ - Using Device #0: Microsoft - Microsoft Basic Render Driver"
    write("exported-load/game.stdout.log", (banner + "\n" + SYNTHETIC + "\n" + renderer + "\n" +
          "DWM_ENDING_PUBLICATION_TRACE " + json.dumps(data["caption"]) + "\n").encode())
    if data["native_rows"] is not None:
        write("native-trace/trace-" + str(PID) + ".jsonl",
              ("\n".join(json.dumps(row) for row in data["native_rows"]) + "\n").encode())
