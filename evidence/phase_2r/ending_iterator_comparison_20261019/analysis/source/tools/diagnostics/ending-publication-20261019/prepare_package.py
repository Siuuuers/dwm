#!/usr/bin/env python3
"""Derive an explicitly diagnostic native package from the frozen, audited PCK.

Run only on the disposable Windows cloud runner. No project export or save edit.
The original archive/validation remain inputs, never rewritten as new evidence.
"""
import argparse
import hashlib
import json
import pathlib
import shutil
import zipfile

GAME_COMMIT = "81847d8b1560340a3a7769223cee0b46c6bdc0f9"
GAME_TREE = "4581a9f12d63684836c722f72cffd533491f3c06"
ENGINE_COMMIT = "35e80b3a8822a9df9be390814b62f44c0a9c69e8"
ENGINE_TREE = "499fa231ee5d21878988a4a9cb881749def3946d"
BUILD_NAME = "dwm_publication_probe_v1"
CONSUMER_BUILD_NAME = "dwm_consumer_probe_v1"
QUERY_BUILD_NAME = "dwm_query_probe_v1"
ORIGINAL = {
    "run": 39155624496,
    "artifact_id": 12146662424,
    "archive_file": "DWM-windows-x86_64-validation.zip",
    "archive_bytes": 99457801,
    "archive_sha256": "7c3053d2073fc3caee98dc5c038e720d5e860952375039d0db054dcd14812eb8",
    "executable_sha256": "91724f15024a3a545e28ccd83134403d31ce2323a38e51c95e4dfa282f732ab6",
    "pck_bytes": 66433104,
    "pck_sha256": "1bbe3794a2febb54960929984556421e04df621f0e21a095f71ea25603147d26",
    "engine_banner": "4.6.3.stable.official.7d41c59c4",
    "original_load_ok": False,
    "original_load_failure": "UIA_UNAVAILABLE_OR_TIMEOUT: TEST Seven-day ending.",
}


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def checked_manifest(package, validation):
    expected = {entry["path"]: entry for entry in validation["files"]}
    require(len(expected) == len(validation["files"]), "Duplicate original manifest path")
    actual = {p.relative_to(package).as_posix() for p in package.rglob("*") if p.is_file()}
    require(actual == set(expected) | {"validation.json"}, "Original package file census changed")
    for name, entry in expected.items():
        path = package / name
        require(path.stat().st_size == entry["bytes"] and digest(path) == entry["sha256"],
                "Original package bytes changed: " + name)
    return expected


def stage(args):
    build_name = QUERY_BUILD_NAME if args.query_probe else (CONSUMER_BUILD_NAME if args.consumer_probe else BUILD_NAME)
    out = args.output
    require(not out.exists(), "Diagnostic package output must be fresh")
    archives = list(args.original.rglob(ORIGINAL["archive_file"]))
    require(len(archives) == 1, "Expected exactly one retained official package ZIP")
    archive = archives[0]
    require(archive.stat().st_size == ORIGINAL["archive_bytes"] and
            digest(archive) == ORIGINAL["archive_sha256"], "Frozen original package mismatch")
    out.mkdir(parents=True)
    package = out / "package"
    package.mkdir()
    with zipfile.ZipFile(archive) as source:
        seen = set()
        for entry in source.infolist():
            relative = pathlib.PurePosixPath(entry.filename)
            require(not relative.is_absolute() and ".." not in relative.parts and
                    "\\" not in entry.filename and ":" not in entry.filename and
                    entry.filename.casefold() not in seen, "Unsafe original archive member")
            seen.add(entry.filename.casefold())
        source.extractall(package)
    validation_path = package / "validation.json"
    original = read(validation_path)
    require(original["ok"] is True and original["commit"] == GAME_COMMIT and
            original["engine"] == "4.6.3.stable" and original["smoke"]["ok"] is True and
            original["pack_audit"] == {"ok": True, "runtime_data_files_verified": 117},
            "Original package validation does not match the accepted packaging input")
    files = checked_manifest(package, original)
    require(files["DWM.exe"]["sha256"] == ORIGINAL["executable_sha256"] and
            files["DWM.pck"]["sha256"] == ORIGINAL["pck_sha256"] and
            files["DWM.pck"]["bytes"] == ORIGINAL["pck_bytes"], "Original EXE/PCK mismatch")
    require(set(files) == {"DWM.exe", "DWM.pck"} |
            {name for name in files if name.startswith("licenses/")},
            "Unexpected original package component")
    shutil.copyfile(validation_path, out / "original-package-validation.json")
    validation_path.unlink()

    build = read(args.build_receipt)
    require(build["ok"] is True and build["source_commit"] == ENGINE_COMMIT and
            build["source_tree"] == ENGINE_TREE and build["build_name"] == build_name and
            build["target"] == "template_release" and build["architecture"] == "x86_64",
            "Native build receipt mismatch")
    native = args.engine / "bin/godot.windows.template_release.x86_64.exe"
    require(native.is_file() and digest(native) == build["template"]["sha256"] and
            native.stat().st_size == build["template"]["bytes"], "Built template changed")
    require(not list((args.engine / "bin").rglob("*.dll")),
            "Unexpected DLL sidecar: review native package requirements before proceeding")
    shutil.copyfile(native, package / "DWM.exe")
    notices = package / "licenses/diagnostic-engine"
    notices.mkdir()
    for name in ["LICENSE.txt", "COPYRIGHT.txt"]:
        shutil.copyfile(args.engine / name, notices / name)
    origin = {
        "schema_version": 1,
        "kind": "isolated_native_query_diagnostic" if args.query_probe else ("isolated_native_consumer_diagnostic" if args.consumer_probe else "isolated_native_publication_diagnostic"),
        "game_commit": GAME_COMMIT,
        "game_tree": GAME_TREE,
        "unchanged_original_package": ORIGINAL,
        "native_build": build,
        "native_build_receipt_sha256": digest(args.build_receipt),
        "qualification": [
            "Standard GDScript data pack is byte-identical to the original failed run.",
            "The native executable is a separately built diagnostic template, not the official executable.",
            "Public source 35e80b3a is not independently mapped to the original 7d41c59c4 banner.",
            "MSVC production build differs from the public historical MinGW release recipe.",
            ("SDK trace records bounded observations of actual UIA provider queries; it does not certify client action acceptance." if args.query_probe else "SDK trace observes applied consumer state, not actual UIA query delivery." if args.consumer_probe else "Native trace observes prepared AccessKit updates before factory return, not adapter acceptance."),
            "Diagnostic outcomes do not certify the official executable or authorize runtime promotion.",
        ],
    }
    write(package / "diagnostic-origin.json", origin)
    write(out / "stage.json", {
        "ok": True,
        "original": ORIGINAL,
        "original_files": files,
        "diagnostic_files_before_smoke": [
            {"path": p.relative_to(package).as_posix(), "bytes": p.stat().st_size, "sha256": digest(p)}
            for p in sorted(package.rglob("*")) if p.is_file()
        ],
    })
    print(json.dumps({"stage_ok": True, "game_commit": GAME_COMMIT, "native_sha256": digest(native),
                      "pck_sha256": digest(package / "DWM.pck")}))


