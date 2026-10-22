#!/usr/bin/env python3
"""Audit geometry-only cloud observations and raw archived screenshot provenance."""
import argparse
from collections import Counter
import hashlib
import io
import json
from pathlib import Path
import zipfile

from PIL import Image


def identity(data):
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def read_json(path):
    return json.loads(path.read_text())


def unique(items):
    return sorted({json.dumps(item, sort_keys=True) for item in items})


def encloses(outer, inner):
    return len(outer) == 4 and len(inner) == 4 and inner[2] > 0 and inner[3] > 0 and (
        inner[0] >= outer[0] and inner[1] >= outer[1]
        and inner[0] + inner[2] <= outer[0] + outer[2]
        and inner[1] + inner[3] <= outer[1] + outer[3]
    )


def reading_archive(directory):
    matches = [row for row in read_json(directory / "artifact-manifest.json")
               if row["name"].startswith("reading-rail-")]
    assert len(matches) == 1, "Expected exactly one original reading-rail artifact"
    row = matches[0]
    path = Path(row["local_zip"])
    data = path.read_bytes()
    checked = identity(data)
    assert checked["bytes"] == row["size_in_bytes"], "Raw ZIP size differs from artifact manifest"
    assert "sha256:" + checked["sha256"] == row["digest"], "Raw ZIP digest differs from artifact manifest"
    archive = zipfile.ZipFile(io.BytesIO(data))
    return row, archive, {"artifact_id": row["id"], "name": row["name"],
        "workflow_run": row["workflow_run"], "zip": checked, "manifest_digest_verified": True}


def member(archive, suffix):
    matches = [name for name in archive.namelist() if name.endswith("/" + suffix) or name == suffix]
    assert len(matches) == 1, f"Expected exactly one ZIP member: {suffix}"
    return matches[0], archive.read(matches[0])


def audit_mode(report):
    assert report["complete"] is True and report["measurement_mode"] == "geometry_only"
    assert report["required_visible_samples"] == 120 and report["events_dropped"] == 0
    for event in report["events"]:
        control = event.get("control", {})
        assert "minimum" not in control and "combined_minimum" not in control, "Eager minimum query in event stream"
    result = {"mode": report["mode"], "process_id": report["process_id"], "streams": {}}
    first_visible_sequence = None
    for stream in ("process", "post_draw"):
        rows = [row for row in report["samples"] if row["kind"] == stream]
        visible = [row for row in rows if row["challenge_visible"]]
        assert len(visible) == 120 == report["visible_samples"][stream]
        assert len(rows) == report["total_samples"][stream]
        first = min(row["sequence"] for row in visible)
        first_visible_sequence = first if first_visible_sequence is None else min(first_visible_sequence, first)
        for row in visible:
            assert row["phase"] == "challenge", "Unexpected visible physical stage"
            assert row["focus"] == "", "Challenge unexpectedly acquired GUI Focus"
            assert row["scroll"]["vertical"] == row["scroll"]["horizontal"] == 0
            title = row["controls"]["ChallengeTitle"]
            assert title["visible_in_tree"] is True and title["fully_inside_clip"] is True
            assert encloses(title["clip"], title["rect"]), "Independent title containment failed"
            for control in row["controls"].values():
                assert "minimum" not in control and "combined_minimum" not in control, "Eager minimum query in raw stream"
        result["streams"][stream] = {
            "total_samples": len(rows), "visible_samples": len(visible),
            "phase_counts": dict(Counter(row.get("phase", "unmounted") for row in rows)),
            "all_visible_titles_enclosed": True, "visible_focus_empty": True, "visible_scroll_zero": True,
            "title_rects": [json.loads(value) for value in unique(row["controls"]["ChallengeTitle"]["rect"] for row in visible)],
            "challenge_bands": [json.loads(value) for value in unique(row["challenge_band"] for row in visible)],
            "first_visible": {k: visible[0][k] for k in ("sequence", "process_frame", "drawn_frame")},
            "last_visible": {k: visible[-1][k] for k in ("sequence", "process_frame", "drawn_frame")},
        }
    active_events = [row for row in report["events"] if row["sequence"] >= first_visible_sequence
                     and row["kind"] in ("gui_focus_changed", "v_scroll_changed", "h_scroll_changed")]
    assert not active_events, "Focus or scroll event during the observed visible interval"
    result["visible_focus_or_scroll_events"] = 0
    result["event_count"] = len(report["events"])
    return result


def png_detail(data):
    image = Image.open(io.BytesIO(data)).convert("RGB")
    assert image.size == (1280, 720)
    # Supporting pixel observation only; geometry is the complete title containment proof.
    coordinates = [(x, y) for y in range(58) for x in range(710, 1100)
                   if min(image.getpixel((x, y))) > 145]
    assert coordinates, "Expected title ink is absent in the fixed English fixture"
    return {**identity(data), "dimensions": list(image.size),
        "title_ink_sample_roi": [710, 0, 390, 58],
        "title_ink_y_bounds": [min(y for _, y in coordinates), max(y for _, y in coordinates)],
        "title_ink_inclusive_bounds": [min(x for x, _ in coordinates), min(y for _, y in coordinates),
                                       max(x for x, _ in coordinates), max(y for _, y in coordinates)],
        "title_band_rgb8_identity": identity(image.crop((480, 0, 1280, 58)).tobytes())}


