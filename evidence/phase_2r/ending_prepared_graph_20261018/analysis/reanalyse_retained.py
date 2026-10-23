#!/usr/bin/env python3
"""Reanalyse a separate copy of already verified original cloud evidence."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys


def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def census(directory):
    return {path.relative_to(directory).as_posix(): digest(path)
            for path in sorted(directory.rglob("*")) if path.is_file()}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--original", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    original, output = args.original.resolve(), args.output.resolve()
    if output.exists() or output == original or original in output.parents:
        raise SystemExit("Output must be a new directory outside original evidence")
    source = Path(__file__).resolve().parent / "sources"
    before = census(original)
    sources_before = {path.relative_to(source).as_posix(): digest(path)
                      for path in sorted(source.rglob("*.py"))}
    driver_before = digest(Path(__file__))
    copy = output / "evidence-copy" / "ci"
    shutil.copytree(original, copy)
    command = [sys.executable, "-B", str(source / "bind_trace.py"),
               "--evidence", str(copy), "--reader", str(source / "replay/read_trace.py")]
    started = datetime.now(timezone.utc).isoformat()
    timed_out = False
    try:
        executed = subprocess.run(command, capture_output=True, text=True, timeout=150)
        exit_code, stdout, stderr = executed.returncode, executed.stdout, executed.stderr
    except subprocess.TimeoutExpired as exc:
        timed_out, exit_code = True, 124
        stdout, stderr = exc.stdout or "", exc.stderr or ""
        if isinstance(stdout, bytes):
            stdout = stdout.decode("utf-8", errors="replace")
        if isinstance(stderr, bytes):
            stderr = stderr.decode("utf-8", errors="replace")
    (output / "binder.stdout.log").write_text(stdout, encoding="utf-8")
    (output / "binder.stderr.log").write_text(stderr, encoding="utf-8")
    after = census(original)
    modified = sorted(name for name in set(before) | set(after) if before.get(name) != after.get(name))
    sources_after = {path.relative_to(source).as_posix(): digest(path)
                     for path in sorted(source.rglob("*.py"))}
    source_bytes_preserved = sources_before == sources_after and driver_before == digest(Path(__file__))
    derived = ["prepared-graph-binding.json", "prepared-graph-replay.json",
               "ending-publication-trace.json", "replay.stdout.log", "replay.stderr.log"]
    report = {
        "schema_version": 1,
        "scope": "Offline banner-corrected analysis of retained diagnostic evidence; no new native execution",
        "started_utc": started,
        "finished_utc": datetime.now(timezone.utc).isoformat(),
        "command": command, "exit_code": exit_code, "timed_out": timed_out,
        "original_directory": str(original), "copy_directory": str(copy),
        "original_file_count": len(before), "modified_original_files": modified,
        "original_bytes_preserved": not modified,
        "original_file_census_sha256": hashlib.sha256(json.dumps(before, sort_keys=True, separators=(",", ":")).encode()).hexdigest(),
        "original_cloud_binder_source": before["source/tools/diagnostics/ending-publication-20261019/bind_trace.py"],
        "original_failed_binding": before["prepared-graph-binding.json"],
        "original_trace": before["native-trace/trace-6124.jsonl"],
        "analysis_sources": sources_before,
        "analysis_source_bytes_preserved": source_bytes_preserved,
        "reanalysis_driver": driver_before,
        "binder_logs": {name: digest(output / name) for name in ["binder.stdout.log", "binder.stderr.log"]},
        "derived_outputs": {name: digest(copy / name) for name in derived if (copy / name).is_file()},
        "native_acceptance_established": False,
        "qualification": "The corrected binder was not the cloud binder. Original cloud results remain unchanged."
    }
    (output / "reanalysis-receipt.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"exit_code": exit_code, "original_bytes_preserved": not modified,
                      "analysis_source_bytes_preserved": source_bytes_preserved,
                      "original_file_count": len(before), "derived_output_count": len(report["derived_outputs"])}))
    raise SystemExit(exit_code if not modified and source_bytes_preserved else 3)
