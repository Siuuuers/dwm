import hashlib, io, json, pathlib, zipfile

out = pathlib.Path(__file__).resolve().parent
raw = (out / '39127084942-evidence.zip').read_bytes()
receipt = {'bytes': 999043, 'sha256': '71e6adb85945fc705cfb7e7b6b7f0834e2e7ffa43c4c507c663e34d125fb6b30'}
assert len(raw) == receipt['bytes'] and hashlib.sha256(raw).hexdigest() == receipt['sha256']
z = zipfile.ZipFile(io.BytesIO(raw))
def doc(path): return json.loads(z.read(path).decode('utf-8-sig'))
manifest = doc('ci/retained-hashes.json')
assert set(z.namelist()) == set(manifest) | {'ci/retained-hashes.json'}
for path, entry in manifest.items():
    data = z.read(path)
    assert len(data) == entry['bytes'] and hashlib.sha256(data).hexdigest() == entry['sha256'], path
origin = doc('ci/audit-origin.json')
assert origin['candidate'] == '2195d5dfc399ef3d40db905d8ec89e48f6ea7c90'
assert origin['tree'] == '1cdd5dafa2a004ec52c1cc264559516404bccf80'
assert origin['controller'] == 'b00319a5bcfb85c996648f479c9310c4b5fa5623'
driver = z.read('ci/source/tools/testing/Invoke-ExportedGameplay.ps1')
assert hashlib.sha1(b'blob '+str(len(driver)).encode()+b'\0'+driver).hexdigest() == '9e78a5ab72c137e73749c10b77e9f7777326dd6c'
assert doc('ci/driver-parse.json')['ok']
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
trace = [e for e in events if e['kind'].startswith('day5-') or (e['kind']=='native-boundary' and e['data']['stage']=='day5-before-query')]
report = dict(archive=receipt, origin=origin, verified_members=len(manifest), outcomes=outcomes, day5_trace=trace)
(out / 'verification.json').write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps(dict(archive=receipt, verified_members=len(manifest), outcomes=outcomes, day5_trace=trace), indent=2))
