import base64, hashlib, io, json, pathlib, zipfile

reports = []
for label, run in (('provider', '39108575134'), ('stacks', '39109040408'), ('compat', '39109479250'), ('foreground', '39110047155')):
    path = pathlib.Path(label + '-capability-evidence.b64')
    archive = pathlib.Path(__file__).resolve().parent / (run + '-evidence.zip')
    payload = base64.b64decode(path.read_text()) if path.exists() else archive.read_bytes()
    z = zipfile.ZipFile(io.BytesIO(payload))
    def doc(p):
        return json.loads(z.read(p).decode('utf-8-sig'))
    manifest = doc('ci/retained-hashes.json')
    assert set(z.namelist()) == set(manifest) | {'ci/retained-hashes.json'}
    for p, expected in manifest.items():
        data = z.read(p)
        assert len(data) == expected['bytes']
        assert hashlib.sha256(data).hexdigest() == expected['sha256']
    results = {}
    for mode in ('capability', 'create', 'load'):
        prefix = 'ci/exported-' + mode + '/'
        if prefix + 'result.json' not in z.namelist():
            continue
        results[mode] = doc(prefix + 'result.json')
        if results[mode]['ok']:
            assert results[mode]['clean_player_exit'] and not results[mode]['forced_cleanup']
            assert results[mode]['exit_code'] == 0
        for item in doc(prefix + 'manifest.json'):
            data = z.read(prefix + item['file'])
            assert len(data) == item['bytes']
            assert hashlib.sha256(data).hexdigest() == item['sha256']
    prefix = 'ci/exported-load/'
    comparison = None
    if prefix + 'failure-saves-slot_2.json' in z.namelist():
        a = doc('ci/exported-create/source-slot-1.json')['current_snapshot']['snapshot']
        b = doc(prefix + 'failure-saves-slot_2.json')['current_snapshot']['snapshot']
        comparison = {
            'equal_fields': {k: a[k] == b[k] for k in ('narrative_checkpoint', 'gameplay', 'scene', 'command_receipts', 'applied_effect_transaction_ids', 'applied_variable_transaction_ids')},
            'same_run': a['lifecycle']['run_id'] == b['lifecycle']['run_id'],
            'different_branch': a['lifecycle']['branch_id'] != b['lifecycle']['branch_id'],
            'profile_equal': doc(prefix + 'profile-before-load.json') == doc(prefix + 'failure-profile.json'),
            'source_slot_byte_identical': z.read('ci/exported-create/source-slot-1.json') == z.read(prefix + 'failure-saves-slot_1.json'),
        }
        for item in doc(prefix + 'failure-save-observations.json'):
            assert item['status'] == 'copied'
            data = z.read(prefix + item['file'])
            assert len(data) == item['bytes'] and hashlib.sha256(data).hexdigest() == item['sha256']
    late = doc(prefix + 'failure.uia.json') if prefix + 'failure.uia.json' in z.namelist() else []
    events = doc(prefix + 'events.json') if prefix + 'events.json' in z.namelist() else []
    report = {
        'label': label, 'archive_sha256': hashlib.sha256(payload).hexdigest(), 'archive_bytes': len(payload),
        'origin': doc('ci/audit-origin.json'), 'verified_members': len(manifest), 'outcomes': results,
        'diagnostic_live_state_comparison_not_acceptance': comparison,
        'native_probe': doc(prefix + 'failure-native-window.json') if prefix + 'failure-native-window.json' in z.namelist() else None,
        'late_failure_uia_node_count': len(late),
        'late_failure_uia_saved_present': any(n['name'].strip() == 'Saved' for n in late),
        'foreground_events': [e for e in events if e['kind'] == 'post-save-foreground'],
        'limits': 'Live captures are non-atomic. Later failure Capture restores foreground and waits 200ms after diagnostic activity; recovery trigger is not isolated. Failed journeys remain failed.',
        'source_blobs': {p[10:]: hashlib.sha1(b'blob ' + str(len(z.read(p))).encode() + b'\0' + z.read(p)).hexdigest() for p in z.namelist() if p.startswith('ci/source/')},
    }
    reports.append(report)
pathlib.Path('post-save-diagnosis-verification.json').write_text(json.dumps(reports, indent=2) + '\n')
print(json.dumps([{k:r[k] for k in ('label','archive_sha256','diagnostic_live_state_comparison_not_acceptance','late_failure_uia_node_count','foreground_events')} for r in reports], indent=2))
