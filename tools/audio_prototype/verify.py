"""Shared pinned downloads and checked process execution for native audio verification."""
import hashlib
from pathlib import Path
import subprocess
import sys
import urllib.request

ROOT = Path(__file__).resolve().parent
BUILD = ROOT / ".build"
REPORTS = ROOT / "reports"
WINDOWS = sys.platform == "win32"
RELEASE = "https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/"


def archive(name, digest):
    path = BUILD / name
    if not path.exists():
        urllib.request.urlretrieve(RELEASE + name, path)
    assert hashlib.sha256(path.read_bytes()).hexdigest() == digest, name + " checksum"
    return path


def run(name, command, marker=None, cwd=ROOT):
    result = subprocess.run([str(arg) for arg in command], cwd=cwd, capture_output=True,
                            text=True, encoding="utf-8", errors="replace", timeout=180)
    output = result.stdout + result.stderr
    (REPORTS / (name + ".log")).write_text(output, encoding="utf-8")
    print(output)
    assert result.returncode == 0, name + " exit " + str(result.returncode)
    assert "SCRIPT ERROR:" not in output and "ERROR:" not in output, name + " engine error"
    if marker:
        assert marker in output, name + " completion marker absent"


if __name__ == "__main__":
    raise SystemExit("Shared verification helpers: run verify_game.py for the game or "
                     "compare_gd_libvgm.py for the isolated comparison.")
