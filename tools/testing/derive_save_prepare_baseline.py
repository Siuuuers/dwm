"""Restore only the eager journal copy that configured Backup capture replaces.

The matched cloud probe keeps the current schemas, capture, clock, parser reuse
and write validator in both variants. Refuse source drift instead of comparing
against a historical SaveManager with unrelated differences.
"""

import hashlib
import json
import pathlib
import sys


def derive_baseline(source: bytes) -> bytes:
    newline = b"\r\n" if b"\r\n" in source else b"\n"
    normalized = source.replace(b"\r\n", b"\n")
    if b"\r" in normalized or normalized.replace(b"\n", newline) != source:
        raise ValueError("Expected consistent LF or CRLF source newlines")
    after = (
        '\t\tvar bundle: Dictionary = stable["value"]["bundle"]\n'
        '\t\tvar earlier: Array\n'
        '\t\tif _backup_capture_configured:\n'
        '\t\t\tvar fresh := _prepare_backup_capture()\n'
        '\t\t\tif not fresh.get("ok", false):\n'
        '\t\t\t\treturn fresh\n'
        '\t\t\tcandidate.merge(fresh["value"])\n'
        '\t\t\tbundle = candidate["journal_candidate"]["current"]\n'
        '\t\t\tearlier = candidate["journal_candidate"]["earlier"]\n'
        '\t\telse:\n'
        '\t\t\tearlier = _journal.get_bundles_for_disk()\n'
        '\t\t_save_load_profile_phase(profile, "capture_us")'
    ).encode().replace(b"\n", newline)
    before = after.replace(
        b"\t\tvar earlier: Array" + newline,
        b"\t\tvar earlier: Array = _journal.get_bundles_for_disk()" + newline,
    ).replace(
        b"\t\telse:" + newline + b"\t\t\tearlier = _journal.get_bundles_for_disk()" + newline,
        b"",
    )
    if source.count(after) != 1 or source.count(before) != 0:
        raise ValueError("Expected exactly one current preparation branch and no eager baseline")
    return source.replace(after, before)


if __name__ == "__main__":
    source_path, destination_path = map(pathlib.Path, sys.argv[1:])
    source = source_path.read_bytes()
    baseline = derive_baseline(source)
    destination_path.write_bytes(baseline)
    print(json.dumps({"candidate_sha256": hashlib.sha256(source).hexdigest(),
                      "baseline_sha256": hashlib.sha256(baseline).hexdigest()}))
