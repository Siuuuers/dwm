import hashlib, io, json, pathlib, zipfile

root = pathlib.Path(__file__).resolve().parent
payload = (root / '39113018109-evidence.zip').read_bytes()
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
assert origin['candidate'] == '146791302b2a0df4ca09a9deb5a3485ec10cb2fc'
assert origin['tree'] == 'ae2946cd542e4360e03483a8db7679c55038428d'
driver = z.read('ci/source/tools/testing/Invoke-ExportedGameplay.ps1')
assert hashlib.sha1(b'blob ' + str(len(driver)).encode() + b'\0' + driver).hexdigest() == 'b0aca70231e0ea48e43abecbe04d0c936a5e433d'
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
quiet = [e for e in events if e['kind'].startswith('quiet-')]
report = dict(run=39113018109, job=117632952558, archive_sha256=hashlib.sha256(payload).hexdigest(), archive_bytes=len(payload), verified_members=len(manifest), origin=origin, outcomes=outcomes, diagnostic_live_comparisons= comparisons, quiet_events=quiet, source_blobs={p[10:]: hashlib.sha1(b'blob ' + str(len(z.read(p))).encode() + b'\0' + z.read(p)).hexdigest() for p in z.namelist() if p.startswith('ci/source/')})
(root / 'quiet-verification.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({k: report[k] for k in ('archive_sha256', 'archive_bytes', 'verified_members', 'diagnostic_live_comparisons', 'quiet_events')}, indent=2))
print(json.dumps({k: {x: v.get(x) for x in ('ok', 'failure', 'exit_code', 'clean_player_exit', 'forced_cleanup', 'quiet_observation_completed', 'quiet_saved_count')} for k, v in outcomes.items()}, indent=2))
