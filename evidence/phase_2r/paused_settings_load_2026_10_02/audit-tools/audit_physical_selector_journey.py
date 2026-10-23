#!/usr/bin/env python3
"""Independently join retained physical selector cloud bytes and executed receipts.

No Godot, PowerShell, network, Git mutation, driver import, or evidence repair.
A completed component audit does not substitute for the canonical broad gate.
"""
from __future__ import annotations
import argparse
import ast
from copy import deepcopy
from datetime import datetime
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import stat
import struct
import subprocess
import zipfile

PRE = 'dating.solo.priscilla.day1.pre_challenge'
POST = 'dating.solo.priscilla.day1.post_challenge'
LINES = ['fixture.selector.pre.a', 'fixture.selector.pre.b', 'fixture.selector.post.a', 'fixture.selector.post.b']
DRIVER = 'tools/testing/run_solo_authored_selector_journey.py'
SCRIPT = 'tests/integration/verify_solo_authored_selector_journey.gd'
CATALOGUE = 'tests/fixtures/dialogic/solo_authored_selector_catalogue.json'
DTL = 'tests/fixtures/dialogic/solo_authored_selector.dtl'
CAPTURES = ('01-title.png', '02-desktop.png', '03-minesweeper.png', '04-pre-history.png',
            '05-dating-board.png', '06-post-history.png', '07-post-save.png',
            '08-restored-history.png', '09-restored-line.png')
TRACE = {
    'write': ('fixture_registered', 'history_inspected', 'pre_history', 'committed_result_then_post_prose',
              'next_unseen_verified', 'next_destination_verified', 'history_inspected', 'quick_committed'),
    'read': ('fresh_restore_prepared', 'forged_checkpoint_refused', 'history_inspected', 'fresh_restore_verified'),
}
RETAINED = ('saved-quick.json', 'saved-profile.json', 'saved-next-source.json', 'saved-next-destination.json')


def require(value, message):
    if not value:
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


def identity(path):
    with path.open('rb') as stream:
        return {'bytes': path.stat().st_size, 'sha256': hashlib.file_digest(stream, 'sha256').hexdigest()}


def canonical_hash(value):
    def bounded(item):
        if isinstance(item, dict):
            return all(isinstance(k, str) and bounded(k) and bounded(v) for k, v in item.items())
        if isinstance(item, list):
            return all(bounded(x) for x in item)
        if isinstance(item, str):
            return all(32 <= ord(c) <= 126 for c in item)
        return item is None or type(item) in (bool, int)
    require(bounded(value), 'CANONICAL_HASH_EXCEEDS_EXACT_ASCII_INTEGER_FIXTURE_DOMAIN')
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def git_source(repo, revision, path):
    return subprocess.check_output(['git', '-C', str(repo), 'show', revision + ':' + path])


def clean(line):
    return re.sub(r'^\ufeff?\d{4}-\d\d-\d\dT\S+\s', '', re.sub(r'\x1b\[[0-9;]*m', '', line)).strip()


def selected(catalogue, frames, native):
    require(set(frames) == {PRE, POST}, 'EXACT_INDEPENDENT_PRE_POST_RUN_FRAMES_REQUIRED')
    result = {}
    for entry in catalogue['entries']:
        key = entry['entry_id']
        selectors = {name: frames[key]['fields'][name] for name in entry['selector_fields']}
        matches = [row for row in entry['variants'] if row['selector_values'] == selectors]
        require(len(matches) == 1, 'ONE_EXACT_FINITE_SELECTOR_ROW_REQUIRED: ' + key)
        row = matches[0]
        require(native[row['label']] == [line['text'] + ' #id:' + line['line_id'] for line in row['lines']],
                'FIXED_NATIVE_PROGRAMME_MUST_EQUAL_SELECTED_AUTHORED_LINES')
        beats = [{'beat_id': line['beat_id'], 'line_id': line['line_id'], 'owning_entry_id': key,
                  'presentation_signature': {'content_revision': line['revision'], 'variant_id': line['variant_id'],
                                            'selectors': {name: selectors[name] for name in line['selector_fields']}}}
                 for line in row['lines']]
        result[key] = {'entry_id': key, 'content_version': entry['content_version'], 'label': row['label'],
                       'lines': row['lines'], 'beats': beats, 'selectors': selectors}
    return result


def projected(plan, phase):
    ledger = deepcopy(plan['source_ledger'])
    frontier = deepcopy(plan['source_frontier'])
    require(plan['destination']['kind'] == 'line' and plan['traversed_captions'] == [], 'BOUNDED_NEXT_LINE_WITH_NO_TRAVERSED_CAPTIONS_REQUIRED')
    if phase == 'destination':
        row = deepcopy(plan['destination']['caption'])
        ledger['captions'].append(row)
        frontier = {'line_id': row['beat']['line_id'], 'publication_id': row['publication_id']}
    return {'schema_version': 2, 'catalogue_fingerprint': plan['catalogue_fingerprint'],
            'boundary': 'line', 'ledger': ledger, 'frontier': frontier,
            'next_operation': {'schema_version': 1, 'operation_id': canonical_hash(plan), 'phase': phase, 'plan': plan}}


