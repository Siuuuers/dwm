"""Regression for stat-only false positives without index refresh or source restore."""
import json
import os
from pathlib import Path
import subprocess
import tempfile


results = []
with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)

    def git(*args):
        p = subprocess.run(["git", "-C", str(root), *args], capture_output=True)
        return p.returncode, p.stdout.decode(errors="replace")

    def require(*args):
        code, text = git(*args)
        assert code == 0, (args, code, text)
        return text

    require("init")
    require("config", "user.name", "Integrity fixture")
    require("config", "user.email", "test@example.invalid")
    require("config", "core.autocrlf", "false")
    (root / ".gitattributes").write_bytes(b"* -text\n")
    path = root / "asset.import"
    original = b"mode=0\n"
    path.write_bytes(original)
    require("add", ".")
    require("commit", "-m", "Fixture")
    index_before = (root / ".git/index").read_bytes()
    # Rewrite identical bytes with an intentionally different mtime. Do not run
    # status/update-index: neither old nor proposed predicate refreshes the index.
    path.write_bytes(original)
    os.utime(path, (1234567890, 1234567890))
    old = git("diff-files", "--exit-code")[0]
    proposed = git("-c", "diff.autoRefreshIndex=false", "diff", "--exit-code")[0]
    assert old == 1 and proposed == 0, (old, proposed)
    assert (root / ".git/index").read_bytes() == index_before
    results.append({"case": "identical_bytes_changed_mtime", "old": old, "proposed": proposed, "index_unchanged": True})
    for name, data in [("same_length_metadata_change", b"mode=1\n"), ("binary_change", b"\x00\xffmeta"), ("raw_crlf_change_binary_attribute", b"mode=0\r\n"), ("deletion", None)]:
        if data is None:
            path.unlink()
        else:
            path.write_bytes(data)
        code = git("-c", "diff.autoRefreshIndex=false", "diff", "--exit-code")[0]
        assert code == 1, (name, code)
        assert (root / ".git/index").read_bytes() == index_before
        results.append({"case": name, "proposed": code, "index_unchanged": True})
    path.write_bytes(b"mode=2\n")
    require("add", "asset.import")
    assert git("-c", "diff.autoRefreshIndex=false", "diff", "--exit-code")[0] == 0
    # Existing second guard compares HEAD, so staging cannot conceal a change.
    assert "asset.import" in require("diff", "HEAD", "--name-only").splitlines()
    results.append({"case": "staged_change", "caught_by_existing_HEAD_guard": True})
print(json.dumps({"passed": True, "cases": results}, indent=2))
