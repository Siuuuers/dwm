#!/usr/bin/env python3
"""Verify the archived Gallery title status boxes without launching Godot."""

from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path

from PIL import Image


EXPECTED_HEIGHT = {100: 12, 125: 14, 150: 16}
PAPER = (195, 186, 163)
INK = {
    "AfterHours": (21, 27, 37),
    "Midnight": (20, 32, 29),
}


def main() -> int:
    evidence_dir = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--measurements",
        type=Path,
        default=evidence_dir / "native-title" / "gallery-measurements.json",
    )
    parser.add_argument("--images", type=Path, default=evidence_dir / "native-title")
    parser.add_argument("--receipt", type=Path, default=evidence_dir / "pixel-receipt.json")
    args = parser.parse_args()

    measurements = json.loads(args.measurements.read_text(encoding="utf-8"))
    assert measurements["ok"] is True
    assert measurements["requested_tuples"] == 18
    samples = measurements["samples"]
    assert len(samples) == 18
    expected_tuples = {
        (locale, percent, palette)
        for locale in ("en", "zh_CN", "zh_HK")
        for percent in (100, 125, 150)
        for palette in ("AfterHours", "Midnight")
    }
    actual_tuples = {
        (sample["locale"].replace("-", "_"), int(sample["text_percent"]), sample["palette"])
        for sample in samples
    }
    assert actual_tuples == expected_tuples
    checks = 4
    results = []

    for sample in samples:
        percent = int(sample["text_percent"])
        palette = sample["palette"]
        x, y, width, height = sample["status_rect"]
        native_rect = tuple(int(round(value / 2.0)) for value in (x, y, width, height))
        assert native_rect[3] == EXPECTED_HEIGHT[percent]
        checks += 1

        image_path = args.images / Path(sample["path"]).name
        assert image_path.is_file()
        checks += 1
        with Image.open(image_path) as source:
            image = source.convert("RGB")
            assert image.size == (640, 360)
            checks += 1
            left, top, box_width, box_height = native_rect
            crop = image.crop((left, top, left + box_width, top + box_height))
            pixels = Counter(crop.get_flattened_data())

        expected_ink = INK[palette]
        assert set(pixels) == {PAPER, expected_ink}
        assert pixels[PAPER] > 0
        assert pixels[expected_ink] > 0
        checks += 3
        results.append(
            {
                "file": image_path.name,
                "locale": sample["locale"],
                "palette": palette,
                "text_percent": percent,
                "native_status_rect": native_rect,
                "background_pixels": pixels[PAPER],
                "ink_pixels": pixels[expected_ink],
            }
        )

    receipt = {
        "ok": True,
        "tuples": len(results),
        "checks": checks,
        "expected_native_heights": EXPECTED_HEIGHT,
        "expected_background_rgb": PAPER,
        "expected_ink_rgb": INK,
        "samples": results,
        "scope": "Read-only Pillow verification of archived title status rectangles and PNG pixels.",
    }
    args.receipt.write_bytes(
        (json.dumps(receipt, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    )
    print(json.dumps({"ok": True, "tuples": len(results), "checks": checks}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
