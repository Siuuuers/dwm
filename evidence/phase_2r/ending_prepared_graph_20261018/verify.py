#!/usr/bin/env python3
"""Verify custody of the original log ZIP for run 39162900907; never replay it.

Inputs: --archive ZIP --archive-sha256 SHA --archive-bytes N
        --source-census publication-source-census.json --output FRESH_DIRECTORY

Writes verification.json and byte-for-byte original/ci/... files. Exit 0 means
archive custody and all available source checks passed. Source completeness is
reported separately when an early failure prevented a complete audit origin.
No exit code here certifies the native journey, binder finding, or engine build.
Missing outcome documents mean unexecuted or unretained, never a passing result.
"""

import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import stat
import zipfile


RUN = 39162900907
JOB = 117779747741
GAME = "81847d8b1560340a3a7769223cee0b46c6bdc0f9"
GAME_TREE = "4581a9f12d63684836c722f72cffd533491f3c06"
TOOLS = "c24934929e3d2c8c013f335309620525e2f64d61"
TOOLS_TREE = "afa5000416f0320aa3d2134982111b7082693e1d"
CONTROLLER = "4543e87557bcb3a045448601f3cf9f64b2281096"
CONTROLLER_SHA = "e54083b1829fb21be567d85c9e8163e6f8c50de498f22fcf9a81ee676b0bebd2"
CENSUS_SHA = "2f22f6965c6f43d131eb62cc66713bbddf984d288a6ffd71ead6cc833c4822de"
PREFIX = "tools/diagnostics/ending-publication-20261019/"
# Independently fetched c249 tree entries; its only changes from GAME are the 83 tool additions.
SHARED_BLOBS = {
    "tools/testing/Invoke-ExportedGameplay.ps1": ("e91f912d8351ba7e38401b261d0fb2f0aa3032dc", 52927),
    "tools/testing/Probe-ExportedWindow.ps1": ("4d678892e911e205a498af5be21afe4ed0242e24", 11121),
    "tools/testing/Invoke-IsolatedGodot.ps1": ("14b379880b4ad26935ad953d141df8c19e399cf3", 19919),
    "tools/testing/Invoke-WindowsExportValidation.ps1": ("322d02bbe72d8e2e3c1e5b637fd9ac253ef31fff", 19523),
    "tests/tooling/Test-ExportedGameplayDeadline.ps1": ("436c73a380baec1a3bc6ba64d273ff052e316d78", 3023),
    "project.godot": ("b3e4ec92242535d81845bdc2dc7537e9e3ec122e", 14532),
    "export_presets.cfg": ("ccb9409ac1054d0b4b52e78df823c33f532e83fb", 1117),
    "scripts/ui/EndingScene.gd": ("dec4979b1d6331a22aac268b4b2a926e70a601eb", 15926),
    "scripts/ui/witnessed/WitnessedCaptionLayer.gd": ("5c85ce306366917c995db06794e18cb4035b2711", 84211),
    "scripts/ui/witnessed/WitnessedAccessibleCaption.gd": ("c29b306199bf1b8f9ce4352872ff569e2b3f0bd4", 1485),
    "scripts/ui/witnessed/WitnessedSourceCanvas.gd": ("db11d71216b47004da8a3207acaac73e964cffa6", 1107),
}
SHARED = set(SHARED_BLOBS)
MANIFEST = "ci/retained-hashes.json"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "Duplicate JSON key: " + key)
        result[key] = value
    return result


def reject_constant(value):
    raise ValueError("Non-JSON numeric constant: " + value)


def decode(data):
    return json.loads(data.decode("utf-8-sig"), object_pairs_hook=unique_object,
                      parse_constant=reject_constant)


def hashes(data):
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
            "git_blob": hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()}


def safe_name(name):
    require(type(name) is str and name.startswith("ci/") and "\\" not in name and ":" not in name,
            "Archive path is outside canonical ci/: " + repr(name))
    require(not any(ord(char) < 32 for char in name) and
            all(part not in {"", ".", ".."} for part in name.split("/")) and
            PurePosixPath(name).as_posix() == name,
            "Unsafe/noncanonical archive path: " + repr(name))
    return name


def check_pin(actual, expected, name, git_blob=True):
    keys = ("bytes", "sha256", "git_blob") if git_blob else ("bytes", "sha256")
    require(type(expected) is dict and type(expected.get("bytes")) is int and
            all(actual[key] == expected.get(key) for key in keys), "File pin mismatch: " + name)