def verify_archive(root, run):
    api = read(root / 'artifacts-api.json')
    require(api.get('total_count', len(api['artifacts'])) == len(api['artifacts']), 'ARTIFACT_PAGINATION_REQUIRED')
    candidates = []
    for item in api['artifacts']:
        match = re.fullmatch('solo-authored-selector-' + str(run['id']) + r'-(\d+)', item['name'])
        if match:
            candidates.append((int(match[1]), item))
    require(candidates, 'RETAINED_SOLO_AUTHORED_SELECTOR_ARTIFACT_REQUIRED')
    attempt, item = max(candidates, key=lambda row: row[0])
    require(item['workflow_run']['id'] == run['id'] and item['workflow_run']['head_sha'] == run['head_sha'],
            'ARTIFACT_MUST_BIND_RUN_WORKFLOW_HEAD_INDEPENDENT_OF_TEST_CHECKOUT')
    records = [row for row in read(root / 'artifact-manifest.json') if row['id'] == item['id']]
    require(len(records) == 1, 'ONE_ORIGINAL_ARTIFACT_DOWNLOAD_REQUIRED')
    archive_path = Path(records[0]['local_zip'])
    require(identity(archive_path) == {'bytes': item['size_in_bytes'], 'sha256': item['digest'].removeprefix('sha256:')},
            'ORIGINAL_ZIP_MUST_MATCH_GITHUB_API_BYTES_AND_DIGEST')
    folder = root / 'artifacts' / item['name']
    with zipfile.ZipFile(archive_path) as archive:
        members = [m for m in archive.infolist() if not m.is_dir()]
        names = {m.filename for m in members}
        require(len(names) == len(members), 'DUPLICATE_ARTIFACT_ZIP_MEMBER')
        for member in members:
            relative = PurePosixPath(member.filename)
            require(not relative.is_absolute() and '..' not in relative.parts and '\\' not in member.filename
                    and ':' not in member.filename and not stat.S_ISLNK(member.external_attr >> 16), 'UNSAFE_ARTIFACT_MEMBER')
            path = folder / member.filename
            require(path.is_file() and not path.is_symlink(), 'EXTRACTED_ARTIFACT_MEMBER_REQUIRED: ' + member.filename)
            with archive.open(member) as stream:
                digest = hashlib.file_digest(stream, 'sha256').hexdigest()
            require(identity(path) == {'bytes': member.file_size, 'sha256': digest}, 'EXTRACTED_ARTIFACT_BYTES_MISMATCH: ' + member.filename)
        require({p.relative_to(folder).as_posix() for p in folder.rglob('*') if p.is_file()} == names, 'EXACT_EXTRACTED_ARTIFACT_MEMBER_SET_REQUIRED')
    return folder, {'id': item['id'], 'name': item['name'], 'attempt': attempt, 'workflow_head': run['head_sha'],
                    'zip_identity': identity(archive_path), 'verified_members': len(members)}


