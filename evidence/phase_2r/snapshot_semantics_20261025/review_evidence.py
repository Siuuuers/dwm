#!/usr/bin/env python3
"""Review six completed Windows qualification artifacts and preserve member bytes.

ZIP names: <artifact name>.zip, original-<id>.zip, or <id>.zip. Metadata accepts
GitHub's {"artifacts": [...]} response; optional local_path overrides each name.
Exactly one passing artifact per lane is required. Failed attempts and baseline
diagnostics are preserved separately; their cases are not accepted coverage.
Historical XML is preserved but excluded from current-case census. No network.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET
import zipfile

ENGINE = '63b3b2208819714c9677fbfdd8217c5b7dee8ecf5f383502e826bc9e2227ff5a'
LANES = {'focused', 'terminal', 'recall', 'inventory', 'baseline-first', 'candidate-first'}
RUNTIME_ROOTS = ['autoload', 'scripts', 'addons', 'scenes', 'assets', 'data', 'dialogic', 'localization', 'project.godot']
CI = 'candidate/.godot/ci/'

def sha(data):
    return hashlib.sha256(data).hexdigest()

def parse_json(data):
    return json.loads(data.decode('utf-8-sig'))

def census(data):
    tree = ET.fromstring(data)
    assert not tree.findall('.//failure') + tree.findall('.//error') + tree.findall('.//skipped'), 'XML failure/error/skip'
    cases = [{'name': c.get('name'), 'source': c.get('classname'), 'status': c.get('status'),
              'assertions': int(c.get('assertions', 0))} for c in tree.findall('.//testcase')]
    assert cases and all(c['status'] == 'pass' and c['assertions'] > 0 for c in cases)
    return cases

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('zip_directory', type=Path)
    p.add_argument('metadata', type=Path)
    p.add_argument('repository', type=Path)
    p.add_argument('output', type=Path)
    p.add_argument('--candidate', required=True)
    p.add_argument('--qualified-candidate', action='append', default=[], help='earlier qualified SHA with identical runtime, tests and tools')
    p.add_argument('--baseline', default='a7a9707dae17b648c09e70a139e1c37d4a7a4d37')
    p.add_argument('--runtime-path', action='append', default=None)
    args = p.parse_args()
    accepted_refs = {args.candidate, *args.qualified_candidate}
    for ref in [*accepted_refs, args.baseline]: assert re.fullmatch('[0-9a-f]{40}', ref)
    assert not args.output.exists(), 'fresh output directory required'
    runtime_paths = args.runtime_path or ['scripts/domain/run/RunSnapshotSchema.gd']
    def git(*argv):
        return subprocess.check_output(['git', '-C', str(args.repository), *argv])
    changes = git('diff', '--name-only', args.baseline, args.candidate, '--', *RUNTIME_ROOTS).decode().splitlines()
    assert sorted(changes) == sorted(runtime_paths), ('unexpected runtime changes', changes)
    for ref in accepted_refs:
        assert not git('diff', '--name-only', ref, args.candidate, '--', *RUNTIME_ROOTS, 'tests', 'tools'), ('qualified candidate differs', ref)
    git_hashes = {}
    def source_hash(ref, path):
        key = (ref, path)
        if key not in git_hashes: git_hashes[key] = sha(git('show', ref + ':' + path))
        return git_hashes[key]
    def verify_hashes(ref, hashes):
        assert hashes, 'missing source hashes'
        for path, digest in hashes.items(): assert source_hash(ref, path) == digest, ('source hash mismatch', ref, path)
    metadata_bytes = args.metadata.read_bytes()
    metadata = parse_json(metadata_bytes)
    entries = metadata['artifacts'] if isinstance(metadata, dict) else metadata
    manifest = {'format': 1, 'scope': 'Each unique uncompressed artifact-member byte sequence is retained under objects/<sha256>. Original ZIP container bytes are not retained; original hashes and member paths are recorded.', 'archives': []}
    objects, lanes, failed, diagnostics = {}, {}, [], []
    for entry in entries:
        options = [args.zip_directory / entry['local_path']] if entry.get('local_path') else [
            args.zip_directory / (entry['name'] + '.zip'), args.zip_directory / ('original-' + str(entry['id']) + '.zip'), args.zip_directory / (str(entry['id']) + '.zip')]
        present = list(dict.fromkeys(x.resolve() for x in options if x.is_file()))
        assert len(present) == 1, ('expected one local ZIP', entry['name'], options)
        path = present[0]
        data = path.read_bytes()
        assert len(data) == entry['size_in_bytes'], ('ZIP size mismatch', path)
        assert entry['digest'] == 'sha256:' + sha(data), ('ZIP digest mismatch', path)
        archive = {'name': path.name, 'artifact_id': entry['id'], 'run_id': entry['workflow_run']['id'],
                   'controller_ref': entry['workflow_run']['head_sha'], 'size_bytes': len(data), 'sha256': sha(data), 'members': []}
        members = {}
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            assert z.testzip() is None, ('CRC failure', path)
            for info in z.infolist():
                if info.is_dir(): continue
                assert info.filename not in members, ('duplicate member', info.filename)
                payload = z.read(info)
                digest = sha(payload)
                members[info.filename] = payload
                objects[digest] = payload
                archive['members'].append({'path': info.filename, 'size_bytes': len(payload), 'sha256': digest, 'object': 'objects/' + digest})
        print('Verified digest, size and CRC: ' + entry['name'], flush=True)
        qnames = [name for name in members if name.endswith('qualification.json')]
        manifest['archives'].append(archive)
        if not qnames:
            result_names = [n for n in members if n.endswith('/fresh-save-load/result.json')]
            assert len(result_names) == 1, ('unrecognized diagnostic artifact', entry['name'])
            native = parse_json(members[result_names[0]])
            assert native['write']['complete'] and native['load']['complete']
            base = result_names[0].rsplit('/', 1)[0] + '/'
            records = [{'path': base + phase + '.xml', 'cases': census(members[base + phase + '.xml'])} for phase in ['write', 'load']]
            assert all(len(r['cases']) == 1 and r['cases'][0]['assertions'] == native['assertions'][phase] for r, phase in zip(records, ['write', 'load']))
            diagnostics.append({'artifact': entry['name'], 'source_ref': native['source_ref'], 'current_cases': records,
                                'excluded_xml': [n for n in members if n.endswith('.xml') and n not in [r['path'] for r in records]],
                                'scope': 'Separate instrumented diagnostic; not candidate qualification or matched performance evidence.'})
            continue
        assert len(qnames) == 1, ('qualification file count', entry['name'])
        q = parse_json(members[qnames[0]])
        lane = q['lane']
        assert lane in LANES, ('unknown lane', lane)
        assert q['candidate_ref'] in accepted_refs and q['baseline_ref'] == args.baseline
        assert q['controller_ref'] == archive['controller_ref'] and q['engine_sha256'] == ENGINE
        assert sorted(q['runtime_changed_files']) == sorted(runtime_paths)
        verify_hashes(args.candidate, q['source_hashes'])
        verify_hashes(q['candidate_ref'], q['source_hashes'])
        if q['status'] != 'passed_requires_evidence_review':
            failed.append({'artifact': entry['name'], 'lane': lane, 'status': q['status'], 'error': q.get('error'),
                           'candidate_ref': q['candidate_ref'], 'controller_ref': q['controller_ref']})
            continue
        assert lane not in lanes, ('duplicate passing lane', lane)
        lanes[lane] = {'qualification': q, 'members': members}
    assert set(lanes) == LANES, ('missing lanes', LANES - set(lanes))
    current, excluded, comparisons, all_ready, input_contracts, images = {}, [], {}, [], [], []
    summaries = {}
    def verify_png(lane, path, payload):
        from PIL import Image
        with Image.open(io.BytesIO(payload)) as image:
            assert image.format == 'PNG' and image.width > 0 and image.height > 0
            size = [image.width, image.height]
            image.verify()
        images.append({'path': lane + '/' + path, 'size': size, 'sha256': sha(payload)})
    for lane, record in lanes.items():
        q, members = record['qualification'], record['members']
        selected = []
        if lane == 'focused':
            assert len(q['suites']) > 0
            for suite in q['suites']:
                path = CI + 'load-' + Path(suite['file']).stem + '.xml'
                cases = census(members[path])
                assert suite['status'] == 'passed' and suite['exit_code'] == 0
                assert len(cases) == suite['expected_tests'] == suite['actual_tests']
                assert sum(c['assertions'] for c in cases) == suite['assertions']
                assert all(c['source'] == suite['file'] for c in cases)
                selected.append(path)
        elif lane == 'terminal':
            selected = [CI + 'terminal_admission.xml']
            cases = census(members[selected[0]])
            assert len(cases) == 1 and cases[0]['name'] == 'test_selected_terminal_admission_rechecks_genuine_saved_authority'
            assert cases[0]['source'] == 'tests/integration/authored_terminal_admission_checks.gd'
        elif lane == 'recall':
            selected = [CI + 'recall-create.xml', CI + 'recall-load.xml']
            assert len(q['suites']) == 2
            for path, suite in zip(selected, q['suites']):
                cases = census(members[path])
                assert suite['status'] == 'passed' and suite['exit_code'] == 0
                assert len(cases) == 1 and cases[0]['source'] == suite['file'] and cases[0]['assertions'] == suite['assertions']
            processes = q['recall_processes']
            assert len(processes) == 2 and all(r['exit_code'] == 0 for r in processes)
            assert processes[0]['test_root'] == processes[1]['test_root'] and processes[0]['user_dir'] == processes[1]['user_dir']
            assert len(q['recall_screenshots']) == 3
            for name, digest in q['recall_screenshots'].items():
                assert sha(members[CI + name]) == digest
                verify_png(lane, CI + name, members[CI + name])
        elif lane == 'inventory':
            assert q['inventory_mode'] == 'read_only_committed_verification'
            for name in ['game_state_surface.json', 'save_manager_surface.json']:
                assert members[name] == git('show', args.candidate + ':evidence/phase_2r/runtime/' + name), ('inventory differs', name)
        else:
            cpath = CI + 'fresh-save-load-comparison/comparison.json'
            c = parse_json(members[cpath])
            assert c == q['comparison'] and c['complete'] and not c['error']
            assert c['base_ref'] == args.baseline and c['candidate_ref'] == q['candidate_ref'] and c['engine_sha256'] == ENGINE
            expected_order = ['baseline', 'candidate'] if lane == 'baseline-first' else ['candidate', 'baseline']
            assert c['order'] == expected_order and [v['variant'] for v in c['variants']] == expected_order
            assert sorted(c['runtime_files']) == sorted(runtime_paths)
            for ref in [args.baseline, q['candidate_ref']]: verify_hashes(ref, c['measurement_sha256'])
            operations = {}
            for v in c['variants']:
                ref = args.baseline if v['variant'] == 'baseline' else q['candidate_ref']
                assert v['complete'] and not v['error'] and v['source_ref'] == ref
                verify_hashes(ref, v['runtime_sha256'])
                result = v['result']
                assert result['source_ref'] == ref
                verify_hashes(ref, result['runtime_sha256'])
                base = CI + 'fresh-save-load-comparison/' + v['variant'] + '/'
                assert result == parse_json(members[base + 'result.json'])
                write, load = result['write'], result['load']
                assert write['complete'] and load['complete'] and write['pending_phase'] == load['pending_phase'] == ''
                assert load['creator_process_id'] == write['process_id'] != load['process_id'] and load['recovery_journal_count'] == 0
                assert all(x['ok'] for x in write['phases'] + load['phases'])
                proof = parse_json(members[base + 'authored-week-terminal-pair.json'])
                assert load['source_slot_sha256'] == proof['slot_sha256'] == sha(members[base + 'slot_3.json'])
                assert load['ready_native'] == proof['saved_native']
                all_ready.append(load['ready_native'])
                contract = {k: result[k] for k in ['archive_sha256', 'helper_sha256', 'fresh_helper_sha256', 'runner_sha256']}
                contract['retained_slot_sha256'] = write['source_slot_sha256']
                input_contracts.append(contract)
                for name in ['computer-authored-restored-slot-2.png', 'computer-authored-terminal-pair.png', 'computer-authored-restored-slot-3.png']:
                    verify_png(lane, base + name, members[base + name])
                def ui(kind):
                    rows = [r for r in write['ui_timings'] if r['operation'] == kind]
                    assert len(rows) == 1 and rows[0].get('ok', True)
                    if kind == 'save_action_press_return':
                        assert rows[0]['save_result_ok_at_return'] and not rows[0]['save_in_operation_at_return']
                    return rows[0]['elapsed_us'] / 1e6
                operations[v['variant']] = {'save_press_return_s': ui('save_action_press_return'),
                    'retained_load_ready_s': ui('load_action_to_ready'), 'fresh_load_ready_s': load['load_action_to_ready_us'] / 1e6}
                assert all(t > 0 for t in operations[v['variant']].values())
                for phase in ['write', 'load']:
                    path = base + phase + '.xml'
                    cases = census(members[path])
                    expected = 'test_genuine_ending_load_save' if phase == 'write' else 'test_fresh_current_save_load'
                    assert len(cases) == 1 and cases[0]['name'] == expected and cases[0]['assertions'] == result['assertions'][phase]
                    selected.append(path)
            comparisons[lane] = {'order': expected_order, 'operations': operations,
                'change_percent': {k: 100 * (operations['candidate'][k] / b - 1) for k, b in operations['baseline'].items()}}
        current[lane] = [{'path': lane + '/' + path, 'cases': census(members[path])} for path in selected]
        excluded += [lane + '/' + path for path in members if path.endswith('.xml') and path not in selected]
        summaries[lane] = {'cases': sum(len(x['cases']) for x in current[lane]),
            'case_assertions': sum(c['assertions'] for x in current[lane] for c in x['cases'])}
    assert len(all_ready) == 4 and all(r == all_ready[0] for r in all_ready)
    assert all(c == input_contracts[0] for c in input_contracts)
    ready = all_ready[0]
    assert ready['visible'] and ready['event_done'] and not ready['revealing'] and ready['visible_ratio'] == 1
    result = {'stage': 'Mechanical review passed; screenshots still require visual review', 'candidate_ref': args.candidate,
        'qualified_candidate_refs': sorted(accepted_refs), 'failed_attempts_excluded': failed, 'diagnostics_separate': diagnostics,
        'baseline_ref': args.baseline, 'engine_sha256': ENGINE, 'source_hashes': lanes['focused']['qualification']['source_hashes'],
        'qualifications': {k: {key: v['qualification'][key] for key in ['status', 'lane', 'candidate_ref', 'baseline_ref', 'controller_ref', 'inventory_mode']} for k, v in lanes.items()},
        'current_xml_summary': summaries, 'excluded_historical_xml': excluded, 'comparisons': comparisons,
        'ready_native': ready, 'all_four_ready_payloads_equal': True,
        'png_integrity_verified_visual_review_pending': images,
        'accepted_current_product_coverage': {key: sum(summaries[l][key] for l in ['focused', 'terminal', 'recall']) for key in ['cases', 'case_assertions']},
        'matched_comparison_execution_coverage': {key: sum(summaries[l][key] for l in ['baseline-first', 'candidate-first']) for key in ['cases', 'case_assertions']},
        'limits': 'Two ordered pairs are not a latency distribution. Windows source project/software rendering, not installed Steam. Only current XML counted; preserved historical fixture XML excluded. No visual judgment is claimed.'}
    args.output.mkdir(parents=True)
    with zipfile.ZipFile(args.output / 'exact-evidence.zip', 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for digest, data in sorted(objects.items()): z.writestr('objects/' + digest, data)
    (args.output / 'original-artifacts.json').write_bytes(metadata_bytes)
    for name, data in [('manifest.json', manifest), ('results.json', result), ('current-case-census.json', current)]:
        (args.output / name).write_text(json.dumps(data, indent=2) + '\n')
    print(json.dumps({'output': str(args.output), 'archives': len(manifest['archives']), 'unique_objects': len(objects),
        'current': result['accepted_current_product_coverage'], 'comparisons': comparisons}, indent=2))

if __name__ == '__main__':
    main()
