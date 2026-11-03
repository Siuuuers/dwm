"""Run only native audio checks; on Windows also export and launch the prototype."""
import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys
import urllib.request
import zipfile

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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, help="Reuse an installed Godot 4.6.3")
    args = parser.parse_args()
    BUILD.mkdir(exist_ok=True)
    REPORTS.mkdir(exist_ok=True)
    godot = args.godot
    if godot is None:
        platform = "win64.exe" if WINDOWS else "linux.x86_64"
        digest = ("e39986a178d585ce7ac198fb8de6ea436366dc0cc00e594810c2e3e104c04b90" if WINDOWS else
                  "d0bc2113065e481c9c2c2b2c37daa4e8be3fe9e27f0ab9ab0b6096e9a37907f3")
        with zipfile.ZipFile(archive("Godot_v4.6.3-stable_" + platform + ".zip", digest)) as package:
            package.extractall(BUILD / "godot")
        godot = BUILD / "godot" / ("Godot_v4.6.3-stable_win64_console.exe" if WINDOWS else
                                   "Godot_v4.6.3-stable_linux.x86_64")
        godot.chmod(0o755)
    godot = godot.resolve()
    version = subprocess.check_output([str(godot), "--version"], text=True).strip()
    assert version.startswith("4.6.3.stable"), version
    (REPORTS / "version.txt").write_text(version + "\n")
    shutil.copy2(ROOT.parents[1] / "scripts/audio/AudioPlaybackPort.gd", ROOT / "production_audio_playback_port.gd")
    base = [godot, "--headless", "--audio-driver", "Dummy", "--path", ROOT]
    run("import", [*base, "--editor", "--import"])
    run("native", [*base, "--script", "res://test_native.gd"], "NSF_NATIVE_CHECKS=18 FAILURES=0")
    run("port", [*base, "--script", "res://test_port.gd"], "PORT_INTEGRATION failures=0")
    run("smoke", base, "EXPORTED_AUDIO_PROTOTYPE_PASS")
    if WINDOWS:
        templates = archive("Godot_v4.6.3-stable_export_templates.tpz",
                            "3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8")
        with zipfile.ZipFile(templates) as package:
            package.extract("templates/windows_release_x86_64.exe", BUILD)
        template = (BUILD / "templates/windows_release_x86_64.exe").as_posix()
        (ROOT / "export_presets.cfg").write_text(
            '[preset.0]\nname="Windows"\nplatform="Windows Desktop"\nrunnable=true\n'
            'export_filter="all_resources"\ninclude_filter="fixtures/*.nsf,fixtures/*.json"\n'
            'exclude_filter=".build/*,reports/*"\nexport_path="reports/export/audio-prototype.exe"\n'
            '[preset.0.options]\ncustom_template/release="' + template + '"\n'
            'binary_format/architecture="x86_64"\napplication/modify_resources=false\n')
        exported = REPORTS / "export"
        exported.mkdir(exist_ok=True)
        run("export", [*base, "--export-release", "Windows", exported / "audio-prototype.exe"])
        run("exported-startup", [exported / "audio-prototype.exe", "--headless", "--audio-driver", "Dummy"],
            "EXPORTED_AUDIO_PROTOTYPE_PASS", cwd=exported)
    print("PASS: focused native audio checks")


if __name__ == "__main__":
    main()
