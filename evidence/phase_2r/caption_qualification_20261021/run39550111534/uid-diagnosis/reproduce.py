"""Read-only offline first-offender reconstruction. Never fetches or runs Godot.

Godot 4.6.3 ResourceUID::text_to_id uses base34 accumulation in uint64,
accepts ASCII lower-case letters/digits, and returns uid & 0x7FFFFFFFFFFFFFFF.
The generated-text validator instead rejects values above that signed maximum.
Official pinned source:
https://github.com/godotengine/godot/blob/35e80b3a8822a9df9be390814b62f44c0a9c69e8/core/io/resource_uid.cpp
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

SOURCE = "b2cb75a792790f7bf396073b1586026fa1e20482"
RUNTIME = "scripts/ui/witnessed/WitnessedAccessibleContinue.gd.uid"
ALPHABET = "abcdefghijklmnopqrstuvwxy012345678"


def canonical(data):
    if re.fullmatch(rb"uid://[a-y0-8]{1,13}\r?\n?", data) is None:
        return False, None, "regex"
    body = data.decode("ascii").rstrip("\r\n")[6:]
    value = 0
    for char in body:
        value = value * 34 + ALPHABET.index(char)
    if value > 0x7FFFFFFFFFFFFFFF:
        return False, value, "exceeds signed63 range"
    if len(body) > 1 and body[0] == "a":
        return False, value, "noncanonical leading zero"
    return True, value, None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--artifact", type=Path, required=True)
    args = parser.parse_args()
    baseline = json.loads((args.artifact / "import/before.json").read_text())
    assert baseline["head"] == SOURCE, "Wrong frozen source"
    inventory = json.loads((args.artifact / "generated-import.json").read_text())
    tracked = {p: v["oid"] for p, v in baseline["head_entries"].items() if p.endswith(".uid")}
    generated = {r["path"]: r for r in inventory["entries"] if r["path"].endswith(".uid")}
    env = dict(os.environ, GIT_NO_LAZY_FETCH="1", GIT_TERMINAL_PROMPT="0")
    # Empty promisor remote URL additionally prevents any accidental lazy network
    # access on Git versions predating GIT_NO_LAZY_FETCH support.
    command = ["git", "-C", str(args.repo), "-c", "remote.origin.url=", "cat-file", "--batch"]
    with subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, env=env) as proc:
        try:
            for ordinal, path in enumerate(sorted((tracked.keys() | generated.keys()) - {RUNTIME}), 1):
                if path in tracked:
                    oid = tracked[path]
                    proc.stdin.write((oid + "\n").encode())
                    proc.stdin.flush()
                    header = proc.stdout.readline().decode().strip()
                    if header.endswith(" missing"):
                        raise RuntimeError(f"Missing local blob {oid} for {path}; refusing fetch. Obtain pinned objects separately.")
                    actual_oid, kind, size = header.split()
                    assert actual_oid == oid and kind == "blob", header
                    data = proc.stdout.read(int(size))
                    assert proc.stdout.read(1) == b"\n"
                    expected_sha = baseline["worktree"][path]["sha256"]
                else:
                    record = generated[path]["bytes"]
                    data = (args.artifact / "import" / record["file"]).read_bytes()
                    oid, expected_sha = record["git_blob"], record["sha256"]
                sha = hashlib.sha256(data).hexdigest()
                git_blob = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
                assert sha == expected_sha and git_blob == oid, f"Byte identity mismatch: {path}"
                valid, value, reason = canonical(data)
                if not valid:
                    print(json.dumps({"source": SOURCE, "first_offending_comparison_path": path,
                          "sorted_comparison_ordinal": ordinal, "preceding_valid_comparisons": ordinal - 1,
                          "git_blob": oid, "sha256": sha, "bytes": len(data), "hex": data.hex(),
                          "text": data.decode("ascii"), "validator_rejection": reason,
                          "base34_unsigned_value": str(value),
                          "godot_masked_value": str(value & 0x7FFFFFFFFFFFFFFF) if value is not None else None,
                          "runtime_own_decode_in_artifact": {k: generated[RUNTIME][k] for k in ("uid_text", "uid")}}, indent=2))
                    return
            raise RuntimeError("No offender reconstructed")
        finally:
            proc.stdin.close()
            proc.wait()


if __name__ == "__main__":
    main()
