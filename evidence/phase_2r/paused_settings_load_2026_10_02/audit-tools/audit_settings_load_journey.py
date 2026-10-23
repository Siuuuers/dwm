#!/usr/bin/env python3
"""Source-bound independent audit of the bounded Settings F9 cloud journey.

Reuses the accepted F5 auditor for the preserved proof and raw provenance.
Does not import the production journey runner or execute Godot/PowerShell.
"""
from __future__ import annotations
import argparse
import ast
import importlib.util
import json
from pathlib import Path, PurePosixPath
import re

MODE = 'settings-load'
STAGES = ('initial', 'advanced', 'entered', 'prepared', 'cancelled', 'reprepared', 'confirmed')
CHECKS = (
    {'retained_f5_input', 'saved_checkpoint_exact', 'saved_history_exact', 'saved_line_complete', 'initial_load_silent', 'initial_load_disk_neutral'},
    {'ordinary_pause_open', 'different_partial_line'},
    {'partial_source_preserved', 'different_saved_line', 'two_history_occurrences', 'settings_interactive', 'reading_category', 'exact_enabled_origin', 'suspension_present', 'new_line_speech_control'},
    {'cancel_first_confirmation', 'bound_quick_candidate', 'no_early_restore', 'source_scene_retained', 'suspension_retained', 'exclusive_modal', 'disk_unchanged', 'zero_mutations'},
    {'exact_partial_source', 'exact_host_focus_scroll_suspension', 'source_scene_retained', 'consent_retired', 'disk_unchanged', 'zero_mutations'},
    {'cancel_first_confirmation', 'bound_quick_candidate', 'no_early_restore', 'source_scene_retained', 'suspension_retained', 'exclusive_modal', 'disk_unchanged', 'zero_mutations'},
    {'load_committed', 'saved_checkpoint_exact', 'saved_history_exact', 'saved_physical_exact', 'saved_app_exact', 'saved_earlier_line_complete', 'restored_live_session', 'old_pause_settings_closed', 'restored_scene_mounted', 'no_restored_speech', 'profile_unchanged', 'disk_unchanged', 'zero_mutations'},
)
EXTRA_SOURCE = ('autoload/SaveManager.gd', 'scripts/application/backup/BackupPresentationPort.gd',
                'scripts/ui/BackupApp.gd', 'scripts/ui/SettingsPanelController.gd', 'scripts/ui/desktop/QuickStatusEdge.gd',
                'tests/integration/verify_playable_startup.gd', 'autoload/InputManager.gd',
                'scripts/application/lifecycle/ProductionPauseController.gd',
                'scripts/ui/witnessed/WitnessedAcceptInput.gd')


