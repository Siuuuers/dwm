"""Focused caption test preparation only; no export acceptance or Godot execution.
Derived from reviewed prepare_delivery.py at 13c34ff20. Retains raw/index/settings
custody; exactly two runtime UID owners are admitted and separately classified.
"""
import argparse
import json
import re
from pathlib import Path
import shutil
import sys
import capture_import as custody

PRODUCT = "bef78c105697a256ee0ff1a40e9b4c306e2740e7"
PROJECT = "5e8009d890f9e4359b24bb68a59fdec1bf56ef0a3ea94be06c3e43a6d2353053"
IMPORTED_PROJECT = "6880d26a04484587a54c63e0a98072984b6adac7ac3e9d07e8d138e934428fdd"
PRESET = "76d904435496d2057572225b796f8b3c74f121a21254d211a6246caaf96efcaa"
RUNTIME_UID_OWNERS = {
    "scripts/ui/witnessed/WitnessedAccessibleContinue.gd.uid": "9e37a90dfb3ca1816df85e41fcc849da90bb64fa",
    "scripts/narrative/SceneValidationTiming.gd.uid": "88b7cf8c00ec2b71942fa33c299498b34161c9db",
}
OBSERVATION_SOURCES = {
    "scripts/narrative/DialogicRuntimeAdapter.gd": {
        "blob": "39d441c636688177e9b1b809013843cc8db0e47d",
        "sha256": "5b8edeeb27eefa097a02c249026ff93ef016255955d0096f1661dcaec7379711"
    },
    "scripts/narrative/SceneValidationTiming.gd": {
        "blob": "88b7cf8c00ec2b71942fa33c299498b34161c9db",
        "sha256": "b07eddde556ea8b15d633da93640c500e910223cc1b2de579480992e050bf793"
    },
    "scripts/narrative/SoloReadingSession.gd": {
        "blob": "cf9e72d23c21a0926248d706f41098cdf3256b1a",
        "sha256": "1639a42e6f4d5a76a516a2738cea247a0e797bfda53990dbdf46d597a6b19cdf"
    },
    "tests/integration/scene_seven_day_connected_child.gd": {
        "blob": "d9f31e79658a83b3a835766564033ba448177cc0",
        "sha256": "1ae0943ad187e6f85d42345a439178cd01f692ca61348a9cf40330ace6c9f7fb"
    },
    "tests/integration/test_scene_ending_direct_return.gd": {
        "blob": "d270ab1535e966f8b32f3a3100350332142c4c5f",
        "sha256": "88e554c884e613018309fd9225014121f50a48ab5f5d67ec9f86a94c2d81835d"
    },
    "tests/integration/scene_later_caption_child.gd": {
        "blob": "5a5b16e1dfd00910be6995317fbc9646581d34e6",
        "sha256": "eb032c12a41d188573cebcbdc30e0c059441fe9a572b277fb55ef8b4174526be"
    },
    "scripts/infrastructure/save/SaveDocumentSchema.gd": {
        "blob": "c9b3b58e21671cf5de39e3d5195869462ef68ca2",
        "sha256": "c0fe0f1e37d2c11fe4884a1efd6fde31c3f93c1963a65f6606c5ff9fe31cfce0"
    }
}
GITLINKS = {".claude/skills/godot-prompter/1.10.0", ".claude/skills/superpowers/6.1.1"}


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def write(name, value):
    (OUTPUT / name).write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def select_custody(name):
    custody.ROOT = ROOT
    custody.OUT = OUTPUT / name
    custody.OUT.mkdir(parents=True, exist_ok=True)


def check_pin():
    require(custody.git("rev-parse", "HEAD").stdout.decode().strip() == PRODUCT, "PRODUCT_PIN_CHANGED")


def check_observation_sources(baseline):
    receipts = []
    for path, expected in OBSERVATION_SOURCES.items():
        owner = baseline["head_entries"].get(path, {})
        require(owner.get("oid") == expected["blob"] and owner.get("mode") in ("100644", "100755"),
                "OBSERVATION_SOURCE_NOT_PINNED: " + path)
        full = ROOT / path
        require(full.is_file() and not full.is_symlink(), "OBSERVATION_SOURCE_NONREGULAR: " + path)
        actual = custody.sha(full.read_bytes())
        require(actual == expected["sha256"], "OBSERVATION_SOURCE_BYTES_CHANGED: " + path)
        receipts.append({"path": path, "blob": owner["oid"], "sha256": actual})
    return receipts


