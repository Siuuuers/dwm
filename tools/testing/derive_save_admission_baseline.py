"""Restore only SaveManager's four redundant validations in the current source.

The paired cloud probe must retain every current schema/recovery rule in both
variants. Refuse source drift instead of loading a historical implementation.
"""

import hashlib
import json
import pathlib
import sys


def derive_baseline(source: bytes) -> bytes:
    newline = b"\r\n" if b"\r\n" in source else b"\n"
    candidate = source.replace(b"\r\n", b"\n")
    replacements = [
        (
            '\t# Admission validates the original evidence, including its version and locator, and\n'
            '\t# returns a detached candidate. It does not reconstruct or relabel outer fields.\n'
            '\tvar migrated := SAVE_MIGRATIONS.migrate_document(parsed["value"],\n'
            '\t\t{"kind": locator["kind"], "slot_id": locator["slot_id"]})\n'
            '\t_save_load_profile_phase(profile, "admission_us")\n'
            '\tif not migrated.get("ok", false):',
            '\t# The legacy migrator reconstructs outer keys. Validate the actual outer evidence first;\n'
            '\t# otherwise a future version/wrong locator or false time could be silently relabeled.\n'
            '\tvar valid := SAVE_DOCUMENT_SCHEMA.validate(parsed["value"])\n'
            '\t_save_load_profile_phase(profile, "schema_us")\n'
            '\tif not valid.get("ok", false):',
            1,
        ),
        (
            '\tvar document: Dictionary = migrated["value"]["document"]\n'
            '\tvar snapshot: Dictionary = document["current_snapshot"]["snapshot"]',
            '\tvar document: Dictionary = valid["value"]["candidate"]\n'
            '\tvar migrated := SAVE_MIGRATIONS.migrate_document(parsed["value"],\n'
            '\t\t{"kind": locator["kind"], "slot_id": locator["slot_id"]})\n'
            '\t_save_load_profile_phase(profile, "migration_us")\n'
            '\tif not migrated.get("ok", false):\n'
            '\t\trecord["reason"] = "unreadable"\n'
            '\t\treturn {"ok": true, "value": record}\n'
            '\tif document["kind"] != locator["kind"] or document["slot_id"] != locator["slot_id"]:\n'
            '\t\trecord["reason"] = "unreadable"\n'
            '\t\treturn {"ok": true, "value": record}\n'
            '\tvar snapshot: Dictionary = document["current_snapshot"]["snapshot"]',
            1,
        ),
        (
            '\t# Admission already returned the validated, detached document.',
            '\tvar validated: Dictionary = SAVE_DOCUMENT_SCHEMA.validate(document)\n'
            '\tif not validated.get("ok", false):\n'
            '\t\treturn validated\n'
            '\tdocument = validated["value"]["candidate"]',
            3,
        ),
    ]
    for after, before, expected_count in replacements:
        needle = after.encode()
        if candidate.count(needle) != expected_count:
            raise ValueError(f"Expected {expected_count} current-source admission anchors")
        candidate = candidate.replace(needle, before.encode())
    return candidate.replace(b"\n", newline)


if __name__ == "__main__":
    source_path, destination_path = map(pathlib.Path, sys.argv[1:])
    source = source_path.read_bytes()
    baseline = derive_baseline(source)
    destination_path.write_bytes(baseline)
    print(json.dumps({
        "candidate_sha256": hashlib.sha256(source).hexdigest(),
        "baseline_sha256": hashlib.sha256(baseline).hexdigest(),
    }))
