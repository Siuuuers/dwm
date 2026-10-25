"""Prepare disposable, instrumented export variants; never edit the source checkout."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError(f"Expected exactly one instrumentation target: {old!r}")
    return text.replace(old, new, 1)


def prepare(root, variant):
    root.mkdir(parents=True, exist_ok=True)
    changes = {}

    def edit(path, transform):
        target = root / path
        before = target.read_bytes()
        after = transform(before.decode("utf-8")).encode("utf-8")
        target.write_bytes(after)
        changes[path] = {"before": hashlib.sha256(before).hexdigest(),
                         "after": hashlib.sha256(after).hexdigest()}

    shutil.copyfile(Path(__file__).with_name("startup_probe.gd"), root / "startup_probe.gd")
    if variant == "minimal":
        shutil.copyfile(Path(__file__).resolve().parents[2] / "export_presets.cfg", root / "export_presets.cfg")
        (root / "project.godot").write_text('''config_version=5
[application]
config/name="DWM Startup Minimal"
run/main_scene="res://startup_minimal.tscn"
config/features=PackedStringArray("4.6", "Forward Plus")
[audio]
general/text_to_speech=true
[autoload]
StartupProbe="*res://startup_probe.gd"
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
[rendering]
rendering_device/driver.windows="d3d12"
''', encoding="utf-8")
        (root / "startup_minimal.tscn").write_text('''[gd_scene format=3]
[node name="Minimal" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
[node name="ProbeButton" type="Button" parent="."]
offset_left = 100.0
offset_top = 100.0
offset_right = 400.0
offset_bottom = 200.0
text = "Startup probe"
''', encoding="utf-8")
        # A minimal package must exclude the game's resource tree as well as its autoloads.
        edit("export_presets.cfg", lambda text: replace_once(text,
             'export_filter="all_resources"',
             'export_filter="selected_scenes"\nexport_files=PackedStringArray("res://startup_minimal.tscn", "res://startup_probe.gd")'))
    else:
        edit("project.godot", lambda text: replace_once(replace_once(text, "[autoload]\n",
             '[autoload]\n\nStartupProbe="*res://startup_probe.gd"\n'),
             ', "res://addons/gut/plugin.cfg"', ''))

        def bootstrap(text):
            text = replace_once(text, 'func _ready() -> void:\n',
                'func _ready() -> void:\n\tget_node("/root/StartupProbe").mark("bootstrap_ready")\n')
            original = 'func start(mode: StringName = MODE_FINAL) -> Dictionary:\n'
            wrapper = '''func start(mode: StringName = MODE_FINAL) -> Dictionary:
	var probe := get_node("/root/StartupProbe")
	probe.mark("bootstrap_start")
	var began: Dictionary = probe.stamp()
	var result: Dictionary = _probe_start(mode)
	probe.finish_phase("bootstrap.total", began, bool(result.get("ok", false)))
	return result

func _probe_start(mode: StringName = MODE_FINAL) -> Dictionary:
'''
            text = replace_once(text, original, wrapper)
            return replace_once(text, '\t\tvar stage_result := _run_stage(stage_id, mode)\n',
                '\t\tvar probe := get_node("/root/StartupProbe")\n'
                '\t\tvar began: Dictionary = probe.stamp()\n'
                '\t\tvar stage_result := _run_stage(stage_id, mode)\n'
                '\t\tprobe.finish_phase("bootstrap." + str(stage_id), began, bool(stage_result.get("ok", false)))\n')
        edit("autoload/ApplicationBootstrap.gd", bootstrap)

        def registration(text):
            text = replace_once(text, '\tvar checked := validate_scene_registration(bundle)\n',
                '\tvar probe: Node = (Engine.get_main_loop() as SceneTree).root.get_node("StartupProbe")\n'
                '\tvar began: Dictionary = probe.stamp()\n'
                '\tvar checked := validate_scene_registration(bundle)\n'
                '\tprobe.finish_phase("registration.physical", began, bool(checked.get("ok", false)))\n')
            return replace_once(text, '\tvar structural := SCENE_EVENTS.validate_bundle_structure(bundle)\n',
                '\tbegan = probe.stamp()\n'
                '\tvar structural := SCENE_EVENTS.validate_bundle_structure(bundle)\n'
                '\tprobe.finish_phase("registration.structural", began, bool(structural.get("ok", false)))\n')
        edit("scripts/narrative/DialogicEntryManifest.gd", registration)

    if variant == "menu":
        def menu(text):
            for constant, path in [("BACKUP_APP_SCENE", "scenes/apps/BackupApp.tscn"),
                                   ("SETTING_SCENE", "scenes/menu/Setting.tscn"),
                                   ("GALLERY_SCENE", "scenes/menu/GalleryScene.tscn")]:
                text = replace_once(text, f'const {constant} := preload("res://{path}")\n',
                                    f'const {constant} := "res://{path}"\n')
                text = replace_once(text, f'{constant}.instantiate()',
                                    f'(load({constant}) as PackedScene).instantiate()')
            return text
        edit("scripts/ui/MenuScene.gd", menu)

    if variant == "fonts":
        def fonts(text):
            for constant, filename in [("SIMPLIFIED", "source-han-sans-sc-regular.otf"),
                                       ("TRADITIONAL", "source-han-sans-hc-regular.otf")]:
                text = replace_once(text,
                    f'const {constant} := preload("res://assets/ui/contacts/fonts/{filename}")\n', '')
            return text
        edit("scripts/ui/UiTypography.gd", lambda text: replace_once(fonts(text),
            'fallbacks.append(TRADITIONAL)', 'fallbacks.append(font("zh-HK", percent, "readable"))'))
        for path in ["scripts/ui/desktop/DesktopTheme.gd", "scripts/ui/SettingsTheme.gd"]:
            edit(path, fonts)
        edit("tests/scene/test_shop_card.gd", lambda text: replace_once(replace_once(text,
            "FONTS.SIMPLIFIED", 'load("res://scripts/ui/UiTypography.gd").font("zh-CN", 100, "readable")'),
            "FONTS.TRADITIONAL", 'load("res://scripts/ui/UiTypography.gd").font("zh-HK", 100, "readable")'))

    (root / "startup-variant.json").write_text(json.dumps({"variant": variant,
        "changes": changes, "probe_sha256": hashlib.sha256((root / "startup_probe.gd").read_bytes()).hexdigest()}, indent=2), encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, required=True)
    parser.add_argument("--variant", choices=["baseline", "menu", "fonts", "minimal"], required=True)
    args = parser.parse_args()
    prepare(args.project_root, args.variant)
