#!/usr/bin/env python3
"""Auditor-only controls; synthetic Settings records are never cloud evidence."""
from copy import deepcopy
import importlib.util
import json
from pathlib import Path
import tempfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('settings_auditor', ROOT / 'audit_settings_quick_journey.py')
a = importlib.util.module_from_spec(spec)
spec.loader.exec_module(a)

prior_path = next((ROOT / 'run127/artifacts').glob('reading-rail-*/result.json'))
prior = a.read(prior_path)
prior_folder = prior_path.parent / Path(prior['artifact_root']).name
pause = prior['reports']['write']['ordinary_pause_save']
entered = deepcopy(pause['ordinary_pause_entered'])
saved = deepcopy(pause['ordinary_backup_entered'])
document = a.read(prior_folder / 'saved-pause-slot.json')
document.update(kind='quick', save_reason='quick', slot_id=None)
quick_raw = (json.dumps(document, sort_keys=True) + '\n').encode()
quick_id = a.digest(quick_raw)
after = {'quick': {'exists': True, **quick_id},
         'autosave': {'exists': True, **a.digest(b'synthetic-autosave-identity')},
         'profile': {'exists': True, **a.digest(b'synthetic-profile-identity')}}
before = deepcopy(after)
before['quick'] = {'exists': False, 'bytes': 0, 'sha256': ''}
marker = {'schema_version': 2, 'relative_path': 'quicksave.json', 'operation': 'write_revision',
          'stage': 'prepared', 'previous_hash': None, 'backup_hash': None, 'outgoing_hash': quick_id['sha256']}
marker_id = a.digest(json.dumps(marker, sort_keys=True, separators=(',', ':')).encode('ascii'))
mutations = [
    {'sequence': 1, 'owner': 'saves', 'operation': 'write', 'path': 'quicksave.json.txn.json', 'ok': True, **marker_id},
    {'sequence': 2, 'owner': 'saves', 'operation': 'flush', 'path': 'quicksave.json.txn.json', 'ok': True},
    {'sequence': 3, 'owner': 'saves', 'operation': 'write', 'path': 'quicksave.json.next', 'ok': True, **quick_id},
    {'sequence': 4, 'owner': 'saves', 'operation': 'flush', 'path': 'quicksave.json.next', 'ok': True},
    {'sequence': 5, 'owner': 'saves', 'operation': 'rename', 'path': 'quicksave.json.next', 'destination': 'quicksave.json', 'ok': True},
    {'sequence': 6, 'owner': 'saves', 'operation': 'remove', 'path': 'quicksave.json.revision-prior', 'ok': True},
    {'sequence': 7, 'owner': 'saves', 'operation': 'remove', 'path': 'quicksave.json.bak', 'ok': True},
    {'sequence': 8, 'owner': 'saves', 'operation': 'remove', 'path': 'quicksave.json.txn.json', 'ok': True},
]
host = {'tree_paused': True, 'visible': True, 'entered_action': 'settings', 'selected_category': 'reading',
        'host_id': 123, 'focus_id': 456, 'focus_path': 'Content/ReadingButton',
        'suspension': {'id': 'synthetic-retained-suspension'}, 'backup_mode': '', 'backup_locator': ''}
written = {'mode': 'settings-write', 'process_id': 111, 'user_dir': '/synthetic/settings',
           'entered': entered, 'hosted': deepcopy(entered), 'saved': saved, 'continued': deepcopy(saved),
           'host_before': host, 'host_after': deepcopy(host), 'disk_before': before, 'disk_after': after,
           'mutations': mutations, 'saved_checkpoint': deepcopy(entered['source']['checkpoint']),
           'physical_record': deepcopy(entered['source']['physical_record']),
           'canonical_transcript': deepcopy(entered['source']['history']['captions']),
           'speech_admissions': entered['source']['speech_admissions'], 'desktop_context': {'active_app_id': 'schedule'}}
restored = {key: deepcopy(written[key]) for key in ('saved_checkpoint', 'physical_record', 'canonical_transcript', 'desktop_context')}
restored.update(mode='settings-read', process_id=222, user_dir='/synthetic/settings',
                disk_before=deepcopy(after), disk_after=deepcopy(after), history=deepcopy(entered['source']['history']),
                speech_admissions=0, history_observations=1, current_line_complete=True, profile_unchanged=True)
