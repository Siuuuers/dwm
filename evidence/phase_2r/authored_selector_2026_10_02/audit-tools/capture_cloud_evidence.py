#!/usr/bin/env python3
"""Materialize connector text and verify/extract downloaded Actions evidence.

Network downloads are done by the documented GitHub artifact tool followed by
download_file(file_id). No tokens, signed URLs, engines or PowerShell are needed.
"""
from __future__ import annotations
import argparse
import base64
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import stat
import zipfile


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read(path):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, "Duplicate JSON key")
            result[key] = value
        return result
    return json.loads(path.read_text(encoding="utf-8-sig"), object_pairs_hook=pairs)


def write_json(path, data):
    raw = (json.dumps(data, ensure_ascii=False, indent=2) + "\n").encode()
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        require(path.read_bytes() == raw, "Refusing to overwrite different retained evidence")
    else:
        path.write_bytes(raw)


def decode(path):
    target = path.with_suffix("")
    raw = base64.b64decode(path.read_bytes().strip(), validate=True)
    # Preserve original evidence; refuse secrets instead of silently redacting it.
    for pattern in (
        rb"\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})\b",
        rb"https?://[^\s\"<>]*[?&](?:sig|signature|token|access_token|X-Amz-Signature|X-Amz-Credential)=",
        rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----",
    ):
        require(re.search(pattern, raw, re.I) is None, "Unredacted secret pattern in returned evidence")
    if target.exists():
        require(target.read_bytes() == raw, "Refusing to overwrite different retained evidence")
    else:
        target.write_bytes(raw)
    path.unlink()


def verify_extract(root):
    run = read(root / "run.json")
    api = read(root / "artifacts-api.json")
    artifacts = api["artifacts"]
    require(len(artifacts) == api["total_count"], "Incomplete artifact pagination")
    require(len({a["id"] for a in artifacts}) == len(artifacts), "Duplicate artifact IDs")
    records = read(root / "artifact-manifest.json")
    omitted = read(root / "omissions.json") if (root / "omissions.json").exists() else {}
    by_id = {a["id"]: a for a in artifacts}
    require(len({a["id"] for a in records}) == len(records), "Duplicate download records")
    require(set(by_id) == {a["id"] for a in records} | {int(x) for x in omitted}, "Artifacts need explicit downloads or omissions")
    for row in records:
        record = by_id[row["id"]]
        require(all(row[k] == record[k] for k in ("name", "digest", "size_in_bytes")), "Download/API mismatch")
        require(record["workflow_run"]["id"] == run["id"] and record["workflow_run"]["head_sha"] == run["head_sha"], "Artifact run mismatch")
        name = record["name"]
        require(PurePosixPath(name).name == name and "\\" not in name, "Unsafe artifact name")
        original = Path(row["local_zip"]).resolve(strict=True)
        with original.open("rb") as stream:
            digest = hashlib.file_digest(stream, "sha256").hexdigest()
        require(record["digest"] == "sha256:" + digest and original.stat().st_size == record["size_in_bytes"], "ZIP hash/size mismatch")
        target = root / "artifacts" / name
        require(not target.is_symlink(), "Artifact symlink")
        with zipfile.ZipFile(original) as archive:
            members = [m for m in archive.infolist() if not m.is_dir()]
            require(len({m.filename for m in members}) == len(members), "Duplicate ZIP member")
            require(sum(m.file_size for m in members) <= 2 * 1024**3, "Extraction size bound")
            for member in members:
                p = PurePosixPath(member.filename)
                require(not p.is_absolute() and ".." not in p.parts and "\\" not in member.filename and ":" not in member.filename and not stat.S_ISLNK(member.external_attr >> 16), "Unsafe ZIP member")
            if target.exists():
                require(not any(p.is_symlink() for p in target.rglob("*")), "Extracted symlink")
                existing = {p.relative_to(target).as_posix() for p in target.rglob("*") if p.is_file()}
                require(existing <= {m.filename for m in members}, "Unknown existing extracted file")
            for member in members:
                destination = target / member.filename
                raw = archive.read(member)
                if destination.exists():
                    require(destination.is_file() and destination.read_bytes() == raw, "Existing extracted bytes differ")
                else:
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    destination.write_bytes(raw)
        print(json.dumps({"id": record["id"], "name": name, "verified_bytes": record["size_in_bytes"], "members": len(members)}))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest="command", required=True)
    sub.add_parser("decode-text").add_argument("paths", nargs="+", type=Path)
    sub.add_parser("verify-extract").add_argument("run_root", type=Path)
    a = p.parse_args()
    if a.command == "decode-text":
        for path in a.paths:
            decode(path)
    else:
        verify_extract(a.run_root.resolve())


if __name__ == "__main__":
    main()
