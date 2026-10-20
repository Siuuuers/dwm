"""Pinned build-input policy around reviewed raw-byte custody. No Godot execution."""
import argparse
import json
from pathlib import Path
import shutil
import sys
import capture_import as custody

PRODUCT = "c8358870d3ece92d5f8cc7ba65aefe34a746be5c"
PROJECT = "5e8009d890f9e4359b24bb68a59fdec1bf56ef0a3ea94be06c3e43a6d2353053"
IMPORTED_PROJECT = "6880d26a04484587a54c63e0a98072984b6adac7ac3e9d07e8d138e934428fdd"
PRESET = "76d904435496d2057572225b796f8b3c74f121a21254d211a6246caaf96efcaa"
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


def generated(phase, baseline):
    # Include ignored source-tree inputs, too. .godot is the disposable engine
    # cache/output, not an authored source input; all receipts live outside ROOT.
    paths = sorted(p.decode("utf-8") for p in custody.git("ls-files", "--others", "-z").stdout.split(b"\0")
                   if p and not p.startswith(b".godot/"))
    entries, rejected = [], []
    for path in paths:
        full = ROOT / path
        record = {"path": path, "provenance": "fresh pinned checkout, generated after baseline by official import/export"}
        if not full.is_file() or full.is_symlink():
            record["classification"] = "unsupported_nonregular_input"
            rejected.append(path)
        else:
            record["bytes"] = custody.retain(full.read_bytes())
            suffix = ".import" if path.endswith(".import") else ".uid" if path.endswith(".uid") else None
            source = path[:-len(suffix)] if suffix else None
            record["source"] = source
            # Keep bounded to the development-input exclusions evidenced by the
            # pinned preset and enforced recursively by the existing PCK audit.
            excluded = path.startswith("tests/") or path.startswith("evidence/")
            owned = source in baseline["head_entries"] if source else False
            if suffix and owned and excluded:
                record["classification"] = "excluded_development_metadata"
                record["exclusion"] = "tests/*" if path.startswith("tests/") else "evidence/*"
                record["source_blob"] = baseline["head_entries"][source]["oid"]
                record["pack_audit"] = "tests permits only three exact legacy data resources; evidence directory forbidden"
            else:
                record["classification"] = "unreviewed_generated_input"
                rejected.append(path)
        entries.append(record)
    write(f"generated-{phase}.json", {"entries": entries, "rejected": rejected,
          "preset_sha256": custody.sha((ROOT / "export_presets.cfg").read_bytes()),
          "ignored_engine_cache": ".godot/", "source_promotion": False})
    require(not rejected, "UNREVIEWED_GENERATED_INPUT: " + repr(rejected))
    require(custody.sha((ROOT / "export_presets.cfg").read_bytes()) == PRESET, "EXPORT_PRESET_CHANGED")
    return entries


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
    if phase in ("restored", "final") and not errors:
        prior = read(OUTPUT / "generated-import.json")["entries"]
        facts = lambda rows: {r["path"]: r["bytes"]["sha256"] for r in rows}
        if facts(entries) != facts(prior):
            errors.append("GENERATED_INPUT_SET_CHANGED_SINCE_IMPORT")
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
    parser.add_argument("--phase", choices=["before", "after", "restore", "final"], required=True)
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
            capture_and_enforce("final", False)
    except Exception as error:
        write(args.phase + "-failure.json", {"error": str(error)})
        raise