def verify_sources(files, census, report):
    snapshots = {name.removeprefix("ci/source/"): hashes(data)
                 for name, data in files.items() if name.startswith("ci/source/")}
    expected_tools = {item["path"]: item for item in census}
    expected_sources = set(expected_tools) | SHARED | {"controller.yml"}
    require(not (snapshots.keys() - expected_sources), "Unexpected source snapshot path")
    source = {"complete": False, "origin_present": "ci/audit-origin.json" in files,
              "expected_tool_count": 83, "expected_game_count": 11, "expected_controller_count": 1,
              "observed_source_count": len(snapshots), "verified_tool_count": 0,
              "verified_game_count": 0, "controller_verified": False,
              "missing_source_paths": sorted(expected_sources - snapshots.keys()), "snapshots": snapshots}
    report["source_custody"] = source
    for name in sorted(snapshots.keys() & expected_tools.keys()):
        check_pin(snapshots[name], expected_tools[name], name)
        source["verified_tool_count"] += 1
    for name in sorted(snapshots.keys() & SHARED):
        require((snapshots[name]["git_blob"], snapshots[name]["bytes"]) == SHARED_BLOBS[name],
                "Game snapshot differs from independently fetched tree: " + name)
        source["verified_game_count"] += 1
    if "controller.yml" in snapshots:
        require(snapshots["controller.yml"]["sha256"] == CONTROLLER_SHA, "Rendered controller bytes differ")
        source["controller_verified"] = True
    if not source["origin_present"]:
        source["coverage"] = "Incomplete: no retained audit origin; only available independent pins were checked"
        return

    origin = decode(files["ci/audit-origin.json"])
    report["audit_origin"] = origin
    for key, value in {"game_commit": GAME, "game_tree": GAME_TREE, "tool_source": TOOLS,
                       "tool_tree": TOOLS_TREE, "controller": CONTROLLER,
                       "engine_base": "35e80b3a8822a9df9be390814b62f44c0a9c69e8",
                       "engine_tree": "499fa231ee5d21878988a4a9cb881749def3946d"}.items():
        require(origin.get(key) == value, "Audit origin identity mismatch: " + key)
    changed = origin["changed_paths"]
    require(type(changed) is list and len(changed) == len(expected_tools) and set(changed) == set(expected_tools),
            "Audit origin changed paths differ from the frozen 83 tools")
    pins = origin["shared_source_pins"]
    require(type(pins) is dict and set(pins) == set(expected_tools) | SHARED,
            "Audit origin source pin census differs from the 83 tools and 11 game files")
    require(set(snapshots) == expected_sources, "Complete audit origin has missing source snapshots")
    for name, pin in pins.items():
        check_pin(snapshots[name], pin, name)
        require(pin.get("source_commit") == (GAME if name in SHARED else TOOLS),
                "Snapshot source commit mismatch: " + name)
    source.update(complete=True, coverage="Complete retained origin and exact 95-source census")


def retain_outcomes(files, report):
    names = ["ci/native-build/build-receipt.json", "ci/native-diagnostic/validation.json",
             "ci/diagnostic-acceptance.json", "ci/prepared-graph-binding.json"]
    for mode in ("capability", "create", "load"):
        names += ["ci/exported-" + mode + "/result.json", "ci/" + mode + "-process.json"]
    documents = {}
    for name in names:
        if name not in files:
            documents[name] = {"present": False, "status": "unexecuted_or_unretained", "value": None}
            continue
        record = {"present": True, "status": "retained", **hashes(files[name])}
        try:
            record["value"] = decode(files[name])
        except (ValueError, UnicodeError) as exc:
            record.update(status="retained_unreadable", value=None, error=str(exc))
        documents[name] = record
    report["original_documents"] = documents
    report["native_modes"] = {}
    for mode in ("capability", "create", "load"):
        result = documents["ci/exported-" + mode + "/result.json"]
        process = documents["ci/" + mode + "-process.json"]
        present = any(name.startswith("ci/exported-" + mode + "/") for name in files) or process["present"]
        report["native_modes"][mode] = {
            "status": "result_retained" if result["present"] else
                      ("partial_evidence_without_result" if present else "no_retained_execution_evidence"),
            "result_present": result["present"], "process_present": process["present"],
            "reported_result": result["value"], "reported_process": process["value"],
            "qualification": "Original values preserved; no independent native acceptance evaluated",
        }


