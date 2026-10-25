"""Prepare disposable, instrumented export variants; never edit the source checkout."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError(f"Expected exactly one instrumentation target: {old!r}")
    return text.replace(old, new, 1)


def defer_desktop_scene(text):
    """One production owner, also usable by an uninstrumented regression checkout."""
    start = text.index("func _ensure_scene_desktop(host: Control) -> Dictionary:\n")
    end = text.index("\nfunc ", start + 1)
    body = text[start:end]
    body = replace_once(body, '\tif not admitted.get("ok", false): return admitted\n',
        '\tif not admitted.get("ok", false): return admitted\n'
        '\tvar desktop_scene := load("res://scenes/desktop/ComputerDesktop.tscn") as PackedScene\n'
        '\tif desktop_scene == null: return _failure(&"scene_desktop_unavailable", "")\n')
    body = replace_once(body,
        '\tdesktop = preload("res://scenes/desktop/ComputerDesktop.tscn").instantiate()\n',
        '\tdesktop = desktop_scene.instantiate()\n')
    return text[:start] + body + text[end:]


def prepare(root, variant, trace_autoloads=False):
    root.mkdir(parents=True, exist_ok=True)
    changes = {}

    def edit(path, transform):
        target = root / path
        before = target.read_bytes()
        after = transform(before.decode("utf-8")).encode("utf-8")
        target.write_bytes(after)
        changes.setdefault(path, {"before": hashlib.sha256(before).hexdigest()})
        changes[path]["after"] = hashlib.sha256(after).hexdigest()

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

    if variant == "desktop":
        edit("autoload/ApplicationBootstrap.gd", defer_desktop_scene)

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

    autoload_sources = {}
    if trace_autoloads:
        # Godot constructs every autoload before adding the first one to root.
        # Consecutive constructor stamps bound loading, member initialization and
        # engine bookkeeping together; they are not exclusive resource I/O costs.
        project = (root / "project.godot").read_text(encoding="utf-8")
        block = re.search(r"(?ms)^\[autoload\]\n(.*?)(?=^\[|\Z)", project)
        if block is None:
            raise ValueError("Autoload section missing")
        entries = re.findall(r'^([A-Za-z_][A-Za-z_0-9]*)="\*([^"\n]+)"$', block[1], re.M)
        if len(entries) != (1 if variant == "minimal" else 15) or entries[0] != ("StartupProbe", "res://startup_probe.gd"):
            raise ValueError("Expected StartupProbe followed by the 14 production autoloads")
        constructors = {
            "AudioManager": ("playback_port: RefCounted = null", "playback_port"),
            "WindowModeManager": ("port: RefCounted = null", "port"),
            "SystemTtsCoordinator": ("speech_port: Object = null, duck_port: Object = null", "speech_port, duck_port"),
        }

        def trace_constructor(text, owner):
            if "_probe_original_init" in text or "_dwm_autoload_trace" in text:
                # The observer reads this metadata in its report; it has no ctor yet.
                if owner != "StartupProbe" or re.search(r"(?m)^func _init\(", text):
                    raise ValueError(f"Constructor already instrumented: {owner}")
            parameters, arguments = constructors.get(owner, ("", ""))
            header = f"func _init({parameters}) -> void:\n"
            wrapper = header
            if owner == "StartupProbe":
                wrapper += '\tEngine.set_meta("_dwm_autoload_trace", [])\n'
            wrapper += '\tvar trace: Array = Engine.get_meta("_dwm_autoload_trace")\n'

            def event(kind):
                return ('\ttrace.append({"ticks_us": Time.get_ticks_usec(), '
                        '"unix_ms": Time.get_unix_time_from_system() * 1000.0, '
                        f'"owner": "{owner}", "event": "{kind}"}})\n')

            wrapper += event("begin")
            if owner in constructors:
                wrapper += f"\t_probe_original_init({arguments})\n"
            wrapper += event("end")
            if owner in constructors:
                return replace_once(text, header, wrapper + "\n" + header.replace("_init(", "_probe_original_init("))
            if re.search(r"(?m)^func _init\(", text):
                raise ValueError(f"Unreviewed constructor: {owner}")
            return text.rstrip() + "\n\n" + wrapper

        for owner, resource in entries:
            if resource.startswith("uid://"):
                path = "addons/dialogic/Core/DialogicGameHandler.gd"
                if owner != "Dialogic" or (root / (path + ".uid")).read_text(encoding="utf-8").strip() != resource:
                    raise ValueError(f"Unreviewed autoload UID: {owner} {resource}")
            elif resource.startswith("res://") and resource.endswith(".gd"):
                path = resource.removeprefix("res://")
            else:
                raise ValueError(f"Unreviewed autoload resource: {owner} {resource}")
            autoload_sources[owner] = path
            edit(path, lambda text, owner=owner: trace_constructor(text, owner))

    (root / "startup-variant.json").write_text(json.dumps({"variant": variant,
        "trace_autoloads": trace_autoloads, "autoload_sources": autoload_sources,
        "changes": changes, "probe_sha256": hashlib.sha256((root / "startup_probe.gd").read_bytes()).hexdigest()}, indent=2), encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, required=True)
    parser.add_argument("--variant", choices=["baseline", "menu", "fonts", "minimal", "desktop"], required=True)
    parser.add_argument("--trace-autoloads", action="store_true",
                        help="Trace constructors in disposable exports; gaps also include loading and member initialization")
    args = parser.parse_args()
    prepare(args.project_root, args.variant, args.trace_autoloads)
