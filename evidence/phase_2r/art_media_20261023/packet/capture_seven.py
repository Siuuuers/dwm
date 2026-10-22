"""Bounded source/generated-content custody for the seven-file authoring change.

No engine invocation. Run before import, after import, after native generation,
and after qualification. Original source remains the pinned Git commit; native
outputs are separately retained and hashed for subsequent publication.
"""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

GENERATED = {
    "data/manifests/scene_story_registration.json",
    "data/manifests/scene_ending_reading_catalogue.json",
}
GITLINKS = {".claude/skills/godot-prompter/1.10.0", ".claude/skills/superpowers/6.1.1"}
EXCLUDED = ("evidence/", "docs/", "prompt_docs/", "art_source/", "temp-artifacts/", ".claude/")


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args])


def sha(data):
    return hashlib.sha256(data).hexdigest()


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--root", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--source", required=True)
    p.add_argument("--phase", choices=["before", "import", "generated", "after"], required=True)
    a = p.parse_args()
    root, out = a.root.resolve(), a.output.resolve()
    if git(root, "rev-parse", "HEAD").decode().strip() != a.source:
        raise RuntimeError("SOURCE_HEAD_MISMATCH")
    entries = {}
    for row in git(root, "ls-tree", "-rz", "HEAD").split(b"\0"):
        if not row:
            continue
        info, path = row.split(b"\t", 1)
        mode, kind, blob = info.decode().split()
        name = path.decode()
        entries[name] = {"mode": mode, "kind": kind, "blob": blob}
    if a.phase == "before":
        if git(root, "status", "--porcelain", "--untracked-files=normal").strip():
            raise RuntimeError("BASE_CHECKOUT_NOT_CLEAN")
        write(out / "source.json", {"source": a.source, "entries": entries})
        (out / "project.checkout").write_bytes((root / "project.godot").read_bytes())
        (out / "project.original").write_bytes(git(root, "show", "HEAD:project.godot"))
        return
    baseline = json.loads((out / "source.json").read_text())
    if baseline != {"source": a.source, "entries": entries}:
        raise RuntimeError("BASE_SOURCE_CHANGED")
    changed = set(git(root, "diff", "HEAD", "--name-only", "-z").decode().split("\0")) - {""}
    untracked = set(git(root, "ls-files", "--others", "--exclude-standard", "-z").decode().split("\0")) - {""}
    retained, omitted = [], []
    for name in sorted(changed | untracked | GENERATED):
        if name in GITLINKS:
            continue
        file = root / name
        metadata = name.endswith((".uid", ".import"))
        if name == "project.godot":
            if a.phase != "import":
                raise RuntimeError("PROJECT_SETTINGS_CHANGED_AFTER_RESTORE")
        elif name in GENERATED:
            if a.phase == "import" and name in changed:
                raise RuntimeError("REGISTRATION_CHANGED_DURING_IMPORT")
        elif not metadata:
            raise RuntimeError("UNEXPECTED_SOURCE_CHANGE: " + name)
        if not file.is_file():
            raise RuntimeError("CHANGED_SOURCE_MISSING: " + name)
        data = file.read_bytes()
        record = {"path": name, "sha256": sha(data), "size": len(data),
                  "git_blob": hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()}
        if metadata and name.startswith(EXCLUDED):
            # Excluded development import metadata cannot enter this product;
            # list its exact digest without retaining thousands of duplicate blobs.
            omitted.append(record)
            continue
        destination = out / a.phase / "files" / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
        retained.append(record)
    write(out / a.phase / "manifest.json", {"source": a.source, "phase": a.phase,
          "retained": retained, "excluded_development_metadata": omitted})
    if a.phase == "import":
        # Original and imported settings have both been retained before restore.
        original = (out / "project.original").read_bytes()
        if hashlib.sha1(b"blob " + str(len(original)).encode() + b"\0" + original).hexdigest() != entries["project.godot"]["blob"]:
            raise RuntimeError("ORIGINAL_SETTINGS_BLOB_MISMATCH")
        (root / "project.godot").write_bytes(original)
    elif a.phase == "after":
        generated = json.loads((out / "generated" / "manifest.json").read_text())
        if generated["retained"] != retained or generated["excluded_development_metadata"] != omitted:
            raise RuntimeError("WORKING_SOURCE_CHANGED_DURING_QUALIFICATION")
    print("SEVEN_SOURCE_PHASE_OK " + a.phase)


if __name__ == "__main__":
    main()
