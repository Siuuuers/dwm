#!/usr/bin/env python3
"""Verify raw archive parts, or concatenate them into a new archive file."""

import argparse
import hashlib
import json
from pathlib import Path
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path,
                        default=Path(__file__).with_name("manifest.json"))
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--verify-only", action="store_true")
    mode.add_argument("--output", type=Path,
                      help="New output path; existing files are never overwritten")
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    if manifest.get("format") != "hospital-broad2-raw-split-v1":
        raise ValueError("Unsupported manifest format")
    parts = manifest["parts"]
    if len(parts) != manifest["split"]["part_count"]:
        raise ValueError("Part count mismatch")
    total = 0
    aggregate = hashlib.sha256()
    output = None
    output_created = False
    try:
        if args.output is not None:
            output = args.output.open("xb")
            output_created = True
        for index, part in enumerate(parts, 1):
            name = part["file"]
            if (part["order"] != index or not name
                    or Path(name).name != name or name in (".", "..")
                    or "/" in name or "\\" in name):
                raise ValueError("Invalid part name or order")
            if not 0 < part["bytes"] <= manifest["split"]["maximum_part_bytes"]:
                raise ValueError("Invalid part size")
            if index < len(parts) and part["bytes"] != manifest["split"]["maximum_part_bytes"]:
                raise ValueError("Short non-final part")
            digest = hashlib.sha256()
            count = 0
            with (args.manifest.parent / name).open("rb") as source:
                for chunk in iter(lambda: source.read(1024 * 1024), b""):
                    digest.update(chunk)
                    aggregate.update(chunk)
                    count += len(chunk)
                    total += len(chunk)
                    if output is not None:
                        output.write(chunk)
            if count != part["bytes"] or digest.hexdigest() != part["sha256"]:
                raise ValueError("Part identity mismatch: " + name)
        archive = manifest["archive"]
        if total != archive["bytes"] or aggregate.hexdigest() != archive["sha256"]:
            raise ValueError("Reassembled archive identity mismatch")
        if output is not None:
            output.close()
            output = None
        print(json.dumps({"verified": True, "bytes": total,
                          "sha256": aggregate.hexdigest(),
                          "output": str(args.output) if args.output is not None else None},
                         sort_keys=True))
    except BaseException:
        if output is not None:
            output.close()
        if output_created:
            args.output.unlink(missing_ok=True)
        raise


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError) as error:
        print("Verification failed: " + str(error), file=sys.stderr)
        sys.exit(1)