def generated(phase, baseline):
    source_receipts = check_observation_sources(baseline)
    # Include ignored source-tree inputs, too. .godot is the disposable engine
    # cache/output, not an authored source input; all receipts live outside ROOT.
    paths = sorted(p.decode("utf-8") for p in custody.git("ls-files", "--others", "-z").stdout.split(b"\0")
                   if p and not p.startswith(b".godot/"))
    entries, rejected = [], []
    for path in paths:
        full = ROOT / path
        record = {"path": path, "provenance": "fresh pinned checkout, generated after baseline by official import/focused tests"}
        if not full.is_file() or full.is_symlink():
            record["classification"] = "unsupported_nonregular_input"
            rejected.append(path)
        else:
            record["bytes"] = custody.retain(full.read_bytes())
            suffix = ".import" if path.endswith(".import") else ".uid" if path.endswith(".uid") else None
            source = path[:-len(suffix)] if suffix else None
            record["source"] = source
            # Keep bounded to development-input exclusions in the pinned preset.
            # This focused lane does not export or audit a package.
            excluded = path.startswith("tests/") or path.startswith("evidence/")
            owned = source in baseline["head_entries"] if source else False
            if path in RUNTIME_UID_OWNERS:
                try:
                    check_runtime_uid(record, baseline, path)
                except Exception as error:
                    record["classification"] = "rejected_runtime_generated_uid"
                    record["failure"] = str(error)
                    rejected.append(path + ": " + str(error))
            elif suffix and owned and excluded:
                record["classification"] = "excluded_development_metadata"
                record["exclusion"] = "tests/*" if path.startswith("tests/") else "evidence/*"
                record["source_blob"] = baseline["head_entries"][source]["oid"]
                record["pack_audit"] = "export preset exclusion only; no package produced or audited in focused lane"
            else:
                record["classification"] = "unreviewed_generated_input"
                rejected.append(path)
        entries.append(record)
    write(f"generated-{phase}.json", {"entries": entries, "rejected": rejected,
          "observation_sources": source_receipts, "preset_sha256": custody.sha((ROOT / "export_presets.cfg").read_bytes()),
          "ignored_engine_cache": ".godot/", "source_promotion": False})
    require(not rejected, "UNREVIEWED_GENERATED_INPUT: " + repr(rejected))
    require(custody.sha((ROOT / "export_presets.cfg").read_bytes()) == PRESET, "EXPORT_PRESET_CHANGED")
    return entries


def decode_generated_uid(data):
    # Canonical id_to_text alphabet is base34 (z and 9 intentionally unused).
    # Validate actual bytes; never derive or install a replacement UID.
    require(re.fullmatch(rb"uid://[a-y0-8]{1,13}\r?\n?", data) is not None, "INVALID_GENERATED_UID")
    text = data.decode("ascii").rstrip("\r\n")
    number = 0
    for char in text[6:]:
        number = number * 34 + "abcdefghijklmnopqrstuvwxy012345678".index(char)
    require(number <= 0x7FFFFFFFFFFFFFFF and (len(text[6:]) == 1 or text[6] != "a"), "INVALID_GENERATED_UID")
    return text, str(number)