baseline = {'reports': {'settings-write': written, 'settings-read': restored}}
catalogue = a.read(ROOT / 'dwm' / a.CATALOGUE)


def execute(result, quick=quick_raw, alter_trace=None):
    w, r = (result['reports'][mode] for mode in a.SETTINGS)
    values = [w['entered'], {'reading': w['hosted'], 'host': w['host_before']},
              {'reading': w['saved'], 'host': w['host_after'], 'disk': w['disk_after'], 'mutations': w['mutations']}, w,
              {'disk': r['disk_before'], 'speech_admissions': 0},
              {'label': 'settings-restored-history', 'history': r['history']}, r]
    trace = []
    for mode in a.SETTINGS:
        for sequence, kind in enumerate(a.TRACE[mode], 1):
            trace.append({'mode': mode, 'kind': kind, 'sequence': sequence,
                          'process_id': result['reports'][mode]['process_id'], 'value': values[len(trace)]})
    if alter_trace:
        alter_trace(trace)
    with tempfile.TemporaryDirectory(prefix='settings-auditor-control-') as location:
        folder = Path(location)
        (folder / 'saved-settings-quick.json').write_bytes(quick)
        (folder / 'transactions.jsonl').write_text(''.join(json.dumps(row) + '\n' for row in trace))
        return a.verify_semantics(folder, result, catalogue)


def replace(path, value):
    def change(result):
        current = result
        for key in path[:-1]:
            current = current[key]
        current[path[-1]] = value
    return change


cases = [
    ('read-aloud positive control removed', replace(('reports', 'settings-write', 'entered', 'source', 'profile', 'preferences', 'reading', 'read_aloud_enabled'), False)),
    ('partial reveal lost', replace(('reports', 'settings-write', 'entered', 'native', 'revealing'), False)),
    ('saved line advanced', replace(('reports', 'settings-write', 'saved', 'native', 'line_id'), 'fixture.solo.pre.b')),
    ('Settings focus drift', replace(('reports', 'settings-write', 'host_after', 'focus_id'), 789)),
    ('Autosave mutation', replace(('reports', 'settings-write', 'disk_after', 'autosave', 'sha256'), '0' * 64)),
    ('foreign storage owner', replace(('reports', 'settings-write', 'mutations', 2, 'owner'), 'profile')),
    ('Quick candidate substituted', replace(('reports', 'settings-write', 'mutations', 2, 'sha256'), '0' * 64)),
    ('transaction marker substituted', replace(('reports', 'settings-write', 'mutations', 0, 'sha256'), '0' * 64)),
    ('transient saved app', replace(('reports', 'settings-write', 'desktop_context', 'active_app_id'), 'settings')),
    ('restored speech repeated', replace(('reports', 'settings-read', 'speech_admissions'), 1)),
    ('bool substituted for zero speech', replace(('reports', 'settings-read', 'speech_admissions'), False)),
]
execute(json.loads(json.dumps(baseline)))
refusals = []
for name, mutation in cases:
    value = json.loads(json.dumps(baseline))
    mutation(value)
    try:
        execute(value)
    except ValueError as error:
        refusals.append({'control': name, 'rejected': True, 'reason': str(error)})
    else:
        raise RuntimeError('Auditor failed to reject: ' + name)
for name, kwargs in (
    ('raw Quick corruption', {'quick': quick_raw + b' '}),
    ('trace process swapped', {'alter_trace': lambda rows: rows[-1].update(process_id=111)}),
    ('trace value substituted', {'alter_trace': lambda rows: rows[0].update(value={})}),
):
    try:
        execute(json.loads(json.dumps(baseline)), **kwargs)
    except ValueError as error:
        refusals.append({'control': name, 'rejected': True, 'reason': str(error)})
    else:
        raise RuntimeError('Auditor failed to reject: ' + name)
report = {'scope': 'Synthetic auditor controls only; no current cloud runtime acceptance.',
          'synthetic_semantic_baseline_passed': True, 'negative_control_count': len(refusals),
          'negative_controls': refusals, 'auditor_identity': a.identity(ROOT / 'audit_settings_quick_journey.py')}
(ROOT / 'paused-settings-cloud/auditor-control-results.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({'synthetic_baseline': True, 'negative_controls_rejected': len(refusals),
                  'current_cloud_acceptance': False}))
