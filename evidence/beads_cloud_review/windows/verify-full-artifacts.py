"""Independent artifact checks; adapted from the earlier dating-preferences verifier."""
from pathlib import Path, PureWindowsPath
import argparse
import hashlib
import json
import xml.etree.ElementTree as ET

parser = argparse.ArgumentParser()
parser.add_argument('root', type=Path)
parser.add_argument('head')
parser.add_argument('run_id', type=int)
parser.add_argument('--artifacts', required=True, type=Path,
                    help='Preserved GitHub workflow artifact response')
args = parser.parse_args()
root = args.root
normal_suites = {'desktop', 'localization', 'minesweeper', 'new_account',
                 'reading_delivery', 'settings', 'shop'}
refusal_scripts = {'res://tests/unit/test_minesweeper_shop_purchase_participant.gd',
                   'res://tests/unit/test_save_manager_checkpoint_port.gd'}


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def one(paths, label):
    found = list(paths)
    assert len(found) == 1, (label, found)
    return found[0]


def clean_log(path):
    data = path.read_bytes()
    assert b'\x00' not in data, ('NUL byte', str(path))
    text = data.decode('utf-8-sig')
    for marker in ('SCRIPT ERROR:', 'ERROR: Failed to load'):
        assert marker not in text, (marker, str(path))
    source_script, source_test, expected_count = '', '', 0
    for line in text.splitlines():
        if line.startswith('res://tests/'):
            source_script, source_test = line, ''
        if line.startswith('* test_'):
            source_test = line[2:]
        if 'Unicode parsing error' not in line and 'Unexpected NUL character' not in line:
            continue
        expected = (
            path.name == 'cloud-new_account.log' and expected_count == 0
            and source_script == 'res://tests/integration/test_prepared_new_run.gd'
            and source_test == 'test_prepare_counts_nonempty_unreadable_autosave_but_not_zero_bytes'
            and line == 'Unicode parsing error, some characters were replaced with � (U+FFFD): Invalid UTF-8 leading byte (ff)'
        )
        assert expected, ('unexpected Unicode/NUL diagnostic', str(path), source_script, source_test, line)
        expected_count += 1
    if path.name == 'cloud-new_account.log':
        assert expected_count == 1, ('missing deliberate corrupt-save diagnostic', str(path))
    return text


def execution(path, suite_id):
    rows = [json.loads(line) for line in path.read_text(encoding='utf-8-sig').splitlines() if line.strip()]
    assert len(rows) == 1, path
    row = rows[0]
    assert row['suite_id'] == suite_id and row['exit_code'] == 0, row
    assert '--headless' in row['argv'] and '--path' in row['argv'], row
    assert row['started_at_utc'] <= row['ended_at_utc'], row
    test_root = PureWindowsPath(row['test_root'])
    user_dir = PureWindowsPath(row['user_dir'])
    assert user_dir.is_relative_to(test_root), row
    return row


raw = read_json(args.artifacts)
if isinstance(raw, dict) and 'structuredContent' in raw:
    raw = raw['structuredContent']
if isinstance(raw, dict) and isinstance(raw.get('content'), str):
    raw = json.loads(raw['content'])
github_artifacts = raw['artifacts'] if isinstance(raw, dict) else raw
by_id = {artifact['id']: artifact for artifact in github_artifacts}
metadata = []
for path in sorted(root.glob('*-metadata.json')):
    item = read_json(path)
    artifact = by_id[item['id']]
    assert artifact['workflow_run']['id'] == args.run_id, artifact
    assert artifact['workflow_run']['head_sha'] == item['head'] == args.head, artifact
    assert not artifact['expired'], artifact
    archive = root / (item['name'] + '.zip')
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    assert artifact['digest'] == 'sha256:' + digest, item['name']
    assert digest == item['sha256'] == item['expected_sha256'], item['name']
    folder = root / item['name']
    files = sorted(str(p.relative_to(folder)) for p in folder.rglob('*') if p.is_file())
    assert files == sorted(item['files']), item['name']
    metadata.append({'name': item['name'], 'artifact_id': item['id'],
                     'github_name': artifact['name'], 'sha256': digest})
assert len(metadata) == 7, metadata
assert {item['github_name'].removeprefix('windows-').split('-' + str(args.run_id))[0]
        for item in metadata} == normal_suites, metadata

