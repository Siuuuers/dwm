#!/usr/bin/env python3
"""Independently audit the retained paused-Settings physical Quick proof.

Reads completed cloud artifacts and exact Git objects only. Never imports the
journey runner or its validators and never runs Godot or PowerShell. The report
is a bounded component receipt, not broad acceptance or native Windows proof.
"""
from __future__ import annotations

import argparse
import ast
from datetime import datetime
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import zipfile

DRIVER = 'tools/testing/run_reading_rail_journey.py'
SCRIPT = 'tests/integration/verify_reading_rail_journey.gd'
CATALOGUE = 'tests/fixtures/dialogic/solo_reading_rail_catalogue.json'
ENTRY = 'dating.solo.priscilla.day1.pre_challenge'
LINE = 'fixture.solo.pre.a'
ORIGINAL = ('write', 'read', 'repeat', 'variant', 'witness-read', 'next-unseen', 'next', 'next-read')
SETTINGS = ('settings-write', 'settings-read')
CAPTURES = ('01-title.png', '02-desktop.png', '03-minesweeper.png', '04-pre-history.png',
            '05-dating-board.png', '06-post-history.png', '07-post-save.png',
            '08-restored-history.png', '09-restored-line.png')
PAUSE = ('ordinary_pause_entered', 'ordinary_pause_cancelled', 'ordinary_pause_continued',
         'ordinary_pause_reentered', 'ordinary_backup_previewed', 'ordinary_backup_entered',
         'ordinary_pause_save_committed', 'ordinary_pause_save_continued')
TRACE = {
    'write': ('fixture_registered', *PAUSE, 'history_inspected', 'pre_history',
              'automatic_board_handoff', 'committed_result_then_post_prose', 'quick_committed',
              'history_inspected', 'reading_quick_load_cancelled', 'stale_candidate_refused'),
    'read': ('fresh_restore_prepared', 'history_inspected', 'fresh_restore_verified'),
    'repeat': ('witness_repeat_entered', 'witness_repeat_verified'),
    'variant': ('witness_variant_refused', 'witness_neutrality_verified', 'witness_retry_committed',
                'history_inspected', 'witness_unseen_stop_verified'),
    'witness-read': ('witness_restart_verified',),
    'next-unseen': ('next_auto_off_refused', 'history_inspected', 'next_unseen_verified'),
    'next': ('next_challenge_verified',), 'next-read': ('next_restart_verified',),
    'settings-write': ('settings_pause_entered', 'settings_host_entered', 'settings_quick_committed',
                       'settings_continue_verified'),
    'settings-read': ('settings_restore_prepared', 'history_inspected', 'settings_restore_verified'),
}
SOURCE_PATHS = (DRIVER, SCRIPT, CATALOGUE, 'tools/testing/run_cloud_journeys.py',
                'tools/evidence/print_user_dir.gd', 'scripts/ui/pause/PauseSurface.gd',
                'scripts/ui/pause/PauseQuickCommands.gd', 'scripts/ui/SettingsContent.gd',
                'scripts/ui/SettingsResetConfirmation.gd',
                'scripts/infrastructure/storage/JsonFileStorage.gd',
                'scripts/infrastructure/storage/FileOps.gd',
                'scripts/infrastructure/save/SaveDocumentSchema.gd',
                'scripts/validation/CanonicalJsonWriter.gd')
ERRORS = re.compile(r'SCRIPT ERROR:|(?:^|\s)ERROR:|Unicode parsing error|Unexpected NUL character|'
                    r'Parse Error:|READING_RAIL_FAIL:|READING_RAIL_CLOUD_FAIL:|Resource still in use:|'
                    r'Leaked instance:|Orphan StringName:', re.M)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def parse(raw):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, 'DUPLICATE_JSON_KEY: ' + key)
            result[key] = value
        return result
    def invalid(value):
        raise ValueError('NONFINITE_JSON: ' + value)
    return json.loads(raw, object_pairs_hook=pairs, parse_constant=invalid)


def read(path):
    return parse(path.read_text(encoding='utf-8-sig'))


