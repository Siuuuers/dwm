#!/usr/bin/env python3
"""Join the broad paused Settings Quick acceptance; read-only and fail-closed.

This executes no engine or PowerShell. Independent component receipts remain
required, and their raw source, metadata, artifact and capture bindings are checked.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import zipfile

BASELINE = '5a581fc89121864aead5202e01d6a82423b1b52d'
CHANGE_BASE = BASELINE
EXPECTED_COUNTS = {'case_executions': 2286, 'unique_cases': 2282, 'unique_scripts': 194,
                   'script_executions': 195, 'xml_count': 13}
SETTINGS_CASES = {
    'test_paused_settings_quick_save_keeps_host_focus_and_exact_canonical_source',
    'test_paused_settings_quick_load_remains_unavailable_and_cannot_wake_on_exit',
    'test_paused_settings_reset_window_forwards_contacts_without_saving_or_queued_replay',
    'test_paused_settings_binding_capture_never_saves_and_requires_fresh_release',
    'test_paused_settings_pending_preference_commit_retires_save_until_release',
    'test_paused_settings_option_popup_forwards_release_and_retires_same_frame_save',
}
POST = 'dating.solo.priscilla.day1.post_challenge'
CAPTURES = ('01-title.png', '02-desktop.png', '03-minesweeper.png', '04-pre-history.png',
            '05-dating-board.png', '06-post-history.png', '07-post-save.png',
            '08-restored-history.png', '09-restored-line.png')


def strict_json(raw):
    def pairs(items):
        value = {}
        for key, item in items:
            assert key not in value, 'duplicate JSON key: ' + key
            value[key] = item
        return value
    def invalid(value):
        raise ValueError('non-finite JSON number: ' + value)
    return json.loads(raw, object_pairs_hook=pairs, parse_constant=invalid)


def file_identity(path):
    raw = path.read_bytes()
    return {'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}


class Evidence:
    def __init__(self, root):
        self.root = root.resolve()

    def path(self, name):
        path = PurePosixPath(name)
        assert not path.is_absolute() and '..' not in path.parts and '\\' not in name and ':' not in name
        resolved = (self.root / path).resolve()
        assert resolved.is_relative_to(self.root)
        return resolved

    def read(self, name):
        return strict_json(self.path(name).read_text(encoding='utf-8-sig'))

    def identity(self, name):
        return {'file': name, **file_identity(self.path(name))}

    def verify(self, record):
        assert {'file', 'sha256', 'bytes'} <= set(record)
        current = self.identity(record['file'])
        assert all(record[key] == current[key] for key in ('bytes', 'sha256'))

    def verify_legacy_hash_record(self, record):
        """The retained non-GUT join emitted file/hash, with no byte count."""
        assert {'file', 'sha256'} <= set(record)
        current = self.identity(record['file'])
        assert record['sha256'] == current['sha256']
        if 'bytes' in record:
            assert record['bytes'] == current['bytes']


def physical_binding(evidence, run, source, checkout, repo, auditor):
    """Bind the new independent receipt to this exact broad run and its raw bytes."""
    physical = evidence.read('audit/physical-selector-journey-audit.json')
    assert physical['audit_complete'] is True and physical['runtime_proof_failures'] == []
    assert physical['run_id'] == run['id'] and physical['run_attempt'] == run['run_attempt']
    assert physical['source'] == source and physical['checkout'] == checkout
    assert physical['auditor_identity'] == file_identity(auditor)
    assert set(physical['metadata_identities']) == {'run.json', 'jobs.json', 'artifacts-api.json', 'artifact-manifest.json'}
    for name, expected in physical['metadata_identities'].items():
        evidence.verify({'file': name, **expected})
    assert physical['caption_count'] == physical['canonical_witness_hashes'] == 4
    assert physical['trace_entries'] == 12 and physical['traversed_captions'] == 0
    assert physical['source_pre_publication_baseline'] is physical['destination_pre_publication_baseline'] is False
    assert physical['restored_speech_admissions'] == 0 and physical['independent_run_frame_forgery_refused'] is True
    assert set(physical['process_ids']) == {'write', 'read'} and len(set(physical['process_ids'].values())) == 2
    assert physical['selected_labels'][POST] in {'fixture.selector.post.sweet.exploded.' + outcome
                                                for outcome in ('hatred', 'upset', 'amused')}
    for path, expected in physical['source_files'].items():
        source_bytes = subprocess.check_output(['git', '-C', str(repo), 'show', source + ':' + path])
        checkout_bytes = subprocess.check_output(['git', '-C', str(repo), 'show', checkout + ':' + path])
        assert source_bytes == checkout_bytes
        assert expected == {'bytes': len(source_bytes), 'sha256': hashlib.sha256(source_bytes).hexdigest()}
    required_sources = {'tools/testing/run_solo_authored_selector_journey.py',
                        'tests/integration/verify_solo_authored_selector_journey.gd',
                        'tests/fixtures/dialogic/solo_authored_selector_catalogue.json',
                        'tests/fixtures/dialogic/solo_authored_selector.dtl', 'tools/testing/run_cloud_journeys.py',
                        'scripts/narrative/ReadingTraversalOperation.gd', 'scripts/validation/CanonicalJsonWriter.gd'}
    assert set(physical['source_files']) == required_sources
    artifact = physical['artifact_identity']
    assert artifact['workflow_head'] == run['head_sha']
    assert 0 < artifact['attempt'] <= run['run_attempt']
    assert artifact['name'] == f"solo-authored-selector-{run['id']}-{artifact['attempt']}"
    api = [row for row in evidence.read('artifacts-api.json')['artifacts'] if row['id'] == artifact['id']]
    manifest = [row for row in evidence.read('artifact-manifest.json') if row['id'] == artifact['id']]
    assert len(api) == len(manifest) == 1
    api, manifest = api[0], manifest[0]
    assert api['name'] == manifest['name'] == artifact['name']
    assert api['workflow_run']['id'] == run['id'] and api['workflow_run']['head_sha'] == run['head_sha']
    assert artifact['zip_identity'] == {'bytes': api['size_in_bytes'], 'sha256': api['digest'].removeprefix('sha256:')}
    archive_path = Path(manifest['local_zip'])
    assert file_identity(archive_path) == artifact['zip_identity']
    top_name = 'artifacts/' + artifact['name']
    top = evidence.path(top_name)
    with zipfile.ZipFile(archive_path) as archive:
        members = [row for row in archive.infolist() if not row.is_dir()]
        names = {row.filename for row in members}
        assert len(names) == len(members) == artifact['verified_members']
        assert names == {path.relative_to(top).as_posix() for path in top.rglob('*') if path.is_file()}
        for member in members:
            path = evidence.path(top_name + '/' + member.filename)
            assert not path.is_symlink()
            raw = archive.read(member)
            assert file_identity(path) == {'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}
    result = evidence.read(top_name + '/result.json')
    assert result['ok'] is True and result['failures'] == [] and result['checkout_sha'] == checkout
    assert physical['report_identity'] == file_identity(top / 'result.json')
    sub_name = top_name + '/' + PurePosixPath(result['artifact_root']).name
    assert evidence.read(sub_name + '/result.json') == result
    bindings = []
    def bind(name, expected):
        relative = sub_name + '/' + name
        evidence.verify({'file': relative, **expected})
        bindings.append(evidence.identity(relative))
    assert set(physical['process_receipt_identities']) == {'write', 'read', 'user-dir-proof'}
    for mode, expected in physical['process_receipt_identities'].items():
        bind(mode + '.process.json', expected)
        assert evidence.read(sub_name + '/' + mode + '.process.json') == result['processes'][mode]
        assert result['processes'][mode]['exit_code'] == 0 and result['processes'][mode]['timed_out'] is False
    for mode in ('write', 'read'):
        report = evidence.read(sub_name + '/' + mode + '.json')
        assert report == result['reports'][mode] and report['process_id'] == physical['process_ids'][mode]
        bindings.append(evidence.identity(sub_name + '/' + mode + '.json'))
    bind('transactions.jsonl', physical['trace_identity'])
    bind('write-seal.json', physical['writer_seal_identity'])
    for name, expected in physical['retained_files'].items():
        bind(name, expected)
    assert set(physical['retained_files']) == {'saved-quick.json', 'saved-profile.json',
        'saved-next-source.json', 'saved-next-destination.json', 'read-before-quick.json',
        'read-after-quick.json', 'read-before-profile.json', 'read-after-profile.json'}
    for stem in ('quick', 'profile'):
        original = evidence.path(sub_name + '/saved-' + stem + '.json').read_bytes()
        assert all(evidence.path(sub_name + '/read-' + phase + '-' + stem + '.json').read_bytes() == original
                   for phase in ('before', 'after'))
    for endpoint in physical['next_endpoints']:
        phase = endpoint['phase']
        assert phase in ('source', 'destination')
        raw = physical['retained_files']['saved-next-' + phase + '.json']
        assert all(endpoint[key] == raw[key] for key in ('bytes', 'sha256'))
        snapshot = evidence.read(sub_name + '/saved-next-' + phase + '.json')['current_snapshot']['snapshot']
        assert snapshot['checkpoint_id'] == endpoint['checkpoint_id']
        operation = snapshot['narrative_checkpoint']['reading_session']['next_operation']
        assert operation['phase'] == phase and operation['operation_id'] == physical['operation_id']
    assert [row['phase'] for row in physical['next_endpoints']] == ['source', 'destination']
    job = physical['job']
    assert job['checkout_shas'] and set(job['checkout_shas']) == {checkout}
    evidence.verify({'file': job['log'], **job['log_identity']})
    jobs = evidence.read('jobs.json')['jobs']
    for job_id in (job['job_id'], job['execution_job_id']):
        found = [row for row in jobs if row['id'] == job_id]
        assert len(found) == 1 and found[0]['name'] == job['name']
        assert found[0]['status'] == 'completed' and found[0]['conclusion'] == 'success'
    assert str(result['workflow']['GITHUB_RUN_ID']) == str(run['id'])
    assert result['workflow']['GITHUB_JOB'] == job['github_job']
    assert result['workflow']['GITHUB_SHA'] == (checkout if run['event'] == 'pull_request' else run['head_sha'])
    assert len(physical['captures']) == 9 and [row['file'] for row in physical['captures']] == list(CAPTURES)
    for capture in physical['captures']:
        assert capture['width'] == 1280 and capture['height'] == 720
        bind('captures/' + capture['file'], {key: capture[key] for key in ('bytes', 'sha256')})
    # This increment preserves physical semantic/byte proof, not a new nine-image
    # visual acceptance. The separately joined layout audit owns two title PNGs.
    return physical, {}, bindings



def settings_binding(evidence, run, source, checkout, repo, auditor):
    """Join the independent two-process receipt to unchanged raw archive bytes."""
    audit = evidence.read('audit/settings-quick-journey-audit.json')
    assert audit['audit_complete'] is True and audit['runtime_proof_failures'] == audit['pending_areas'] == []
    assert audit['run_id'] == run['id'] and audit['run_attempt'] == run['run_attempt']
    assert audit['source'] == source and audit['checkout'] == checkout
    assert audit['auditor_identity'] == file_identity(auditor)
    assert audit['generic_audit_binding']['file'] == 'audit/generic-evidence-audit.json'
    evidence.verify(audit['generic_audit_binding'])
    assert set(audit['metadata_identities']) == {'run.json', 'jobs.json', 'artifacts-api.json', 'artifact-manifest.json'}
    for name, expected in audit['metadata_identities'].items():
        evidence.verify({'file': name, **expected})
    required_sources = {'tools/testing/run_reading_rail_journey.py', 'tests/integration/verify_reading_rail_journey.gd',
                        'scripts/ui/pause/PauseSurface.gd', 'scripts/ui/pause/PauseQuickCommands.gd',
                        'scripts/ui/SettingsContent.gd', 'scripts/ui/SettingsResetConfirmation.gd'}
    assert required_sources <= set(audit['source_files'])
    for path, expected in audit['source_files'].items():
        raw = subprocess.check_output(['git', '-C', str(repo), 'show', source + ':' + path])
        assert raw == subprocess.check_output(['git', '-C', str(repo), 'show', checkout + ':' + path])
        assert expected == {'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}
    artifact = audit['artifact_identity']
    assert artifact['workflow_head'] == run['head_sha'] and artifact['attempt'] == run['run_attempt']
    assert artifact['name'] == f"reading-rail-{run['id']}-{run['run_attempt']}"
    api = [item for item in evidence.read('artifacts-api.json')['artifacts'] if item['id'] == artifact['id']]
    manifest = [item for item in evidence.read('artifact-manifest.json') if item['id'] == artifact['id']]
    assert len(api) == len(manifest) == 1
    api, manifest = api[0], manifest[0]
    assert api['name'] == manifest['name'] == artifact['name']
    assert api['workflow_run']['id'] == run['id'] and api['workflow_run']['head_sha'] == run['head_sha']
    assert artifact['zip_identity'] == {'bytes': api['size_in_bytes'], 'sha256': api['digest'].removeprefix('sha256:')}
    archive_path = Path(manifest['local_zip'])
    assert file_identity(archive_path) == artifact['zip_identity']
    top_name = 'artifacts/' + artifact['name']
    top = evidence.path(top_name)
    with zipfile.ZipFile(archive_path) as archive:
        members = [item for item in archive.infolist() if not item.is_dir()]
        names = {item.filename for item in members}
        assert len(names) == len(members) == artifact['verified_members']
        assert names == {path.relative_to(top).as_posix() for path in top.rglob('*') if path.is_file()}
        for member in members:
            path = evidence.path(top_name + '/' + member.filename)
            assert not path.is_symlink()
            raw = archive.read(member)
            assert file_identity(path) == {'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}
    parent = evidence.read(top_name + '/result.json')
    assert audit['parent_report_identity'] == file_identity(top / 'result.json')
    assert parent['ok'] is True and parent['failures'] == [] and parent['checkout_sha'] == checkout
    parent_name = top_name + '/' + PurePosixPath(parent['artifact_root']).name
    assert evidence.read(parent_name + '/result.json') == parent
    nested = parent['settings_quick_save']
    folder_name = parent_name + '/settings-quick'
    assert nested == evidence.read(folder_name + '/result.json')
    assert audit['supplemental_report_identity'] == file_identity(evidence.path(folder_name + '/result.json'))
    assert nested['ok'] is True and nested['failures'] == [] and nested['checkout_sha'] == checkout
    assert nested['workflow'] == parent['workflow']
    assert nested['validation'] == {'retained_quick': audit['raw_quick_identity'], 'physical_quick_candidates': 1,
        'partial_reveal_retained_until_f5': True, 'settings_and_focus_retained': True,
        'only_quick_family_mutated': True, 'fresh_restore_speech_admissions': 0,
        'profile_and_autosave_unchanged': True}
    assert PurePosixPath(nested['artifact_root']) == PurePosixPath(parent['artifact_root']) / 'settings-quick'
    first, second = (PurePosixPath(value['isolation_root']) for value in (parent, nested))
    assert not first.is_relative_to(second) and not second.is_relative_to(first)
    assert nested['user_dir'] != parent['user_dir']
    assert audit['isolation'] == {'original': str(first), 'settings': str(second),
                                  'settings_user_dir': nested['user_dir'], 'disjoint_profiles_verified': True}
    modes = {'settings-write', 'settings-read'}
    assert set(nested['reports']) == set(audit['process_ids']) == modes
    assert len(set(audit['process_ids'].values())) == 2
    assert set(nested['processes']) == set(audit['process_receipt_identities']) == modes | {'user-dir-proof'}
    bindings = []
    def bind(relative, expected):
        evidence.verify({'file': relative, **expected})
        bindings.append(evidence.identity(relative))
    for mode, expected in audit['process_receipt_identities'].items():
        bind(folder_name + '/' + mode + '.process.json', expected)
        process = evidence.read(folder_name + '/' + mode + '.process.json')
        assert process == nested['processes'][mode] and process['exit_code'] == 0 and process['timed_out'] is False
        logs = audit['process_log_identities'][mode]
        assert set(logs) == {mode + '.log', mode + '.stdout.txt', mode + '.stderr.txt'}
        for name, identity in logs.items():
            bind(folder_name + '/' + name, identity)
    for mode in modes:
        report = evidence.read(folder_name + '/' + mode + '.json')
        assert report == nested['reports'][mode] and report['process_id'] == audit['process_ids'][mode]
        bindings.append(evidence.identity(folder_name + '/' + mode + '.json'))
    assert audit['original_process_ids'] == {name: value['process_id'] for name, value in parent['reports'].items()}
    for original, dirname, filename, key, count, names in (
        (True, parent_name, 'write-read-seal.json', 'original_write_read_seal', 14,
         {'write.json', 'read.json', 'saved-quick.json', 'saved-pause-slot.json', 'transactions.jsonl', *CAPTURES}),
        (False, folder_name, 'settings-write-seal.json', 'settings_write_seal', 3,
         {'settings-write.json', 'saved-settings-quick.json', 'transactions.jsonl'}),
    ):
        receipt = audit[key]
        assert receipt['file_count'] == count and receipt['all_sealed_and_retained_bytes_verified'] is True
        assert receipt['sealed_after_mode'] == ('read' if original else 'settings-write')
        assert receipt['before_mode'] == ('repeat' if original else 'settings-read')
        bind(dirname + '/' + filename, receipt['identity'])
        seal = evidence.read(dirname + '/' + filename)
        result = parent if original else nested
        assert seal == result['write_read_seal' if original else 'write_seal']
        assert result['write_read_seal_verified' if original else 'write_seal_verified'] is True
        assert set(seal['files']) == names
        sealed_name = dirname + '/' + ('sealed-write-read' if original else 'sealed-settings-write')
        for name, identity in seal['files'].items():
            bind(sealed_name + '/' + name, identity)
            retained = dirname + '/' + ('captures/' if name in CAPTURES else '') + name
            if name == 'transactions.jsonl':
                assert evidence.path(retained).read_bytes().startswith(evidence.path(sealed_name + '/' + name).read_bytes())
            else:
                bind(retained, identity)
    bind(folder_name + '/saved-settings-quick.json', audit['raw_quick_identity'])
    bind(folder_name + '/transactions.jsonl', audit['trace_identity'])
    assert audit['trace_entries'] == 7
    assertions = {'partial_reveal_preserved_until_f5', 'only_current_reveal_completed',
                  'exact_settings_host_focus_and_suspension_retained', 'exact_canonical_source_preserved',
                  'single_quick_transaction_verified', 'autosave_profile_identity_receipts_unchanged',
                  'fresh_restore_exact_and_silent', 'original_eight_modes_and_seal_unchanged'}
    assert set(audit['semantic_assertions']) == assertions and all(value is True for value in audit['semantic_assertions'].values())
    job = audit['job']
    assert job['checkout_shas'] and set(job['checkout_shas']) == {checkout}
    bind(job['log'], job['log_identity'])
    jobs = [item for item in evidence.read('jobs.json')['jobs'] if item['id'] == job['job_id']]
    assert len(jobs) == 1 and jobs[0]['name'] == job['name']
    assert jobs[0]['status'] == 'completed' and jobs[0]['conclusion'] == 'success'
    assert str(parent['workflow']['GITHUB_RUN_ID']) == str(run['id']) and parent['workflow']['GITHUB_JOB'] == job['github_job']
    assert parent['workflow']['GITHUB_SHA'] == checkout
    return audit, bindings


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--run-root', type=Path, required=True)
    p.add_argument('--repo', type=Path, required=True)
    p.add_argument('--source', required=True)
    p.add_argument('--checkout', required=True)
    p.add_argument('--broad', action='store_true')
    helper_root = Path(__file__).parent
    p.add_argument('--physical-auditor', type=Path)
    p.add_argument('--discovery-auditor', type=Path, default=helper_root / 'settings_f5_review_adapters_v2/audit_coverage_test_discovery.py')
    p.add_argument('--public-auditor', type=Path, default=helper_root / 'settings_f5_review_adapters_v2/audit_coverage_public_surfaces.py')
    p.add_argument('--settings-auditor', type=Path, default=helper_root / 'audit_settings_quick_journey.py')
    args = p.parse_args()
    if args.physical_auditor is None:
        args.physical_auditor = args.repo / 'evidence/phase_2r/physical_authored_selector_2026_10_02/audit-tools/audit_physical_selector_journey.py'
    assert args.broad, 'This acceptance join requires the completed canonical broad gate; focused evidence alone cannot pass.'
    evidence = Evidence(args.run_root)
    root = evidence.root
    read, identity, verify_record = evidence.read, evidence.identity, evidence.verify

    generic = read('audit/generic-evidence-audit.json')
    run = read('run.json')
    boundary = generic['source_boundary']
    source, checkout = boundary['source'], boundary['tested_checkout']
    assert all(re.fullmatch(r'[0-9a-f]{40}', value) for value in (args.source, args.checkout))
    assert source == args.source and checkout == args.checkout
    assert generic['generic_audit_pass'] is True
    assert boundary == read('audit/source-provenance.json')
    assert all(run[key] == generic['run'][key] for key in (
        'id', 'run_number', 'run_attempt', 'event', 'head_sha', 'status', 'conclusion'))
    for name, expected in generic['raw_metadata_identities'].items():
        verify_record({'file': name, **expected})
    assert run['status'] == 'completed' and run['conclusion'] == 'success'
    assert all(j['status'] == 'completed' and j['conclusion'] == 'success' for j in generic['jobs'])
    assert generic['gut']['failures'] == generic['gut']['errors'] == generic['gut']['skipped'] == 0
    next_proof = read('audit/next-component-audit.json')
    trace = read('audit/next-reading-trace-audit.json')
    assert next_proof['next_component_audit_pass'] is True
    assert next_proof['checkout'] == checkout
    assert next_proof['run_id'] == run['id'] and next_proof['workflow_head'] == run['head_sha']
    assert 0 < next_proof['execution_attempt'] <= run['run_attempt']
    assert next_proof['run_metadata_identity'] == {key: identity('run.json')[key] for key in ('bytes', 'sha256')}
    assert trace['audit_complete'] is True and trace['source'] == source and trace['checkout'] == checkout
    assert trace['runtime_proof_failures'] == []
    assert len(generic['reading']) == 1 and len(generic['reading'][0]['process_ids']) == 8
    reading = generic['reading'][0]
    assert reading['write_read_seal']['file_count'] == 14
    assert reading['write_read_seal']['sealed_after_mode'] == 'read' and reading['write_read_seal']['before_mode'] == 'repeat'
    assert trace['original_proof_and_process_audit'] == generic['reading']
    assert len(trace['readings']) == 1
    trace_reading = trace['readings'][0]
    assert all(trace_reading[key] == reading[key] for key in (
        'report', 'report_identity', 'trace_identity', 'trace_entries', 'process_ids', 'modes'))
    verify_record({'file': reading['report'], **reading['report_identity']})
    assert next_proof['report'] == reading['report_identity']
    assert next_proof['process_ids'] == {name: reading['process_ids'][name]
                                         for name in ('next-unseen', 'next', 'next-read')}
    assert len(next_proof['captures']) == 3
    assert {Path(row['path']).name for row in next_proof['captures']} == {
        '01-next-unseen.png', '02-next-board.png', '03-next-restored-board.png'}
    for capture in next_proof['captures']:
        verify_record({'file': capture['path'], 'bytes': capture['bytes'], 'sha256': capture['sha256']})
    checks = ['audit/generic-evidence-audit.json', 'audit/next-component-audit.json',
              'audit/next-reading-trace-audit.json', 'audit/layout-observations-audit.json']
    visual = read(checks[-1])
    assert visual['audit_pass'] is True and visual['run'] == generic['run']
    assert visual['source_boundary'] == boundary
    assert visual['generic_audit_identity'] == file_identity(evidence.path('audit/generic-evidence-audit.json'))
    assert len(visual['layout_modes']) == 2
    assert {mode['mode'] for mode in visual['layout_modes']} == {'next', 'next-read'}
    assert all(item['raw_member_bytes_identical'] for item in visual['historical_image_comparisons'])
    assert {item['name'] for item in visual['historical_image_comparisons']} == {'02-next-board.png', '03-next-restored-board.png'}
    for mode in visual['layout_modes']:
        assert mode['process_id'] == reading['process_ids'][mode['mode']]
        assert set(mode['streams']) == {'process', 'post_draw'}
        verify_record({'file': 'artifacts/' + visual['current_archive']['name'] + '/' + mode['raw_report']['zip_member'],
                       **{key: mode['raw_report'][key] for key in ('bytes', 'sha256')}})
        assert all(stream['visible_samples'] == 120 and stream['all_visible_titles_enclosed']
                   for stream in mode['streams'].values())
    # Require the new cloud driver guard itself to have executed successfully,
    # separately from the independent read-only geometry audit.
    cloud_layout = read(reading['report'])['challenge_layout']
    assert set(cloud_layout) == {'next', 'next-read'}
    for mode in visual['layout_modes']:
        reported = cloud_layout[mode['mode']]
        assert reported['title_fully_inside_clip'] is True
        assert reported['observation'] == {key: mode['raw_report'][key] for key in ('bytes', 'sha256')}
        for stream, details in mode['streams'].items():
            checked = reported['checked'][stream]
            frame_key = 'process_frame' if stream == 'process' else 'drawn_frame'
            assert checked['frames'] == 120
            assert checked['first_frame'] == details['first_visible'][frame_key]
            assert checked['last_frame'] == details['last_visible'][frame_key]
    non_gut = None
    if args.broad:
        non_gut = read('audit/non-gut-summary.json')
        discovery = read('audit/physical-selector-test-discovery.json')
        assert non_gut['audit_complete'] is True
        assert non_gut['run_id'] == run['id'] and non_gut['run_attempt'] == run['run_attempt']
        assert non_gut['candidate_source'] == source and non_gut['tested_merge'] == checkout
        assert non_gut['runtime_proof_failures'] == non_gut['pending_areas'] == []
        evidence.verify_legacy_hash_record(non_gut['generic_audit_binding'])
        assert non_gut['generic_audit_binding']['file'] == 'audit/generic-evidence-audit.json'
        assert len(non_gut['component_audits']) == 5
        assert {component['file'] for component in non_gut['component_audits']} == {
            'audit/rendered-functional-audit.json', 'audit/settings-storage-audit.json',
            'audit/next-reading-trace-audit.json', 'audit/performance-export-audit.json',
            'audit/next-component-audit.json'}
        for component in non_gut['component_audits']:
            evidence.verify_legacy_hash_record(component)
        assert non_gut['next_component'] == next_proof and non_gut['reading_journey'] == reading
        assert run['head_sha'] == source and run['event'] == 'pull_request'
        assert len(generic['jobs']) == 23 and generic['gut']['xml_count'] == 13
        assert len([j for j in generic['jobs'] if j['checkout_shas']]) == 22
        assert discovery['audit_complete'] is True
        assert discovery['run_id'] == run['id'] and discovery['run_attempt'] == run['run_attempt']
        assert discovery['source'] == source and discovery['tested_checkout'] == checkout
        assert set(discovery['input_identities']) == {
            'run.json', 'audit/source-provenance.json', 'audit/generic-evidence-audit.json'}
        for name, expected in discovery['input_identities'].items():
            verify_record({'file': name, **expected})
        assert discovery['all_added_functions_discovered_and_passed'] is True
        assert discovery['observed_counts'] == {key: generic['gut'][key] for key in (
            'case_executions', 'unique_cases', 'unique_scripts', 'script_executions', 'xml_count')}
        checks.extend(['audit/non-gut-summary.json', 'audit/physical-selector-test-discovery.json'])
    else:
        assert source == checkout
        assert len(generic['jobs']) == 3 and generic['gut']['xml_count'] == 2

    assert discovery['added_count'] == 6 and discovery['removed_count'] == 0
    assert discovery['new_test_scripts'] == [] and discovery['removed_test_functions'] == []
    assert discovery['net_declared_test_delta'] == 6
    assert discovery['baseline'] == BASELINE and discovery['increment_change_base'] == CHANGE_BASE
    assert discovery['baseline_static_counts'] == discovery['increment_change_base_static_counts']
    assert discovery['expected_current_counts'] == discovery['observed_counts'] == EXPECTED_COUNTS
    assert discovery['aggregate_delta'] == {'case_executions': 6, 'unique_cases': 6, 'unique_scripts': 0,
                                           'script_executions': 0, 'xml_count': 0}
    assert discovery['duplicate_case_executions'] == 4
    assert len(discovery['added_test_functions']) == 6
    assert {row['script'] for row in discovery['added_test_functions']} == {'tests/unit/test_production_pause_controller.gd'}
    assert {row['test'] for row in discovery['added_test_functions']} == SETTINGS_CASES
    assert discovery['auditor_sha256'] == file_identity(args.discovery_auditor)['sha256']
    public = read('audit/physical-selector-public-surfaces-audit.json')
    assert public['audit_complete'] is True
    assert public['run_id'] == run['id'] and public['source'] == source and public['tested_checkout'] == checkout
    assert public['run_attempt'] == run['run_attempt'] and public['baseline'] == BASELINE
    assert public['auditor_sha256'] == file_identity(args.public_auditor)['sha256']
    assert {name: row['record_count'] for name, row in public['inventories'].items()} == {
        'game_state_surface.json': 236, 'save_manager_surface.json': 74}
    for row in public['inventories'].values():
        assert row['contract_declarations_unchanged'] and row['artifact_equals_source_and_tested_commit']
        verify_record({'file': row['path'], 'bytes': row['bytes'], 'sha256': row['sha256']})
    assert evidence.path('audit/settings-storage-audit.json').read_bytes() == evidence.path(
        'audit/physical-selector-settings-storage-audit.json').read_bytes()
    checks.extend(['audit/physical-selector-public-surfaces-audit.json',
                   'audit/physical-selector-settings-storage-audit.json'])
    physical, physical_visual, physical_raw_bindings = physical_binding(
        evidence, run, source, checkout, args.repo, args.physical_auditor)
    assert any(job['execution_job_id'] == physical['job']['execution_job_id']
               and job['checkout_shas'] == physical['job']['checkout_shas'] for job in generic['jobs'])
    checks.append('audit/physical-selector-journey-audit.json')
    settings, settings_raw_bindings = settings_binding(evidence, run, source, checkout, args.repo, args.settings_auditor)
    checks.append('audit/settings-quick-journey-audit.json')
    helpers = {path.name: file_identity(path) for path in (
        args.physical_auditor, args.discovery_auditor, args.public_auditor, args.settings_auditor, Path(__file__))}
    # The old component still describes its own limited v1 proof. Its former v2 gap
    # is now discharged by the separately bound physical selector component.
    old_next_limits = [limit for limit in next_proof['limits']
                       if 'does not establish v2 physical fresh-process Save/Load' not in limit]


    summary = {
        'schema_version': 1, 'run_id': run['id'], 'run_number': run['run_number'],
        'run_url': run['html_url'], 'source_commit': source, 'actual_checkout_merge': checkout,
        'master_parent': boundary['master'],
        'workflow_run': {k: run[k] for k in ('run_attempt', 'event', 'head_sha', 'status', 'conclusion')},
        'scope': 'required broad gate and paused Settings F5 Save/restore proof; existing title geometry and v1/v2 semantic Save/Load proof preserved',
        'overall_acceptance_pass': True, 'overall_accepted': True,
        'expected_job_count': 23 if args.broad else 3, 'observed_job_count': len(generic['jobs']),
        'all_jobs_completed': True, 'all_checkout_provenance_verified': True,
        'unique_verified_checkout_execution_count': sum(bool(j['checkout_shas']) for j in generic['jobs']),
        'independent_non_gut_audit_complete': args.broad,
        'jobs': generic['jobs'], 'gut': generic['gut'], 'source_boundary': boundary,
        'reading': generic['reading'][0], 'next': next_proof,
        'non_gut_proofs': non_gut, 'public_surfaces': public,
        'physical_selector': physical, 'title_layout': visual,
        'settings_quick_save': settings, 'settings_quick_raw_bindings': settings_raw_bindings,
        'physical_selector_raw_bindings': physical_raw_bindings, 'audit_helper_identities': helpers,
        'settings_increment': {'baseline': BASELINE, 'increment_change_base': CHANGE_BASE,
            'new_cases': discovery['added_test_functions'], 'new_scripts': discovery['new_test_scripts'],
            'discovery_binding': identity('audit/physical-selector-test-discovery.json')},
        'selectors': {'catalogue_version': 2, 'new_cases': [],
            'new_scripts': discovery['new_test_scripts'],
            'discovery_binding': identity('audit/physical-selector-test-discovery.json'),
            'baseline': BASELINE, 'increment_change_base': CHANGE_BASE,
            'scope': 'Finite noncanonical Priscilla Day-1 Solo physical Save/Load after one actually observed sweet/exploded terminal outcome; exact selected frames, four-caption History, Next operation and Profile witnesses survive the fresh process.',
            'finite_post_rows': ['sweet/exploded/hatred/hostile', 'sweet/exploded/upset/upset', 'sweet/exploded/amused/amused'],
            'observed_post_label': physical['selected_labels'][POST],
            'checkpoint_transport': 'Real SaveManager Quick Save/Load across distinct OS processes; actual source and destination Next Autosaves retained. Original catalogue-v1 eight-process journey separately rerun.',
            'production_catalogue_registered': False},
        'joined_audit_identities': [identity(n) for n in checks],
        'limits': list(dict.fromkeys(['Original catalogue-v1 Next component: ' + limit for limit in old_next_limits]
            + visual['limitations'] + [
            'Finite noncanonical catalogue-v2 physical proof covers only the observed real sweet/exploded disposition. The three finite rows have pure selector coverage; other physical dispositions and production dialogue are not accepted.',
            'Both Next Autosave endpoints are byte-audited; the final Quick is the endpoint actually loaded by the fresh reader.',
            'The writer retains preceding post-A text above current B while the fresh reader shows B alone; exact semantic current text and History do not establish pixel-identical accumulated native layout.',
            'The former cold board-null Load clipping claim was incorrect; original PNGs already contain the complete title. No title-layout runtime fix is claimed. Native all-input, accessibility and final visual polish remain outside this increment.',
            'Paused Settings Save is accepted only for the bounded supported source and fresh physical contact. Settings Quick Load remains unavailable; no new image-based visual acceptance is inferred.',
            'The retained Settings Quick bytes are directly audited; Autosave/Profile neutrality is supported by source-bound raw-identity receipts and write observations rather than newly archived raw copies.',
            'This increment does not close unfinished Beads or accept production catalogue registration/replay or all-platform behavior.',
            'Later documentation/evidence-only commits are not separately engine-tested.'])),
    }
    (root / 'acceptance-summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps({'accepted': True, 'run': run['run_number'], 'jobs': len(generic['jobs']),
                      'gut': {k: generic['gut'][k] for k in ('case_executions', 'unique_cases', 'unique_scripts')}}))


if __name__ == '__main__':
    main()
