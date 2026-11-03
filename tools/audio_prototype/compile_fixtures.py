#!/usr/bin/env python3
"""Rebuild the three uniform-tempo prototype fixtures with FamiStudio 4.5.3."""
import argparse
import hashlib
import json
from pathlib import Path
import shlex
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent
COMPILER_SHA256 = "3cea9acdf40d56e61585747205cece862c14a8c48eb8ad373dc7d0db3c0c79cf"
ARCHIVE_SHA256 = "9133afed2fb384663b0735d8e950cdc2714849f4fd476b16de8d56e5e81da0ad"


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("famistudio", type=Path, help="Path to the official FamiStudio executable")
    parser.add_argument("--write", action="store_true", help="Update generated NSF and manifest after editing scores")
    args = parser.parse_args()
    executable = args.famistudio.resolve()
    assert sha256(executable.with_suffix(".dll").read_bytes()) == COMPILER_SHA256, "Expected official FamiStudio 4.5.3 DLL"
    manifest = {"compiler": {"version": "4.5.3", "archive_sha256": ARCHIVE_SHA256, "dll_sha256": COMPILER_SHA256}, "fixtures": {}}
    with tempfile.TemporaryDirectory(prefix="dwm-audio-fixtures-") as temp:
        for name in ("loop_a", "loop_b", "confirm"):
            source = ROOT / "fixtures" / f"{name}.txt"
            lines = [shlex.split(line) for line in source.read_text().splitlines() if line.strip()]
            project = dict(token.split("=", 1) for token in lines[0][1:])
            songs = [dict(token.split("=", 1) for token in line[1:]) for line in lines if line[0] == "Song"]
            assert project["Version"] == "4.5.3" and project["TempoMode"] == "FamiStudio" and project["Expansions"] == "VRC6"
            assert len(songs) == 1
            assert not any(line[0] in ("DPCMSample", "DPCMMapping", "PatternCustomSettings") for line in lines)
            assert not any(token.startswith("Speed=") for line in lines for token in line)
            song = songs[0]
            assert song["Groove"] == song["NoteLength"], "Fixture timing derivation requires a constant groove"
            pattern_ticks = int(song["PatternLength"]) * int(song["NoteLength"])
            total_ticks = pattern_ticks * int(song["Length"])
            loop = int(song["LoopPoint"])
            target = Path(temp) / f"{name}.nsf"
            subprocess.run([str(executable), str(source), "nsf-export", str(target), "-nsf-export-mode:ntsc"], check=True)
            data = target.read_bytes()
            assert data[:5] == b"NESM\x1a" and data[6] == 1 and data[122] == 0 and data[123] == 1
            tick_us = int.from_bytes(data[110:112], "little")
            intro_ticks = pattern_ticks * loop if loop >= 0 else 0
            loop_ticks = total_ticks - intro_ticks if loop >= 0 else 0
            end_ticks = total_ticks if loop < 0 else 0
            manifest["fixtures"][name] = {
                "source_sha256": sha256(source.read_bytes()), "nsf_sha256": sha256(data),
                "tick_us": tick_us, "intro_ticks": intro_ticks, "loop_ticks": loop_ticks, "end_ticks": end_ticks,
                "intro_seconds": intro_ticks * tick_us / 1000000,
                "loop_seconds": loop_ticks * tick_us / 1000000,
                "end_seconds": end_ticks * tick_us / 1000000,
            }
            committed = source.with_suffix(".nsf")
            if args.write:
                committed.write_bytes(data)
            else:
                assert committed.read_bytes() == data, f"Stale {committed.name}; rebuild with --write"
    content = json.dumps(manifest, indent=2) + "\n"
    target = ROOT / "fixtures" / "manifest.json"
    if args.write:
        target.write_text(content)
    else:
        assert target.read_text() == content, "Stale manifest; rebuild with --write"
    print("PASS: three fixture exports, compiler/source hashes, NSF bytes and derived timing")


if __name__ == "__main__":
    main()