def decode_peer_uid(data):
    # Godot 4.6.3 at 35e80b3a: ResourceFormatLoader::get_resource_uid passes
    # FileAccess::get_line() to ResourceUID::text_to_id. get_line stops at the
    # first CR, LF, or NUL; trailing bytes stay in custody, not in the UID text.
    # text_to_id accepts a-z/0-9 (including z/9), accumulates uint64 base34 with
    # wraparound, then masks to signed63. This is comparison, not normalization.
    line = re.split(rb"[\r\n\0]", data, maxsplit=1)[0]
    # String::utf8 consumes one initial UTF-8 BOM (core/string/ustring.cpp).
    # Only the parsed view changes; the complete original bytes stay retained.
    if line.startswith(b"\xef\xbb\xbf"):
        line = line[3:]
    # Intentionally stricter malformed-input guard: require a nonempty suffix.
    # Engine text_to_id would accept bare uid:// as zero. We refuse that case
    # with the exact peer path rather than silently treating missing data as UID0.
    require(re.fullmatch(rb"uid://[a-z0-9]+", line) is not None, "INVALID_PEER_UID_LINE")
    text = line.decode("ascii")
    value = 0
    for char in text[6:]:
        digit = ord(char) - ord("a") if "a" <= char <= "z" else ord(char) - ord("0") + 25
        value = (value * 34 + digit) & 0xFFFFFFFFFFFFFFFF
    return text, str(value & 0x7FFFFFFFFFFFFFFF)


def check_runtime_uid(entry, baseline, runtime_uid):
    entry["uid_comparisons_complete"] = False
    source = runtime_uid[:-4]
    owner = baseline["head_entries"].get(source, {})
    require(owner.get("oid") == RUNTIME_UID_OWNERS[runtime_uid] and owner.get("mode") in ("100644", "100755"),
            "RUNTIME_UID_SOURCE_NOT_PINNED")
    text, uid = decode_generated_uid((ROOT / runtime_uid).read_bytes())
    entry.update({"classification": "focused_runtime_generated_uid", "source_blob": owner["oid"],
                  "uid_text": text, "uid": uid,
                  "scope": "focused rendered source test only; no export/package acceptance"})
    # Check every actual peer, including ignored generated sidecars, by its
    # effective engine ID. Retain attempted progress and offending bytes even
    # when malformed input prevents completion; never claim a partial no-collision.
    tracked = {path for path in baseline["head_entries"] if path.endswith(".uid")}
    generated_paths = {p.decode("utf-8") for p in custody.git("ls-files", "--others", "-z").stdout.split(b"\0")
                       if p and not p.startswith(b".godot/") and p.endswith(b".uid")}
    peers = sorted((tracked | generated_paths) - {runtime_uid})
    compared, collisions = [], []
    entry.update({"uid_comparisons": compared, "collisions": collisions,
                  "uid_comparisons_complete": False, "uid_peer_count": len(peers)})
    for path in peers:
        row = {"path": path, "tracked": path in tracked, "source": path[:-4],
               "source_blob": baseline["head_entries"].get(path[:-4], {}).get("oid"),
               "tracked_sidecar_blob": baseline["head_entries"].get(path, {}).get("oid"),
               "status": "pending"}
        compared.append(row)
        try:
            full = ROOT / path
            require(full.is_file() and not full.is_symlink(), "UID_COMPARISON_NONREGULAR")
            data = full.read_bytes()
            row["bytes"] = custody.retain(data)
            row["sha256"] = row["bytes"]["sha256"]
            peer_text, other_uid = decode_peer_uid(data)
            row.update({"line": peer_text, "uid": other_uid, "status": "decoded"})
            if uid == other_uid:
                collisions.append(path)
        except Exception as error:
            row.update({"status": "failed", "failure": str(error)})
            entry["uid_comparison_failure_path"] = path
            raise RuntimeError("UID_COMPARISON_FAILED: " + path + ": " + str(error)) from error
    entry["uid_comparisons_complete"] = True
    require(not collisions, "RUNTIME_UID_COLLISION: " + repr(collisions))


def enforce_report(report, permit_settings):
    require(report["complete"] and report["head"] == report["head_after"] == PRODUCT, "INCOMPLETE_OR_MOVED_CUSTODY")
    for change in report["changes"]:
        path = change["path"]
        if change["index_changed"]:
            require(path in GITLINKS and change["index_before"]["mode"] == "160000" and change["index_after"] is None,
                    "UNEXPECTED_INDEX_MUTATION: " + path)
        if change["worktree_changed"]:
            require(permit_settings and path == "project.godot" and
                    change["before"].get("sha256") == PROJECT and
                    change["after"].get("sha256") == IMPORTED_PROJECT and
                    change["before"]["kind"] == change["after"]["kind"] == "file" and
                    change["before"]["executable"] == change["after"]["executable"],
                    "UNEXPECTED_RAW_BYTE_MUTATION: " + path)