def verify_job(root, run, result, checkout, job_name):
    records = read(root / 'jobs.json')
    require(records.get('total_count', len(records['jobs'])) == len(records['jobs']), 'JOB_PAGINATION_REQUIRED')
    if job_name:
        candidates = [job for job in records['jobs'] if job['name'] == job_name]
    else:
        candidates = [job for job in records['jobs'] if any('run_solo_authored_selector_journey.py' in
                      (root / 'logs' / (str(job['id']) + '.log')).read_text(encoding='utf-8-sig')
                      for _ in [0] if (root / 'logs' / (str(job['id']) + '.log')).exists())]
    require(candidates, 'EXACT_PHYSICAL_SELECTOR_CLOUD_JOB_REQUIRED')
    job = max(candidates, key=lambda row: (row.get('run_attempt', 1), row['id']))
    require(job['status'] == 'completed' and job['conclusion'] == 'success', 'PHYSICAL_SELECTOR_JOB_NOT_SUCCESS')
    aliases = [j for j in records['jobs'] if all(j.get(k) == job.get(k) for k in ('name', 'status', 'conclusion', 'started_at', 'completed_at', 'runner_id', 'steps'))]
    execution = min(aliases, key=lambda row: (row.get('run_attempt', 1), row['id']))
    path = root / 'logs' / (str(execution['id']) + '.log')
    log = path.read_text(encoding='utf-8-sig')
    lines = [clean(line) for line in log.splitlines()]
    checkouts = [lines[i + 1] for i, line in enumerate(lines[:-1]) if 'log -1 --format=%H' in line and re.fullmatch(r'[0-9a-f]{40}', lines[i + 1])]
    require(checkouts and all(value == checkout for value in checkouts), 'JOB_LOG_MUST_PROVE_EXACT_TESTED_CHECKOUT')
    require(DRIVER in log and 'SOLO_AUTHORED_SELECTOR_CLOUD_RESULT:' in log, 'DRIVER_INVOCATION_AND_RESULT_MUST_BE_EXECUTED')
    emitted = [parse(line.split('SOLO_AUTHORED_SELECTOR_CLOUD_RESULT: ', 1)[1]) for line in lines
               if line.startswith('SOLO_AUTHORED_SELECTOR_CLOUD_RESULT: ')]
    require(len(emitted) == 1 and emitted[0]['ok'] is True and emitted[0]['failures'] == []
            and emitted[0]['checkout_sha'] == checkout and emitted[0]['artifact_root'] == result['artifact_root'], 'EXECUTED_DRIVER_RESULT_MUST_MATCH_RETAINED_RESULT')
    workflow = result['workflow']
    event_sha = checkout if run['event'] == 'pull_request' else run['head_sha']
    require(run['event'] in ('push', 'pull_request'), 'REVIEW_UNSUPPORTED_WORKFLOW_EVENT')
    require(str(workflow['GITHUB_RUN_ID']) == str(run['id'])
            and int(workflow['GITHUB_RUN_ATTEMPT']) == execution.get('run_attempt', 1)
            and workflow['GITHUB_SHA'] == event_sha and bool(workflow['GITHUB_JOB']), 'DRIVER_WORKFLOW_METADATA_MISMATCH')
    return {'name': job['name'], 'job_id': job['id'], 'execution_job_id': execution['id'],
            'log': path.relative_to(root).as_posix(), 'log_identity': identity(path), 'checkout_shas': checkouts,
            'github_job': workflow['GITHUB_JOB']}


