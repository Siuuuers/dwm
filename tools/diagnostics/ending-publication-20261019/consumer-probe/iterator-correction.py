"""Apply only the reviewed sibling correction; retain and verify complete crate custody."""
import argparse
import hashlib
import json
from pathlib import Path

BASELINE = "22233da2a6c999c355b74edddbf80fc98c6f32bd52f55de2bacd523f013824a7"
CORRECTED = "7d2f876b4744af77b576ea35726ebb5c3943bf8f01b61595e61a9ad8dd1f4fa5"
OLD = b"            if result == FilterResult::ExcludeNode {\n                consider_children = true;\n            }"
NEW = b"            consider_children = result == FilterResult::ExcludeNode;"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def inventory(root):
    return {p.relative_to(root).as_posix(): digest(p.read_bytes())
            for p in sorted(root.rglob("*")) if p.is_file()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--crate-root", required=True, type=Path)
    parser.add_argument("--variant", required=True, choices=("Baseline", "Corrected"))
    parser.add_argument("--receipt", required=True, type=Path)
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    expected = BASELINE if args.variant == "Baseline" else CORRECTED
    if args.verify:
        receipt = json.loads(args.receipt.read_text())
        assert receipt["variant"] == args.variant
        assert receipt["iterator_sha256"] == expected
        assert inventory(args.crate_root) == receipt["source_manifest"], "Consumer source changed"
        return
    path = args.crate_root / "src/iterators.rs"
    original = path.read_bytes()
    assert digest(original) == BASELINE, "Unreviewed original iterator"
    assert original.count(OLD) == 2, "Expected exactly two sibling assignments"
    before = inventory(args.crate_root)
    candidate = original.replace(OLD, NEW)
    assert digest(candidate) == CORRECTED, "Unreviewed corrected iterator"
    if args.variant == "Corrected":
        path.write_bytes(candidate)
    after = inventory(args.crate_root)
    changed = [name for name in before if before[name] != after[name]]
    assert changed == (["src/iterators.rs"] if args.variant == "Corrected" else [])
    assert digest(path.read_bytes()) == expected
    args.receipt.write_text(json.dumps({"schema_version": 1, "diagnostic_only": True,
        "variant": args.variant, "baseline_iterator_sha256": BASELINE,
        "iterator_sha256": expected, "changed_files": changed,
        "original_source_manifest": before, "source_manifest": after}, indent=2) + "\n")


if __name__ == "__main__":
    main()
