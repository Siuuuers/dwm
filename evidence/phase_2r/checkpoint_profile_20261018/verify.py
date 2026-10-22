import base64, hashlib, io, json, pathlib, re, sys, zipfile

source = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2]); out.mkdir(parents=True, exist_ok=True)
if source.suffix == '.zip':
    raw = source.read_bytes()
    receipt = {'bytes': 1041039, 'sha256': '839fefe9232367290fd3ef4ae12f9720e4ac24223d4843ac20a61f10e6548b7a'}
else:
    log = source.read_text()
    receipt = json.loads(re.search(r'DWM_EVIDENCE_BEGIN (\{[^\r\n]+\})', log)[1])
    chunks = re.findall(r'DWM_EVIDENCE_CHUNK ([A-Za-z0-9+/=]+)', log)
    raw = base64.b64decode(''.join(chunks), validate=True)
assert len(raw) == receipt['bytes'] and hashlib.sha256(raw).hexdigest() == receipt['sha256']
(out / '39131596323-evidence.zip').write_bytes(raw)
z = zipfile.ZipFile(io.BytesIO(raw))
def doc(path): return json.loads(z.read(path).decode('utf-8-sig'))
manifest = doc('ci/retained-hashes.json')
assert set(z.namelist()) == set(manifest) | {'ci/retained-hashes.json'}
for path, entry in manifest.items():
    data = z.read(path)
    assert len(data) == entry['bytes'] and hashlib.sha256(data).hexdigest() == entry['sha256'], path
origin = doc('ci/audit-origin.json')
assert origin['candidate'] == 'afbaeb0994bba9070df2c18e17cd8d474b666b09'
assert origin['tree'] == '35549a89ffa36d40a951035df0a7cc915947b112'
assert origin['controller'] == 'b93ccbb73eed31dc7770298a27dd26642b52cb01'
driver = z.read('ci/source/tools/testing/Invoke-ExportedGameplay.ps1')
assert hashlib.sha1(b'blob '+str(len(driver)).encode()+b'\0'+driver).hexdigest() == '3f715a4e503de5427175b2b819640c4dc221c504'
assert doc('ci/driver-parse.json')['ok']
checks = doc('ci/deadline-tests.json')
assert checks['ok'] and len(checks['cases']) == 4 and all(c['ok'] for c in checks['cases'])
test_source = z.read('ci/source/tests/tooling/Test-ExportedGameplayDeadline.ps1')
assert hashlib.sha1(b'blob '+str(len(test_source)).encode()+b'\0'+test_source).hexdigest() == '436c73a380baec1a3bc6ba64d273ff052e316d78'
export = doc('ci/windows-export/validation.json')
assert export['ok'] and export['commit'] == '193691f9dfa06aed698274cd1ce7346cee77857a'
assert export['archive']['sha256'] == '4291ba8bcc07a1077a4cea4f5b99f20c5352c5dbe15885a1523dd2b77922f237'
outcomes = {}
for mode in ('capability', 'create', 'load'):
    prefix = 'ci/exported-' + mode + '/'
    if prefix + 'result.json' not in z.namelist(): continue
    for item in doc(prefix + 'manifest.json'):
        data = z.read(prefix + item['file'])
        assert len(data) == item['bytes'] and hashlib.sha256(data).hexdigest() == item['sha256']
    result = doc(prefix + 'result.json')
    outcomes[mode] = {k: result.get(k) for k in ('ok','failure','elapsed_seconds','exit_code','clean_player_exit','forced_cleanup','continued_after_quiet','restored_checkpoint_matches')}
    assert result['source_commit'] == export['commit']
    assert result['archive_sha256'] == export['archive']['sha256']
source_pins = {}
for name in ('GameState', 'DialogicBridge'):
    path = 'autoload/' + name + '.gd'
    data = z.read('ci/source/' + path)
    source_pins[path] = hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
assert source_pins == {'autoload/GameState.gd': 'c015a954089738ccc4a805e351b51e0c4294210b', 'autoload/DialogicBridge.gd': '6542701617c214f5de9486e7558da03c3c2b6787'}
data = z.read('ci/source/scripts/application/run/SaveManagerCheckpointPort.gd')
source_pins['scripts/application/run/SaveManagerCheckpointPort.gd'] = hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
assert source_pins['scripts/application/run/SaveManagerCheckpointPort.gd'] == '37df70df455d7b8c49780bedb27a7ada25e5117a'
data = z.read('ci/source/scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd')
source_pins['scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd'] = hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
assert source_pins['scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd'] == '5cb4ada73c8faa8ad22405447266ad566f1aa87e'
profiles = []
for line in z.read('ci/exported-load/game.stdout.log').decode('utf-8-sig', errors='replace').splitlines():
    for prefix in ('DWM_SAVE_LOAD_PROFILE ', 'DWM_CHECKPOINT_PROFILE '):
        if prefix not in line: continue
        item = json.loads(line.split(prefix,1)[1])
        profiles.append(dict(file='ci/exported-load/game.stdout.log', prefix=prefix.strip(), **item))
assert doc('ci/exported-load/result.json')['checkpoint_profile']
assert any(p['prefix']=='DWM_CHECKPOINT_PROFILE' for p in profiles)
events = doc('ci/exported-load/events.json') if 'ci/exported-load/events.json' in z.namelist() else []
trace = [e for e in events if e['kind'].startswith(('day5-', 'native-caption-', 'caption-', 'wait-deadline-')) or (e['kind']=='native-boundary' and e['data']['stage'].startswith('caption-before-query'))]
report = dict(archive=receipt, origin=origin, verified_members=len(manifest), outcomes=outcomes, deadline_tests=checks, source_pins=source_pins, forward_profiles=profiles, export=export, primary_forward_profiles=[p for p in profiles if p['scope'].startswith('scene_forward')], native_trace=trace)
(out / 'verification.json').write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps(dict(archive=receipt, verified_members=len(manifest), outcomes=outcomes, deadline_tests=checks, source_pins=source_pins, profile_count=len(profiles)), indent=2))
