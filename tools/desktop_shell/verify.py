"""Run real Contacts/shared-shell scenes in a disposable project without autoloads."""
from pathlib import Path
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[2]
cache = root / '.godot'
cache.mkdir(exist_ok=True)
scratch = Path(tempfile.mkdtemp(prefix='desktop-shell-', dir=cache))
classes = {}
for path in (root / 'scripts').rglob('*.gd'):
    match = re.search(r'^class_name\s+(\w+)', path.read_text(encoding='utf-8-sig'), re.M)
    if match:
        classes[match.group(1)] = path.relative_to(root).as_posix()
pending = ['scenes/desktop/ComputerDesktop.tscn', 'scenes/apps/ContactListApp.tscn',
           'tests/desktop_shell/test_desktop_shell.gd']
copied = set()
while pending:
    relative = pending.pop()
    if relative in copied:
        continue
    source = root / relative
    if not source.is_file():
        continue  # Dynamic paths are checked by the actual suite if they are used.
    copied.add(relative)
    target = scratch / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
    if source.suffix in {'.gd', '.tscn', '.tres'}:
        content = source.read_text(encoding='utf-8-sig')
        pending.extend(re.findall(r'res://([^"\s]+)', content))
        for name in set(re.findall(r'\b\w+\b', content)).intersection(classes):
            pending.append(classes[name])
for source in (root / 'assets/ui/contacts/fonts').iterdir():
    if source.is_file() and source.suffix != '.import':
        relative = source.relative_to(root)
        target = scratch / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        copied.add(relative.as_posix())
for source in (root / 'localization').rglob('*'):
    if source.is_file() and source.suffix != '.import':
        relative = source.relative_to(root)
        target = scratch / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        copied.add(relative.as_posix())
(scratch / 'project.godot').write_text('''config_version=5
[application]
config/name="DwmDesktopShellTests"
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
[rendering]
renderer/rendering_method="gl_compatibility"
''', encoding='utf-8')
env = os.environ.copy()
for key in ['APPDATA', 'LOCALAPPDATA']:
    location = scratch / key.lower()
    location.mkdir()
    env[key] = str(location)
godot = env.get('GODOT_CONSOLE_PATH', r'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe')
logs = []
passed = True
for arguments in [['--editor', '--import', '--quit'], ['--script', 'res://tests/desktop_shell/test_desktop_shell.gd']]:
    result = subprocess.run([godot, '--headless', '--path', str(scratch), *arguments],
                            env=env, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=90)
    output = result.stdout + result.stderr
    logs.append(output)
    checked = output.replace('ERROR: Failed to read the root certificate store.', '')
    if result.returncode or 'SCRIPT ERROR:' in checked or 'ERROR:' in checked:
        print(output, end='')
        passed = False
        break
(scratch / 'verification.log').write_text('\n'.join(logs), encoding='utf-8')
passed = passed and 'DESKTOP_SHELL_PASS' in logs[-1]
report = {
    'passed': passed,
    'scope': 'Real MainGameScene, desktop, Contacts and Settings scenes/controller; real ProfileManager and LocalizationManager explicitly initialized with a shared mutation gate and in-memory FakeFileOps for cross-app routing. Contacts projection and desktop host are fakes. Covers launcher/shared strip, multilingual layout, clock, navigation and cache focus. No configured game autoloads, player persistence, full Bootstrap startup or GPU raster proof.',
    'log': (scratch / 'verification.log').relative_to(root).as_posix(),
    'known_environment_diagnostic': 'Windows root certificate store inaccessible; only that exact diagnostic is allowed and remains logged.',
    'sources': {relative: hashlib.sha256((scratch / relative).read_bytes()).hexdigest() for relative in sorted(copied)},
}
report['sources'][Path(__file__).relative_to(root).as_posix()] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
report['observed_unicode_diagnostics'] = [line for output in logs for line in output.splitlines() if 'Unicode parsing error' in line]
(scratch / 'result.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
evidence = root / 'tools/desktop_shell/evidence'
evidence.mkdir(exist_ok=True)
portable_report = dict(report)
portable_report['log'] = 'tools/desktop_shell/evidence/verification.log'
(evidence / 'verification.log').write_text('\n'.join(logs), encoding='utf-8')
(evidence / 'result.json').write_text(json.dumps(portable_report, indent=2) + '\n', encoding='utf-8')
print('Verification evidence:', scratch / 'result.json')
print('Portable evidence:', evidence / 'result.json')
if passed:
    print(logs[-1], end='')
sys.exit(0 if passed else 1)