def digest(raw):
    return {'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}


def identity(path):
    return digest(path.read_bytes())


def integer(value, minimum=0):
    return type(value) is int and value >= minimum


def finite(value):
    return type(value) in (int, float) and math.isfinite(value)


def safe_relative(name):
    path = PurePosixPath(name)
    require(not path.is_absolute() and '..' not in path.parts and '\\' not in name
            and ':' not in name, 'UNSAFE_RETAINED_RELATIVE_PATH: ' + name)
    return path


def git_blob(repo, revision, path):
    return subprocess.check_output(['git', '-C', str(repo), 'cat-file', 'blob', revision + ':' + path])


def utc(value):
    result = datetime.fromisoformat(value)
    require(result.tzinfo is not None, 'TIMEZONE_REQUIRED_IN_PROCESS_RECEIPT')
    return result


def clean(line):
    return re.sub(r'^\ufeff?\d{4}-\d\d-\d\dT\S+\s', '',
                  re.sub(r'\x1b\[[0-9;]*m', '', line)).strip()


def verify_archive(root, run):
    api = read(root / 'artifacts-api.json')
    require(api.get('total_count', len(api['artifacts'])) == len(api['artifacts']), 'ARTIFACT_PAGINATION_REQUIRED')
    name = f"reading-rail-{run['id']}-{run['run_attempt']}"
    rows = [row for row in api['artifacts'] if row['name'] == name]
    require(len(rows) == 1, 'EXACT_CURRENT_ATTEMPT_READING_ARTIFACT_REQUIRED')
    item = rows[0]
    require(item['workflow_run']['id'] == run['id'] and item['workflow_run']['head_sha'] == run['head_sha'],
            'ARTIFACT_WORKFLOW_RUN_IDENTITY_MISMATCH')
    retained = [row for row in read(root / 'artifact-manifest.json') if row['id'] == item['id']]
    require(len(retained) == 1 and retained[0]['name'] == name, 'ONE_EXACT_ORIGINAL_ARTIFACT_DOWNLOAD_REQUIRED')
    path = Path(retained[0]['local_zip'])
    expected = {'bytes': item['size_in_bytes'], 'sha256': item['digest'].removeprefix('sha256:')}
    require(identity(path) == expected, 'ORIGINAL_ZIP_API_DIGEST_OR_LENGTH_MISMATCH')
    folder = root / 'artifacts' / name
    with zipfile.ZipFile(path) as archive:
        members = [row for row in archive.infolist() if not row.is_dir()]
        names = {row.filename for row in members}
        require(len(names) == len(members), 'DUPLICATE_ZIP_MEMBER')
        for member in members:
            relative = safe_relative(member.filename)
            require(not stat.S_ISLNK(member.external_attr >> 16), 'SYMLINK_ZIP_MEMBER')
            local = folder / relative
            require(local.is_file() and not local.is_symlink(), 'EXACT_EXTRACTED_MEMBER_REQUIRED: ' + member.filename)
            require(identity(local) == digest(archive.read(member)), 'EXTRACTED_BYTES_DIFFER: ' + member.filename)
        require({path.relative_to(folder).as_posix() for path in folder.rglob('*') if path.is_file()} == names,
                'EXACT_EXTRACTED_ARTIFACT_MEMBER_SET_REQUIRED')
    return folder, {'id': item['id'], 'name': name, 'attempt': run['run_attempt'],
                    'workflow_head': run['head_sha'], 'zip_identity': expected,
                    'verified_members': len(members)}


def verify_job(root, run, result, checkout):
    jobs = read(root / 'jobs.json')
    require(jobs.get('total_count', len(jobs['jobs'])) == len(jobs['jobs']), 'JOB_PAGINATION_REQUIRED')
    candidates = []
    for job in jobs['jobs']:
        path = root / 'logs' / f"{job['id']}.log"
        if path.is_file() and job.get('run_attempt', 1) == run['run_attempt']:
            text = path.read_text(encoding='utf-8-sig')
            if 'READING_RAIL_CLOUD_RESULT: ' in text:
                candidates.append((job, path, text))
    require(len(candidates) == 1, 'ONE_CURRENT_ATTEMPT_EXECUTED_READING_JOB_REQUIRED')
    job, path, log = candidates[0]
    require(job['status'] == 'completed' and job['conclusion'] == 'success', 'READING_JOB_NOT_SUCCESSFUL')
    lines = [clean(line) for line in log.splitlines()]
    checkouts = [lines[i + 1] for i, line in enumerate(lines[:-1])
                 if 'log -1 --format=%H' in line and re.fullmatch('[0-9a-f]{40}', lines[i + 1])]
    require(checkouts and set(checkouts) == {checkout}, 'EXECUTED_EXACT_CHECKOUT_REQUIRED')
    emitted = [parse(line.split('READING_RAIL_CLOUD_RESULT: ', 1)[1])
               for line in lines if line.startswith('READING_RAIL_CLOUD_RESULT: ')]
    require(emitted == [{'ok': True, 'artifact_root': result['artifact_root'],
                         'checkout_sha': checkout, 'failures': []}]
            and ('python3 ' + DRIVER) in log, 'EXECUTED_RUNNER_RESULT_MISMATCH')
    require(run['event'] in ('push', 'pull_request'), 'WORKFLOW_EVENT_REQUIRES_REVIEW')
    expected_sha = checkout if run['event'] == 'pull_request' else run['head_sha']
    workflow = result['workflow']
    require(str(workflow['GITHUB_RUN_ID']) == str(run['id'])
            and int(workflow['GITHUB_RUN_ATTEMPT']) == run['run_attempt']
            and workflow['GITHUB_SHA'] == expected_sha and workflow['GITHUB_JOB'], 'WORKFLOW_METADATA_MISMATCH')
    return {'name': job['name'], 'job_id': job['id'], 'log': path.relative_to(root).as_posix(),
            'log_identity': identity(path), 'checkout_shas': checkouts, 'github_job': workflow['GITHUB_JOB']}


def verify_trace(folder, reports, modes):
    path = folder / 'transactions.jsonl'
    rows = [parse(line) for line in path.read_text(encoding='utf-8').splitlines()]
    require([(row['mode'], row['kind']) for row in rows]
            == [(mode, kind) for mode in modes for kind in TRACE[mode]], 'EXACT_EXECUTED_TRACE_ORDER_REQUIRED')
    for mode in modes:
        selected = [row for row in rows if row['mode'] == mode]
        require([row['sequence'] for row in selected] == list(range(1, len(selected) + 1))
                and all(integer(row['sequence'], 1) and row['process_id'] == reports[mode]['process_id']
                        for row in selected), 'TRACE_SEQUENCE_OR_PROCESS_MISMATCH: ' + mode)
    return rows


def verify_processes(folder, result, modes):
    require(set(result['reports']) == set(modes)
            and set(result['processes']) == {*modes, 'user-dir-proof'}, 'EXACT_REPORT_AND_PROCESS_SETS_REQUIRED')
    cloud_folder = PurePosixPath(result['artifact_root'])
    user = PurePosixPath(result['user_dir'])
    isolation = PurePosixPath(result['isolation_root'])
    require(user.is_absolute() and isolation.is_absolute() and '..' not in user.parts
            and user != isolation and user.is_relative_to(isolation), 'STRICT_ISOLATED_USER_DIRECTORY_REQUIRED')
    suffixes = {'XDG_DATA_HOME': 'data', 'XDG_CONFIG_HOME': 'config',
                'XDG_CACHE_HOME': 'cache', 'DWM_TEST_ROOT': 'test-root'}
    require(set(result['isolated_environment']) == set(suffixes), 'EXACT_ISOLATED_ENVIRONMENT_REQUIRED')
    for key, suffix in suffixes.items():
        require(PurePosixPath(result['isolated_environment'][key]) == isolation / suffix,
                'ISOLATION_ENVIRONMENT_ESCAPE: ' + key)
    require(user.is_relative_to(isolation / 'data'), 'USER_DIR_MUST_USE_ISOLATED_DATA_HOME')
    pids = [result['reports'][mode]['process_id'] for mode in modes]
    require(all(integer(pid, 1) for pid in pids) and len(set(pids)) == len(modes), 'DISTINCT_RENDERED_PROCESS_IDS_REQUIRED')
    identities, log_identities = {}, {}
    order = ('user-dir-proof', *modes)
    previous_end = None
    for mode in order:
        process = result['processes'][mode]
        receipt = folder / (mode + '.process.json')
        require(read(receipt) == process and type(process['exit_code']) is int and process['exit_code'] == 0
                and process['timed_out'] is False, 'REAL_SUCCESSFUL_PROCESS_RECEIPT_REQUIRED: ' + mode)
        started, ended = utc(process['started_at_utc']), utc(process['ended_at_utc'])
        require(started <= ended and (previous_end is None or previous_end <= started), 'FRESH_PROCESSES_MUST_EXECUTE_SEQUENTIALLY')
        previous_end = ended
        require(integer(process['timeout_seconds'], 1) and finite(process['elapsed_seconds'])
                and 0 <= process['elapsed_seconds'] <= process['timeout_seconds'], 'VALID_PROCESS_WATCHDOG_RECEIPT_REQUIRED')
        logs = [folder / (mode + '.log')]
        for field, suffix in (('stdout', '.stdout.txt'), ('stderr', '.stderr.txt')):
            require(PurePosixPath(process[field]) == cloud_folder / (mode + suffix), 'PROCESS_LOG_PATH_MISMATCH')
            logs.append(folder / (mode + suffix))
        for log in logs:
            require(ERRORS.search(log.read_text(encoding='utf-8-sig')) is None, 'RUNTIME_OR_LIFETIME_ERROR: ' + log.name)
        stdout = logs[1].read_text(encoding='utf-8-sig')
        argv = process['argv']
        require(argv[argv.index('--log-file') + 1] == str(cloud_folder / (mode + '.log')), 'PROCESS_GODOT_LOG_PATH_MISMATCH')
        if mode == 'user-dir-proof':
            require('--headless' in argv and 'res://tools/evidence/print_user_dir.gd' in argv, 'EXECUTED_USER_DIR_PROOF_REQUIRED')
            markers = re.findall(r'^PHASE2R_USER_DIR=(.+)$', stdout, re.M)
            require(len(markers) == 1 and PurePosixPath(markers[0].strip()) == user, 'USER_DIRECTORY_STDOUT_PROOF_MISMATCH')
        else:
            report = result['reports'][mode]
            require(read(folder / (mode + '.json')) == report and report['mode'] == mode
                    and PurePosixPath(report['user_dir']) == user, 'RETAINED_PROCESS_REPORT_MISMATCH')
            require('--headless' not in argv and PurePosixPath(argv[0]).name == 'xvfb-run'
                    and 'res://' + SCRIPT in argv and '--reading-rail-mode=' + mode in argv
                    and argv[argv.index('--rendering-method') + 1] == 'gl_compatibility'
                    and argv[argv.index('--rendering-driver') + 1] == 'opengl3', 'REAL_RENDERED_PROCESS_ARGUMENTS_REQUIRED')
            marker = 'READING_RAIL_' + mode.upper().replace('-', '_') + '_PASS:'
            require(len(re.findall('^' + re.escape(marker), stdout, re.M)) == 1, 'EXACT_EXECUTED_PASS_MARKER_REQUIRED')
        identities[mode] = identity(receipt)
        log_identities[mode] = {p.name: identity(p) for p in logs}
    return dict(zip(modes, pids)), identities, log_identities


def verify_seal(folder, result, original, trace):
    manifest = 'write-read-seal.json' if original else 'settings-write-seal.json'
    key, verified = ('write_read_seal', 'write_read_seal_verified') if original else ('write_seal', 'write_seal_verified')
    seal = read(folder / manifest)
    names = {'write.json', 'read.json', 'saved-quick.json', 'saved-pause-slot.json', 'transactions.jsonl', *CAPTURES} if original else {
        'settings-write.json', 'saved-settings-quick.json', 'transactions.jsonl'}
    dirname = 'sealed-write-read' if original else 'sealed-settings-write'
    require(seal == result[key] and result[verified] is True and set(seal['files']) == names,
            'EXACT_UNCHANGED_SEAL_MANIFEST_REQUIRED: ' + manifest)
    require(seal['sealed_after_mode'] == ('read' if original else 'settings-write')
            and seal['before_mode'] == ('repeat' if original else 'settings-read')
            and PurePosixPath(seal['root']) == PurePosixPath(result['artifact_root']) / dirname,
            'EXACT_SEAL_TEMPORAL_AND_PATH_BOUNDARY_REQUIRED')
    for name in names:
        sealed = folder / dirname / name
        current = folder / ('captures/' + name if name in CAPTURES else name)
        require(identity(sealed) == seal['files'][name], 'SEALED_BYTES_CHANGED: ' + name)
        if name == 'transactions.jsonl':
            require(current.read_bytes().startswith(sealed.read_bytes()), 'SEALED_TRACE_PREFIX_CHANGED')
            expected_modes = {'write', 'read'} if original else {'settings-write'}
            require([parse(line) for line in sealed.read_text().splitlines()]
                    == [row for row in trace if row['mode'] in expected_modes], 'EXACT_SEALED_TRACE_BOUNDARY_REQUIRED')
        else:
            require(identity(current) == seal['files'][name], 'RETAINED_SEALED_BYTES_CHANGED: ' + name)
    return {'file_count': len(names), 'identity': identity(folder / manifest),
            'sealed_after_mode': seal['sealed_after_mode'], 'before_mode': seal['before_mode'],
            'all_sealed_and_retained_bytes_verified': True}


def verify_semantics(folder, result, catalogue):
    written, restored = (result['reports'][mode] for mode in SETTINGS)
    entered, hosted, saved, continued = (written[name] for name in ('entered', 'hosted', 'saved', 'continued'))
    source = entered['source']
    native = entered['native']
    require(source['profile']['preferences']['reading']['read_aloud_enabled'] is True,
            'ENABLED_READ_ALOUD_POSITIVE_CONTROL_REQUIRED')
    require(hosted == entered and saved['source'] == source and continued == saved, 'EXACT_READING_SOURCE_AND_CONTINUE_REQUIRED')
    require(native['line_id'] == LINE and native['revealing'] is True and integer(native['caption_id'], 1)
            and integer(native['reveal_generation']) and integer(native['total_characters'], 1)
            and integer(native['visible_characters']) and native['visible_characters'] < native['total_characters']
            and finite(native['visible_ratio']) and 0 <= native['visible_ratio'] < 1, 'LITERAL_PARTIAL_REVEAL_REQUIRED')
    full = saved['native']
    require({key: full[key] for key in ('line_id', 'caption_id', 'text', 'total_characters')}
            == {key: native[key] for key in ('line_id', 'caption_id', 'text', 'total_characters')}
            and integer(full['reveal_generation']) and full['reveal_generation'] == native['reveal_generation'] + 1
            and full['revealing'] is False and finite(full['visible_ratio']) and full['visible_ratio'] == 1
            and type(full['visible_characters']) is int and (full['visible_characters'] == -1
                 or full['visible_characters'] >= full['total_characters']), 'ONLY_CURRENT_NATIVE_REVEAL_MUST_COMPLETE')
    host = written['host_before']
    require(host == written['host_after'] and host['tree_paused'] is True and host['visible'] is True
            and host['entered_action'] == 'settings' and host['selected_category'] == 'reading'
            and integer(host['host_id'], 1) and integer(host['focus_id'], 1) and host['focus_path']
            and not PurePosixPath(host['focus_path']).is_absolute() and '..' not in PurePosixPath(host['focus_path']).parts
            and type(host['suspension']) is dict and bool(host['suspension']), 'EXACT_SETTINGS_HOST_FOCUS_AND_SUSPENSION_REQUIRED')
    states = [written['disk_before'], written['disk_after'], restored['disk_before'], restored['disk_after']]
    for state in states:
        require(set(state) == {'quick', 'autosave', 'profile'}, 'EXACT_THREE_DISK_FAMILIES_REQUIRED')
        for family, value in state.items():
            require(set(value) == {'exists', 'bytes', 'sha256'}, 'EXACT_DISK_IDENTITY_FIELDS_REQUIRED')
            if value['exists'] is True:
                require(integer(value['bytes'], 1) and re.fullmatch('[0-9a-f]{64}', value['sha256']), 'VALID_DISK_BYTES_AND_DIGEST_REQUIRED')
            else:
                require(family == 'quick' and value == {'exists': False, 'bytes': 0, 'sha256': ''}, 'ONLY_INITIAL_QUICK_CAN_BE_ABSENT')
    before, after = states[:2]
    require(before['quick']['exists'] is False and after['quick']['exists'] is True
            and before['autosave'] == after['autosave'] and before['profile'] == after['profile']
            and states[1] == states[2] == states[3], 'ONLY_QUICK_APPEARS_AND_READER_DISK_IDENTITIES_REMAIN_UNCHANGED')
    quick_path = folder / 'saved-settings-quick.json'
    quick_id = identity(quick_path)
    require(quick_id == {key: after['quick'][key] for key in ('bytes', 'sha256')}, 'RAW_QUICK_BYTES_MUST_EQUAL_DISK_IDENTITY')
    marker = {'schema_version': 2, 'relative_path': 'quicksave.json', 'operation': 'write_revision',
              'stage': 'prepared', 'previous_hash': None, 'backup_hash': None, 'outgoing_hash': quick_id['sha256']}
    marker_id = digest(json.dumps(marker, sort_keys=True, separators=(',', ':')).encode('ascii'))
    sequence = [('write', 'quicksave.json.txn.json'), ('flush', 'quicksave.json.txn.json'),
                ('write', 'quicksave.json.next'), ('flush', 'quicksave.json.next'),
                ('rename', 'quicksave.json.next'), ('remove', 'quicksave.json.revision-prior'),
                ('remove', 'quicksave.json.bak'), ('remove', 'quicksave.json.txn.json')]
    expected_mutations = []
    for ordinal, (operation, path) in enumerate(sequence, 1):
        row = {'sequence': ordinal, 'owner': 'saves', 'operation': operation, 'path': path, 'ok': True}
        if operation == 'write':
            row.update(marker_id if path.endswith('.txn.json') else quick_id)
        if operation == 'rename':
            row['destination'] = 'quicksave.json'
        expected_mutations.append(row)
    require(written['mutations'] == expected_mutations
            and all(type(row['sequence']) is int and row['ok'] is True for row in written['mutations']),
            'EXACT_SINGLE_SUCCESSFUL_ABSENT_QUICK_REVISION_TRANSACTION_REQUIRED')
    document = read(quick_path)
    require(document['kind'] == 'quick' and document['save_reason'] == 'quick'
            and document['slot_id'] is None and type(document['schema_version']) is int
            and document['schema_version'] == 7, 'REAL_QUICK_DOCUMENT_ENVELOPE_REQUIRED')
    snapshot = document['current_snapshot']['snapshot']
    checkpoint = snapshot['narrative_checkpoint']
    require(checkpoint == source['checkpoint'] == written['saved_checkpoint'] == restored['saved_checkpoint'],
            'RAW_QUICK_CANONICAL_CHECKPOINT_MISMATCH')
    require(snapshot['route_id'] == 'dating' and snapshot['active_app_id'] == 'schedule'
            and written['desktop_context']['active_app_id'] == 'schedule'
            and written['desktop_context'] == restored['desktop_context'], 'TRANSIENT_SETTINGS_MUST_NOT_OWN_CANONICAL_ROUTE')
    physical = snapshot['gameplay']['route_context']['active_dating_challenge']
    require(physical == source['physical_record'] == written['physical_record'] == restored['physical_record']
            and physical['phase'] == 'pre_challenge' and physical['board'] is None
            and physical['outcome'] is None and physical['applied_result'] == {}, 'EXACT_UNGENERATED_DATING_PHYSICAL_SOURCE_REQUIRED')
    session = checkpoint['reading_session']
    entry = next(item for item in catalogue['entries'] if item['entry_id'] == ENTRY)
    line = entry['lines'][0]
    require(catalogue['schema_version'] == 1 and line['line_id'] == line['beat_id'] == LINE
            and checkpoint['entry_id'] == ENTRY and checkpoint['content_version'] == entry['content_version']
            and checkpoint['stage'] == 'pre_challenge' and session['schema_version'] == 1
            and session['boundary'] == 'line' and 'next_operation' not in session, 'EXACT_FIRST_READING_BEAT_REQUIRED')
    expected_caption = {'publication_id': 'caption:1', 'beat': {
        'beat_id': line['beat_id'], 'line_id': LINE, 'owning_entry_id': ENTRY,
        'presentation_signature': {'content_revision': line['revision'], 'variant_id': LINE}}}
    require(session['frontier'] == {'line_id': LINE, 'publication_id': 'caption:1'}
            and session['ledger']['captions'] == [expected_caption]
            and session['ledger']['entry_contexts'] == {ENTRY: checkpoint['frozen_context']}, 'EXACT_ONE_CAPTION_AND_FROZEN_ENTRY_FRAME_REQUIRED')
    frame = snapshot['gameplay']['route_context']['dating_frozen_contexts_v1']['entries'][ENTRY]
    require(frame == checkpoint['frozen_context']['presentation']
            and frame['fields']['run_id'] == snapshot['run_id'] == source['live_session']['run_id']
            and source['live_session']['active'] is True, 'INDEPENDENT_SAVED_RUN_FRAME_MUST_BIND_READING_CONTEXT')
    expected_history = [{'beat_id': line['beat_id'], 'entry_id': ENTRY, 'line_id': LINE,
                         'publication_id': 'caption:1', 'text': line['text']}]
    require(native['text'] == line['text'] and native['total_characters'] == len(line['text'])
            and source['history']['captions'] == expected_history == written['canonical_transcript'] == restored['canonical_transcript']
            and source['history'] == restored['history'] and source['history']['frontier'] == session['frontier']
            and source['history']['session_id'] == session['ledger']['session_token'], 'SOURCE_OWNED_LITERAL_AND_HISTORY_MUST_MATCH_RAW_SAVED_BEAT')
    require(integer(written['speech_admissions'], 1) and written['speech_admissions'] == source['speech_admissions']
            and type(restored['speech_admissions']) is int and restored['speech_admissions'] == 0
            and type(restored['history_observations']) is int and restored['history_observations'] == 1
            and restored['current_line_complete'] is True and restored['profile_unchanged'] is True,
            'FRESH_RESTORE_MUST_BE_COMPLETE_EXACT_AND_SILENT')
    trace = verify_trace(folder, result['reports'], SETTINGS)
    expected_values = [entered, {'reading': hosted, 'host': host},
                       {'reading': saved, 'host': host, 'disk': after, 'mutations': expected_mutations}, written,
                       {'disk': after, 'speech_admissions': 0},
                       {'label': 'settings-restored-history', 'history': restored['history']}, restored]
    require([row['value'] for row in trace] == expected_values, 'ALL_SEVEN_EXECUTED_TRACE_VALUES_MUST_BIND_REPORTS_AND_RAW_QUICK')
    return quick_id, marker_id, trace


def audit(args, output):
    root, repo = args.run_root.resolve(), args.repo.resolve()
    require(all(re.fullmatch('[0-9a-f]{40}', value) for value in (args.source, args.checkout)), 'FULL_EXACT_SOURCE_AND_CHECKOUT_REQUIRED')
    run = read(root / 'run.json')
    require(run['status'] == 'completed' and run['conclusion'] == 'success', 'COMPLETED_SUCCESSFUL_CLOUD_RUN_REQUIRED')
    output.update(run_id=run['id'], run_attempt=run['run_attempt'], source=args.source, checkout=args.checkout)
    output['metadata_identities'] = {name: identity(root / name) for name in ('run.json', 'jobs.json', 'artifacts-api.json', 'artifact-manifest.json')}
    generic_path = root / 'audit/generic-evidence-audit.json'
    generic = read(generic_path)
    boundary = read(root / 'audit/source-provenance.json')
    require(generic['generic_audit_pass'] is True and generic['run']['id'] == run['id']
            and generic['run']['head_sha'] == run['head_sha'] and generic['source_boundary'] == boundary
            and boundary['source'] == args.source and boundary['tested_checkout'] == args.checkout
            and boundary['all_unlisted_paths_byte_identical'] is True, 'COMPLETE_GENERIC_RAW_AND_SOURCE_BINDING_REQUIRED')
    output['generic_audit_binding'] = {'file': 'audit/generic-evidence-audit.json', **identity(generic_path)}
    for name, expected in generic['raw_metadata_identities'].items():
        require(identity(root / safe_relative(name)) == expected, 'GENERIC_METADATA_BINDING_CHANGED: ' + name)
    source_bytes = {path: git_blob(repo, args.source, path) for path in SOURCE_PATHS}
    for path, raw in source_bytes.items():
        require(raw == git_blob(repo, args.checkout, path), 'SOURCE_CHECKOUT_BYTES_DIFFER: ' + path)
    output['source_files'] = {path: digest(raw) for path, raw in source_bytes.items()}
    constants = {}
    for node in ast.parse(source_bytes[DRIVER]).body:
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
            name = node.targets[0].id
            if name in ('SCRIPT', 'MODES', 'NEXT_MODES', 'SETTINGS_MODES', 'CAPTURES'):
                constants[name] = ast.literal_eval(node.value)
    require(constants == {'SCRIPT': 'res://' + SCRIPT, 'MODES': ORIGINAL[:5],
                          'NEXT_MODES': ORIGINAL[5:], 'SETTINGS_MODES': SETTINGS, 'CAPTURES': CAPTURES},
            'FROZEN_DRIVER_MODE_AND_CAPTURE_CONTRACT_CHANGED')
    top, output['artifact_identity'] = verify_archive(root, run)
    result = read(top / 'result.json')
    cloud_parent = PurePosixPath(result['artifact_root'])
    require(cloud_parent.is_absolute() and '..' not in cloud_parent.parts, 'ABSOLUTE_SAFE_CLOUD_ARTIFACT_ROOT_REQUIRED')
    parent_folder = top / cloud_parent.name
    require(read(parent_folder / 'result.json') == result and result['ok'] is True and result['failures'] == []
            and result['checkout_sha'] == args.checkout, 'EXACT_SUCCESSFUL_PARENT_RESULTS_REQUIRED')
    output['parent_report_identity'] = identity(top / 'result.json')
    output['job'] = verify_job(root, run, result, args.checkout)
    original_pids, original_receipts, original_logs = verify_processes(parent_folder, result, ORIGINAL)
    original_trace = verify_trace(parent_folder, result['reports'], ORIGINAL)
    output['original_write_read_seal'] = verify_seal(parent_folder, result, True, original_trace)
    require(len(generic['reading']) == 1 and generic['reading'][0]['report_identity'] == output['parent_report_identity']
            and generic['reading'][0]['process_ids'] == original_pids
            and generic['reading'][0]['write_read_seal']['file_count'] == 14, 'ORIGINAL_GENERIC_READING_PROOF_BINDING_MISMATCH')
    nested = result['settings_quick_save']
    folder = parent_folder / 'settings-quick'
    require(nested == read(folder / 'result.json') and nested['schema_version'] == 1 and nested['ok'] is True
            and nested['failures'] == [] and nested['checkout_sha'] == args.checkout
            and nested['workflow'] == result['workflow']
            and PurePosixPath(nested['artifact_root']) == cloud_parent / 'settings-quick', 'EXACT_BOUND_SUCCESSFUL_NESTED_SETTINGS_RESULT_REQUIRED')
    require(PurePosixPath(nested['isolation_root']) != PurePosixPath(result['isolation_root'])
            and not PurePosixPath(nested['isolation_root']).is_relative_to(PurePosixPath(result['isolation_root']))
            and not PurePosixPath(result['isolation_root']).is_relative_to(PurePosixPath(nested['isolation_root']))
            and PurePosixPath(nested['user_dir']) != PurePosixPath(result['user_dir']), 'SEPARATE_DISJOINT_SETTINGS_PROFILE_REQUIRED')
    require(utc(result['processes']['next-read']['ended_at_utc'])
            <= utc(nested['processes']['user-dir-proof']['started_at_utc']), 'SETTINGS_SUPPLEMENT_MUST_FOLLOW_ORIGINAL_EIGHT_PROCESSES')
    output['process_ids'], output['process_receipt_identities'], output['process_log_identities'] = verify_processes(folder, nested, SETTINGS)
    quick_id, marker_id, trace = verify_semantics(folder, nested, parse(source_bytes[CATALOGUE]))
    output.update(supplemental_report_identity=identity(folder / 'result.json'),
                  original_process_ids=original_pids, original_process_receipt_identities=original_receipts,
                  original_process_log_identities=original_logs,
                  raw_quick_identity=quick_id, reconstructed_transaction_marker_identity=marker_id,
                  trace_identity=identity(folder / 'transactions.jsonl'), trace_entries=len(trace),
                  settings_write_seal=verify_seal(folder, nested, False, trace),
                  isolation={'original': result['isolation_root'], 'settings': nested['isolation_root'],
                             'settings_user_dir': nested['user_dir'], 'disjoint_profiles_verified': True},
                  semantic_assertions={name: True for name in (
                      'partial_reveal_preserved_until_f5', 'only_current_reveal_completed',
                      'exact_settings_host_focus_and_suspension_retained', 'exact_canonical_source_preserved',
                      'single_quick_transaction_verified', 'autosave_profile_identity_receipts_unchanged',
                      'fresh_restore_exact_and_silent', 'original_eight_modes_and_seal_unchanged')},
                  audit_complete=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run-root', type=Path, required=True)
    parser.add_argument('--repo', type=Path, required=True)
    parser.add_argument('--source', required=True)
    parser.add_argument('--checkout', required=True)
    args = parser.parse_args()
    output = {'schema_version': 1, 'audit_complete': False, 'runtime_proof_failures': [], 'pending_areas': [],
              'auditor_identity': identity(Path(__file__)),
              'audit_scope': 'Existing English Solo first-line paused Settings physical F5 and fresh Quick Load; original proof seal retained.',
              'limitations': [
                  'Only Quick raw bytes are retained; Profile/Autosave neutrality is bound to exact size/hash observations and the transparent writer FileOps receipts.',
                  'Mutation receipts use basenames at source-bound owned storage roots; no arbitrary-filesystem or physical-crash coverage is claimed.',
                  'This rendered proof uses Linux software OpenGL and a fixed noncanonical English fixture; Windows GUT, broader authored selectors and native input/accessibility remain separate gates.',
                  'The original eight-process proof remains separately admitted; this audit adds two Settings processes and does not inflate original capture or seal counts.',
              ]}
    try:
        audit(args, output)
    except Exception as error:
        output['audit_complete'] = False
        output['runtime_proof_failures'].append(type(error).__name__ + ': ' + str(error))
        output['pending_areas'] = ['Settings supplemental-proof acceptance has not completed.']
    destination = args.run_root / 'audit/settings-quick-journey-audit.json'
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(output, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print(json.dumps({'output': str(destination), 'audit_complete': output['audit_complete'],
                      'runtime_proof_failures': output['runtime_proof_failures']}))
    raise SystemExit(0 if output['audit_complete'] else 1)


if __name__ == '__main__':
    main()