def helper(path):
    spec = importlib.util.spec_from_file_location('accepted_settings_quick', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def audit(a, h):
    require, read, identity = h.require, h.read, h.identity
    root, repo = a.run_root.resolve(), a.repo.resolve()
    # A fresh run of the original accepted auditor independently preserves the
    # original eight modes and F5 pair without rewriting its accepted contracts.
    f5 = {'audit_complete': False}
    h.audit(a, f5)
    require(f5['audit_complete'] is True, 'PRESERVED_ORIGINAL_AND_F5_PROOF_REQUIRED')
    run = read(root / 'run.json')
    top = root / 'artifacts' / f5['artifact_identity']['name']
    parent = read(top / 'result.json')
    parent_folder = top / PurePosixPath(parent['artifact_root']).name
    prior = parent['settings_quick_save']
    result = prior['settings_load']
    folder = parent_folder / MODE
    require(read(folder / 'result.json') == result and result['ok'] is True and result['failures'] == []
            and result['schema_version'] == 1 and result['checkout_sha'] == a.checkout
            and result['workflow'] == parent['workflow'], 'EXACT_SUCCESSFUL_NESTED_LOAD_RESULT_REQUIRED')
    require(PurePosixPath(result['artifact_root']) == PurePosixPath(parent['artifact_root']) / MODE
            and result['isolation_root'] == prior['isolation_root'] and result['user_dir'] == prior['user_dir'],
            'LOAD_MUST_REUSE_EXACT_F5_ISOLATED_PROFILE')
    require(set(result['reports']) == {MODE} and set(result['processes']) == {MODE}, 'ONE_EXTRA_LOAD_PROCESS_REQUIRED')
    report = result['reports'][MODE]
    require(read(folder / (MODE + '.json')) == report and report['mode'] == MODE and report['user_dir'] == prior['user_dir'],
            'EXACT_LOAD_PROCESS_REPORT_REQUIRED')
    pid = report['process_id']
    require(h.integer(pid, 1) and pid not in f5['process_ids'].values(), 'LOAD_PROCESS_MUST_DIFFER_FROM_F5_PROCESSES')
    require(result['follows_process'] == {'mode': 'settings-read', 'process_id': prior['reports']['settings-read']['process_id'],
            'receipt': prior['processes']['settings-read']}, 'EXACT_PRECEDING_F5_READER_BINDING_REQUIRED')
    process = result['processes'][MODE]
    require(read(folder / (MODE + '.process.json')) == process and type(process['exit_code']) is int
            and process['exit_code'] == 0 and process['timed_out'] is False, 'SUCCESSFUL_REAL_LOAD_PROCESS_REQUIRED')
    require(h.utc(prior['processes']['settings-read']['ended_at_utc']) <= h.utc(result['started_at_utc'])
            <= h.utc(process['started_at_utc']) <= h.utc(process['ended_at_utc']) <= h.utc(result['ended_at_utc']),
            'LOAD_PROCESS_AND_RAW_INPUT_MUST_FOLLOW_F5_READER')
    require(h.integer(process['timeout_seconds'], 1) and h.finite(process['elapsed_seconds'])
            and 0 <= process['elapsed_seconds'] <= process['timeout_seconds'], 'VALID_LOAD_WATCHDOG_REQUIRED')
    cloud_folder = PurePosixPath(result['artifact_root'])
    argv = process['argv']
    require('--headless' not in argv and PurePosixPath(argv[0]).name == 'xvfb-run'
            and 'res://' + h.SCRIPT in argv and '--reading-rail-mode=' + MODE in argv
            and argv[argv.index('--rendering-method') + 1] == 'gl_compatibility'
            and argv[argv.index('--rendering-driver') + 1] == 'opengl3'
            and argv[argv.index('--log-file') + 1] == str(cloud_folder / (MODE + '.log')), 'EXACT_RENDERED_LOAD_ARGUMENTS_REQUIRED')
    process_files = {MODE + '.process.json': identity(folder / (MODE + '.process.json'))}
    for field, suffix in (('stdout', '.stdout.txt'), ('stderr', '.stderr.txt'), (None, '.log')):
        name = MODE + suffix
        path = folder / name
        if field:
            require(PurePosixPath(process[field]) == cloud_folder / name, 'LOAD_PROCESS_LOG_PATH_DIFFERS')
        text = path.read_text(encoding='utf-8-sig')
        require(h.ERRORS.search(text) is None, 'LOAD_PROCESS_ERROR_OR_LEAK: ' + name)
        if field == 'stdout':
            require(len(re.findall(r'^READING_RAIL_SETTINGS_LOAD_PASS:', text, re.M)) == 1, 'EXACT_EXECUTED_LOAD_PASS_MARKER_REQUIRED')
        process_files[name] = identity(path)
    source_files = dict(f5['source_files'])
    for path in EXTRA_SOURCE:
        raw = h.git_blob(repo, a.source, path)
        require(raw == h.git_blob(repo, a.checkout, path), 'LOAD_SOURCE_CHECKOUT_DIFFERENCE: ' + path)
        source_files[path] = h.digest(raw)
    constants = {}
    for node in ast.parse(h.git_blob(repo, a.source, h.DRIVER)).body:
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
            name = node.targets[0].id
            if name in ('SETTINGS_LOAD_MODE', 'SETTINGS_LOAD_STAGES', 'SETTINGS_DISK_PATHS'):
                constants[name] = ast.literal_eval(node.value)
    require(constants == {'SETTINGS_LOAD_MODE': MODE, 'SETTINGS_LOAD_STAGES': STAGES,
            'SETTINGS_DISK_PATHS': {'quick': 'saves/quicksave.json', 'autosave': 'saves/autosave.json', 'profile': 'profile.json'}},
            'EXACT_LOAD_DRIVER_MODE_STAGE_AND_DISK_CONTRACT_REQUIRED')
    initial, advanced, before, prepared, cancelled, reprepared, after = [report[k] for k in
        ('initial', 'advanced', 'before', 'prepared', 'cancelled', 'reprepared', 'after')]
    trace = [h.parse(line) for line in (folder / 'settings-load-transactions.jsonl').read_text().splitlines()]
    require(len(trace) == len(STAGES), 'EXACT_LOAD_TRACE_LENGTH_REQUIRED')
    for i, (stage, value, checks, row) in enumerate(zip(STAGES, (initial, advanced, before, prepared, cancelled, reprepared, after), CHECKS, trace), 1):
        require(read(folder / ('settings-load-' + stage + '.json')) == value
                and row == {'mode': MODE, 'process_id': pid, 'sequence': i, 'kind': 'settings_load_' + stage, 'value': value},
                'EXACT_STAGE_TRACE_REPORT_BINDING_REQUIRED: ' + stage)
        require(set(value['checks']) == checks and value['failed_checks'] == []
                and all(item is True for item in value['checks'].values()), 'SOURCE_STAGE_FAILURE: ' + stage)
    raw = {}
    require(set(result['raw_files']) == {'quick', 'autosave', 'profile'}, 'EXACT_PRIMARY_RAW_FILE_FAMILIES_REQUIRED')
    for family in ('quick', 'autosave', 'profile'):
        expected_source = PurePosixPath(result['user_dir']) / {'quick': 'saves/quicksave.json', 'autosave': 'saves/autosave.json', 'profile': 'profile.json'}[family]
        require(result['raw_files'][family] == {'source': str(expected_source), 'input': str(cloud_folder / f'input-{family}.json'),
                'paused_baseline': str(cloud_folder / f'settings-load-baseline-{family}.json'), 'final': str(cloud_folder / f'final-{family}.json')},
                'RAW_PRIMARY_FILE_PATH_BINDING_MISMATCH: ' + family)
        records = {}
        for label, name in (('input', f'input-{family}.json'), ('baseline', f'settings-load-baseline-{family}.json'), ('final', f'final-{family}.json')):
            path = folder / name
            record = {'file': path.relative_to(root).as_posix(), **identity(path)}
            records[label] = record
            expected = report['input_disk'][family] if label == 'input' else before['disk'][family]
            require(expected == {'exists': True, **identity(path)}, 'RAW_DISK_OBSERVATION_MISMATCH: ' + family + '/' + label)
        require((folder / f'settings-load-baseline-{family}.json').read_bytes() == (folder / f'final-{family}.json').read_bytes(),
                'RAW_CANCEL_AND_LOAD_DISK_NEUTRALITY_REQUIRED: ' + family)
        raw[family] = records
    inputs = read(folder / 'input-files.json')
    require(result['input_files'] == inputs == {key: identity(folder / f'input-{key}.json') for key in raw}, 'PREPROCESS_RAW_INPUT_BINDING_REQUIRED')
    quick_path = folder / 'input-quick.json'
    require(quick_path.read_bytes() == (folder / 'settings-load-baseline-quick.json').read_bytes()
            == (parent_folder / 'settings-quick/saved-settings-quick.json').read_bytes(), 'RETAINED_F5_QUICK_BYTES_REQUIRED')
    saved = read(quick_path)
    snapshot = saved['current_snapshot']['snapshot']
    checkpoint = snapshot['narrative_checkpoint']
    written = prior['reports']['settings-write']
    require(report['input_disk'] == written['disk_after'] == initial['disk']
            and initial['speech_admissions'] == 0 and initial['current_line_complete'] is True
            and initial['reading']['source']['checkpoint'] == checkpoint == written['saved_checkpoint']
            and initial['reading']['source']['history'] == written['entered']['source']['history'], 'INITIAL_EXACT_SILENT_F5_LOAD_REQUIRED')
    transport = advanced['transport']
    input_path = folder / 'settings-load-input.json'
    require(read(input_path) == transport and transport['packet_type'] == 'InputEventKey'
            and transport['accept_admitted'] is True and transport['source_line'] == 'fixture.solo.pre.a'
            and transport['back_admitted'] is True and transport['pause_source_admission']['ok'] is True
            and transport['admitted_frontier'] == before['reading']['source']['checkpoint']['reading_session']['frontier']
            and transport['tree_paused'] is True and transport['contacts_after'] == {},
            'RAW_ADMITTED_ACCEPT_THEN_BACK_PROTOCOL_REQUIRED')
    packets = transport['events']
    require(type(packets) is list and len(packets) == 4
            and [(packet['key'], packet['pressed']) for packet in packets]
                == [('Enter', True), ('Enter', False), ('Escape', True), ('Escape', False)]
            and all(type(packet['pressed']) is bool and h.integer(packet['frame'], 1) for packet in packets)
            and all(left['frame'] < right['frame'] for left, right in zip(packets, packets[1:])),
            'EXACT_FOUR_SEPARATE_FRAME_PHYSICAL_PACKETS_REQUIRED')
    active_contacts = []
    for packet in packets:
        contacts = packet['contacts']
        require(type(contacts) is dict and len(contacts) == (1 if packet['pressed'] else 0),
                'EACH_PHYSICAL_PRESS_MUST_HAVE_EXACTLY_ONE_CONTACT_AND_EACH_RELEASE_NONE')
        if packet['pressed']:
            contact, generation = next(iter(contacts.items()))
            require(re.fullmatch(r'key:-?\d+:\d+', contact) and h.integer(generation, 1), 'REAL_KEY_CONTACT_AND_GENERATION_REQUIRED')
            active_contacts.append((contact, generation))
    require(active_contacts[0][0] != active_contacts[1][0] and active_contacts[0][1] < active_contacts[1][1],
            'DISTINCT_FRESH_ACCEPT_AND_BACK_CONTACT_GENERATIONS_REQUIRED')
    require(advanced['reading'] == before['reading'] and advanced['scene_id'] == before['scene_id']
            and advanced['tree_paused'] is True and advanced['pause_visible'] is True, 'ORDINARY_SETTINGS_ENTRY_MUST_RETAIN_PARTIAL_SOURCE')
    source = before['reading']['source']
    native = before['reading']['native']
    host = before['host']
    require(source['checkpoint'] != checkpoint and source['profile']['preferences']['reading']['read_aloud_enabled'] is True
            and h.integer(source['speech_admissions'], 1), 'DIFFERENT_SOURCE_WITH_POSITIVE_SPEECH_CONTROL_REQUIRED')
    catalogue = h.parse(h.git_blob(repo, a.source, h.CATALOGUE))
    entry = next(row for row in catalogue['entries'] if row['entry_id'] == h.ENTRY)
    a_line, b_line = entry['lines'][:2]
    require(a_line['line_id'] == h.LINE and b_line['line_id'] == native['line_id'] == 'fixture.solo.pre.b'
            and native['text'] == b_line['text'] and native['total_characters'] == len(b_line['text'])
            and h.integer(native['caption_id'], 1) and h.integer(native['reveal_generation']) and native['revealing'] is True
            and h.integer(native['visible_characters']) and native['visible_characters'] < native['total_characters']
            and h.finite(native['visible_ratio']) and 0 <= native['visible_ratio'] < 1, 'LITERAL_PARTIAL_SECOND_CAPTION_REQUIRED')
    expected_history = [{'beat_id': line['beat_id'], 'entry_id': h.ENTRY, 'line_id': line['line_id'],
                         'publication_id': 'caption:' + str(i), 'text': line['text']} for i, line in enumerate((a_line, b_line), 1)]
    history = source['history']
    session = source['checkpoint']['reading_session']
    require(history['captions'] == expected_history and history['frontier'] == session['frontier']
            == {'line_id': b_line['line_id'], 'publication_id': 'caption:2'}
            and history['session_id'] == session['ledger']['session_token'], 'EXACT_TWO_PUBLICATION_SOURCE_HISTORY_REQUIRED')
    require(host['visible'] is True and host['tree_paused'] is True and host['entered_action'] == 'settings'
            and host['selected_category'] == 'reading' and h.integer(host['host_id'], 1) and h.integer(host['focus_id'], 1)
            and host['focus_path'] and not PurePosixPath(host['focus_path']).is_absolute() and '..' not in PurePosixPath(host['focus_path']).parts
            and bool(host['suspension']) and h.integer(before['scene_id'], 1), 'EXACT_VISIBLE_SUSPENDED_SETTINGS_ORIGIN_REQUIRED')
    for scroll in ('rail_scroll', 'sheet_scroll'):
        require(len(host[scroll]) == 2 and all(h.integer(value) for value in host[scroll]), 'EXACT_SCROLL_OBSERVATIONS_REQUIRED')
    for value in (prepared, reprepared):
        require(value['reading'] == before['reading'] and value['disk'] == before['disk'] and value['scene_id'] == before['scene_id']
                and value['suspension'] == host['suspension'] and value['confirmation_open'] is True and value['cancel_focused'] is True
                and value['settings_covered'] is True and value['tree_paused'] is True and type(value['pending_token']) is str
                and bool(value['pending_token']) and value['mutations'] == [], 'EXCLUSIVE_CANCEL_FIRST_MODAL_MUST_RETAIN_SOURCE')
    require(cancelled['reading'] == before['reading'] and cancelled['host'] == host and cancelled['disk'] == before['disk']
            and cancelled['scene_id'] == before['scene_id'] and cancelled['pending_token'] == ''
            and cancelled['confirmation_open'] is False and cancelled['mutations'] == []
            and prepared['pending_token'] != reprepared['pending_token'], 'CANCEL_EXACT_SOURCE_AND_FRESH_CONSENT_REQUIRED')
    physical = snapshot['gameplay']['route_context']['active_dating_challenge']
    for name, expected in (('checkpoint', checkpoint), ('history', written['entered']['source']['history']), ('physical_record', physical)):
        require(after[name].get('ok') is True and after[name].get('value') == expected, 'CONFIRMED_RAW_QUICK_DESTINATION_DIFFERS: ' + name)
    require(after['desktop_context'] == written['desktop_context'] == {'active_app_id': snapshot['active_app_id']}
            and snapshot['route_id'] == 'dating' and after['current_line_id'] == a_line['line_id']
            and after['current_line_complete'] is True and after['load_result'].get('ok') is True
            and after['live_session'].get('ok') is True and after['live_session']['value']['active'] is True
            and after['live_session']['value']['run_id'] == snapshot['run_id'], 'CONFIRMED_CANONICAL_DESTINATION_REQUIRED')
    require(after['scene_id'] != before['scene_id'] and h.integer(after['scene_id'], 1)
            and after['tree_paused'] is False and after['pause_visible'] is False and after['settings_visible'] is False
            and after['suspension'] == {}, 'CONFIRMED_LOAD_MUST_RETIRE_PAUSE_SETTINGS_AND_REMOUNT_SCENE')
    require(after['speech_admissions'] == source['speech_admissions'] and after['profile'] == source['profile']
            and after['disk'] == before['disk'] and after['mutations'] == [], 'LOAD_MUST_NOT_REPEAT_SPEECH_OR_WRITE_STORAGE')
    raw_validation = {'raw_input': inputs, 'raw_paused_source': {key: identity(folder / f'settings-load-baseline-{key}.json') for key in raw},
                      'raw_final': {key: identity(folder / f'final-{key}.json') for key in raw},
                      'cancel_exact_partial_source_focus_scroll': True, 'fresh_confirm_saved_earlier_line': True,
                      'saved_history_physical_app_restored': True, 'old_pause_settings_closed': True,
                      'load_mutations': 0, 'restored_speech_admissions': 0, 'stage_observations': len(STAGES)}
    require(result['validation'] == raw_validation, 'RUNNER_VALIDATION_MUST_EQUAL_INDEPENDENT_RAW_RESULT')
    return {'schema_version': 1, 'audit_complete': True, 'run_id': run['id'], 'run_attempt': run['run_attempt'],
        'source': a.source, 'checkout': a.checkout, 'workflow_head': run['head_sha'], 'job': f5['job'],
        'artifact_identity': f5['artifact_identity'], 'source_files': source_files,
        'auditor_identity': identity(Path(__file__)), 'accepted_f5_auditor_identity': identity(a.f5_auditor),
        'preserved_f5_and_original_audit': f5, 'load_process_id': pid, 'load_process_file_identities': process_files,
        'supplemental_report': {'file': (folder / 'result.json').relative_to(root).as_posix(), **identity(folder / 'result.json')},
        'trace': {'file': (folder / 'settings-load-transactions.jsonl').relative_to(root).as_posix(), **identity(folder / 'settings-load-transactions.jsonl'), 'entries': len(STAGES)},
        'physical_input_protocol': {'file': input_path.relative_to(root).as_posix(), **identity(input_path),
            'packet_count': len(packets), 'frames': [packet['frame'] for packet in packets],
            'distinct_contact_generations': [generation for _, generation in active_contacts],
            'fresh_released_accept_then_admitted_physical_back': True},
        'raw_file_bindings': raw, 'semantic_assertions': raw_validation,
        'limitations': [
            'Bounded noncanonical English catalogue-v1 Solo pre-challenge fixture: saved A, physically advanced partly revealed B, Cancel exact B, Confirm exact saved A.',
            'The initial and final Quick/Autosave/Profile primary files are retained; byte neutrality and source-bound FileOps observers support zero Load mutations, not arbitrary-filesystem or OS-crash proof.',
            'Original eight-mode catalogue-v1 and F5 pair are independently preserved; physical catalogue-v2 proof remains a separately required component.',
            'The rendered F9 journey does not itself establish every blocked-owner input scenario; those need the registered cloud tests and actual XML discovery.',
            'Linux software rendering does not establish native Windows all-input/accessibility, pixel-identical scrollback, production replay or final visual polish.',
            'This component cannot replace the canonical broad gate or close unfinished Beads.']}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--run-root', type=Path, required=True)
    p.add_argument('--repo', type=Path, required=True)
    p.add_argument('--source', required=True)
    p.add_argument('--checkout', required=True)
    p.add_argument('--f5-auditor', type=Path, default=Path(__file__).parent / 'audit_settings_quick_journey.py')
    p.add_argument('--output', type=Path)
    a = p.parse_args()
    h = helper(a.f5_auditor)
    target = a.output or a.run_root / 'audit/settings-load-journey-audit.json'
    target.parent.mkdir(parents=True, exist_ok=True)
    try:
        result = audit(a, h)
    except Exception as error:
        target.write_text(json.dumps({'audit_complete': False, 'source': a.source, 'checkout': a.checkout,
            'failure': {'type': type(error).__name__, 'message': str(error)}}, indent=2) + '\n')
        raise
    target.write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
    print(json.dumps({'audit_complete': True, 'run_id': result['run_id'], 'process_id': result['load_process_id'], 'output': str(target)}))


if __name__ == '__main__':
    main()
