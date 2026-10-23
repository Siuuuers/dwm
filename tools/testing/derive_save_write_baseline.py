"""Bypass the current per-write witness/memo, retaining every other save rule.

The unused helper stays available so the shared benchmark owner's production
forwarder still parses. Both writes call the full validator directly in this
historical no-memo control; preparation comparisons use the current helper.
"""

import hashlib
import json
import pathlib
import sys


def derive_baseline(source: bytes) -> bytes:
    newline = b"\r\n" if b"\r\n" in source else b"\n"
    result = source.replace(b"\r\n", b"\n")
    after = (
        '\t\t\tvar validated_texts := {}\n'
        '\t\t\tvar validator := _write_document_text_validator.bind(validated_texts)\n'
        '\t\t\tvar written: Dictionary = _storage.write_atomic_if_revision(path, bytes, validator, candidate["revision"])'
    ).encode()
    before = '\t\t\tvar written: Dictionary = _storage.write_atomic_if_revision(path, bytes, _document_text_validator, candidate["revision"])'.encode()
    helper = '''## One synchronous Backup write may validate the same outgoing text before and after promotion.
## Reuse only a successful validation of that exact String within this call. Storage still reads
## and proves the physical revision/bytes itself; another write receives a fresh empty memo.
## The caller consumes a storage witness, not the admitted document; each success is detached.
func _write_document_text_validator(text: String, validated_texts: Dictionary) -> Dictionary:
	if validated_texts.has(text):
		return {"ok": true, "code": &"ok", "value": {}}
	var result := _document_text_validator(text)
	# Preserve every refusal, including a malformed success that storage rejects.
	if not result.get("ok", false) or typeof(result.get("value")) != TYPE_DICTIONARY:
		return result
	validated_texts[text] = {"ok": true, "code": &"ok", "value": {}}
	return {"ok": true, "code": &"ok", "value": {}}

'''.encode()
    if result.count(after) != 1 or result.count(helper) != 1:
        raise ValueError("Expected exactly one current write caller and memo helper")
    return result.replace(after, before).replace(b"\n", newline)


if __name__ == "__main__":
    source_path, destination_path = map(pathlib.Path, sys.argv[1:])
    source = source_path.read_bytes()
    baseline = derive_baseline(source)
    destination_path.write_bytes(baseline)
    print(json.dumps({"candidate_sha256": hashlib.sha256(source).hexdigest(),
                      "baseline_sha256": hashlib.sha256(baseline).hexdigest()}))
