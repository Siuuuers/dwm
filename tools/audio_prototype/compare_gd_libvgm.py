"""Compare gd_libvgm without changing production or the existing native assertions."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import zipfile

import verify

ROOT = Path(__file__).resolve().parent
BUILD = ROOT / ".build" / "gd_trial"


def replace_once(source, old, new):
    assert source.count(old) == 1, "fixture factory changed; review the comparison adapter"
    return source.replace(old, new)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--addon", type=Path, default=BUILD / "addon")
    args = parser.parse_args()
    BUILD.mkdir(parents=True, exist_ok=True)
    verify.REPORTS = ROOT / "reports" / "gd_libvgm"
    verify.REPORTS.mkdir(parents=True, exist_ok=True)
    godot = args.godot
    if godot is None:
        platform = "win64.exe" if verify.WINDOWS else "linux.x86_64"
        digest = ("e39986a178d585ce7ac198fb8de6ea436366dc0cc00e594810c2e3e104c04b90" if verify.WINDOWS else
                  "d0bc2113065e481c9c2c2b2c37daa4e8be3fe9e27f0ab9ab0b6096e9a37907f3")
        with zipfile.ZipFile(verify.archive("Godot_v4.6.3-stable_" + platform + ".zip", digest)) as package:
            package.extractall(BUILD / "godot")
        godot = BUILD / "godot" / ("Godot_v4.6.3-stable_win64_console.exe" if verify.WINDOWS else
                                   "Godot_v4.6.3-stable_linux.x86_64")
        godot.chmod(0o755)
    godot = godot.resolve()
    version = subprocess.check_output([str(godot), "--version"], text=True).strip()
    assert version.startswith("4.6.3.stable"), version
    (verify.REPORTS / "version.txt").write_text(version + "\n")
    effect = ROOT / "fixtures/confirm.nsfe"
    assert hashlib.sha256(effect.read_bytes()).hexdigest() == "84e71d644c17f4a26c8ae389e992c214efc50bc28b35022f69b830e90a44710e"
    with tempfile.TemporaryDirectory(prefix="project-", dir=BUILD) as directory:
        project = Path(directory)
        shutil.copytree(args.addon, project / "addons/gd_libvgm")
        shutil.copytree(ROOT / "fixtures", project / "fixtures")
        for name in ("project.godot", "export_smoke.tscn"):
            shutil.copy2(ROOT / name, project / name)
        shutil.copy2(ROOT.parents[1] / "scripts/audio/AudioPlaybackPort.gd", project / "production_audio_playback_port.gd")
        native = replace_once((ROOT / "test_native.gd").read_text(),
            "    return DwmNsfStream.create(FileAccess.get_file_as_bytes('res://fixtures/' + id + '.nsf'),\n"
            "        cue.end_seconds, cue.intro_seconds, cue.loop_seconds)",
            "    var stream := VGMStream.new()\n"
            "    stream.data = FileAccess.get_file_as_bytes('res://fixtures/' + id + ('.nsfe' if id == 'confirm' else '.nsf'))\n"
            "    stream.loop_count = 0\n    stream.fade_time = 0.0\n    return stream")
        port = replace_once((ROOT / "test_port.gd").read_text(),
            '\t\tstreams[cue] = DwmNsfStream.create(\n'
            '\t\t\tFileAccess.get_file_as_bytes("res://fixtures/" + cue + ".nsf"),\n'
            '\t\t\tfloat(timing.end_seconds), float(timing.intro_seconds), float(timing.loop_seconds))',
            '\t\tvar stream := VGMStream.new()\n'
            '\t\tstream.data = FileAccess.get_file_as_bytes("res://fixtures/" + cue + (".nsfe" if cue == "confirm" else ".nsf"))\n'
            '\t\tstream.loop_count = 0\n\t\tstream.fade_time = 0.0\n\t\tstreams[cue] = stream')
        smoke = replace_once((ROOT / "export_smoke.gd").read_text(),
            '\tvar stream = DwmNsfStream.create(FileAccess.get_file_as_bytes("res://fixtures/confirm.nsf"), cue.end_seconds)',
            '\tvar stream := VGMStream.new()\n'
            '\tstream.data = FileAccess.get_file_as_bytes("res://fixtures/confirm.nsfe")\n'
            '\tstream.loop_count = 0\n\tstream.fade_time = 0.0')
        for name, source in (("test_native.gd", native), ("test_port.gd", port), ("export_smoke.gd", smoke)):
            (project / name).write_text(source, encoding="utf-8")
        with tempfile.TemporaryDirectory(prefix="cold-control-", dir=BUILD) as control:
            shutil.copytree(project, control, dirs_exist_ok=True)
            result = subprocess.run([str(godot), "--headless", "--path", control, "--import"],
                                    capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=180)
            (verify.REPORTS / "cold-control.log").write_text(result.stdout + result.stderr, encoding="utf-8")
            (verify.REPORTS / "cold-control.json").write_text(json.dumps({"exit_code": result.returncode}) + "\n")
            print("Unmodified cold-import diagnostic exit:", result.returncode)
        base = [godot, "--headless", "--audio-driver", "Dummy", "--path", project]
        verify.run("cold-import-workaround", [*base, "--import", "--frame-delay", "800"], cwd=project)
        result = subprocess.run([str(arg) for arg in [*base, "--script", "res://test_native.gd"]],
                                cwd=project, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=180)
        output = result.stdout + result.stderr
        (verify.REPORTS / "native-strict.log").write_text(output, encoding="utf-8")
        print(output)
        differences = re.findall(r"^ERROR: (.*)$", output, re.MULTILINE)
        assert result.returncode == 1 and "NSF_NATIVE_CHECKS=18 FAILURES=2" in output, "strict native result changed"
        assert differences == ["loop count excludes introduction after multiple passes", "finite endpoint is sample rounded"], differences
        assert "SCRIPT ERROR:" not in output
        print("DIAGNOSTIC: strict native 16/18; two recorded API differences remain unresolved")
        verify.run("port", [*base, "--script", "res://test_port.gd"], "PORT_INTEGRATION failures=0", cwd=project)
        verify.run("smoke", base, "EXPORTED_AUDIO_PROTOTYPE_PASS", cwd=project)
        if verify.WINDOWS:
            templates = verify.archive("Godot_v4.6.3-stable_export_templates.tpz",
                                       "3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8")
            with zipfile.ZipFile(templates) as package:
                package.extract("templates/windows_release_x86_64.exe", BUILD)
            template = (BUILD / "templates/windows_release_x86_64.exe").as_posix()
            (project / "export_presets.cfg").write_text(
                '[preset.0]\nname="Windows"\nplatform="Windows Desktop"\nrunnable=true\n'
                'export_filter="all_resources"\ninclude_filter="fixtures/*.nsf,fixtures/*.nsfe,fixtures/*.json"\n'
                '[preset.0.options]\ncustom_template/release="' + template + '"\n'
                'binary_format/architecture="x86_64"\napplication/modify_resources=false\n')
            exported = verify.REPORTS / "export"
            exported.mkdir(exist_ok=True)
            verify.run("export", [*base, "--export-release", "Windows", exported / "gd-libvgm-trial.exe"], cwd=project)
            verify.run("exported-startup", [exported / "gd-libvgm-trial.exe", "--headless", "--audio-driver", "Dummy"],
                       "EXPORTED_AUDIO_PROTOTYPE_PASS", cwd=exported)
        print("PASS: candidate port/smoke checks; strict native differences and import workaround are not adoption approval")


if __name__ == "__main__":
    main()
