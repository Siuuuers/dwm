"""Verify the component without loading the game's autoloads or user data."""
from pathlib import Path
import hashlib, json, os, shutil, subprocess, sys, tempfile

root = Path(__file__).resolve().parents[2]
cache = root / '.godot'
cache.mkdir(exist_ok=True)
scratch = Path(tempfile.mkdtemp(prefix='contacts-component-', dir=cache))
for folder in ['scripts/ui/contacts', 'assets/ui/contacts', 'tests/contacts_component']:
    source = root / folder
    if source.exists():
        shutil.copytree(source, scratch / folder, dirs_exist_ok=True)
(scratch / 'project.godot').write_text('''config_version=5
[application]
config/name="DwmContactsComponentTests"
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
[rendering]
renderer/rendering_method="gl_compatibility"
''', encoding='utf-8')
env = os.environ.copy()
for key, folder in [('APPDATA', 'appdata'), ('LOCALAPPDATA', 'localappdata')]:
    location = scratch / folder
    location.mkdir(exist_ok=True)
    env[key] = str(location)
godot = env.get('GODOT_CONSOLE_PATH', r'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe')
logs = []
commands = [['--editor', '--import', '--quit'], ['--script', 'res://tests/contacts_component/test_contacts_panel.gd'], ['--script', 'res://tests/contacts_component/ablate_fixed_text.gd']]
for args in commands:
    result = subprocess.run([godot, '--headless', '--path', str(scratch), *args], env=env, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=90)
    output = result.stdout + result.stderr
    logs.append(output)
    # This sandbox cannot read Windows' certificate store. No network is used.
    # Preserve that engine diagnostic in the log; reject every other error.
    checked = output.replace('ERROR: Failed to read the root certificate store.', '')
    if result.returncode or 'SCRIPT ERROR:' in checked or 'ERROR:' in checked:
        print(output, end='')
        (scratch / 'verification.log').write_text('\n'.join(logs), encoding='utf-8')
        sys.exit(result.returncode or 1)
(scratch / 'verification.log').write_text('\n'.join(logs), encoding='utf-8')
if 'CONTACTS_COMPONENT_PASS' not in logs[-2] or 'CONTACTS_ABLATION_PASS' not in logs[-1]:
    sys.exit('Expected suite completion marker missing')
ablation = next(json.loads(line) for line in logs[-1].splitlines() if line.startswith('{'))
source_files = [*sorted((root / 'scripts/ui/contacts').glob('*.gd')), *sorted((root / 'tests/contacts_component').glob('*.gd')), Path(__file__)]
evidence = root / 'evidence' / 'contacts_component'
evidence.mkdir(parents=True, exist_ok=True)
(evidence / 'result.json').write_text(json.dumps({
    'engine': logs[-1].splitlines()[0],
    'suite': 'CONTACTS_COMPONENT_PASS', 'ablation': ablation,
    'known_environment_diagnostic': 'Windows root certificate store inaccessible in sandbox; no network used. This single engine diagnostic is retained in logs; other errors fail verification.',
    'scope': 'Isolated headless Godot layout and input checks, not GPU raster or whole-game integration proof',
    'log': str((scratch / 'verification.log').relative_to(root)).replace('\\', '/'),
    'sources': {str(p.relative_to(root)).replace('\\', '/'): hashlib.sha256(p.read_bytes()).hexdigest() for p in source_files}
}, indent=2) + '\n', encoding='utf-8')
print('CONTACTS_COMPONENT_PASS; CONTACTS_ABLATION_PASS')
print('Two-line cap hides', ablation['fixed_two_lines']['hidden_lines'], 'of', ablation['fixed_two_lines']['total_lines'], 'lines; normal reflow hides', ablation['normal_reflow']['hidden_lines'])
print('Verified in isolated project:', scratch)
