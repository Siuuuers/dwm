"""Verify native authoring, manager playback and the real Windows game export."""
import os
from pathlib import Path
import shutil
import xml.etree.ElementTree as ET
import zipfile

import verify

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(__file__).resolve().parent


def main():
    reports = ROOT / ".godot/ci/native-audio"
    reports.mkdir(parents=True, exist_ok=True)
    verify.REPORTS = reports
    platform = "win64.exe" if verify.WINDOWS else "linux.x86_64"
    digest = ("e39986a178d585ce7ac198fb8de6ea436366dc0cc00e594810c2e3e104c04b90" if verify.WINDOWS else
              "d0bc2113065e481c9c2c2b2c37daa4e8be3fe9e27f0ab9ab0b6096e9a37907f3")
    with zipfile.ZipFile(verify.archive("Godot_v4.6.3-stable_" + platform + ".zip", digest)) as package:
        package.extractall(verify.BUILD / "godot")
    godot = verify.BUILD / "godot" / ("Godot_v4.6.3-stable_win64_console.exe" if verify.WINDOWS else
                                      "Godot_v4.6.3-stable_linux.x86_64")
    godot.chmod(0o755)
    os.environ["DWM_TEST_ROOT"] = str(ROOT / ".godot/phase2r_tests/native-audio")
    os.environ["XDG_DATA_HOME"] = str(reports / "user")
    if verify.WINDOWS:
        os.environ["APPDATA"] = str(reports / "user")
    Path(os.environ["DWM_TEST_ROOT"]).mkdir(parents=True, exist_ok=True)
    Path(os.environ["XDG_DATA_HOME"]).mkdir(exist_ok=True)
    staged = ROOT / "native_audio_verify"
    staged.mkdir(exist_ok=True)
    shutil.copy2(SOURCE / "game_smoke.gd", staged / "smoke.gd")
    (staged / "smoke.tscn").write_text('[gd_scene load_steps=2 format=3]\n\n'
        '[ext_resource type="Script" path="res://native_audio_verify/smoke.gd" id="1"]\n\n'
        '[node name="NativeAudioSmoke" type="Node"]\nscript = ExtResource("1")\n')
    for source, target in (("loop_a.nsf", "audio/bgm/_native_verify.nsf"),
                           ("confirm.nsfe", "audio/sfx/_native_verify.nsfe")):
        destination = ROOT / target
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(SOURCE / "fixtures" / source, destination)
    base = [godot, "--headless", "--audio-driver", "Dummy", "--path", ROOT]
    verify.run("import-workaround", [*base, "--editor", "--import", "--frame-delay", "800"], cwd=ROOT)
    suites = [
        "test_audio_manager", "test_audio_settings_transactions", "test_scene_audio_manifest",
        "test_scene_audio_manager", "test_scene_audio_playback_port", "test_inline_audio_authoring",
    ]
    report = reports / "audio.xml"
    report.unlink(missing_ok=True)
    verify.run("audio", [*base, "-s", "res://addons/gut/gut_cmdln.gd", "-gconfig=",
        "-gtest=" + ",".join("res://tests/unit/" + name + ".gd" for name in suites),
        "-gexit", "-glog=1", "-gjunit_xml_file=" + str(report)], cwd=ROOT)
    result = ET.parse(report).getroot()
    assert result.findall(".//testcase"), "No audio cases executed"
    assert not any(result.findall(".//" + tag) for tag in ("failure", "error", "skipped"))
    verify.run("game-smoke", [*base, "res://native_audio_verify/smoke.tscn"],
               "NATIVE_GAME_EXPORT_PASS", cwd=ROOT)
    if verify.WINDOWS:
        templates = verify.archive("Godot_v4.6.3-stable_export_templates.tpz",
            "3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8")
        with zipfile.ZipFile(templates) as package:
            package.extract("templates/windows_release_x86_64.exe", verify.BUILD)
        preset = ROOT / "export_presets.cfg"
        original = preset.read_text()
        project = ROOT / "project.godot"
        original_project = project.read_text()
        project.write_text(original_project.replace('run/main_scene="res://scenes/menu/MenuScene.tscn"',
            'run/main_scene="res://native_audio_verify/smoke.tscn"'))
        template = (verify.BUILD / "templates/windows_release_x86_64.exe").as_posix()
        preset.write_text(original.replace('custom_template/release=""', 'custom_template/release="' + template + '"'))
        exported = reports / "export"
        exported.mkdir(exist_ok=True)
        verify.run("game-export", [*base, "--export-release", "Windows Desktop", exported / "game.exe"], cwd=ROOT)
        preset.write_text(original)
        project.write_text(original_project)
        for attempt in range(3):
            os.environ["APPDATA"] = str(reports / "user" / ("export-" + str(attempt)))
            Path(os.environ["APPDATA"]).mkdir(exist_ok=True)
            verify.run("exported-game-" + str(attempt + 1),
                [exported / "game.exe", "--headless", "--audio-driver", "Dummy"],
                "NATIVE_GAME_EXPORT_PASS", cwd=exported)
    print("PASS: native game integration and focused audio suites")
    shutil.rmtree(staged)
    (ROOT / "audio/bgm/_native_verify.nsf").unlink()
    (ROOT / "audio/sfx/_native_verify.nsfe").unlink()


if __name__ == "__main__":
    main()
