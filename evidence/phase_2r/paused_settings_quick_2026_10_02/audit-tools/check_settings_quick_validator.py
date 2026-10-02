"""Task-local Python-only negative controls; this is not a cloud runtime proof."""
from pathlib import Path
import copy
import hashlib
import json
import sys
import tempfile

ROOT = Path('/workspace/scratch/e169b180163f')
sys.path.insert(0, str(ROOT / 'dwm/tools/testing'))
import run_reading_rail_journey as runner

prior = ROOT / 'run127/artifacts/reading-rail-36960182145-1/30a5aa58-b18c-42b6-82d9-d45dcf91c60c'
old = json.loads((prior / 'write.json').read_text())['ordinary_pause_save']
entered = copy.deepcopy(old['ordinary_pause_entered'])
saved = copy.deepcopy(old['ordinary_backup_entered'])
assert saved['source'] == entered['source']
raw = (prior / 'saved-pause-slot.json').read_bytes()
identity = {'exists': True, 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}
disk_before = {'quick': {'exists': False, 'sha256': '', 'bytes': 0},
               'autosave': {'exists': True, 'sha256': 'a' * 64, 'bytes': 100},
               'profile': {'exists': True, 'sha256': 'b' * 64, 'bytes': 101}}
disk_after = copy.deepcopy(disk_before)
disk_after['quick'] = identity
host = {'tree_paused': True, 'visible': True, 'entered_action': 'settings',
        'selected_category': 'reading', 'host_id': 11, 'focus_id': 12,
        'focus_path': 'SettingsContent/RailScroll/ReadingCategory', 'suspension': {'handle_id': 'synthetic-control'},
        'backup_mode': 'save', 'backup_locator': 'slot:1'}
written = {'mode': 'settings-write', 'process_id': 101, 'user_dir': '/synthetic-settings',
           'entered': entered, 'hosted': entered, 'saved': saved, 'continued': saved,
           'host_before': host, 'host_after': host, 'disk_before': disk_before, 'disk_after': disk_after,
           'mutations': [{'sequence': 1, 'owner': 'saves', 'operation': 'write', 'path': 'quicksave.json.next',
                          'ok': True, 'bytes': len(raw), 'sha256': identity['sha256']}],
           'saved_checkpoint': entered['source']['checkpoint'], 'physical_record': entered['source']['physical_record'],
           'canonical_transcript': entered['source']['history']['captions'], 'speech_admissions': 1,
           'desktop_context': {'active_app_id': 'schedule'}}
restored = {'mode': 'settings-read', 'process_id': 102, 'user_dir': '/synthetic-settings',
            'saved_checkpoint': written['saved_checkpoint'], 'physical_record': written['physical_record'],
            'history': entered['source']['history'], 'canonical_transcript': written['canonical_transcript'],
            'disk_before': disk_after, 'disk_after': disk_after, 'profile_unchanged': True,
            'speech_admissions': 0, 'history_observations': 1, 'current_line_complete': True,
            'desktop_context': written['desktop_context']}
base = {'settings-write': written, 'settings-read': restored}


def trace_for(reports):
    w, r = reports['settings-write'], reports['settings-read']
    values = (w['entered'], {'reading': w['hosted'], 'host': w['host_before']},
              {'reading': w['saved'], 'host': w['host_after'], 'disk': w['disk_after'], 'mutations': w['mutations']}, w,
              {'disk': r['disk_before'], 'speech_admissions': 0},
              {'label': 'settings-restored-history', 'history': r['history']}, r)
    result = []
    for mode in runner.SETTINGS_MODES:
        for seq, kind in enumerate(runner.TRACE_KINDS[mode], 1):
            result.append({'mode': mode, 'sequence': seq, 'process_id': reports[mode]['process_id'],
                           'kind': kind, 'value': values[len(result)]})
    return result


