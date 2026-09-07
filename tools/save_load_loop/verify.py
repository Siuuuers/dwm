"""Run the real project startup with a first, test-only observer autoload."""
from pathlib import Path
import difflib
import hashlib
import json
import os
import re
from collections import Counter
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[2]
RUNTIME_DIRS = (
    'addons', 'assets', 'autoload', 'data', 'dialogic', 'localization',
    'scenes', 'schemas', 'scripts', 'story', 'tests',
)
OBSERVER = 'tests/save_load_loop/Observe.gd'
CERTIFICATE_DIAGNOSTIC = 'ERROR: Failed to read the root certificate store.'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def allow_baseline_shutdown(output):
    baseline_log = ROOT / 'tools/save_load_loop/evidence/baseline/verification.log'
    if not baseline_log.is_file():
        return output, None
    reference = baseline_log.read_text(encoding='utf-8')
    warning = 'WARNING: ObjectDB instances leaked at exit (run with --verbose for details).'
    def signature(log):
        resources = sorted(re.findall(r'^Resource still in use: (.+)$', log, re.M))
        classes = dict(Counter(re.findall(r'^Leaked instance: ([^:]+):', log, re.M)))
        return resources, classes
    resources, classes = signature(reference)
    tail = reference[reference.rindex(warning):] if warning in reference else ''
    if len(resources) != 56 or not tail or signature(output) != (resources, classes) or not output.endswith(tail):
        return output, None
    return output[:-len(tail)], {
        'baseline_log': baseline_log.relative_to(ROOT).as_posix(),
        'baseline_log_sha256': digest(baseline_log),
        'resource_paths': resources,
        'leaked_instance_classes': classes,
        'exact_shutdown_tail': tail,
        'limitation': 'Only the identical observer-free baseline shutdown tail and resource/class counts are allowed; this does not prove leak-free shutdown.',
    }