def audit(run_dir, historical_dir, expected_source=None):
    generic_path = run_dir / "audit/generic-evidence-audit.json"
    generic = read_json(generic_path)
    assert generic["generic_audit_pass"] is True
    assert generic["run"]["conclusion"] == "success"
    source = generic["source_boundary"]
    if expected_source is not None:
        assert source["source"] == expected_source, "Source identity differs from requested source"
    assert source["all_unlisted_paths_byte_identical"] is True
    current_row, current_zip, current_archive = reading_archive(run_dir)
    _, historical_zip, historical_archive = reading_archive(historical_dir)
    generic_artifacts = generic["artifact_inventory"]["artifacts"]
    bound = [row for row in generic_artifacts if row["id"] == current_row["id"]]
    assert len(bound) == 1 and bound[0]["zip_and_extraction_verified"] is True
    assert bound[0]["zip_sha256"] == current_archive["zip"]["sha256"]
    modes = []
    for name in ("layout-next.json", "layout-next-read.json"):
        member_name, data = member(current_zip, name)
        report = json.loads(data)
        assert report["mode"] == name.removeprefix("layout-").removesuffix(".json")
        mode = audit_mode(report)
        mode["raw_report"] = {"zip_member": member_name, **identity(data)}
        modes.append(mode)
    assert modes[0]["process_id"] != modes[1]["process_id"], "Warm/cold processes must differ"
    screenshots = []
    for name in ("02-next-board.png", "03-next-restored-board.png"):
        current_name, current_data = member(current_zip, "next/captures/" + name)
        historical_name, historical_data = member(historical_zip, "next/captures/" + name)
        assert current_data == historical_data, f"Screenshot bytes differ from archived baseline: {name}"
        screenshots.append({"name": name, "current_member": current_name,
            "historical_member": historical_name, "raw_member_bytes_identical": True,
            "current": png_detail(current_data), "historical": png_detail(historical_data)})
    title_band_equal = screenshots[0]["current"]["title_band_rgb8_identity"] == screenshots[1]["current"]["title_band_rgb8_identity"]
    original_reading = generic["reading"]
    assert len(original_reading) == 1 and original_reading[0]["all_process_exits_zero"] is True
    reading = original_reading[0]
    assert len(reading["modes"]) == 8 and len(set(reading["process_ids"].values())) == 8
    for mode in modes:
        assert mode["process_id"] == reading["process_ids"][mode["mode"]], "Probe process differs from admitted journey mode"
    return {"schema_version": 1, "audit_pass": True,
        "audit_scope": "Bounded existing English Solo board-entry geometry and corrected historical image interpretation",
        "run": generic["run"], "source_boundary": source,
        "generic_audit_identity": identity(generic_path.read_bytes()),
        "stage_counts": {"original_reading_modes": len(reading["modes"]),
            "distinct_processes": len(set(reading["process_ids"].values())),
            "all_process_exits_zero": True, "gut_case_executions": generic["gut"]["case_executions"]},
        "current_archive": current_archive, "historical_archive": historical_archive,
        "layout_modes": modes, "historical_image_comparisons": screenshots,
        "warm_cold_title_pixel_comparison": {"roi": [480, 0, 800, 58], "encoding": "raw row-major RGB8",
            "bytes_identical": title_band_equal,
            "warm": screenshots[0]["current"]["title_band_rgb8_identity"],
            "cold": screenshots[1]["current"]["title_band_rgb8_identity"],
            "scope": "Rendered title region only; no equality of worksheet bands or complete warm/cold frames is required."},
        "historical_visual_correction": {
            "finding": "The retained Run122 raw warm/cold PNGs contain the complete title and exactly match this run's corresponding PNGs.",
            "prior_claim": "Cold board-null Load title clipping was reported from visual inspection.",
            "disposition": "Corrected historical visual interpretation; no production layout defect or fix is established.",
            "runtime_fix_claimed": False,
        },
        "limitations": [
            "Only the existing fixed English Solo board-entry fixture and current settings are observed.",
            "Geometry containment plus raw PNG inspection does not establish every locale, text preset, resize, native Windows or accessibility case.",
            "Warm and cold worksheet bands may differ; this audit does not require equal bands or pixel identity between warm and cold.",
            "Upstream lazy minimum-size behavior and an initial eager probe do not establish a production cause or observer effect.",
            "This audit does not close the reading parent, establish whole-game visual polish, or replace the separately bound broad gate.",
        ]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run_dir", type=Path)
    parser.add_argument("historical_dir", type=Path)
    parser.add_argument("--expected-source")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = audit(args.run_dir, args.historical_dir, args.expected_source)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"audit_pass": result["audit_pass"], "output": str(args.output),
        "run": result["run"]["run_number"], "source": result["source_boundary"]["source"],
        "visible_samples": 480, "historical_png_matches": 2}))


if __name__ == "__main__":
    main()
