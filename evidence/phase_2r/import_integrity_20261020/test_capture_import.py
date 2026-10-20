"""Synthetic Git custody test; does not run Godot or PowerShell."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile


def run(*args):
    return subprocess.run(args, check=True, capture_output=True).stdout


with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary) / "repo"
    output = Path(temporary) / "evidence"
    root.mkdir()

    def git(*args):
        return run("git", "-C", str(root), *args)

    git("init")
    git("config", "user.name", "Synthetic custody test")
    git("config", "user.email", "test@example.invalid")
    git("config", "core.autocrlf", "false")
    original = {
        ".gitattributes": b"* -text\n",
        ".editorconfig": b"root=true\n",
        "export_presets.cfg": b"[preset.0]\n",
        "project.godot": b"config_version=5\n",
        "metadata.import": b"[remap]\npath=old\n",
        "checkout.import": b"committed\n",
        "binary.bin": b"\x00\xff\r\n\x80",
        "deleted.import": b"retain deleted bytes\n",
        "staged.import": b"original index\n",
        "unchanged.import": b"unchanged\n",
    }
    for path, data in original.items():
        (root / path).write_bytes(data)
    git("add", ".")
    git("commit", "-m", "Fixture")
    commit = git("rev-parse", "HEAD").decode().strip()
    git("update-index", "--add", "--cacheinfo", "160000", commit, "gitlink")
    git("commit", "-m", "Fixture gitlink")
    # Raw checkout differs from the immutable blob before import.
    original["checkout.import"] = b"committed\r\n"
    (root / "checkout.import").write_bytes(original["checkout.import"])
    helper = Path(__file__).with_name("capture_import.py")

    def capture(phase):
        return run(sys.executable, str(helper), "--phase", phase, "--root", str(root), "--output", str(output))

    capture("before")
    after = dict(original)
    after.update({"metadata.import": b"[remap]\npath=new\n", "checkout.import": b"committed\n",
                  "binary.bin": b"\x00\xfe\r\n\x81", "project.godot": b"config_version=5\nchanged=true\n",
                  "added.import": b"newly indexed\n"})
    after.pop("deleted.import")
    for path, data in after.items():
        (root / path).write_bytes(data)
    (root / "deleted.import").unlink()
    git("update-index", "--force-remove", "--", "gitlink")
    (root / "staged.import").write_bytes(b"index only mutation\n")
    git("add", "staged.import", "added.import")
    (root / "staged.import").write_bytes(original["staged.import"])
    capture("after")
    report = json.loads((output / "changes.json").read_text())
    entries = {c["path"]: c for c in report["changes"]}
    expected = {"metadata.import", "checkout.import", "binary.bin", "deleted.import", "project.godot", "added.import", "staged.import", "gitlink"}
    assert set(entries) == expected, set(entries)
    for path, entry in entries.items():
        for field, expected_data in [("before_bytes", original.get(path)), ("after_bytes", after.get(path))]:
            if expected_data is None:
                assert field not in entry, (path, field)
                continue
            locator = entry[field]
            actual = (output / locator["file"]).read_bytes()
            assert actual == expected_data, (path, field)
            assert hashlib.sha256(actual).hexdigest() == locator["sha256"]
    assert entries["checkout.import"]["crlf_to_lf_equal"] is True
    assert entries["metadata.import"]["crlf_to_lf_equal"] is False
    assert entries["staged.import"]["index_changed"] and not entries["staged.import"]["worktree_changed"]
    assert entries["gitlink"]["index_changed"] and not entries["gitlink"]["worktree_changed"]
    assert report["worktree_changed_count"] == 6
    assert report["index_changed_count"] == 3
    assert report["complete"] is True
    # An unexpected HEAD move must fail closed after retaining changed bytes.
    git("commit", "-m", "Unexpected index commit")
    moved = subprocess.run([sys.executable, str(helper), "--phase", "after", "--root", str(root), "--output", str(output)], capture_output=True)
    assert moved.returncode != 0
    moved_report = json.loads((output / "changes.json").read_text())
    assert moved_report["complete"] is True
    assert moved_report["head_after"] != moved_report["head"]
    assert "binary.bin" in {c["path"] for c in moved_report["changes"]}
    # Capturing twice must refuse to overwrite custody baseline.
    duplicate = subprocess.run([sys.executable, str(helper), "--phase", "before", "--root", str(root), "--output", str(output)], capture_output=True)
    assert duplicate.returncode != 0
    assert (output / "before-capture-failure.json").exists()
    print("PASS: exact binary/pre-normalized bytes, deletion, addition, settings, index-only mutation, gitlink cleanup, hashes, immutable baseline, HEAD-move failure custody")
