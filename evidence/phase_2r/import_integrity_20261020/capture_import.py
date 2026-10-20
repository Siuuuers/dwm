"""Read-only tracked-byte custody around one cloud Godot import; never restores files."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import stat
import subprocess
import sys


def sha(data):
    return hashlib.sha256(data).hexdigest()


def blob_id(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def git(*args, allow_failure=False, input=None):
    result = subprocess.run(["git", "-C", str(ROOT), *args], input=input, capture_output=True)
    if result.returncode and not allow_failure:
        raise RuntimeError(f"git {args}: {result.returncode}: {result.stderr!r}")
    return result


def write_json(name, value):
    (OUT / name).write_text(json.dumps(value, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")


def retain(data):
    digest = sha(data)
    path = OUT / "bytes" / digest
    path.parent.mkdir(exist_ok=True)
    if not path.exists():
        path.write_bytes(data)
    return {"file": "bytes/" + digest, "sha256": digest, "size": len(data), "git_blob": blob_id(data)}


def head_entries():
    entries = {}
    for row in git("ls-tree", "-rz", "HEAD").stdout.split(b"\0"):
        if not row:
            continue
        info, path = row.split(b"\t", 1)
        mode, kind, oid = info.decode("ascii").split()
        entries[path.decode("utf-8")] = {"mode": mode, "kind": kind, "oid": oid}
    return entries


def index_entries():
    entries = {}
    for row in git("ls-files", "--stage", "-z").stdout.split(b"\0"):
        if not row:
            continue
        info, path = row.split(b"\t", 1)
        mode, oid, stage = info.decode("ascii").split()
        if stage != "0":
            raise RuntimeError("Unmerged index cannot be a pinned import baseline")
        entries[path.decode("utf-8")] = {"mode": mode, "oid": oid}
    return entries


def worktree(path, entry):
    full = ROOT / path
    if not full.exists() and not full.is_symlink():
        return {"kind": "missing"}, None
    if full.is_symlink():
        data = os.fsencode(os.readlink(full))
        kind = "symlink"
    elif full.is_file():
        data = full.read_bytes()
        kind = "file"
    elif entry and entry.get("mode") == "160000":
        return {"kind": "gitlink_directory"}, None
    else:
        return {"kind": "directory"}, None
    return {"kind": kind, "sha256": sha(data), "size": len(data), "git_blob": blob_id(data),
            "executable": bool(full.lstat().st_mode & stat.S_IXUSR)}, data


def diagnostics(phase, paths):
    commands = {
        "status": ("status", "--porcelain=v2", "--untracked-files=all", "-z"),
        "index": ("ls-files", "--stage", "-z"),
        "worktree-diff": ("diff-files", "--raw", "-z"),
        "index-diff": ("diff-index", "--cached", "--raw", "-z", "HEAD"),
        "eol": ("ls-files", "--eol", "-z"),
        "line-ending-config": ("config", "--show-origin", "--get-regexp", "^(core\\.(autocrlf|eol|safecrlf|attributesfile)|filter\\..*)$"),
    }
    for name, args in commands.items():
        result = git(*args, allow_failure=True)
        (OUT / f"{phase}-{name}.bin").write_bytes(result.stdout)
        write_json(f"{phase}-{name}-command.json", {"args": list(args), "exit": result.returncode,
                   "stderr": result.stderr.decode("utf-8", errors="replace")})
    supplied = b"\0".join(p.encode("utf-8") for p in paths) + b"\0"
    (OUT / f"{phase}-attributes.bin").write_bytes(git("check-attr", "-z", "--stdin", "--all", input=supplied).stdout)


class Objects:
    def __enter__(self):
        self.process = subprocess.Popen(["git", "-C", str(ROOT), "cat-file", "--batch"],
                                        stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        return self

    def read(self, oid):
        self.process.stdin.write(oid.encode("ascii") + b"\n")
        self.process.stdin.flush()
        actual, kind, size = self.process.stdout.readline().split()
        if actual.decode() != oid or kind != b"blob":
            raise RuntimeError("Expected exact immutable Git blob")
        data = self.process.stdout.read(int(size))
        if self.process.stdout.read(1) != b"\n" or blob_id(data) != oid:
            raise RuntimeError("Git blob framing/hash mismatch")
        return data

    def __exit__(self, *unused):
        self.process.stdin.close()
        if self.process.wait(timeout=30) != 0:
            raise RuntimeError("Git object reader failed")


def capture_before():
    if (OUT / "before.json").exists():
        raise RuntimeError("Baseline must not be overwritten")
    head, index = head_entries(), index_entries()
    entries = {}
    for path in sorted(set(head) | set(index)):
        record, data = worktree(path, index.get(path) or head.get(path))
        # Exact raw checkout bytes can be reconstructed from an immutable Git blob
        # only if the raw Git blob hash agrees. Otherwise retain actual checkout bytes.
        if data is not None:
            matching = next((e["oid"] for e in (index.get(path), head.get(path))
                             if e and e["mode"] != "160000" and e["oid"] == record["git_blob"]), None)
            record["preimage"] = {"git_blob": matching} if matching else retain(data)
        entries[path] = record
    diagnostics("before", sorted(entries))
    write_json("before.json", {"head": git("rev-parse", "HEAD").stdout.decode().strip(),
               "tree": git("rev-parse", "HEAD^{tree}").stdout.decode().strip(),
               "platform": platform.platform(), "python": sys.version,
               "git": git("--version").stdout.decode().strip(), "head_entries": head,
               "index_entries": index, "worktree": entries})
    for path in ["project.godot", ".gitattributes", ".editorconfig", "export_presets.cfg"]:
        retain((ROOT / path).read_bytes())
    print(f"IMPORT_BASELINE_CAPTURED tracked={len(entries)}")


def capture_after():
    before = json.loads((OUT / "before.json").read_text(encoding="utf-8"))
    head, index = head_entries(), index_entries()
    head_after = git("rev-parse", "HEAD").stdout.decode().strip()
    paths = sorted(set(before["worktree"]) | set(head) | set(index))
    diagnostics("after", paths)
    changes = []
    complete, active_path = False, None
    try:
        with Objects() as objects:
            for path in paths:
                active_path = path
                old = before["worktree"].get(path, {"kind": "missing"})
                now, data = worktree(path, index.get(path) or head.get(path))
                old_fact = {k: v for k, v in old.items() if k != "preimage"}
                index_changed = before["index_entries"].get(path) != index.get(path)
                changed = old_fact != now
                # Include project settings independently even if unchanged.
                if not changed and not index_changed and path != "project.godot":
                    continue
                entry = {"path": path, "worktree_changed": changed, "index_changed": index_changed,
                         "before": old_fact, "after": now, "head": head.get(path),
                         "index_before": before["index_entries"].get(path), "index_after": index.get(path)}
                prior = None
                if "preimage" in old:
                    locator = old["preimage"]
                    prior = (OUT / locator["file"]).read_bytes() if "file" in locator else objects.read(locator["git_blob"])
                    if sha(prior) != old["sha256"]:
                        raise RuntimeError("Preimage custody mismatch: " + path)
                    entry["before_bytes"] = retain(prior)
                if data is not None:
                    entry["after_bytes"] = retain(data)
                for label, source in [("head_bytes", head.get(path)), ("index_before_bytes", before["index_entries"].get(path)), ("index_after_bytes", index.get(path))]:
                    if source and source["mode"] != "160000":
                        entry[label] = retain(objects.read(source["oid"]))
                entry["crlf_to_lf_equal"] = (prior.replace(b"\r\n", b"\n") == data.replace(b"\r\n", b"\n")) if prior is not None and data is not None else None
                changes.append(entry)
        complete, active_path = True, None
    finally:
        write_json("changes.json", {"head": before["head"], "head_after": head_after, "complete": complete, "active_path": active_path, "changes": changes,
                   "worktree_changed_count": sum(c["worktree_changed"] for c in changes),
                   "index_changed_count": sum(c["index_changed"] for c in changes),
                   "policy": "Exact bytes only; no restore, deletion, filter, exemption or semantic classification"})
    if head_after != before["head"]:
        raise RuntimeError("HEAD changed during import; captured post-state retained")
    print(f"IMPORT_POST_CAPTURED entries={len(changes)}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--phase", choices=["before", "after"], required=True)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    ROOT, OUT = args.root.resolve(), args.output.resolve()
    if OUT == ROOT or ROOT in OUT.parents:
        raise RuntimeError("Evidence must be outside imported checkout")
    OUT.mkdir(parents=True, exist_ok=True)
    try:
        capture_before() if args.phase == "before" else capture_after()
    except Exception as error:
        write_json(args.phase + "-capture-failure.json", {"error": str(error)})
        raise
