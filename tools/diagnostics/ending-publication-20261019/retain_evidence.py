#!/usr/bin/env python3
"""Seal all original diagnostic streams and source snapshots without rewriting them."""
import argparse
import base64
import hashlib
import io
import json
from pathlib import Path
import subprocess
import zipfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--evidence", type=Path, required=True)
args = parser.parse_args()
out = args.evidence
out.mkdir(parents=True, exist_ok=True)
status = subprocess.run(["git", "status", "--porcelain"], capture_output=True, text=True, timeout=30)
(out / "final-status.txt").write_text(status.stdout + status.stderr, encoding="utf-8")
files = sorted(path for path in out.rglob("*") if path.is_file() and
    not ({"package", "smoke-user", "__pycache__"} & set(path.relative_to(out).parts)) and
    path.suffix not in {".zip", ".dmp", ".pyc"} and path.name != "retained-hashes.json")
manifest = {path.relative_to(out.parent).as_posix(): {
    "bytes": path.stat().st_size, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()} for path in files}
manifest_path = out / "retained-hashes.json"
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
files.append(manifest_path)
payload = io.BytesIO()
with zipfile.ZipFile(payload, "w", zipfile.ZIP_DEFLATED) as target:
    for path in files:
        target.write(path, path.relative_to(out.parent).as_posix())
data = payload.getvalue()
if len(data) > 16 * 1024 * 1024:
    raise RuntimeError("Bounded log evidence exceeds 16 MiB; full evidence artifact remains separate")
print("DWM_EVIDENCE_BEGIN " + json.dumps({"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}))
encoded = base64.b64encode(data).decode("ascii")
for offset in range(0, len(encoded), 4096):
    print("DWM_EVIDENCE_CHUNK " + encoded[offset:offset + 4096])
print("DWM_EVIDENCE_END")
