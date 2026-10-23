"""Stage an unchanged validated Windows export as a minimal Steam content folder.

Input is the inner DWM-windows-x86_64-validation.zip from Actions.
No engine run, upload, or Steam publication. Output directories must be new.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import zipfile


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("validated_zip", type=Path)
    parser.add_argument("output_directory", type=Path)
    args = parser.parse_args()
    output = args.output_directory
    output.mkdir(parents=True, exist_ok=False)
    game = output / "game-build"
    game.mkdir()
    archive = output / "game-build.zip"
    with zipfile.ZipFile(args.validated_zip) as source:
        names = source.namelist()
        if len(names) != len(set(names)):
            raise ValueError("Duplicate input members")
        receipt = json.loads(source.read("validation.json"))
        if receipt.get("ok") is not True or receipt.get("smoke", {}).get("ok") is not True:
            raise ValueError("Input export did not pass validation")
        expected = {row["path"]: row for row in receipt["files"]}
        if set(names) != set(expected) | {"validation.json"}:
            raise ValueError("Unexpected or missing export files")
        if not {"DWM.exe", "DWM.pck", "licenses/Godot/LICENSE.txt"} <= set(expected):
            raise ValueError("Required runtime or license file missing")
        for name, record in expected.items():
            path = PurePosixPath(name)
            if path.is_absolute() or ".." in path.parts or "\\" in name:
                raise ValueError("Unsafe member path")
            if name not in {"DWM.exe", "DWM.pck"} and not name.startswith("licenses/"):
                raise ValueError("Unexpected runtime member: " + name)
            data = source.read(name)
            if len(data) != record["bytes"] or digest(data) != record["sha256"]:
                raise ValueError("Validated bytes changed: " + name)
            destination = game / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(data)
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as target:
        for name in sorted(expected):
            target.write(game / name, name)
    with zipfile.ZipFile(archive) as check:
        if set(check.namelist()) != set(expected):
            raise ValueError("Output member mismatch")
        for name, record in expected.items():
            if digest(check.read(name)) != record["sha256"]:
                raise ValueError("Output bytes changed: " + name)
    summary = {"source_commit": receipt["commit"], "files": len(expected),
               "runtime_bytes_unchanged": True, "steam_review_approved": False,
               "zip_sha256": digest(archive.read_bytes()), "zip_bytes": archive.stat().st_size,
               "removed": ["validation.json"], "launch_executable": "DWM.exe"}
    (output / "package-receipt.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary))


if __name__ == "__main__":
    main()
