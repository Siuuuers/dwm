"""Run the data-boundary checks in an isolated Godot project, without game autoloads."""
from pathlib import Path
import os, re, shutil, subprocess, tempfile

root = Path(__file__).resolve().parents[2]
scratch = Path(tempfile.mkdtemp(prefix='contacts-presentation-', dir=root / '.godot'))
pending = ['tests/contacts_presentation/test_presentation.gd']
seen = set()
while pending:
    relative = pending.pop()
    if relative in seen:
        continue
    seen.add(relative)
    source = root / relative
    target = scratch / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    if source.suffix == '.gd':
        pending.extend(re.findall(r'(?:preload|load)\("res://([^"\n]+)"\)', source.read_text(encoding='utf-8')))
(scratch / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="ContactsBoundaryTests"\n', encoding='utf-8')
env = os.environ.copy()
for key in ['APPDATA', 'LOCALAPPDATA']:
    target = scratch / key.lower()
    target.mkdir()
    env[key] = str(target)
godot = env.get('GODOT_CONSOLE_PATH', r'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe')
result = subprocess.run([godot, '--headless', '--path', str(scratch), '--script', 'res://tests/contacts_presentation/test_presentation.gd'], env=env, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=60)
output = result.stdout + result.stderr
(scratch / 'verification.log').write_text(output, encoding='utf-8')
print(output)
print('Log:', scratch / 'verification.log')
checked = output.replace('ERROR: Failed to read the root certificate store.', '')
raise SystemExit(0 if result.returncode == 0 and 'CONTACTS_PRESENTATION_PASS' in output and 'ERROR:' not in checked else 1)