def audit(args, output):
    root = args.run_root.resolve()
    require(all(re.fullmatch('[0-9a-f]{40}', rev) for rev in (args.source, args.checkout)), 'FULL_SOURCE_AND_CHECKOUT_SHA_REQUIRED')
    run = read(root / 'run.json')
    output.update(run_id=run['id'], run_attempt=run.get('run_attempt', 1), source=args.source, checkout=args.checkout)
    output['metadata_identities'] = {name: identity(root / name) for name in ('run.json', 'jobs.json', 'artifacts-api.json', 'artifact-manifest.json')}
    require(run['status'] == 'completed' and run['conclusion'] == 'success', 'COMPLETED_SUCCESSFUL_RUN_REQUIRED')
    sources = {}
    for path in (DRIVER, SCRIPT, CATALOGUE, DTL, 'tools/testing/run_cloud_journeys.py',
                 'scripts/narrative/ReadingTraversalOperation.gd', 'scripts/validation/CanonicalJsonWriter.gd'):
        source = git_source(args.repo, args.source, path)
        require(source == git_source(args.repo, args.checkout, path), 'SOURCE_CHECKOUT_BYTES_DIFFER: ' + path)
        sources[path] = {'bytes': len(source), 'sha256': hashlib.sha256(source).hexdigest()}
    output['source_files'] = sources
    driver = git_source(args.repo, args.source, DRIVER).decode()
    constants = {}
    for node in ast.parse(driver).body:
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name) and node.targets[0].id in ('MODES', 'TRACE_KINDS', 'CAPTURES', 'SCRIPT', 'CATALOGUE'):
            constants[node.targets[0].id] = ast.literal_eval(node.value)
    require(constants == {'MODES': ('write', 'read'), 'TRACE_KINDS': TRACE, 'CAPTURES': CAPTURES,
                          'SCRIPT': 'res://' + SCRIPT, 'CATALOGUE': CATALOGUE}, 'FROZEN_DRIVER_CONTRACT_CHANGED_REVIEW_AUDITOR')
    catalogue = parse(git_source(args.repo, args.source, CATALOGUE))
    native_text = git_source(args.repo, args.source, DTL).decode()
    native = {match[1]: match[2].strip().splitlines() for match in re.finditer(r'^label (\S+)\n(.*?)^return\s*$', native_text, re.M | re.S)}
    top, output['artifact_identity'] = verify_archive(root, run)
    result = read(top / 'result.json')
    folder = top / PurePosixPath(result['artifact_root']).name
    require(read(folder / 'result.json') == result and result['ok'] is True and result['failures'] == []
            and result['checkout_sha'] == args.checkout, 'EXACT_SUCCESSFUL_RAW_AND_TOP_DRIVER_RESULTS_REQUIRED')
    output['job'] = verify_job(root, run, result, args.checkout, args.job_name)
    output['report_identity'] = identity(top / 'result.json')
    reports = {mode: read(folder / (mode + '.json')) for mode in TRACE}
    require(reports == result['reports'] and set(result['processes']) == {'write', 'read', 'user-dir-proof'}, 'EXACT_TWO_REPORT_THREE_PROCESS_SET_REQUIRED')
    pids = [row['process_id'] for row in reports.values()]
    require(all(type(pid) is int and pid > 0 for pid in pids) and len(set(pids)) == 2, 'TWO_DISTINCT_POSITIVE_PROCESS_IDS_REQUIRED')
    for mode, report in reports.items():
        require(report['mode'] == mode and report['schema_version'] == 1
                and PurePosixPath(report['user_dir']) == PurePosixPath(result['user_dir']), 'RAW_REPORT_MODE_OR_ISOLATION_MISMATCH')
    isolated = PurePosixPath(result['isolation_root'])
    user = PurePosixPath(result['user_dir'])
    require(user.is_absolute() and user.is_relative_to(isolated) and user != isolated
            and user.is_relative_to(PurePosixPath(result['isolated_environment']['XDG_DATA_HOME'])), 'REAL_USER_DIRECTORY_MUST_BE_STRICTLY_ISOLATED')
    for mode, process in result['processes'].items():
        require(read(folder / (mode + '.process.json')) == process and process['exit_code'] == 0 and process['timed_out'] is False, 'ACTUAL_SUCCESSFUL_FRESH_PROCESS_REQUIRED: ' + mode)
        logs = [folder / (mode + '.log'), folder / PurePosixPath(process['stdout']).name, folder / PurePosixPath(process['stderr']).name]
        for log in logs:
            text = log.read_text(encoding='utf-8-sig')
            require(re.search(r'SCRIPT ERROR:|(?:^|\s)ERROR:|Unicode parsing error|Unexpected NUL character|Parse Error:|SOLO_AUTHORED_SELECTOR_FAIL:|Resource still in use:|Leaked instance:|Orphan StringName:', text, re.M) is None, 'ENGINE_OR_ASSERTION_OR_LIFETIME_ERROR: ' + log.name)
        stdout = logs[1].read_text(encoding='utf-8-sig')
        if mode in TRACE:
            require('res://' + SCRIPT in process['argv'] and '--solo-authored-selector-mode=' + mode in process['argv']
                    and '--headless' not in process['argv'] and 'gl_compatibility' in process['argv'], 'EXECUTED_RENDERED_MODE_ARGUMENTS_REQUIRED')
            require(len(re.findall(r'^SOLO_AUTHORED_SELECTOR_' + mode.upper() + '_PASS:', stdout, re.M)) == 1, 'EXACT_EXECUTED_PASS_MARKER_REQUIRED: ' + mode)
        else:
            markers = re.findall(r'^PHASE2R_USER_DIR=(.+)$', stdout, re.M)
            require(len(markers) == 1 and PurePosixPath(markers[0].strip()) == user, 'EXECUTED_USER_DIRECTORY_PROOF_MISMATCH')
    require(datetime.fromisoformat(result['processes']['write']['ended_at_utc'])
            <= datetime.fromisoformat(result['processes']['read']['started_at_utc']), 'READER_PROCESS_MUST_START_AFTER_WRITER_EXIT')
    output['process_receipt_identities'] = {mode: identity(folder / (mode + '.process.json')) for mode in result['processes']}
    written, restored = reports['write'], reports['read']
    trace_path = folder / 'transactions.jsonl'
    trace = [parse(line) for line in trace_path.read_text().splitlines()]
    require([(entry['mode'], entry['kind']) for entry in trace] == [(mode, kind) for mode, kinds in TRACE.items() for kind in kinds], 'EXACT_EXECUTED_TRACE_ORDER_REQUIRED')
    by_kind = {}
    for mode, kinds in TRACE.items():
        observed = [entry for entry in trace if entry['mode'] == mode]
        require([row['sequence'] for row in observed] == list(range(1, len(kinds) + 1))
                and all(row['process_id'] == reports[mode]['process_id'] for row in observed), 'TRACE_PROCESS_OR_SEQUENCE_MISMATCH')
        by_kind.update({row['kind']: row['value'] for row in observed})
    for kind, mode, key in [('next_unseen_verified', 'write', 'unseen_stop'), ('next_destination_verified', 'write', 'next'), ('forged_checkpoint_refused', 'read', 'forged_checkpoint')]:
        require(by_kind[kind] == reports[mode][key], 'EXECUTED_TRACE_AND_REPORT_PROOF_DIFFER: ' + kind)
    for kind, report in [('quick_committed', written), ('fresh_restore_verified', restored)]:
        require(by_kind[kind]['checkpoint'] == report['saved_checkpoint'], 'EXECUTED_TRACE_CHECKPOINT_MISMATCH')
    inspected = [entry for entry in trace if entry['kind'] == 'history_inspected']
    require([(entry['mode'], entry['value']['label']) for entry in inspected]
            == [('write', '04-pre-history'), ('write', '06-post-history'), ('read', '08-restored-history')],
            'EXACT_EXECUTED_PRE_POST_RESTORED_HISTORY_INSPECTIONS_REQUIRED')
    for entry, count in zip(inspected, (2, 4, 4)):
        require(entry['value']['history']['captions'] == reports[entry['mode']]['canonical_transcript'][:count],
                'RENDERED_HISTORY_INSPECTION_MUST_EQUAL_EXACT_SELECTED_TRANSCRIPT')
    documents = {name: read(folder / name) for name in RETAINED}
    retained = {name: identity(folder / name) for name in RETAINED}
    for stem, name in [('quick', 'saved-quick.json'), ('profile', 'saved-profile.json')]:
        expected = {'bytes': written[stem + '_bytes'], 'sha256': written[stem + '_sha256']}
        require(retained[name] == expected == {'bytes': restored[stem + '_bytes'], 'sha256': restored[stem + '_sha256']}, 'PHYSICAL_QUICK_PROFILE_BYTES_MISMATCH: ' + stem)
        for phase in ('before', 'after'):
            observed_name = 'read-' + phase + '-' + stem + '.json'
            observed = folder / observed_name
            require(observed.read_bytes() == (folder / name).read_bytes(), 'FRESH_READER_RAW_BEFORE_AFTER_BYTES_MUST_EQUAL_WRITER: ' + observed_name)
            retained[observed_name] = identity(observed)
    quick = documents['saved-quick.json']['current_snapshot']['snapshot']
    route = quick['gameplay']['route_context']
    frames = route['dating_frozen_contexts_v1']['entries']
    physical = route['active_dating_challenge']
    checkpoint = quick['narrative_checkpoint']
    programmes = selected(catalogue, frames, native)
    output['selected_labels'] = {key: value['label'] for key, value in programmes.items()}
    beats = [beat for key in (PRE, POST) for beat in programmes[key]['beats']]
    lines = [line for key in (PRE, POST) for line in programmes[key]['lines']]
    contexts = {key: {'expected_stage': 'pre_challenge' if key == PRE else 'post_challenge',
                     'playback_id': physical['physical_token'] + (':pre_challenge' if key == PRE else ':post_challenge'),
                     'role': 'dating_phase', 'transaction_id': physical['completion_transaction_id'] + (':pre_challenge' if key == PRE else ':post_challenge'),
                     'presentation': frame} for key, frame in frames.items()}
    session = checkpoint['reading_session']
    captions = session['ledger']['captions']
    require(len(captions) == 4 and [row['beat'] for row in captions] == beats
            and len({row['publication_id'] for row in captions}) == 4
            and all(type(row['publication_id']) is str and row['publication_id'] for row in captions), 'FOUR_EXACT_DISTINCT_AUTHORED_PUBLICATIONS_REQUIRED')
    require(session['catalogue_fingerprint'] == canonical_hash(catalogue)
            and session['ledger']['entry_contexts'] == contexts and session['boundary'] == 'line'
            and session['frontier'] == {'line_id': LINES[-1], 'publication_id': captions[-1]['publication_id']}, 'SAVED_READING_MUST_BIND_RUN_CONTEXTS_AND_SELECTED_FRONTIER')
    post = frames[POST]['fields']
    attitudes = {'hatred': 'hostile', 'upset': 'upset', 'amused': 'amused'}
    require(physical['phase'] == 'post_challenge' and physical['outcome'] == 'exploded'
            and physical['board']['terminal'] is True and post['board_result'] == 'exploded'
            and post['relationship_outcome'] == physical['relationship_outcome']
            and post['attitude'] == attitudes[post['relationship_outcome']]
            and post['tone'] == 'sweet' and post['tier'] == 'friend' and post['due_echoes'] == []
            and post['attempt_residue_id'] is None and post['perfect_reasons'] == physical['perfect_reasons'] == []
            and post['effect_receipt_id'] == physical['applied_result']['receipt']['terminal_fact']['transaction_id'], 'PHYSICAL_COMMITTED_BOARD_EFFECT_MUST_AUTHORIZE_EXACT_SELECTED_POST_ROW')
    require(by_kind['pre_history']['authoritative_frames'] == {PRE: frames[PRE]}
            and by_kind['committed_result_then_post_prose']['authoritative_frames'] == frames
            and by_kind['committed_result_then_post_prose']['physical_record'] == physical, 'EXECUTED_PRE_FRAME_IMMUTABLE_AND_NO_PREDICTED_POST_FACTS')
    pre_history = by_kind['pre_history']['history']
    post_history = by_kind['committed_result_then_post_prose']['history']
    require(pre_history['captions'] == written['canonical_transcript'][:2]
            and post_history['captions'] == written['canonical_transcript'][:3]
            and pre_history['session_id'] == post_history['session_id'] == session['ledger']['session_token'],
            'ONE_LEDGER_MUST_RETAIN_ORDERED_PRE_AND_POST_HISTORY')
    for mode, report in reports.items():
        require(report['saved_checkpoint'] == checkpoint and report['authoritative_frames'] == frames
                and report['authoritative_entry_contexts'] == contexts and report['physical_record'] == physical
                and report['selected_programmes'] == programmes, 'REPORT_MUST_MATCH_INDEPENDENT_PHYSICAL_QUICK: ' + mode)
        require([row['line_id'] for row in report['canonical_transcript']] == LINES
                and [row['text'] for row in report['canonical_transcript']] == [row['text'] for row in lines]
                and report['current_line_id'] == LINES[-1] and report['current_text'] == lines[-1]['text'], 'EXACT_FOUR_CAPTION_HISTORY_AND_POST_B_REQUIRED')
        native_caption = report['native_caption']
        require(native_caption['label'] == programmes[POST]['label'] and native_caption['line_id'] == LINES[-1]
                and native_caption['text'] == lines[-1]['text'] and native_caption['fully_visible'] is True
                and native_caption['revealing'] is False and native_caption['visible_ratio'] == 1
                and report['next_active'] is False, 'VISIBLE_EXACT_SELECTED_NATIVE_POST_B_AND_RETIRED_NEXT_REQUIRED')
    require(written['canonical_transcript'] == restored['canonical_transcript']
            and written['speech_admissions'] > 0 and restored['speech_admissions'] == 0
            and by_kind['fresh_restore_verified']['speech_admissions'] == 0
            and written['history_observations'] >= 2 and restored['history_observations'] >= 1
            and restored['profile_unchanged'] is True and restored['quick_unchanged'] is True, 'REAL_WRITER_SPEECH_CONTROL_AND_FRESH_RESTORE_WITHOUT_REPLAY_REQUIRED')
    profile = documents['saved-profile.json']
    witnesses = profile['witnessed_caption_variants']
    require(witnesses == written['witnesses'] == restored['witnesses'] and len(witnesses) == 4
            and all(beat in witnesses.values() for beat in beats)
            and profile['preferences']['reading']['read_aloud_enabled'] is True, 'EXACT_VISIBLE_DESTINATION_PROFILE_WITNESS_AND_ENABLED_SPEECH_REQUIRED')
    for token, beat in witnesses.items():
        require(token == canonical_hash(beat), 'EXACT_PHYSICAL_PROFILE_WITNESS_HASH_REQUIRED')
    unseen = written['unseen_stop']
    require(unseen['result']['ok'] is True and unseen['result']['code'] == 'unseen_stop'
            and unseen['checkpoint_writes'] == [] and unseen['before_checkpoint'] == unseen['after_checkpoint'], 'FIRST_UNSEEN_NEXT_MUST_NOT_WRITE_OR_ADVANCE')
    before, after = unseen['native_before'], unseen['native_after']
    require(before['line_id'] == after['line_id'] == LINES[2] and before['text'] == after['text'] == lines[2]['text']
            and before['revealing'] is True and 0 <= before['visible_characters'] < before['total_characters']
            and 0 <= before['visible_ratio'] < 1 and after['revealing'] is False and after['visible_ratio'] == 1,
            'FIRST_NEXT_MUST_FINISH_ACTUAL_PARTIAL_SELECTED_SOURCE_ONLY')
    next_proof = written['next']
    for proof_name, observations in [('unseen_stop', unseen['observations']), ('next', next_proof['observations'])]:
        count = 0 if proof_name == 'unseen_stop' else 1
        require(all(observations[key] == count for key in ('text_started', 'about_to_show_text', 'caption_publications', 'exclusive_activations'))
                and observations['intermediate_checkpoint_admissions'] == 0, 'EXECUTED_NATIVE_NEXT_PUBLICATION_COUNTS_OR_EXCLUSIVE_CUSTODY_MISMATCH')
    require(unseen['observations']['speech_before'] == unseen['observations']['speech_after']
            and unseen['observations']['texts'] == unseen['observations']['publications'] == [], 'UNSEEN_STOP_MUST_NOT_PUBLISH_OR_REPEAT_SPEECH')
    publication = next_proof['observations']['publications']
    require(next_proof['observations']['texts'] == [lines[-1]['text']] and len(publication) == 1
            and publication[0]['ok'] is True and publication[0]['value']['duplicate'] is True
            and publication[0]['value']['ordinal'] == 3, 'EXACT_NATIVE_POST_B_REUSES_FOURTH_SEMANTIC_PUBLICATION')
    operation = session['next_operation']
    plan = operation['plan']
    require(session == projected(plan, 'destination') and next_proof['operation'] == operation
            and next_proof['checkpoint'] == checkpoint and next_proof['result']['ok'] is True
            and next_proof['result']['code'] == 'next_complete' and next_proof['result']['value']['destination'] == 'line'
            and plan['source_ledger'] == unseen['after_checkpoint']['reading_session']['ledger']
            and plan['source_frontier'] == unseen['after_checkpoint']['reading_session']['frontier']
            and plan['source_frontier']['line_id'] == LINES[2] and plan['entry_id'] == POST,
            'EXACT_HASHED_NEXT_PLAN_AND_BOTH_ENDPOINT_PROJECTIONS_REQUIRED')
    for name, line_id in [('source_ack', LINES[2]), ('destination_ack', LINES[3])]:
        ack = next_proof[name]
        require(ack['was_visited_before_presentation'] is False and ack['line_id'] == line_id
                and ack['entry_id'] == POST and bool(ack['playback_token']) and ack['frontier']['ok'] is True
                and ack['frontier']['value']['paused'] is False, 'RETAINED_FALSE_PRE_PUBLICATION_BASELINE_REQUIRED: ' + name)
    require(unseen['acknowledgement_receipt'] == next_proof['source_ack'], 'INITIAL_FALSE_SOURCE_BASELINE_MUST_BE_RETAINED')
    writes = next_proof['checkpoint_results']
    require([row['phase'] for row in writes] == ['source', 'destination'], 'EXACT_REAL_SOURCE_DESTINATION_WRITE_ORDER_REQUIRED')
    endpoints = []
    for row in writes:
        phase = row['phase']
        name = 'saved-next-' + phase + '.json'
        snapshot = documents[name]['current_snapshot']['snapshot']
        receipt = row['result']['receipt']
        require(retained[name] == {key: row['autosave'][key] for key in ('bytes', 'sha256')}
                and row['autosave']['file'] == name and row['checkpoint']['reading_session'] == projected(plan, phase)
                and snapshot['narrative_checkpoint'] == row['checkpoint']
                and snapshot['gameplay']['route_context']['active_dating_challenge'] == physical
                and snapshot['gameplay']['route_context']['dating_frozen_contexts_v1']['entries'] == frames,
                'EXACT_RETAINED_NEXT_AUTOSAVE_ENDPOINT_REQUIRED: ' + phase)
        require(row['result']['ok'] is True and row['result']['value']['duplicate'] is False
                and receipt['phase'] == phase and receipt['operation_id'] == row['operation_id'] == operation['operation_id']
                and receipt['checkpoint_id'] == row['result']['value']['checkpoint_id'] == snapshot['checkpoint_id']
                and receipt['narrative_fingerprint'] == canonical_hash(row['checkpoint']), 'REAL_NEXT_CHECKPOINT_RECEIPT_MUST_MATCH_PHYSICAL_SAVED_ENDPOINT')
        endpoints.append({'phase': phase, 'checkpoint_id': snapshot['checkpoint_id'], 'checkpoint_sequence': snapshot['checkpoint_sequence'], **retained[name]})
    require(endpoints[0]['checkpoint_id'] != endpoints[1]['checkpoint_id']
            and endpoints[0]['checkpoint_sequence'] < endpoints[1]['checkpoint_sequence'], 'ORDERED_DISTINCT_PHYSICAL_NEXT_ENDPOINTS_REQUIRED')
    forged = restored['forged_checkpoint']
    changed = forged['forged_checkpoint']['reading_session']
    alternate = deepcopy(plan)
    alternate['source_ledger']['entry_contexts'][PRE]['presentation']['fields']['tone'] = 'dark'
    alternate_frames = {key: value['presentation'] for key, value in alternate['source_ledger']['entry_contexts'].items()}
    alternate_programmes = selected(catalogue, alternate_frames, native)
    alternate_beats = {beat['line_id']: beat for beat in alternate_programmes[PRE]['beats']}
    for row in alternate['source_ledger']['captions']:
        if row['beat']['owning_entry_id'] == PRE:
            row['beat'] = alternate_beats[row['beat']['line_id']]
    expected_forged = deepcopy(checkpoint)
    expected_forged['reading_session'] = projected(alternate, 'destination')
    require(forged['forged_checkpoint'] == expected_forged and changed['next_operation']['operation_id'] != operation['operation_id']
            and forged['internally_valid']['ok'] is True and forged['live_unchanged'] is True and forged['files_unchanged'] is True,
            'FORGERY_MUST_BE_COHERENT_EARLIER_TONE_CHANGE_WITH_REGENERATED_OPERATION_AND_NO_MUTATION')
    for key in ('writer_authority_refusal', 'route_authority_refusal'):
        require(forged[key]['ok'] is False and forged[key]['code'] == 'reading_context_invalid', 'INDEPENDENT_RUN_AUTHORITY_MUST_REFUSE_FORGED_READING')
    refusal = forged['restore_participant_refusal']
    require(refusal['ok'] is False and refusal['code'] == 'invalid_narrative_checkpoint'
            and refusal['message'] == 'reading_entry_context_mismatch'
            and forged['quick_sha256'] == retained['saved-quick.json']['sha256']
            and forged['profile_sha256'] == retained['saved-profile.json']['sha256'], 'ACTUAL_RESTORE_PREPARATION_MUST_REFUSE_WITHOUT_FILE_MUTATION')
    seal = read(folder / 'write-seal.json')
    sealed = folder / PurePosixPath(seal['root']).name
    expected_seal = {'write.json', *RETAINED, 'transactions.jsonl', *CAPTURES[:7]}
    require(set(seal['files']) == expected_seal and seal['sealed_after_mode'] == 'write' and seal['before_mode'] == 'read'
            and result['write_seal_verified'] is True and result['write_seal'] == seal, 'EXACT_PRE_READER_WRITER_SEAL_REQUIRED')
    for name, expected in seal['files'].items():
        require(identity(sealed / name) == expected, 'SEALED_WRITER_BYTES_MISMATCH: ' + name)
        current = folder / ('captures/' + name if name.endswith('.png') else name)
        if name == 'transactions.jsonl':
            require(current.read_bytes().startswith((sealed / name).read_bytes()), 'READER_MUST_PRESERVE_WRITER_TRACE_PREFIX')
            sealed_trace = [parse(line) for line in (sealed / name).read_text().splitlines()]
            require(sealed_trace == trace[:len(TRACE['write'])], 'EXACT_WRITER_TRACE_SEAL_REQUIRED')
        else:
            require(identity(current) == expected, 'READER_MUST_PRESERVE_ALL_WRITER_EVIDENCE_BYTES: ' + name)
    captures = []
    require({PurePosixPath(item['file']).name for item in result['captures']} == set(CAPTURES), 'EXACT_NINE_CAPTURE_SET_REQUIRED')
    for item in result['captures']:
        path = folder / 'captures' / PurePosixPath(item['file']).name
        raw = path.read_bytes()
        require(raw.startswith(b'\x89PNG\r\n\x1a\n') and raw[12:16] == b'IHDR', 'REAL_PNG_CAPTURE_REQUIRED')
        width, height = struct.unpack('>II', raw[16:24])
        require(identity(path) == {key: item[key] for key in ('bytes', 'sha256')} and (width, height) == (item['width'], item['height']), 'RENDERED_CAPTURE_IDENTITY_MISMATCH')
        captures.append({'file': path.name, **identity(path), 'width': width, 'height': height})
    output.update(process_ids=dict(zip(TRACE, pids)), trace_entries=len(trace), trace_identity=identity(trace_path),
                  retained_files=retained, next_endpoints=endpoints, operation_id=operation['operation_id'],
                  source_pre_publication_baseline=False, destination_pre_publication_baseline=False,
                  traversed_captions=0, caption_count=4, restored_speech_admissions=0,
                  independent_run_frame_forgery_refused=True, canonical_witness_hashes=len(witnesses),
                  writer_seal_identity=identity(folder / 'write-seal.json'), captures=captures,
                  audit_complete=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run-root', type=Path, required=True)
    parser.add_argument('--repo', type=Path, required=True)
    parser.add_argument('--source', required=True)
    parser.add_argument('--checkout', required=True)
    parser.add_argument('--job-name')
    args = parser.parse_args()
    output = {'schema_version': 1, 'audit_complete': False, 'runtime_proof_failures': [],
              'source': args.source, 'checkout': args.checkout,
              'limits': ['Read-only audit of retained cloud execution; no local engine or PowerShell execution.',
                         'Finite noncanonical Priscilla Day 1 sweet exploded fixture; actual observed disposition only.',
                         'Both Next autosave endpoints are retained and byte-audited; the final Quick is the endpoint fresh-loaded in the reader.',
                         'Nine capture identities are verified; layout quality requires separate visual review.',
                         'Canonical JSON hash recomputation is limited to exact integers and printable ASCII used by this fixture.',
                         'This component receipt does not substitute for the canonical broad workflow gate.']}
    try:
        audit(args, output)
    except Exception as error:
        output['runtime_proof_failures'].append(type(error).__name__ + ': ' + str(error))
    destination = args.run_root / 'audit' / 'physical-selector-journey-audit.json'
    destination.parent.mkdir(parents=True, exist_ok=True)
    output['auditor_identity'] = identity(Path(__file__))
    destination.write_text(json.dumps(output, indent=2, sort_keys=True, ensure_ascii=False) + '\n')
    print(json.dumps({'output': str(destination), 'audit_complete': output['audit_complete'],
                      'runtime_proof_failures': output['runtime_proof_failures']}))
    return 0 if output['audit_complete'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