def main(config=None):
    config = config or {}
    observer = config.get('observer', OBSERVER)
    scratch_prefix = config.get('name', 'save-load-loop') + '-'
    smoke = '--smoke' in sys.argv
    baseline = '--baseline' in sys.argv
    marker = 'SAVE_LOAD_STARTUP_PASS' if smoke else 'SAVE_LOAD_LOOP_PASS'
    if not (ROOT / observer).is_file():
        raise SystemExit('Observer must exist with its user-path guard before launch.')
    free_bytes = shutil.disk_usage(ROOT).free
    if free_bytes < 500 * 1024 * 1024:
        raise SystemExit('At least 500 MiB free disk space is required before copying/import; available: %d MiB.' % (free_bytes // 1024 // 1024))
    cache = ROOT / '.godot'
    cache.mkdir(exist_ok=True)
    scratch = Path(tempfile.mkdtemp(prefix=scratch_prefix, dir=cache)).resolve()
    project = scratch / 'project'
    project.mkdir()
    try:
        sources = {}
        for directory in RUNTIME_DIRS:
            for source in sorted((ROOT / directory).rglob('*')):
                if not source.is_file() or any(part in {'.godot', '.git', '__pycache__'} for part in source.parts):
                    continue
                if source.is_symlink():
                    raise RuntimeError('Runtime copy refuses symlink: ' + str(source))
                relative = source.relative_to(ROOT)
                target = project / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, target)
                sources[relative.as_posix()] = digest(target)
        for relative in ['project.godot', 'icon.svg', 'icon.svg.import']:
            source = ROOT / relative
            if source.is_file():
                shutil.copyfile(source, project / relative)
                sources[relative] = digest(project / relative)
        sources['tools/save_load_loop/verify.py'] = digest(Path(__file__))
        if config.get('runner'):
            sources[config['runner']] = digest(ROOT / config['runner'])
        original = (project / 'project.godot').read_text(encoding='utf-8-sig')
        insertion = 'SaveLoadLoopObserver="*res://' + observer + '"\n'
        if original.count('[autoload]\n') != 1 or 'SaveLoadLoopObserver=' in original:
            raise RuntimeError('Expected one unmodified production autoload section.')
        modified = original if baseline else original.replace('[autoload]\n', '[autoload]\n\n' + insertion, 1)
        # GUT's editor plugin performs a remote GitHub update check. It is not
        # needed for resource import; runtime below restores all original plugins.
        import_settings = modified.replace(', \"res://addons/gut/plugin.cfg\"', '')
        (project / 'project.godot').write_text(import_settings, encoding='utf-8', newline='\n')
        env = os.environ.copy()
        for key in ['APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP']:
            location = scratch / key.lower()
            location.mkdir()
            env[key] = str(location)
        env.pop('DWM_TEST_ROOT', None)
        expected_user_root = scratch / 'appdata/Godot/app_userdata/DWM'
        env['DWM_EXPECTED_USER_ROOT'] = str(expected_user_root)
        env['DWM_SAVE_LOAD_LOOP_ROOT'] = str(scratch)
        env['DWM_SAVE_LOAD_PHASE'] = 'baseline' if baseline else ('smoke' if smoke else 'loop')
        godot = env.get('GODOT_CONSOLE_PATH', r'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe')
        base = [godot, '--headless', '--rendering-method', 'gl_compatibility', '--path', str(project)]
        runtime_args = ['--verbose', '--quit-after', '8'] if baseline else ['--verbose']
        runtime_phases = config.get('runtime_phases', [('runtime', marker)])
        phases = [('import', ['--editor', '--import', '--quit'], None)] + [(name, runtime_args, expected) for name, expected in runtime_phases]
        logs = []
        inherited_shutdown = None
        import_project_changes = []
        executions = []
        passed = True
        for name, arguments, expected_marker in phases:
            if config and name != 'import':
                env['DWM_SAVE_LOAD_PHASE'] = name
            command = base + arguments + ['--', '--phase2r-bootstrap-mode=final']
            try:
                result = subprocess.run(command, env=env, cwd=project, capture_output=True,
                                        text=True, encoding='utf-8', errors='replace', timeout=180)
                output = result.stdout + result.stderr
                returncode = result.returncode
            except subprocess.TimeoutExpired as error:
                def decoded(value):
                    return value.decode('utf-8', errors='replace') if isinstance(value, bytes) else value or ''
                output = decoded(error.stdout) + decoded(error.stderr) + '\nRUNNER_TIMEOUT\n'
                returncode = None
            logs.append(output)
            (scratch / (name + '.log')).write_text(output, encoding='utf-8')
            checked = output.replace(CERTIFICATE_DIAGNOSTIC, '')
            if name != 'import' and not baseline:
                checked, inherited_shutdown = allow_baseline_shutdown(checked)
            phase_passed = returncode == 0 and 'ERROR:' not in checked and 'FAIL:' not in checked
            if expected_marker and not baseline:
                phase_passed = phase_passed and expected_marker in output.splitlines()
            executions.append({'phase': name, 'command': command, 'returncode': returncode, 'passed': phase_passed, 'project_sha256_after': digest(project / 'project.godot'), 'inherited_shutdown': inherited_shutdown})
            if not phase_passed:
                passed = False
                break
            if name == 'import':
                imported = (project / 'project.godot').read_text(encoding='utf-8-sig')
                import_project_changes = list(difflib.unified_diff(modified.splitlines(), imported.splitlines(), fromfile='runner/project.godot', tofile='editor-import/project.godot', lineterm=''))
                # Editor plugins may rewrite caches in project settings. Runtime must
                # use the requested production settings plus only our observer.
                (project / 'project.godot').write_text(modified, encoding='utf-8', newline='\n')
        summaries = []
        summary_prefix = config.get('summary_prefix', 'SAVE_LOAD_LOOP_SUMMARY ')
        for output in logs:
            for line in output.splitlines():
                if line.startswith(summary_prefix):
                    summaries.append(json.loads(line.removeprefix(summary_prefix)))
        combined = '\n'.join(logs)
        (scratch / 'verification.log').write_text(combined, encoding='utf-8')
        final_project = (project / 'project.godot').read_text(encoding='utf-8-sig')
        (scratch / 'project.original.godot').write_text(original, encoding='utf-8', newline='\n')
        (scratch / 'project.executed.godot').write_text(final_project, encoding='utf-8', newline='\n')
        report = {
            'passed': passed,
            'phase': config.get('name', env['DWM_SAVE_LOAD_PHASE']),
            'scope': config.get('scope') or ('Actual project startup without observer; eight-frame verbose shutdown baseline, isolated final mode. No save/load assertion coverage.' if baseline else 'Actual project main_scene, production autoloads and owners; one temporary observer autoload. Isolated final-mode startup and observer-defined save/load checks, headless GL compatibility; no GPU raster proof.'),
            'sources': sources,
            'project_copy_sha256': digest(project / 'project.godot'),
            'editor_import_changes_reverted_before_runtime': import_project_changes,
            'inherited_shutdown': inherited_shutdown,
            'runner_project_changes': list(difflib.unified_diff(original.splitlines(), modified.splitlines(), fromfile='original/project.godot', tofile='runner/project.godot', lineterm='')),
            'project_changes': list(difflib.unified_diff(original.splitlines(), final_project.splitlines(), fromfile='original/project.godot', tofile='temporary/project.godot', lineterm='')),
            'isolation': {'scratch': str(scratch), 'expected_user_root': str(expected_user_root),
                          'environment': {key: env[key] for key in ['APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP', 'DWM_EXPECTED_USER_ROOT', 'DWM_SAVE_LOAD_LOOP_ROOT', 'DWM_SAVE_LOAD_PHASE']},
                          'cleared_environment': ['DWM_TEST_ROOT'], 'bootstrap_mode': 'final'},
            'executions': executions,
            'summaries': summaries,
            'known_environment_diagnostic': CERTIFICATE_DIAGNOSTIC,
            'log': (scratch / 'verification.log').relative_to(ROOT).as_posix(),
        }
    finally:
        # Remove only this invocation's copied project and import cache, after Godot exits.
        # Keep isolated user files and the complete logs for transaction inspection.
        resolved_project = project.resolve()
        if scratch.parent != cache.resolve() or not scratch.name.startswith(scratch_prefix) or resolved_project != scratch / 'project':
            raise RuntimeError('Disposable-project containment check failed; refusing cleanup.')
        shutil.rmtree(resolved_project)
    report['copied_project_removed_after_run'] = True
    report['import_only_disabled_editor_plugin'] = 'res://addons/gut/plugin.cfg'
    (scratch / 'result.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    evidence = ROOT / config['evidence_dir'] if config.get('evidence_dir') else ROOT / 'tools/save_load_loop/evidence' / env['DWM_SAVE_LOAD_PHASE']
    evidence.mkdir(parents=True, exist_ok=True)
    portable = dict(report)
    portable['log'] = (evidence / 'verification.log').relative_to(ROOT).as_posix()
    shutil.copyfile(scratch / 'project.original.godot', evidence / 'project.original.godot')
    shutil.copyfile(scratch / 'project.executed.godot', evidence / 'project.executed.godot')
    (evidence / 'verification.log').write_text(combined, encoding='utf-8')
    (evidence / 'result.json').write_text(json.dumps(portable, indent=2) + '\n', encoding='utf-8')
    print('Verification evidence:', scratch / 'result.json')
    for line in logs[-1].splitlines():
        if line.startswith(('SAVE_LOAD_', 'TITLE_RESUME_', 'ERROR:', 'WARNING:', 'RUNNER_TIMEOUT')):
            print(line)
    return 0 if passed else 1


if __name__ == '__main__':
    sys.exit(main())
