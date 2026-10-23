"""Compile real owners and test the Contacts seams without application startup or user I/O."""
from pathlib import Path
import hashlib, json, os, re, shutil, subprocess, tempfile

root = Path(__file__).resolve().parents[2]
scratch = Path(tempfile.mkdtemp(prefix='contacts-real-owner-', dir=root / '.godot'))
classes = {}
for source in (root / 'scripts').rglob('*.gd'):
    match = re.search(r'^class_name\s+(\w+)', source.read_text(encoding='utf-8-sig'), re.M)
    if match:
        classes[match.group(1)] = source.relative_to(root).as_posix()
pending = ['tests/contacts_presentation/test_real_owner.gd']
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
(scratch / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="ContactsRealOwnerTests"\n', encoding='utf-8')
env = os.environ.copy()
for key in ['APPDATA', 'LOCALAPPDATA']:
    target = scratch / key.lower()
    target.mkdir()
    env[key] = str(target)
godot = env.get('GODOT_CONSOLE_PATH', r'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe')
logs = []
passed = True
for args in [['--editor', '--import', '--quit'],
             ['--check-only', '--script', 'res://scripts/infrastructure/storage/JsonFileStorage.gd'],
             ['--script', 'res://tests/contacts_presentation/test_real_owner.gd']]:
    result = subprocess.run([godot, '--headless', '--path', str(scratch), *args], env=env, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=90)
    output = result.stdout + result.stderr
    logs.append(output)
    checked = output.replace('ERROR: Failed to read the root certificate store.', '')
    if result.returncode or 'ERROR:' in checked:
        passed = False
        break
passed = passed and 'CONTACTS_REAL_OWNER_PASS' in logs[-1]
(scratch / 'verification.log').write_text('\n'.join(logs), encoding='utf-8')
(scratch / 'result.json').write_text(json.dumps({
    'passed': passed,
    'scope': 'Real GameState preview/commit and real Bootstrap Contacts configuration; manual fixture startup, not full application startup.',
    'known_diagnostics': [
        'Windows certificate store inaccessible in sandbox; retained in log.',
        'Unexpected NUL character Unicode diagnostic reproduces by check-only compiling unchanged JsonFileStorage.gd, whose line 418 contains a literal Unicode NUL escape. The separate check-only output is retained in the log; this is inherited, not a clean-diagnostics claim.'
    ],
    'sources': {path: hashlib.sha256((scratch / path).read_bytes()).hexdigest() for path in sorted(copied)},
}, indent=2) + '\n', encoding='utf-8')
print(logs[-1])
print('Evidence:', scratch / 'result.json')
raise SystemExit(0 if passed else 1)
