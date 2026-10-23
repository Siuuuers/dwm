"""Authenticate one frozen historical substrate; never qualify current gameplay.

Run from the separate historical checkout. This observer does not modify its
owners, tests, manifests, historical inverses, or saved data.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path, PureWindowsPath
import re
import subprocess
import xml.etree.ElementTree as ET
import zipfile

SOURCE = "a24f71766a624b57601814dda487b53c66518c39"
TREE = "173218aacfb79c580f2a593d864fb625a84aa076"
PRIOR_RECEIPT = "b5f09abdea6a1d0de7310c74b7ea1b7bcff5b9943c94a6388be6713fd3ffcdab"
IDENTITIES = {
    "data/manifests/dialogic_entries.json": "410934868a736082daa4ff55bc7e25f550359b2f8b91ff956a7997788c334a3a",
    "autoload/EffectResolver.gd": "03baf9c2bff333739ca2795114060968e5908d35663fd8307ffe242b26dc1d04",
    "autoload/GameState.gd": "02ed11392633e9ded43609d93977adb0805870880add55b67c483d5d305694bc",
}
GROUPS = {
    "contracts": [
        "tests/unit/test_dtl_master_structure.gd",
        "tests/unit/test_effect_resolver.gd",
        "tests/unit/tooling/test_phase2r_schedule_gate.gd",
        "tests/unit/test_hospital_rules.gd",
    ],
    "controls": [
        "tests/integration/test_run_restore_isolation.gd",
        "tests/integration/test_live_run_rollback_isolation.gd",
    ],
}
OUT = Path(".godot/ci/historical")


def git(*args):
    return subprocess.check_output(["git", *args])


def digest(data):
    return hashlib.sha256(data).hexdigest()


def write(name, value):
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / name).write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def authenticate(receipt):
    assert git("rev-parse", "HEAD").decode().strip() == SOURCE
    assert git("rev-parse", "HEAD^{tree}").decode().strip() == TREE
    raw = receipt.read_bytes()
    assert digest(raw) == PRIOR_RECEIPT, "prior accepted receipt drift"
    previous = json.loads(raw)
    assert previous["source_boundary"]["source"] == SOURCE
    assert previous["source_tree"] == TREE
    assert previous["run"]["id"] == 37048318182
    assert previous["canonical_broad_acceptance"] is True
    assert previous["whole_game_acceptance"] is False
    # Compare every tracked working file to its immutable source blob. Ignoring
    # disposable gitlink index cleanup cannot hide edited runtime/test bytes.
    records = {}
    for row in git("ls-tree", "-rz", SOURCE).split(b"\0"):
        if not row:
            continue
        metadata, raw_path = row.split(b"\t", 1)
        mode, kind, blob = metadata.decode().split()
        if kind != "blob":
            continue
        path = raw_path.decode()
        data = Path(path).read_bytes()
        actual_blob = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
        assert actual_blob == blob, ("changed frozen source", path)
        records[path] = {"git_blob": blob, "bytes": len(data), "sha256": digest(data)}
    for path, expected in IDENTITIES.items():
        assert records[path]["sha256"] == expected, path
    manifest = json.loads(Path("data/manifests/dialogic_entries.json").read_text())
    assert len(manifest["entries"]) == manifest["entry_count"] == 137
    expected = {}
    for group, paths in GROUPS.items():
        expected[group] = []
        for path in paths:
            source = Path(path).read_text(encoding="utf-8-sig")
            assert source.splitlines()[0] == 'extends "res://addons/gut/test.gd"'
            names = re.findall(r"^func (test_\w+)\(", source, re.M)
            assert names and len(names) == len(set(names)), path
            expected[group] += [{"path": path, "name": name} for name in names]
    write("source-manifest.json", records)
    write("expected-census.json", expected)
    (OUT / "prior-accepted-receipt.json").write_bytes(raw)
    (OUT / "verifier.py").write_bytes(Path(__file__).read_bytes())
    write("origin.json", {
        "mode": "historical-contracts-only", "source": SOURCE, "source_tree": TREE,
        "prior_run": 37048318182, "prior_receipt_sha256": PRIOR_RECEIPT,
        "entry_count": 137, "source_transformations": [],
        "current_game_acceptance": False, "export_acceptance": False,
        "scope": "Frozen registration, health effects, Hospital rules and restore controls; no current authored-flow or later timed-hold claim.",
    })


def verify():
    expected = json.loads((OUT / "expected-census.json").read_text())
    assert json.loads((OUT / "import-process.json").read_text(encoding="utf-8-sig"))["exit_code"] == 0
    processes, totals = [], {}
    for group in GROUPS:
        rows = [json.loads(line) for line in (OUT / (group + ".jsonl")).read_text(encoding="utf-8-sig").splitlines() if line.strip()]
        assert len(rows) == 1 and rows[0]["exit_code"] == 0, (group, rows)
        row = rows[0]
        assert row["suite_id"] == "historical-" + group
        root, user = PureWindowsPath(row["test_root"]), PureWindowsPath(row["user_dir"])
        assert root != user and root in user.parents, row
        assert PureWindowsPath(str(Path.cwd())) in root.parents, row
        processes.extend(rows)
        cases = ET.parse(OUT / (group + ".xml")).findall(".//testcase")
        actual = Counter((c.attrib["classname"].removeprefix("res://"), c.attrib["name"]) for c in cases)
        wanted = Counter((c["path"], c["name"]) for c in expected[group])
        assert actual == wanted, (group, actual - wanted, wanted - actual)
        assert all(c.find(tag) is None for c in cases for tag in ("failure", "error", "skipped"))
        assert all(c.attrib.get("status") == "pass" and int(c.attrib.get("assertions", "0")) > 0 for c in cases)
        totals[group] = {"cases": len(cases), "assertions": sum(int(c.attrib["assertions"]) for c in cases)}
    assert len({p["test_root"] for p in processes}) == len(GROUPS), "shared historical process root"
    logs = list(Path(".godot/phase2r_logs").glob("historical-*.log")) + [OUT / "import.log"]
    for path in logs:
        assert not re.search(r"SCRIPT ERROR:|ERROR:|Unicode parsing error|Unexpected NUL character", path.read_text(encoding="utf-8-sig")), path
    control_log = Path(".godot/phase2r_logs/historical-controls.log").read_text(encoding="utf-8-sig")
    for marker in [
        "RESTORE_ALIAS_CONTROL: six historical directions observed; nested dictionary/array aliases reproduced",
        "LIVE_RUN_ALIAS_CONTROL: six historical directions observed; raw and wrapped rollback reproduce nested aliases",
    ]:
        assert control_log.splitlines().count(marker) == 1, marker
    # Recheck all bytes after execution, without rewriting the original census.
    for path, record in json.loads((OUT / "source-manifest.json").read_text()).items():
        assert digest(Path(path).read_bytes()) == record["sha256"], path
    write("gate.json", {"historical_only": True, "source": SOURCE, "source_tree": TREE, "groups": totals, "processes": processes})


def archive():
    OUT.mkdir(parents=True, exist_ok=True)
    files = sorted(p for p in Path(".godot").rglob("*") if p.is_file() and ("ci" in p.parts or "phase2r_logs" in p.parts) and p.name not in {"original-evidence.zip", "retained-hashes.json"})
    write("retained-hashes.json", {p.relative_to(".godot").as_posix(): {"bytes": p.stat().st_size, "sha256": digest(p.read_bytes())} for p in files})
    files.append(OUT / "retained-hashes.json")
    with zipfile.ZipFile(OUT / "original-evidence.zip", "w", zipfile.ZIP_DEFLATED) as package:
        for path in files:
            package.write(path, path.relative_to(".godot").as_posix())
    print("HISTORICAL_ARCHIVE_SHA256=" + digest((OUT / "original-evidence.zip").read_bytes()))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["prepare", "verify", "archive"])
    parser.add_argument("--prior-receipt", type=Path)
    args = parser.parse_args()
    if args.mode == "prepare":
        assert args.prior_receipt is not None
        authenticate(args.prior_receipt)
    elif args.mode == "verify":
        verify()
    else:
        archive()