results = []
all_scripts = []
normal_xmls = []
for suite in sorted(normal_suites):
    path = one(root.rglob(suite + '.xml'), suite)
    normal_xmls.append(path)
    report = ET.parse(path).getroot()
    cases = report.findall('.//testcase')
    assert cases and int(report.attrib['tests']) == len(cases), path
    assert all(int(report.attrib.get(key, 0)) == 0 for key in ('failures', 'errors', 'skipped')), path
    assert not report.findall('.//failure') and not report.findall('.//error') and not report.findall('.//skipped'), path
    assert all(case.attrib.get('status') == 'pass' for case in cases), path
    row = execution(path.with_suffix('.jsonl'), 'cloud-' + suite)
    requested_argument = one((a for a in row['argv'] if a.startswith('-gtest=')), suite + ' argv')
    requested = requested_argument.removeprefix('-gtest=').split(',')
    executed = ['res://' + child.attrib['name'] for child in report.findall('testsuite')]
    assert len(set(requested)) == len(requested) and sorted(requested) == sorted(executed), suite
    assert PureWindowsPath(row['log_path']).name == 'cloud-' + suite + '.log', row
    one(path.parent.parent.rglob(PureWindowsPath(row['log_path']).name), suite + ' log')
    all_scripts.extend(requested)
    results.append({'suite': suite, 'tests': len(cases), 'scripts': len(requested),
                    'exit_code': row['exit_code'], 'report': str(path.relative_to(root))})
assert len(all_scripts) == len(set(all_scripts)) == 109, (len(all_scripts), len(set(all_scripts)))

refusal_root = one((p for p in root.rglob('storage-refusal') if p.is_dir()), 'storage refusals')
refusal_summary = read_json(refusal_root / 'results.json')
assert len(refusal_summary) == 2 and {row['case'] for row in refusal_summary} == {'empty', 'whitespace'}
refusals = []
for summary in refusal_summary:
    case_root = refusal_root / summary['case']
    path = case_root / 'tests.xml'
    report = ET.parse(path).getroot()
    cases = report.findall('.//testcase')
    failures = report.findall('.//failure')
    passes = [case for case in cases if not any(case.findall(tag) for tag in ('failure', 'error', 'skipped'))]
    assert len(cases) == int(report.attrib['tests']) == summary['tests'] == 78, path
    assert len(failures) == int(report.attrib['failures']) == summary['expected_root_refusals'] == 75, path
    assert len(passes) == summary['storage_free_passes'] == 3, path
    assert not report.findall('.//error') and not report.findall('.//skipped'), path
    assert all('test_root_missing' in ''.join(failure.itertext()) for failure in failures), path
    assert {'res://' + child.attrib['name'] for child in report.findall('testsuite')} == refusal_scripts, path
    assert summary['exit_code'] != 0, summary
    before, after = case_root / 'repository-before.json', case_root / 'repository-after.json'
    assert before.read_bytes() == after.read_bytes(), ('repository changed', summary['case'])
    proof = clean_log(case_root / 'user-dir-console.log')
    markers = [line.removeprefix('PHASE2R_USER_DIR=') for line in proof.splitlines()
               if line.startswith('PHASE2R_USER_DIR=')]
    assert len(markers) == 1 and PureWindowsPath(markers[0]) == PureWindowsPath(summary['user_dir']), summary
    parts = tuple(part.lower() for part in PureWindowsPath(summary['user_dir']).parts)
    expected = ('storage-refusal', summary['case'], 'appdata')
    assert any(parts[index:index + 3] == expected for index in range(len(parts) - 2)), summary
    refusals.append({'case': summary['case'], 'tests': len(cases),
                     'expected_root_refusals': len(failures), 'storage_free_passes': len(passes),
                     'exit_code': summary['exit_code'], 'repository_unchanged': True})
assert set(root.rglob('*.xml')) == set(normal_xmls + [refusal_root / case / 'tests.xml' for case in ('empty', 'whitespace')])

latency_path = one(root.rglob('new-account-latency.json'), 'latency')
latency = read_json(latency_path)
assert latency['ok'] and len(latency['samples']) == 2
assert {sample['case'] for sample in latency['samples']} == {'fresh', 'replacement'}
assert all(sample['button_to_desktop_us'] > 0 and sample['max_frame_gap_us'] >= 0 for sample in latency['samples'])
latency_row = execution(latency_path.with_suffix('.jsonl'), 'cloud-new-account-latency')
assert 'res://tests/integration/verify_new_acc_latency.gd' in latency_row['argv']
latency_log = clean_log(one(root.rglob('cloud-new-account-latency.log'), 'latency log'))
prefix = 'NEW_ACC_LATENCY_VERIFIED '
markers = [line[len(prefix):] for line in latency_log.splitlines() if line.startswith(prefix)]
assert len(markers) == 1 and json.loads(markers[0]) == latency
for path in root.rglob('*.log'):
    clean_log(path)

out = {'head_sha': args.head, 'run_id': args.run_id, 'suites': results,
       'tests': sum(row['tests'] for row in results), 'scripts': len(set(all_scripts)),
       'storage_refusal_checks': refusals, 'latency': latency, 'artifacts': metadata,
       'expected_corrupt_save_diagnostic': {'script': 'res://tests/integration/test_prepared_new_run.gd',
           'test': 'test_prepare_counts_nonempty_unreadable_autosave_but_not_zero_bytes',
           'leading_byte': 'ff', 'count': 1}, 'ok': True}
(root / 'verified-windows.json').write_text(json.dumps(out, indent=2) + '\n')
print(json.dumps(out, indent=2))
