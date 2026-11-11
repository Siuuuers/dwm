"""Run one authored save creator and two isolated fresh-process Load measurements."""
from pathlib import Path
import gzip
import hashlib
import json
import os
import re
import shutil
import subprocess
import time
import xml.etree.ElementTree as ET

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / '.godot/ci/checkpoint-load/results'
ISOLATED = REPO / '.godot/phase2r_tests/checkpoint-load'
PROBE = REPO / 'tests/manual/benchmark_checkpoint_load.gd'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def tree_hashes(root):
    return {str(p.relative_to(root)): digest(p) for p in sorted(root.rglob('*')) if p.is_file()}


def main():
    if OUT.exists() or ISOLATED.exists():
        raise SystemExit('Owned output/isolation already exists; preserve it before starting a new measurement.')
    OUT.mkdir(parents=True)
    (ISOLATED / 'data').mkdir(parents=True)
    (ISOLATED / 'test-root').mkdir()
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=REPO, text=True).strip()
    patch = subprocess.check_output(['git', 'diff', '--binary', 'HEAD', '--', '.'], cwd=REPO)
    (OUT / 'tracked-working-tree.patch').write_bytes(patch)
    env = dict(os.environ, XDG_DATA_HOME=str(ISOLATED / 'data'),
               DWM_TEST_ROOT=str(ISOLATED / 'test-root'), DWM_BENCHMARK_REVISION=revision,
               DWM_SAVE_LOAD_PROFILE='', DWM_SCENE_VALIDATION_PROFILE='')
    result = {
        'revision': revision,
        'tracked_patch_sha256': digest(OUT / 'tracked-working-tree.patch'),
        'tracked_working_tree_dirty': bool(patch),
        'probe_source': str(PROBE.relative_to(REPO)),
        'probe_sha256': digest(PROBE),
        'runner_sha256': digest(Path(__file__)),
        'engine': subprocess.check_output(['godot', '--version'], text=True).strip(),
        'environment': {k: env[k] for k in ['XDG_DATA_HOME', 'DWM_TEST_ROOT',
                                          'DWM_BENCHMARK_REVISION', 'DWM_SAVE_LOAD_PROFILE',
                                          'DWM_SCENE_VALIDATION_PROFILE']},
        'runs': [],
        'limits': [
            'Linux headless source project; no physical display or audio qualification.',
            'First Load is a fresh process after service and expected-content setup; OS cache is not cleared.',
            'Each loader performs Title first Load then three correlated in-game repeated Loads.',
            'Commit-dispatch timers exclude helper waits; action-to-usable includes a confirmation layout frame. Assertions follow timing.',
            'Expected checkpoint expansion is outside the timer; no numeric PID-inequality assertion.',
            'Whole-process duration includes startup/setup/assertions/teardown and is not Load latency.',
            'Same absolute user-data path and identical whole isolated seed bytes restored before each loader.'
        ],
    }

    def save_result():
        (OUT / 'result.json').write_text(json.dumps(result, indent=2) + '\n')

    def run(label, test, selector):
        log = OUT / (label + '.log')
        report = OUT / (label + '.xml')
        command = ['godot', '--headless', '--path', str(REPO), '-s',
                   'res://addons/gut/gut_cmdln.gd', '-gconfig=', '-gtest=' + test,
                   '-gunit_test_name=' + selector, '-gjunit_xml_file=' + str(report), '-gexit']
        row = {'label': label, 'command': command, 'log': str(log.relative_to(REPO)),
               'report': str(report.relative_to(REPO)), 'exit_code': None}
        result['runs'].append(row)
        save_result()
        started = time.monotonic()
        with log.open('w') as stream:
            process = subprocess.run(command, cwd=REPO, env=env, stdout=stream,
                                     stderr=subprocess.STDOUT, timeout=300)
        row['process_elapsed_ms'] = (time.monotonic() - started) * 1000
        row['exit_code'] = process.returncode
        row['log_sha256'] = digest(log)
        save_result()
        if process.returncode != 0:
            raise SystemExit(f'{label} exited {process.returncode}; inspect {log}')
        cases = ET.parse(report).getroot().findall('.//testcase')
        assert len(cases) == 1 and cases[0].get('name') == selector, [c.attrib for c in cases]
        assert cases[0].get('status') == 'pass' and int(cases[0].get('assertions', '0')) > 0, cases[0].attrib
        assert not any(cases[0].findall(tag) for tag in ('failure', 'error', 'skipped'))
        row['assertions'] = int(cases[0].get('assertions'))
        contents = log.read_text()
        assert not re.search(r'SCRIPT ERROR:|ERROR: Failed to load|Unicode parsing error', contents), str(log)
        row['loads'] = [json.loads(line.split('CHECKPOINT_LOAD_SAMPLE ', 1)[1]) for line in contents.splitlines() if line.startswith('CHECKPOINT_LOAD_SAMPLE ')]
        if label != 'creator':
            assert [x['index'] for x in row['loads']] == [0, 1, 2, 3], row['loads']
        (OUT / (label + '.log.gz')).write_bytes(gzip.compress(log.read_bytes(), mtime=0))
        save_result()
        print(label, 'exit', row['exit_code'], 'assertions', row['assertions'], 'loads', row['loads'], flush=True)

    run('creator', 'res://tests/integration/test_compact_history_create.gd',
        'test_save_then_add_later_library_discovery')
    proofs = list(ISOLATED.rglob('compact-history-proof.json'))
    assert len(proofs) == 1, proofs
    proof_path = proofs[0]
    proof = json.loads(proof_path.read_text())
    assert Path(proof['user_dir']).resolve() == proof_path.parent.resolve(), proof['user_dir']
    assert proof_path.parent.is_relative_to(ISOLATED)
    slot = proof_path.parent / 'saves/slot_1.json'
    assert slot.is_file() and digest(slot) == proof['slot_sha256']
    result['seed_user_dir'] = proof['user_dir']
    result['seed_proof_relative_path'] = str(proof_path.relative_to(ISOLATED))
    result['seed_slot_relative_path'] = str(slot.relative_to(ISOLATED))
    result['seed_slot_sha256'] = digest(slot)
    seed = OUT / 'seed-root'
    shutil.copytree(ISOLATED, seed)
    result['seed_hashes'] = tree_hashes(seed)
    save_result()
    for label in ('load-1', 'load-2'):
        shutil.rmtree(ISOLATED)
        shutil.copytree(seed, ISOLATED)
        assert tree_hashes(ISOLATED) == result['seed_hashes']
        run(label, 'res://tests/manual/benchmark_checkpoint_load.gd', 'test_checkpoint_load_cost')
    print('Evidence:', OUT / 'result.json', flush=True)


if __name__ == '__main__':
    main()
