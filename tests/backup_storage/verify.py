"""Isolated storage protocol: raw revisions, injected I/O failures, durable crash snapshots."""
from pathlib import Path
import hashlib, json, os, re, shutil, subprocess, tempfile

root = Path(__file__).resolve().parents[2]
scratch = Path(tempfile.mkdtemp(prefix='backup-storage-', dir=root / '.godot'))
pending = ['tests/backup_storage/test_revision_storage.gd', 'tests/unit/test_json_file_storage.gd']
pending.extend(path.relative_to(root).as_posix() for path in (root / 'addons/gut').rglob('*') if path.is_file() and path.suffix != '.uid')
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
        pending.extend(re.findall(r'res://([^"\s]+)', source.read_text(encoding='utf-8-sig')))
(scratch / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="BackupStorageTests"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding='utf-8')
env = os.environ.copy()
for key in ['APPDATA', 'LOCALAPPDATA']:
    target = scratch / key.lower()
    target.mkdir()
    env[key] = str(target)
godot = env.get('GODOT_CONSOLE_PATH', r'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe')
logs, passed = [], True
for args in [['--editor', '--import', '--quit'], ['--script', 'res://tests/backup_storage/test_revision_storage.gd'], ['--script', 'res://addons/gut/gut_cmdln.gd', '-gtest=res://tests/unit/test_json_file_storage.gd', '-gexit']]:
    result = subprocess.run([godot, '--headless', '--path', str(scratch), *args], env=env, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=60)
    output = result.stdout + result.stderr
    logs.append(output)
    checked = output.replace('ERROR: Failed to read the root certificate store.', '')
    if result.returncode or 'ERROR:' in checked:
        passed = False
        break
passed = passed and any('BACKUP_REVISION_STORAGE_PASS' in log for log in logs)
(scratch / 'verification.log').write_text('\n'.join(logs), encoding='utf-8')
receipt = {'passed': passed, 'scope': 'FakeFileOps only; existing GUT storage suite, raw inspection, revision overwrite/delete, operation fault positions, persisted crash snapshots, foreign hash and marker refusal. No player file access.', 'known_diagnostics': ['Sandbox certificate store unavailable.', 'Inherited literal NUL diagnostic.', 'Intentional malformed UTF-8 fixtures emit Unicode decoding diagnostics.'], 'sources': {path: hashlib.sha256((scratch / path).read_bytes()).hexdigest() for path in sorted(copied)}}
(scratch / 'result.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
for log in logs:
    for line in log.splitlines():
        if any(token in line for token in ['BACKUP_REVISION', '"assertions"', 'Passed', 'Failed', 'Tests', 'Totals', 'SCRIPT ERROR', 'Parse Error']):
            print(line)
print('Evidence:', scratch / 'result.json')
raise SystemExit(0 if passed else 1)