def finish(args):
    build_name = QUERY_BUILD_NAME if args.query_probe else (CONSUMER_BUILD_NAME if args.consumer_probe else BUILD_NAME)
    out = args.output
    package = out / "package"
    prepared = read(out / "stage.json")
    smoke = read(out / "smoke-result.json")
    expected_banner = "4.6.3.stable." + build_name + "." + ENGINE_COMMIT[:9]
    require(smoke["ok"] is True and smoke["version"] == expected_banner and
            smoke["exit_code"] == 0 and smoke["timed_out"] is False and
            smoke["isolated_profile_created"] is True, "Diagnostic headless smoke failed")
    expected = {entry["path"]: entry for entry in prepared["diagnostic_files_before_smoke"]}
    actual = {p.relative_to(package).as_posix() for p in package.rglob("*") if p.is_file()}
    require(actual == set(expected), "Diagnostic package changed during smoke")
    for name, entry in expected.items():
        path = package / name
        require(path.stat().st_size == entry["bytes"] and digest(path) == entry["sha256"],
                "Diagnostic bytes changed during smoke: " + name)
    for name, entry in prepared["original_files"].items():
        if name != "DWM.exe":
            require(digest(package / name) == entry["sha256"], "Retained game/notice changed: " + name)
    validation = {
        "schema_version": 1,
        "ok": True,
        "commit": GAME_COMMIT,
        "engine": "4.6.3.stable",
        "engine_banner": expected_banner,
        "architecture": "x86_64",
        "signed": False,
        "diagnostic": True,
        "scope": "Derived native diagnostic package: original PCK custody and fresh isolated headless startup",
        "limitations": read(package / "diagnostic-origin.json")["qualification"],
        "original_package": ORIGINAL,
        "pack_custody": {"ok": True, "method": "Byte identity with the previously audited original PCK",
                         "previous_runtime_data_files_verified": 117, "audit_reexecuted": False},
        "smoke": smoke,
        "files": prepared["diagnostic_files_before_smoke"],
    }
    write(package / "validation.json", validation)
    archive = out / "DWM-windows-x86_64-diagnostic.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as target:
        for path in sorted(package.rglob("*")):
            if path.is_file():
                target.write(path, path.relative_to(package).as_posix())
    validation["archive"] = {"file": archive.name, "bytes": archive.stat().st_size, "sha256": digest(archive)}
    write(out / "validation.json", validation)
    print("NATIVE_DIAGNOSTIC_PACKAGE " + json.dumps({
        "ok": True, "diagnostic": True, "game_commit": GAME_COMMIT,
        "engine_banner": expected_banner, "archive": validation["archive"],
        "native_sha256": digest(package / "DWM.exe"), "pck_sha256": digest(package / "DWM.pck")}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=["stage", "finish"])
    parser.add_argument("--original", type=pathlib.Path, required=True)
    parser.add_argument("--engine", type=pathlib.Path, required=True)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument("--build-receipt", type=pathlib.Path, required=True)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--consumer-probe", action="store_true")
    mode.add_argument("--query-probe", action="store_true")
    arguments = parser.parse_args()
    {"stage": stage, "finish": finish}[arguments.phase](arguments)
