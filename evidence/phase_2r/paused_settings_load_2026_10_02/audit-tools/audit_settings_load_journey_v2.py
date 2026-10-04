#!/usr/bin/env python3
"""Source-bound Settings F9 audit with exact external recovery bookkeeping.

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

PREDECESSOR_IDENTITY = {'path': 'audit_settings_load_journey.py', 'bytes': 22169, 'sha256': '9ed27f51a1936eabf03112ddb8adf101f10e89475e865197059071521e75251f'}
MODE = 'settings-load'
STAGES = ('initial', 'advanced', 'entered', 'prepared', 'cancelled', 'reprepared', 'confirmed')
CHECKS = (
    {'retained_f5_input', 'saved_checkpoint_exact', 'saved_history_exact', 'saved_line_complete', 'initial_load_silent', 'initial_load_disk_neutral'},
    {'ordinary_pause_open', 'different_partial_line'},
    {'partial_source_preserved', 'different_saved_line', 'two_history_occurrences', 'settings_interactive', 'reading_category', 'exact_enabled_origin', 'suspension_present', 'new_line_speech_control'},
    {'cancel_first_confirmation', 'bound_quick_candidate', 'no_early_restore', 'source_scene_retained', 'suspension_retained', 'exclusive_modal', 'disk_unchanged', 'zero_mutations'},
    {'exact_partial_source', 'exact_host_focus_scroll_suspension', 'source_scene_retained', 'consent_retired', 'disk_unchanged', 'zero_mutations'},
    {'cancel_first_confirmation', 'bound_quick_candidate', 'no_early_restore', 'source_scene_retained', 'suspension_retained', 'exclusive_modal', 'disk_unchanged', 'zero_mutations'},
    {'load_committed', 'saved_checkpoint_exact', 'saved_history_exact', 'saved_physical_exact', 'saved_app_exact', 'saved_earlier_line_complete', 'restored_live_session', 'old_pause_settings_closed', 'restored_scene_mounted', 'no_restored_speech', 'profile_unchanged', 'disk_unchanged', 'recovery_bookkeeping_only'},
)
EXTRA_SOURCE = ('autoload/SaveManager.gd', 'scripts/application/backup/BackupPresentationPort.gd',
                'scripts/ui/BackupApp.gd', 'scripts/ui/SettingsPanelController.gd', 'scripts/ui/desktop/QuickStatusEdge.gd',
                'tests/integration/verify_playable_startup.gd', 'autoload/InputManager.gd',
                'scripts/application/lifecycle/ProductionPauseController.gd',
                'scripts/ui/witnessed/WitnessedAcceptInput.gd',
                'scripts/infrastructure/save/DesktopContinuationOperationJournal.gd',
                'scripts/infrastructure/identity/DesktopIssuerRootStore.gd',
                'scripts/application/restore/DesktopIdentityAllocationRestoreParticipant.gd')


def helper(path):
    spec = importlib.util.spec_from_file_location('accepted_settings_quick', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def raw_member(raw, member, require):
    """Return an exact JSON object member fragment, preserving numeric spellings."""
    text = raw.decode('utf-8')
    decoder = json.JSONDecoder()
    position = 0
    def space(index):
        while index < len(text) and text[index].isspace(): index += 1
        return index
    position = space(position)
    require(text[position] == '{', 'RAW_FRAGMENT_OBJECT_REQUIRED')
    position += 1
    while True:
        position = space(position)
        require(text[position] != '}', 'RAW_FRAGMENT_MEMBER_MISSING: ' + member)
        key, end = decoder.raw_decode(text, position)
        position = space(end)
        require(text[position] == ':', 'RAW_FRAGMENT_COLON_REQUIRED')
        position = space(position + 1)
        _, end = decoder.raw_decode(text, position)
        if key == member: return text[position:end].encode('utf-8')
        position = space(end)
        require(text[position] == ',', 'RAW_FRAGMENT_MEMBER_MISSING: ' + member)
        position += 1


def verify_recovery(h, folder, root, before, after, quick_path, source_files_raw):
    require = h.require
    recovery_paths = {'issuer': ('profile', 'desktop-issuer-root.json'),
                      'continuation': ('saves', 'desktop-continuation-operations.json')}
    endpoints, bindings = {}, {}
    for stage, observed in (('before', before['recovery']), ('after', after['recovery'])):
        require(set(observed) == set(recovery_paths), 'EXACT_TWO_RECOVERY_ENDPOINT_FAMILIES_REQUIRED')
        endpoints[stage], bindings[stage] = {}, {}
        for key in recovery_paths:
            path = folder / f'settings-load-recovery-{stage}-{key}.json'
            require(h.identity(path) == observed[key], 'RAW_RECOVERY_ENDPOINT_OBSERVATION_DIFFERS: ' + stage + '/' + key)
            endpoints[stage][key] = h.read(path)
            bindings[stage][key] = {'file': path.relative_to(root).as_posix(), **h.identity(path)}
    save_source = source_files_raw['autoload/SaveManager.gd'].decode()
    journal_source = source_files_raw['scripts/infrastructure/save/DesktopContinuationOperationJournal.gd'].decode()
    def order(text, name):
        match = re.search(r'const ' + re.escape(name) + r': Array\[String\] = \[(.*?)\]', text, re.S)
        require(match is not None, 'EXPLICIT_RESTORE_PARTICIPANT_ORDER_REQUIRED')
        return re.findall(r'"([a-z_]+)"', match[1])
    participants = order(save_source, '_PARTICIPANT_APPLY_ORDER')
    require(participants == order(journal_source, 'PARTICIPANT_ORDER') == [
        'run', 'desktop_consequence', 'desktop_board', 'schedule_view', 'profile', 'localization', 'audio', 'route', 'narrative'],
        'EXACT_EXISTING_NINE_RESTORE_PARTICIPANTS_REQUIRED')
    blocks = ['issuer', 'continuation', 'issuer'] + ['continuation'] * (len(participants) + 4)
    steps = [('write','.txn.json'), ('flush','.txn.json'), ('write','.next'), ('flush','.next'),
             ('write','.txn.json'), ('flush','.txn.json'), ('remove','.bak'), ('rename','', '.bak'),
             ('write','.txn.json'), ('flush','.txn.json'), ('rename','.next',''),
             ('write','.txn.json'), ('flush','.txn.json'), ('remove','.txn.json')]
    mutations = after['mutations']
    require(type(mutations) is list and len(mutations) == len(blocks) * len(steps) == 224,
            'EXACT_SIXTEEN_EXISTING_ATOMIC_RECOVERY_COMMITS_REQUIRED')
    previous = {key: before['recovery'][key]['sha256'] for key in recovery_paths}
    last_payload = {}
    marker_count = 0
    for block, key in enumerate(blocks):
        owner, filename = recovery_paths[key]
        rows = mutations[block * len(steps):(block + 1) * len(steps)]
        payload = rows[2]
        require(h.integer(payload.get('bytes'), 1) and re.fullmatch('[0-9a-f]{64}', payload.get('sha256','')),
                'VALID_OBSERVED_RECOVERY_PAYLOAD_IDENTITY_REQUIRED')
        outgoing = payload['sha256']
        markers = {}
        for index, stage, next_hash, backup_hash in ((0,'prepared',None,None),
                (4,'next_validated',outgoing,None), (8,'backup_preserved',outgoing,previous[key]),
                (11,'final_promoted',outgoing,previous[key])):
            marker = {'backup_hash': backup_hash, 'keep_backup': True, 'next_hash': next_hash,
                      'operation': 'write', 'outgoing_hash': outgoing, 'previous_hash': previous[key],
                      'relative_path': filename, 'schema_version': 1, 'stage': stage}
            markers[index] = h.digest(json.dumps(marker,sort_keys=True,separators=(',',':')).encode('ascii'))
        for index, (row, step) in enumerate(zip(rows,steps)):
            expected = {'sequence': block * len(steps) + index + 1, 'owner': owner, 'ok': True,
                        'operation': step[0], 'path': filename + step[1]}
            if step[0] == 'rename': expected['destination'] = filename + step[2]
            if step[0] == 'write':
                expected.update(markers[index] if index in markers else {k: payload[k] for k in ('bytes','sha256')})
            require(row == expected and type(row['sequence']) is int and row['ok'] is True,
                    f'EXACT_SOURCE_BOUND_ATOMIC_RECOVERY_RECEIPT_REQUIRED: {block}/{index}')
        marker_count += len(markers)
        previous[key] = outgoing
        last_payload[key] = {k: payload[k] for k in ('bytes','sha256')}
    require(last_payload == after['recovery'], 'LAST_RECOVERY_PAYLOADS_MUST_EQUAL_RAW_FINAL_ENDPOINTS')
    before_journal, after_journal = endpoints['before']['continuation'], endpoints['after']['continuation']
    require(set(before_journal) == set(after_journal) == {'schema_version','operations'}
            and type(before_journal['schema_version']) is int and before_journal['schema_version'] == after_journal['schema_version'] == 4,
            'EXACT_EXISTING_CONTINUATION_JOURNAL_FORMAT_REQUIRED')
    old_ops, new_ops = before_journal['operations'], after_journal['operations']
    added = set(new_ops) - set(old_ops)
    require(len(added) == 1 and set(old_ops) <= set(new_ops)
            and all(new_ops[key] == value for key,value in old_ops.items()), 'EXACTLY_ONE_RESTORE_OPERATION_MUST_BE_APPENDED')
    transaction = next(iter(added))
    operation = new_ops[transaction]
    require(operation['transaction_id'] == transaction and operation['kind'] == 'restore'
            and operation['stage'] == 'completed' and operation['failure'] is None
            and operation['next_participant_index'] == len(participants)
            and set(operation['participant_receipts']) == set(participants)
            and all(type(operation['participant_receipts'][key]) is dict for key in participants)
            and operation['initial_context'] is None and operation['initial_context_sha256'] is None,
            'ONE_COMPLETED_RESTORE_WITH_ALL_PARTICIPANT_RECEIPTS_REQUIRED')
    quick_raw = quick_path.read_bytes()
    bundle_raw = raw_member(quick_raw, 'current_snapshot', require)
    snapshot_raw = raw_member(bundle_raw, 'snapshot', require)
    bundle, snapshot = h.parse(bundle_raw), h.parse(snapshot_raw)
    require(operation['source_locator'] == {'slot_id':'quick', 'bundle_id':h.digest(bundle_raw)['sha256'],
            'document_sha256':h.digest(snapshot_raw)['sha256'], 'checkpoint_id':snapshot['checkpoint_id']},
            'COMPLETED_RESTORE_MUST_BIND_EXACT_RAW_QUICK_BUNDLE_AND_SNAPSHOT')
    require(after['load_result']['value']['checkpoint_id'] == snapshot['checkpoint_id'], 'CONFIRMED_RESULT_MUST_NAME_SAVED_CHECKPOINT')
    require(operation['request_fingerprint'] == h.digest(json.dumps({'kind':'restore','transaction_id':transaction,
            'source_locator':operation['source_locator']},sort_keys=True,separators=(',',':')).encode('utf-8'))['sha256'],
            'RESTORE_REQUEST_FINGERPRINT_MUST_BIND_SOURCE_AND_TRANSACTION')
    before_issuer, after_issuer = endpoints['before']['issuer'], endpoints['after']['issuer']
    require(set(before_issuer) == set(after_issuer) == {'schema_version','namespace','next_counter','receipts','allocation_receipts','day_advance_allocation_receipts'}
            and before_issuer['schema_version'] == after_issuer['schema_version'] == 1
            and before_issuer['namespace'] == after_issuer['namespace']
            and before_issuer['day_advance_allocation_receipts'] == after_issuer['day_advance_allocation_receipts'],
            'EXTERNAL_ISSUER_NAMESPACE_FORMAT_AND_DAY_HISTORY_MUST_SURVIVE')
    old_alloc, new_alloc = before_issuer['allocation_receipts'], after_issuer['allocation_receipts']
    require(set(new_alloc) == set(old_alloc) | {transaction} and transaction not in old_alloc
            and all(new_alloc[key] == value for key,value in old_alloc.items()), 'EXACTLY_ONE_MATCHING_ISSUER_ALLOCATION_REQUIRED')
    allocation = new_alloc[transaction]
    require(allocation == operation['allocation_receipt'] and allocation['kind'] == 'restore'
            and allocation['root_namespace'] == before_issuer['namespace'] and allocation['run_id'] == snapshot['run_id']
            and allocation['run_id_issuer_receipt'] is None
            and allocation['request']['transaction_id'] == transaction
            and allocation['request']['transaction_issuer_receipt'] == operation['transaction_issuer_receipt']
            and allocation['request']['kind'] == 'restore' and allocation['request']['existing_run_id'] == snapshot['run_id']
            and allocation['request']['source_desktop_timeline_generation'] == snapshot['lifecycle']['desktop_timeline_generation']
            and allocation['desktop_timeline_generation'] == snapshot['lifecycle']['desktop_timeline_generation'] + 1,
            'RESTORE_ALLOCATION_MUST_PRESERVE_RUN_AND_ADVANCE_SOURCE_GENERATION')
    allocation_raw = raw_member(raw_member((folder/'settings-load-recovery-after-issuer.json').read_bytes(), 'allocation_receipts', require), transaction, require)
    require(operation['allocation_candidate_fingerprint'] == h.digest(allocation_raw)['sha256'], 'RAW_ALLOCATION_FINGERPRINT_MISMATCH')
    issued = operation['transaction_issuer_receipt']
    require(issued['purpose'] == 'transaction_id' and issued['token'] == transaction
            and issued['counter'] == before_issuer['next_counter'], 'EXACT_NEW_RESTORE_TRANSACTION_RECEIPT_REQUIRED')
    expected_receipts = [operation['transaction_issuer_receipt'], allocation['branch_id_issuer_receipt'],
                         allocation['desktop_timeline_generation_issuer_receipt'], allocation['causal_day_instance_issuer_receipt']]
    expected_receipts += [allocation['remap_transaction_issuer_receipts'][key] for key in allocation['request']['remap_source_transaction_ids']]
    new_receipts = {receipt['receipt_id']:receipt for receipt in expected_receipts}
    old_receipts, actual_receipts = before_issuer['receipts'], after_issuer['receipts']
    require(len(new_receipts) == len(expected_receipts) and not (set(new_receipts) & set(old_receipts))
            and actual_receipts == old_receipts | new_receipts
            and h.integer(before_issuer['next_counter']) and h.integer(after_issuer['next_counter'])
            and [row['counter'] for row in expected_receipts] == list(range(before_issuer['next_counter'], after_issuer['next_counter']))
            and allocation['root_next_counter'] == before_issuer['next_counter'] + 1,
            'PRIOR_ISSUER_RECEIPTS_MUST_SURVIVE_WITH_EXACT_CONTIGUOUS_RESTORE_ALLOCATION_ADDITIONS')
    return {'atomic_transactions':len(blocks),'fileops_observations':len(mutations),
        'reconstructed_marker_writes':marker_count,'raw_endpoint_bindings':bindings,
        'new_restore_transaction_id':transaction,'all_prior_operations_and_issuer_receipts_preserved':True,
        'new_issuer_receipts':len(new_receipts),'participant_order':participants,
        'retained_quick_source_locator':operation['source_locator'],'terminal_stage':'completed'}


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
    source_files_raw = {}
    for path in EXTRA_SOURCE:
        raw = h.git_blob(repo, a.source, path)
        require(raw == h.git_blob(repo, a.checkout, path), 'LOAD_SOURCE_CHECKOUT_DIFFERENCE: ' + path)
        source_files[path] = h.digest(raw)
        source_files_raw[path] = raw
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
            and after['disk'] == before['disk'], 'LOAD_MUST_NOT_REPEAT_SPEECH_OR_CHANGE_PRIMARY_FILES')
    recovery = verify_recovery(h, folder, root, before, after, quick_path, source_files_raw)
    runner_recovery = {'raw_endpoints': {stage: {key: {field: record[field] for field in ('bytes','sha256')}
            for key,record in recovery['raw_endpoint_bindings'][stage].items()} for stage in ('before','after')},
        'operation_count': recovery['fileops_observations'], 'atomic_commits': recovery['atomic_transactions'],
        'transaction_id': recovery['new_restore_transaction_id'], 'source_locator': recovery['retained_quick_source_locator'],
        'completed_participants': sorted(recovery['participant_order']), 'primary_file_operation_attempts': 0,
        'prior_recovery_records_preserved': True,
        'intermediate_journal_semantics': 'source-bound operation sequence; raw endpoints retained'}
    raw_validation = {'raw_input': inputs, 'raw_paused_source': {key: identity(folder / f'settings-load-baseline-{key}.json') for key in raw},
                      'raw_final': {key: identity(folder / f'final-{key}.json') for key in raw},
                      'cancel_exact_partial_source_focus_scroll': True, 'fresh_confirm_saved_earlier_line': True,
                      'saved_history_physical_app_restored': True, 'old_pause_settings_closed': True,
                      'primary_file_mutations': 0, 'recovery_bookkeeping_mutations': recovery['fileops_observations'],
                      'recovery_bookkeeping': runner_recovery, 'restored_speech_admissions': 0, 'stage_observations': len(STAGES)}
    require(result['validation'] == raw_validation, 'RUNNER_VALIDATION_MUST_EQUAL_INDEPENDENT_RAW_RESULT')
    return {'schema_version': 1, 'audit_complete': True, 'run_id': run['id'], 'run_attempt': run['run_attempt'],
        'source': a.source, 'checkout': a.checkout, 'workflow_head': run['head_sha'], 'job': f5['job'],
        'artifact_identity': f5['artifact_identity'], 'source_files': source_files,
        'auditor_identity': identity(Path(__file__)), 'accepted_f5_auditor_identity': identity(a.f5_auditor),
        'predecessor_auditor_identity': PREDECESSOR_IDENTITY,
        'corrected_assertion': 'Confirmed restore preserves primary Quick/Autosave/Profile bytes while executing the existing issuer-root and continuation recovery protocol; the prior zero-all-mutations assumption was incorrect.',
        'preserved_f5_and_original_audit': f5, 'load_process_id': pid, 'load_process_file_identities': process_files,
        'supplemental_report': {'file': (folder / 'result.json').relative_to(root).as_posix(), **identity(folder / 'result.json')},
        'trace': {'file': (folder / 'settings-load-transactions.jsonl').relative_to(root).as_posix(), **identity(folder / 'settings-load-transactions.jsonl'), 'entries': len(STAGES)},
        'physical_input_protocol': {'file': input_path.relative_to(root).as_posix(), **identity(input_path),
            'packet_count': len(packets), 'frames': [packet['frame'] for packet in packets],
            'distinct_contact_generations': [generation for _, generation in active_contacts],
            'fresh_released_accept_then_admitted_physical_back': True},
        'raw_file_bindings': raw, 'recovery_bookkeeping_audit': recovery, 'semantic_assertions': raw_validation,
        'limitations': [
            'Bounded noncanonical English catalogue-v1 Solo pre-challenge fixture: saved A, physically advanced partly revealed B, Cancel exact B, Confirm exact saved A.',
            'Initial, paused-source and final Quick/Autosave/Profile primary files remain byte-neutral with no mutation attempts. Confirmed Load performs exactly sixteen existing internal recovery transactions; this is not zero filesystem writes.',
            'Four raw recovery endpoints bind one appended completed restore and issuer allocation, preserving earlier records. All 224 FileOps receipts and 64 reconstructed marker hashes match the source-derived atomic sequence; intermediate journal payloads themselves are not retained or semantically decoded.',
            'These bounded source-bound receipts do not establish arbitrary-filesystem or actual OS-crash behavior.',
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
    target = a.output or a.run_root / 'audit/settings-load-journey-v2-audit.json'
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
