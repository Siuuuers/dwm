"""Real Label/font/timer check with deterministic clock reads and isolated user roots."""
from pathlib import Path
import hashlib, json, os, shutil, subprocess, tempfile

root = Path(__file__).resolve().parents[2]
scratch = Path(tempfile.mkdtemp(prefix='routine-clock-', dir=root / '.godot'))
sources = ['scripts/ui/desktop/RoutineClock.gd', 'tests/routine_clock/test_routine_clock.gd',
           'assets/ui/contacts/fonts/source-sans-3-regular.ttf.woff2']
for relative in sources:
    target = scratch / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / relative, target)
(scratch / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="RoutineClockTests"\n', encoding='utf-8')
env = os.environ.copy()
for key in ['APPDATA', 'LOCALAPPDATA']:
    target = scratch / key.lower()
    target.mkdir()
    env[key] = str(target)
godot = env.get('GODOT_CONSOLE_PATH', r'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe')
logs, passed = [], True
for args in [['--editor', '--import', '--quit'], ['--script', 'res://tests/routine_clock/test_routine_clock.gd']]:
    result = subprocess.run([godot, '--headless', '--path', str(scratch), *args], env=env,
                            capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=45)
    output = result.stdout + result.stderr
    logs.append(output)
    checked = output.replace('ERROR: Failed to read the root certificate store.', '')
    if result.returncode or 'ERROR:' in checked:
        passed = False
        break
passed = passed and 'ROUTINE_CLOCK_PASS' in logs[-1]
(scratch / 'verification.log').write_text('\n'.join(logs), encoding='utf-8')
(scratch / 'result.json').write_text(json.dumps({'passed': passed,
    'scope': 'Actual RoutineClock Label, one-shot Timer, Source Sans font; injected deterministic time reader, no autoloads or player storage.',
    'known_diagnostic': 'Windows certificate-store failure is allowed and retained.',
    'sources': {p: hashlib.sha256((scratch / p).read_bytes()).hexdigest() for p in sources}}, indent=2) + '\n', encoding='utf-8')
print(logs[-1])
print('Evidence:', scratch / 'result.json')
raise SystemExit(0 if passed else 1)
