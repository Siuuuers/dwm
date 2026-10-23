import hashlib, io, json, pathlib, zipfile

root = pathlib.Path(__file__).resolve().parent
payload = (root / '39124502119-evidence.zip').read_bytes()
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
assert origin['candidate'] == '63f1e4dbfe649039881d138541abd377a8639778'
assert origin['tree'] == 'd8da757693c190bb6cde7eafdbeacaf02c7330cd'
driver = z.read('ci/source/tools/testing/Invoke-ExportedGameplay.ps1')
assert hashlib.sha1(b'blob ' + str(len(driver)).encode() + b'\0' + driver).hexdigest() == 'd2003611a97c99626b72a727a56d0c9d55a72f55'
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
report = dict(run=39124502119, job=117666685695, archive_sha256=hashlib.sha256(payload).hexdigest(), archive_bytes=len(payload), verified_members=len(manifest), origin=origin, outcomes=outcomes, diagnostic_live_comparisons= comparisons, quiet_events=quiet, source_blobs={p[10:]: hashlib.sha1(b'blob ' + str(len(z.read(p))).encode() + b'\0' + z.read(p)).hexdigest() for p in z.namelist() if p.startswith('ci/source/')})
(root / 'export-verification.json').write_text(json.dumps(report, indent=2) + '\n')
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
assert outcomes['capability']['ok'] and outcomes['create']['ok']
assert outcomes['capability']['exit_code'] == 0 and outcomes['create']['exit_code'] == 0
assert outcomes['load']['continued_after_quiet'] and not outcomes['load']['ok']
assert outcomes['load']['failure'] == 'UIA_UNAVAILABLE_OR_TIMEOUT: TEST Day5 opening.'
for stage, compared in comparisons.items():
    assert all(compared['equal_fields'].values())
    assert compared['same_run'] and compared['different_branch'] and compared['source_slot_byte_identical']
    if stage != 'failure':
        assert compared['profile_equal']
for path, sha in {'scripts/ui/BackupApp.gd':'69be339643d27ab6e35efb945e3505915ad2cbb1','scripts/application/backup/BackupPresentationPort.gd':'4524984d3ef3e74bdcbab1c296232a603f0eb040'}.items():
    raw = z.read('ci/source/' + path)
    assert hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest() == sha
(root / 'export-phase-records.json').write_text(json.dumps(records, indent=2) + '\n')
print(json.dumps({'record_count':len(records),'backup_commits':[x for x in records if x['scope']=='backup_commit'], 'slowest_records': sorted(records, key=lambda x:x['elapsed_us'],reverse=True)[:12]},indent=2))