def capture_and_enforce(phase, permit_settings):
    require(phase in ("import", "restored", "post-tests"), "FOCUSED_PHASE_ONLY")
    select_custody(phase)
    if phase != "import":
        # Preserve the original import capture; use its immutable baseline in a
        # separate final snapshot so a later failure cannot erase earlier bytes.
        shutil.copyfile(OUTPUT / "import/before.json", custody.OUT / "before.json")
        shutil.copytree(OUTPUT / "import/bytes", custody.OUT / "bytes", dirs_exist_ok=True)
    errors = []
    try:
        custody.capture_after()
    except Exception as error:
        errors.append(str(error))
    baseline = read(OUTPUT / "import/before.json")
    try:
        entries = generated(phase, baseline)
    except Exception as error:
        errors.append(str(error))
        entries = []
    try:
        enforce_report(read(custody.OUT / "changes.json"), permit_settings)
    except Exception as error:
        errors.append(str(error))
    if phase in ("restored", "post-tests") and not errors:
        prior = read(OUTPUT / "generated-import.json")["entries"]
        facts = lambda rows: {r["path"]: r["bytes"]["sha256"] for r in rows}
        try:
            require(facts(entries) == facts(prior), "GENERATED_INPUT_SET_CHANGED_SINCE_IMPORT")
        except Exception as error:
            errors.append(str(error))
    write(f"{phase}-policy.json", {"passed": not errors, "errors": errors, "settings_exception": permit_settings})
    require(not errors, "; ".join(errors))


def before():
    select_custody("import")
    check_pin()
    custody.capture_before()
    baseline = read(custody.OUT / "before.json")
    require(set(baseline["head_entries"]) == set(baseline["index_entries"]), "BASELINE_INDEX_PATHS")
    for path, head in baseline["head_entries"].items():
        index = baseline["index_entries"][path]
        require(index["mode"] == head["mode"] and index["oid"] == head["oid"], "BASELINE_INDEX_CHANGED: " + path)
        if head["mode"] != "160000":
            require(baseline["worktree"][path].get("git_blob") == head["oid"], "BASELINE_RAW_BYTES_NOT_PINNED: " + path)
    require(custody.sha((ROOT / "project.godot").read_bytes()) == PROJECT, "PROJECT_BASELINE_CHANGED")
    entries = generated("before", baseline)
    require(not entries, "BASELINE_NOT_CLEAN")
    write("before-policy.json", {"passed": True, "product": PRODUCT, "tracked_paths": len(baseline["worktree"])})


def restore():
    require(read(OUTPUT / "import-policy.json")["passed"], "IMPORT_POLICY_NOT_PASSED")
    select_custody("import")
    check_pin()
    current = (ROOT / "project.godot").read_bytes()
    require(custody.sha(current) in (PROJECT, IMPORTED_PROJECT), "PROJECT_CHANGED_SINCE_CAPTURE")
    source = custody.git("show", PRODUCT + ":project.godot").stdout
    require(custody.sha(source) == PROJECT, "PINNED_PROJECT_BYTES_MISMATCH")
    # The only authorized restoration; source bytes come from the pinned object,
    # never a regenerated settings file. Exact post-write bytes are checked.
    (ROOT / "project.godot").write_bytes(source)
    require((ROOT / "project.godot").read_bytes() == source, "PROJECT_RESTORE_NOT_EXACT")
    write("settings-restore.json", {"before_sha256": custody.sha(current), "restored_sha256": custody.sha(source), "source": PRODUCT + ":project.godot", "exact": True})
    capture_and_enforce("restored", False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--phase", choices=["before", "after", "restore", "post-tests"], required=True)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    ROOT, OUTPUT = args.root.resolve(), args.output.resolve()
    require(OUTPUT != ROOT and ROOT not in OUTPUT.parents, "EVIDENCE_MUST_BE_EXTERNAL")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    try:
        if args.phase == "before":
            before()
        elif args.phase == "after":
            capture_and_enforce("import", True)
        elif args.phase == "restore":
            restore()
        else:
            capture_and_enforce("post-tests", False)
    except Exception as error:
        write(args.phase + "-failure.json", {"error": str(error)})
        raise

