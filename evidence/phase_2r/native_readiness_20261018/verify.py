import base64, hashlib, io, json, pathlib, re, sys, zipfile

log = pathlib.Path(sys.argv[1]).read_text()
out = pathlib.Path(sys.argv[2]); out.mkdir(parents=True, exist_ok=True)
receipt = json.loads(re.search(r'DWM_EVIDENCE_BEGIN (\{[^\r\n]+\})', log)[1])
chunks = re.findall(r'DWM_EVIDENCE_CHUNK ([A-Za-z0-9+/=]+)', log)
raw = base64.b64decode(''.join(chunks), validate=True)
assert len(raw) == receipt['bytes'] and hashlib.sha256(raw).hexdigest() == receipt['sha256']
(out / '39128530440-evidence.zip').write_bytes(raw)
z = zipfile.ZipFile(io.BytesIO(raw))
def doc(path): return json.loads(z.read(path).decode('utf-8-sig'))
manifest = doc('ci/retained-hashes.json')
assert set(z.namelist()) == set(manifest) | {'ci/retained-hashes.json'}
for path, entry in manifest.items():
    data = z.read(path)
    assert len(data) == entry['bytes'] and hashlib.sha256(data).hexdigest() == entry['sha256'], path
origin = doc('ci/audit-origin.json')
assert origin['candidate'] == 'b59b9d548f352895ac89b6aa55b80822358f8b69'
assert origin['tree'] == '82cafaf91f939be1545d7cd61c8770e687273e97'
assert origin['controller'] == 'bf53dcf82ba290d220756767563961ca5d4b17fc'
driver = z.read('ci/source/tools/testing/Invoke-ExportedGameplay.ps1')
assert hashlib.sha1(b'blob '+str(len(driver)).encode()+b'\0'+driver).hexdigest() == 'ba3858721cd3e4ac667be1ddccf327ec6bc2d671'
assert doc('ci/driver-parse.json')['ok']
checks = doc('ci/deadline-tests.json')
assert checks['ok'] and len(checks['cases']) == 4 and all(c['ok'] for c in checks['cases'])
test_source = z.read('ci/source/tests/tooling/Test-ExportedGameplayDeadline.ps1')
assert hashlib.sha1(b'blob '+str(len(test_source)).encode()+b'\0'+test_source).hexdigest() == '436c73a380baec1a3bc6ba64d273ff052e316d78'
outcomes = {}
for mode in ('capability', 'create', 'load'):
    prefix = 'ci/exported-' + mode + '/'
    if prefix + 'result.json' not in z.namelist(): continue
    for item in doc(prefix + 'manifest.json'):
        data = z.read(prefix + item['file'])
        assert len(data) == item['bytes'] and hashlib.sha256(data).hexdigest() == item['sha256']
    result = doc(prefix + 'result.json')
    outcomes[mode] = {k: result.get(k) for k in ('ok','failure','elapsed_seconds','exit_code','clean_player_exit','forced_cleanup','continued_after_quiet','restored_checkpoint_matches')}
    assert result['source_commit'] == '63f1e4dbfe649039881d138541abd377a8639778'
    assert result['archive_sha256'] == 'ef5f3f19980064080a84a28bcae9f97db4feb41934a9f007bc828172394f3431'
events = doc('ci/exported-load/events.json') if 'ci/exported-load/events.json' in z.namelist() else []
trace = [e for e in events if e['kind'].startswith(('day5-', 'native-caption-', 'caption-', 'wait-deadline-')) or (e['kind']=='native-boundary' and e['data']['stage'].startswith('caption-before-query'))]
report = dict(archive=receipt, origin=origin, verified_members=len(manifest), outcomes=outcomes, deadline_tests=checks, native_trace=trace)
(out / 'verification.json').write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps(dict(archive=receipt, verified_members=len(manifest), outcomes=outcomes, deadline_tests=checks, boundaries=[e for e in trace if e['kind']!='native-boundary']), indent=2))
