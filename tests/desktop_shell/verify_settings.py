"""Real Settings host/controller/managers; fake storage and isolated app directories."""
from pathlib import Path
import hashlib, json, os, re, shutil, subprocess, tempfile

root = Path(__file__).resolve().parents[2]
scratch = Path(tempfile.mkdtemp(prefix='desktop-settings-', dir=root / '.godot'))
classes = {}
for source in (root / 'scripts').rglob('*.gd'):
    match = re.search(r'^class_name\s+(\w+)', source.read_text(encoding='utf-8-sig'), re.M)
    if match:
        classes[match.group(1)] = source.relative_to(root).as_posix()
pending = ['tests/desktop_shell/test_settings_host.gd']
pending.extend(path.relative_to(root).as_posix() for path in (root / 'localization').rglob('*') if path.is_file())
copied = set()
while pending:
    relative = pending.pop()
    if relative in copied:
        continue
    source = root / relative
    if not source.is_file():
        continue
    copied.add(relative)
    target = scratch / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
    if source.suffix in {'.gd', '.tscn', '.tres'}:
        text = source.read_text(encoding='utf-8-sig')
        pending.extend(re.findall(r'res://([^"\s]+)', text))
        for name in set(re.findall(r'\b\w+\b', text)).intersection(classes):
            pending.append(classes[name])
(scratch / 'project.godot').write_text('''config_version=5
[application]
config/name="DesktopSettingsTests"
[display]
window/size/viewport_width=1280
window/size/viewport_height=800
window/subwindows/embed_subwindows=true
[rendering]
renderer/rendering_method="gl_compatibility"
''', encoding='utf-8')
env = os.environ.copy()
for key in ['APPDATA', 'LOCALAPPDATA']:
    target = scratch / key.lower()
    target.mkdir()
    env[key] = str(target)
godot = env.get('GODOT_CONSOLE_PATH', r'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe')
logs = []
passed = True
for args in [['--editor', '--import', '--quit'], ['--script', 'res://tests/desktop_shell/test_settings_host.gd']]:
    result = subprocess.run([godot, '--headless', '--path', str(scratch), *args], env=env, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=60)
    output = result.stdout + result.stderr
    logs.append(output)
    checked = output.replace('ERROR: Failed to read the root certificate store.', '')
    if result.returncode or 'ERROR:' in checked:
        passed = False
        break
passed = passed and 'SETTINGS_DESKTOP_HOST_PASS' in logs[-1]
(scratch / 'verification.log').write_text('\n'.join(logs), encoding='utf-8')
(scratch / 'result.json').write_text(json.dumps({'passed': passed,
    'scope': 'Real Settings scene/controller/ProfileManager/LocalizationManager, fake FileOps, headless geometry and focus; no production profile writes or full startup.',
    'known_diagnostics': ['Sandbox certificate store unavailable.', 'Inherited JsonFileStorage Unicode NUL diagnostic, independently reproduced by Contacts real-owner suite.'],
    'sources': {path: hashlib.sha256((scratch / path).read_bytes()).hexdigest() for path in sorted(copied)}}, indent=2) + '\n', encoding='utf-8')
print(logs[-1])
print('Evidence:', scratch / 'result.json')
raise SystemExit(0 if passed else 1)
