#!/usr/bin/env python3
"""Read-only verification of the retained found-painting artifacts and maps."""

from __future__ import annotations

import csv
import hashlib
import json
import struct
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCES = ROOT / "art_source/found_paintings/sources.json"
PLACEMENTS = ROOT / "data/manifests/art_placements.json"
EXPECTED_WORKS = {
    "cma_1950.89",
    "cma_1946.83",
    "cma_1920.379",
    "cma_1958.57",
    "cma_1958.39",
    "cma_1982.6",
    "getty_2018.59",
}
REQUIRED_WORK_FIELDS = {
    "museum", "accession", "artist", "title", "date", "medium", "credit",
    "license", "page", "image", "role", "source_sha256", "stored_file",
    "stored_sha256", "stored_size", "stored_note",
}
JPEG_SOF = {0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7,
            0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF}


def image_size(data: bytes) -> tuple[int, int]:
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return struct.unpack(">II", data[16:24])
    if not data.startswith(b"\xff\xd8"):
        raise ValueError("not a PNG or JPEG")
    offset = 2
    while offset < len(data):
        while offset < len(data) and data[offset] == 0xFF:
            offset += 1
        if offset >= len(data):
            break
        marker = data[offset]
        offset += 1
        if marker in {0x01, 0xD8, 0xD9} or 0xD0 <= marker <= 0xD7:
            continue
        if offset + 2 > len(data):
            break
        length = struct.unpack(">H", data[offset:offset + 2])[0]
        if marker in JPEG_SOF:
            if offset + 7 > len(data):
                break
            height, width = struct.unpack(">HH", data[offset + 3:offset + 7])
            return width, height
        if length < 2:
            break
        offset += length
    raise ValueError("JPEG has no supported size marker")


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def main() -> int:
    errors: list[str] = []
    source = json.loads(SOURCES.read_text(encoding="utf-8"))
    catalog = json.loads(PLACEMENTS.read_text(encoding="utf-8"))
    works = source.get("works", {})
    placed = source.get("placed", {})
    assets = catalog.get("assets", {})
    scenes = catalog.get("scenes", {})

    if set(works) != EXPECTED_WORKS:
        fail(errors, f"source work IDs differ: {sorted(set(works) ^ EXPECTED_WORKS)}")
    for work_id, record in works.items():
        missing = REQUIRED_WORK_FIELDS - set(record)
        if missing:
            fail(errors, f"{work_id}: missing metadata {sorted(missing)}")
            continue
        path = ROOT / record["stored_file"]
        if not path.is_file():
            fail(errors, f"{work_id}: missing {path.relative_to(ROOT)}")
            continue
        data = path.read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        if digest != record["stored_sha256"]:
            fail(errors, f"{work_id}: stored SHA-256 mismatch")
        if list(image_size(data)) != record["stored_size"]:
            fail(errors, f"{work_id}: stored dimensions mismatch")

    if len(placed) != 13:
        fail(errors, f"expected 13 installed derivatives, found {len(placed)}")
    for relative, record in placed.items():
        path = ROOT / relative
        if not path.is_file():
            fail(errors, f"missing derivative {relative}")
            continue
        data = path.read_bytes()
        if hashlib.sha256(data).hexdigest() != record["sha256"]:
            fail(errors, f"{relative}: SHA-256 mismatch")
        if len(data) != record["bytes"]:
            fail(errors, f"{relative}: byte-count mismatch")
        if list(image_size(data)) != record["size"]:
            fail(errors, f"{relative}: dimensions mismatch")
        sidecar = Path(str(path) + ".import")
        expected_source = f'source_file="res://{relative}"'
        if not sidecar.is_file() or expected_source not in sidecar.read_text(encoding="utf-8"):
            fail(errors, f"{relative}: missing or stale .import sidecar")
        refs = [asset_id for asset_id, asset in assets.items()
                if asset.get("path") == f"res://{relative}"]
        if not refs:
            fail(errors, f"{relative}: no asset binding")

    with (ROOT / "art/asset-paths.csv").open(encoding="utf-8-sig", newline="") as handle:
        asset_rows = {row["asset_id"]: row for row in csv.DictReader(handle)}
    if set(asset_rows) != set(assets):
        fail(errors, "asset-paths.csv IDs differ from the placement catalog")
    for asset_id, asset in assets.items():
        row = asset_rows.get(asset_id)
        if row is None:
            continue
        expected = (asset["path"].removeprefix("res://"),
                    str(asset["size"][0]), str(asset["size"][1]))
        actual = (row["project_relative_path"], row["width"], row["height"])
        if actual != expected:
            fail(errors, f"asset CSV differs at {asset_id}")

    with (ROOT / "art/scene-map.csv").open(encoding="utf-8-sig", newline="") as handle:
        scene_rows = {row["entry_id"]: row for row in csv.DictReader(handle)}
    if set(scene_rows) != set(scenes):
        fail(errors, "scene-map.csv IDs differ from the placement catalog")

    def asset_path(asset_id: str) -> str:
        if not asset_id:
            return ""
        if asset_id not in assets:
            fail(errors, f"scene names unregistered asset {asset_id}")
            return ""
        return assets[asset_id]["path"].removeprefix("res://")

    for entry_id, scene in scenes.items():
        portraits = scene.get("portraits", [])
        expected = (
            scene.get("timeline", "").removeprefix("res://"),
            "" if scene.get("day") is None else str(scene.get("day")),
            asset_path(scene.get("background", "")),
            asset_path(portraits[0]) if len(portraits) > 0 else "",
            asset_path(portraits[1]) if len(portraits) > 1 else "",
            asset_path(scene.get("cg", "")),
        )
        row = scene_rows.get(entry_id)
        if row is None:
            continue
        actual = (row["dtl_path"], row["day"], row["background"],
                  row["portrait_1"], row["portrait_2"], row["ending_cg"])
        if actual != expected:
            fail(errors, f"scene CSV differs at {entry_id}")

    credits = (ROOT / "art/README.md").read_text(encoding="utf-8")
    for accession in ("1950.89", "1946.83", "1920.379", "1958.57",
                      "1958.39", "1982.6", "2018.59"):
        if accession not in credits:
            fail(errors, f"credits omit accession {accession}")

    result = {
        "ok": not errors,
        "works": len(works),
        "derivatives": len(placed),
        "assets": len(assets),
        "scenes": len(scenes),
        "errors": errors,
    }
    print(json.dumps(result, sort_keys=True))
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main())
