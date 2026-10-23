import hashlib, io, json, pathlib, zipfile

root = pathlib.Path(__file__).resolve().parent
payload = (root / '39122595303-save-phase-profile.zip').read_bytes()
z = zipfile.ZipFile(io.BytesIO(payload))
def doc(p):
    return json.loads(z.read(p).decode('utf-8-sig'))
manifest = doc('ci/retained-hashes.json')
assert set(z.namelist()) == set(manifest) | {'ci/retained-hashes.json'}
for p, expected in manifest.items():
    data = z.read(p)
    assert len(data) == expected['bytes'] and hashlib.sha256(data).hexdigest() == expected['sha256'], p
outcomes = {}
for mode in ('capability', 'create', 'load'):
    prefix = 'ci/exported-' + mode + '/'
    if prefix + 'result.json' not in z.namelist():
        continue
    outcomes[mode] = doc(prefix + 'result.json')
    for item in doc(prefix + 'manifest.json'):
        data = z.read(prefix + item['file'])
        assert len(data) == item['bytes'] and hashlib.sha256(data).hexdigest() == item['sha256'], item['file']
origin = doc('ci/audit-origin.json')
assert origin['candidate'] == '39990c0834d6eb94bd34aa1947245c998c42ed21'
assert origin['tree'] == 'b4808a6cf95e98c24c51b791e8f7c8f9fb62abe0'
driver = z.read('ci/source/tools/testing/Invoke-ExportedGameplay.ps1')
assert hashlib.sha1(b'blob ' + str(len(driver)).encode() + b'\0' + driver).hexdigest() == 'a47c412c825f83f45ca8384d60af8d1ca05b5a62'
prefix = 'ci/exported-load/'
comparisons = {}
for stage in ('quiet-before', 'quiet-after', 'failure'):
    if prefix + stage + '-save-observations.json' not in z.namelist():
        continue
    for item in doc(prefix + stage + '-save-observations.json'):
        assert item['status'] == 'copied', item
        data = z.read(prefix + item['file'])
        assert len(data) == item['bytes'] and hashlib.sha256(data).hexdigest() == item['sha256']
    a = doc('ci/exported-create/source-slot-1.json')['current_snapshot']['snapshot']
    b = doc(prefix + stage + '-saves-slot_2.json')['current_snapshot']['snapshot']
    comparisons[stage] = {
        'equal_fields': {k: a[k] == b[k] for k in ('narrative_checkpoint', 'gameplay', 'scene', 'command_receipts', 'applied_effect_transaction_ids', 'applied_variable_transaction_ids')},
        'same_run': a['lifecycle']['run_id'] == b['lifecycle']['run_id'],
        'different_branch': a['lifecycle']['branch_id'] != b['lifecycle']['branch_id'],
        'profile_equal': doc(prefix + 'profile-before-load.json') == doc(prefix + stage + '-profile.json'),
        'source_slot_byte_identical': z.read('ci/exported-create/source-slot-1.json') == z.read(prefix + stage + '-saves-slot_1.json'),
    }
events = doc(prefix + 'events.json') if prefix + 'events.json' in z.namelist() else []
quiet = [e for e in events if e['kind'].startswith(('quiet-', 'save-invoke-', 'save-file-wait-')) or e['kind'] == 'native-boundary']
report = dict(run=39122595303, job=117661039428, archive_sha256=hashlib.sha256(payload).hexdigest(), archive_bytes=len(payload), verified_members=len(manifest), origin=origin, outcomes=outcomes, diagnostic_live_comparisons= comparisons, quiet_events=quiet, source_blobs={p[10:]: hashlib.sha1(b'blob ' + str(len(z.read(p))).encode() + b'\0' + z.read(p)).hexdigest() for p in z.namelist() if p.startswith('ci/source/')})
(root / 'profile-verification.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({k: report[k] for k in ('archive_sha256', 'archive_bytes', 'verified_members', 'diagnostic_live_comparisons', 'quiet_events')}, indent=2))
print(json.dumps({k: {x: v.get(x) for x in ('ok', 'failure', 'exit_code', 'clean_player_exit', 'forced_cleanup', 'quiet_observation_completed', 'quiet_saved_count')} for k, v in outcomes.items()}, indent=2))

source = z.read('ci/source/autoload/SaveManager.gd')
assert hashlib.sha1(b'blob ' + str(len(source)).encode() + b'\0' + source).hexdigest() == '319449c17e7d3859076d7ba20e362b775f096802'
assert outcomes['load']['save_load_profile'] is True
assert outcomes['create']['save_load_profile'] is False and outcomes['capability']['save_load_profile'] is False
records = []
for line in z.read('ci/exported-load/game.stdout.log').decode('utf-8-sig').splitlines():
    if line.startswith('DWM_SAVE_LOAD_PROFILE '):
        records.append(json.loads(line.split(' ', 1)[1]))
assert records, 'No profiling records captured'
(root / 'save-phase-records.json').write_text(json.dumps(records, indent=2) + '\n')
print(json.dumps({'record_count':len(records),'backup_commits':[x for x in records if x['scope']=='backup_commit'], 'slowest_records': sorted(records, key=lambda x:x['elapsed_us'],reverse=True)[:12]},indent=2))