def check(label, mutate=None, expected=None):
    # JSON round trip removes shared fixture aliases before a single-field mutation.
    reports = json.loads(json.dumps(base))
    if mutate:
        mutate(reports)
    with tempfile.TemporaryDirectory(prefix='settings-validator-', dir=ROOT) as temporary:
        evidence = Path(temporary) / 'evidence'
        output = Path(temporary) / 'output'
        evidence.mkdir()
        output.mkdir()
        (evidence / 'saved-settings-quick.json').write_bytes(raw)
        (evidence / 'transactions.jsonl').write_text(''.join(json.dumps(row) + '\n' for row in trace_for(reports)))
        try:
            runner.validate_settings_quick(reports, evidence, output)
            result = 'accepted'
        except RuntimeError as error:
            result = str(error)
        assert result == (expected or 'accepted'), (label, result, expected)
        return {'case': label, 'expected': expected or 'accepted', 'observed': result, 'passed': True}


cases = [check('valid synthetic Settings route over source-bound existing first-line save')]
cases.append(check('Settings entry completes line early', lambda r: r['settings-write']['hosted']['native'].__setitem__('revealing', False), 'SETTINGS_ENTRY_MUST_RETAIN_LITERAL_PARTIAL_READING'))
cases.append(check('semantic advance during F5', lambda r: r['settings-write']['saved']['source']['checkpoint']['reading_session']['frontier'].__setitem__('line_id', 'foreign'), 'SETTINGS_F5_MUST_COMPLETE_ONLY_CURRENT_REVEAL'))
cases.append(check('focus lost', lambda r: r['settings-write']['host_after'].__setitem__('focus_id', 999), 'SETTINGS_F5_MUST_RETAIN_EXACT_HOST_FOCUS_AND_SUSPENSION'))
cases.append(check('Profile bytes change', lambda r: r['settings-write']['disk_after']['profile'].__setitem__('sha256', 'c' * 64), 'SETTINGS_QUICK_ONLY_DISK_CHANGE_REQUIRED'))
cases.append(check('Autosave bytes change', lambda r: r['settings-write']['disk_after']['autosave'].__setitem__('sha256', 'c' * 64), 'SETTINGS_QUICK_ONLY_DISK_CHANGE_REQUIRED'))
cases.append(check('extra Profile mutation', lambda r: r['settings-write']['mutations'].append({'sequence': 2, 'owner': 'profile', 'operation': 'write', 'path': 'profile.json.next', 'ok': True}), 'SETTINGS_NON_QUICK_FILE_MUTATION'))
cases.append(check('missing physical Quick candidate', lambda r: r['settings-write'].__setitem__('mutations', []), 'SETTINGS_ONE_EXACT_QUICK_CANDIDATE_REQUIRED'))
cases.append(check('candidate digest mismatch', lambda r: r['settings-write']['mutations'][0].__setitem__('sha256', 'c' * 64), 'SETTINGS_ONE_EXACT_QUICK_CANDIDATE_REQUIRED'))
cases.append(check('restored speech replay', lambda r: r['settings-read'].__setitem__('speech_admissions', 1), 'SETTINGS_FRESH_EXACT_RESTORE_WITHOUT_SPEECH_REQUIRED'))
cases.append(check('restored History mutation', lambda r: r['settings-read']['history']['captions'].clear(), 'SETTINGS_FRESH_EXACT_RESTORE_WITHOUT_SPEECH_REQUIRED'))
cases.append(check('transient Settings saved as app', lambda r: (r['settings-write']['desktop_context'].__setitem__('active_app_id', 'settings'), r['settings-read']['desktop_context'].__setitem__('active_app_id', 'settings')), 'SETTINGS_TRANSIENT_HOST_ENTERED_CANONICAL_SAVE'))
result = {'complete': True, 'scope': 'Python validator controls only; generated reports are synthetic, not evidence of new cloud execution.',
          'source_prior_save': str(prior / 'saved-pause-slot.json'), 'prior_save_sha256': identity['sha256'], 'cases': cases,
          'local_engine_invocations': 0}
(ROOT / 'settings-quick-validator-review.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({'complete': True, 'checks': len(cases), 'negative_controls': len(cases)-1}))