def verify(args):
    args.output.mkdir(parents=True, exist_ok=False)
    report = {"schema_version": 1, "scope": "Original archive and source custody only",
              "expected_run": RUN, "expected_job": JOB,
              "run_job_binding": "Externally supplied archive identity; this ZIP does not itself attest Actions run/job metadata",
              "archive_custody_ok": False, "available_source_checks_ok": False,
              "custody_ok": False, "native_acceptance_evaluated": False,
              "official_acceptance_established": False, "problems": [],
              "source_custody": {"complete": False}, "extracted_file_count": 0}
    files = {}
    try:
        require(type(args.archive_bytes) is int and args.archive_bytes > 0 and
                re.fullmatch(r"[0-9a-f]{64}", args.archive_sha256) is not None, "Invalid external archive receipt")
        data = args.archive.read_bytes()
        observed = hashes(data)
        report["archive"] = {"path": str(args.archive), "expected_bytes": args.archive_bytes,
                             "expected_sha256": args.archive_sha256, **observed}
        require(observed["bytes"] == args.archive_bytes and observed["sha256"] == args.archive_sha256,
                "Original archive outer bytes/SHA256 mismatch")
        census_data = args.source_census.read_bytes()
        report["source_census"] = {"path": str(args.source_census), **hashes(census_data)}
        require(report["source_census"]["sha256"] == CENSUS_SHA, "Supplied source census is not the frozen reviewed file")
        census = decode(census_data)
        require(type(census) is list and len(census) == 83 and
                len({item["path"] for item in census}) == 83 and
                all(item["path"].startswith(PREFIX) for item in census), "Invalid frozen 83-tool census")

        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            entries = archive.infolist()
            seen = set()
            for item in entries:
                name = safe_name(item.filename)
                require(item.orig_filename == name and not item.is_dir() and
                        stat.S_IFMT(item.external_attr >> 16) in (0, stat.S_IFREG) and
                        not (item.flag_bits & 1), "Non-regular or encrypted archive member: " + name)
                require(name.casefold() not in seen, "Duplicate/case-colliding archive path: " + name)
                seen.add(name.casefold())
            names = {item.filename for item in entries}
            require(not any("/".join(name.split("/")[:index]) in names
                            for name in names for index in range(1, len(name.split("/")))),
                    "Archive file/directory prefix collision")
            require(MANIFEST in names, "Original retained-hashes.json is absent")
            manifest = decode(archive.read(MANIFEST))
            require(type(manifest) is dict, "Outer retained manifest is not an object")
            for name in manifest:
                safe_name(name)
            require(set(manifest) == names - {MANIFEST}, "Retained manifest does not cover the exact ZIP file census")
            for item in entries:
                # ZipFile.read checks each original member CRC, including empty files.
                files[item.filename] = archive.read(item)
                if item.filename != MANIFEST:
                    check_pin(hashes(files[item.filename]), manifest[item.filename], item.filename, git_blob=False)
        report.update(archive_custody_ok=True, archive_member_count=len(files),
                      manifest_file_count=len(manifest), manifest_sha256=hashes(files[MANIFEST])["sha256"])
        original = args.output / "original"
        for name, data in files.items():
            path = original / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        report["extracted_file_count"] = len(files)
        report["original_directory"] = str(original)
        verify_sources(files, census, report)
        report["available_source_checks_ok"] = True
        report["custody_ok"] = True
    except (OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile, RuntimeError) as exc:
        report["problems"].append(type(exc).__name__ + ": " + str(exc))
    # These are the actual top-level run files, never similarly named historical source fixtures.
    retain_outcomes(files, report)
    report["outcome_note"] = "Absent or unreadable documents establish no pass. Retained false outcomes are copied unchanged."
    result_path = args.output / "verification.json"
    result_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({"custody_ok": report["custody_ok"], "archive_custody_ok": report["archive_custody_ok"],
                      "source_complete": report["source_custody"]["complete"],
                      "verification": str(result_path), "problems": report["problems"]}))
    return 0 if report["custody_ok"] else 2


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--archive-sha256", required=True)
    parser.add_argument("--archive-bytes", type=int, required=True)
    parser.add_argument("--source-census", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    raise SystemExit(verify(parser.parse_args()))
