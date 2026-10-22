import hashlib, io, json, pathlib, re, zipfile
import xml.etree.ElementTree as ET

root = pathlib.Path(__file__).resolve().parent
data = (root / '39124136055-evidence.zip').read_bytes()
z = zipfile.ZipFile(io.BytesIO(data))
manifest = json.loads(z.read('ci/retained-hashes.json'))
assert set(z.namelist()) == set(manifest) | {'ci/retained-hashes.json'}
for name, receipt in manifest.items():
    raw = z.read(name)
    assert len(raw) == receipt['bytes']
    assert hashlib.sha256(raw).hexdigest() == receipt['sha256']
origin = json.loads(z.read('ci/audit-origin.json').decode('utf-8-sig'))
source_pins = {"ci/source/scripts/application/backup/BackupPresentationPort.gd":"4524984d3ef3e74bdcbab1c296232a603f0eb040","ci/source/scripts/ui/BackupApp.gd":"69be339643d27ab6e35efb945e3505915ad2cbb1","ci/source/tests/integration/test_pause_backup_host.gd":"8b9db30f2d38f42da6f1a7cfb46e23a01848157f","ci/source/tests/integration/test_scene_backup_inspection.gd":"7b1668331f05106649fe1589a3709f4ff178272b","ci/source/tests/unit/test_backup_presentation.gd":"3c5029d294bf29027e0cf662354d13c0b6ff209a","ci/source/tools/testing/Invoke-IsolatedGodot.ps1":"14b379880b4ad26935ad953d141df8c19e399cf3"}
for name, sha in source_pins.items():
    raw = z.read(name)
    assert hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest() == sha
assert origin['candidate'] == '8a431447b3fffa180b4cdd22fdc8f74a40e95d77'
assert origin['tree'] == '8aa17066accfc5ae8877780b50007acc16df0aea'
assert origin['controller'] == '1817a808e390030850d42eba086189ad8676f45f'
baseline = ET.fromstring(z.read('ci/baseline.xml'))
assert len(baseline.findall('.//testcase')) == 1
assert len(baseline.findall('.//failure')) == 1
assert not baseline.findall('.//error')
reports = {}
for folder, name in [('unit','test_backup_presentation'), ('integration','test_scene_backup_inspection'), ('integration','test_pause_backup_host')]:
    source = z.read(f'ci/source/tests/{folder}/{name}.gd').decode()
    expected = set(re.findall(r'^func (test_\w+)\(', source, re.M))
    xml = ET.fromstring(z.read(f'ci/{name}.xml'))
    cases = xml.findall('.//testcase')
    assert {case.attrib['name'] for case in cases} == expected
    assert len(cases) == len(expected)
    assert not xml.findall('.//failure') and not xml.findall('.//error') and not xml.findall('.//skipped')
    receipts = [json.loads(line) for line in z.read(f'ci/{name}.jsonl').decode('utf-8-sig').splitlines() if line.strip()]
    assert len(receipts) == 1 and receipts[0]['exit_code'] == 0
    reports[name] = {'tests':len(cases),'assertions':sum(int(case.attrib.get('assertions',0)) for case in cases),'exit_code':0}
result = {'archive_bytes':len(data),'archive_sha256':hashlib.sha256(data).hexdigest(),'verified_members':len(manifest),'origin':origin,'suites':reports,'baseline_failure':baseline.find('.//failure').attrib}
(root / 'refresh-verification.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
