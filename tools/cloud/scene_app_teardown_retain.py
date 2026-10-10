"""Verify and retain original cloud evidence. This program never runs Godot."""
from decimal import Decimal
import hashlib
import io
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
import zipfile

SOURCE = '69a5cdd70261692b7f1b1e2d4550155141ca6375'
BASE = '68a51519dedbfe572a2ec943926a964a59db6974'
TREE = 'da00da734204d41c10cebbe2cb2295f28e77a016'
TEST = 'tests/integration/test_scene_app_preparation.gd'
BLOB = '38ddc30af3dd5c0beed7deaf3648ea7d1064d1fc'
BRANCH = 'codex/scene-runtime-evidence-20261009'
SCOPE = 'Fixture-owned Node teardown only. No production memory, storage, rendered desktop, playable-producer or release acceptance.'
RUNS = [
    (38028509673, 11660909076, '18d37922553c6fef38a736c591fa1e20cac7b03d', '16eea0d4d1c06fe887fe3669db51349246ed238c19d450e76989fa36ed1e4c99'),
    (38028858250, 11661047481, '9e4412c76f3ad57727c8eb4d3e84da8ccd783880', 'e7646cf93821b18dbb5b6f9a15c4c55d2396e6354748e52c3f312d650548db24'),
]

def git(*args, cwd='../source'):
    return subprocess.check_output(['git', *args], cwd=cwd)

def gtext(*args, cwd='../source'):
    return git(*args, cwd=cwd).decode('utf-8').strip()

def sha(data):
    return hashlib.sha256(data).hexdigest()

def blob(data):
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()

def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

def api(path):
    url = 'https://api.github.com/repos/Siuuuers/dwm/' + path
    request = urllib.request.Request(url, headers={
        'Authorization': 'Bearer ' + os.environ['GH_TOKEN'],
        'Accept': 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28'})
    try:
        with urllib.request.build_opener(NoRedirect).open(request, timeout=120) as response:
            return response.read()
    except urllib.error.HTTPError as error:
        if error.code not in (301, 302, 303, 307, 308):
            raise
        location = urllib.parse.urljoin(url, error.headers['Location'])
        if urllib.parse.urlsplit(location).scheme != 'https':
            raise RuntimeError('Refused non-HTTPS artifact redirect')
        # The signed download URL needs no GitHub credential. Do not forward it.
        with urllib.request.urlopen(urllib.request.Request(location), timeout=120) as response:
            return response.read()

def original_archive(data):
    archive = zipfile.ZipFile(io.BytesIO(data))
    assert archive.testzip() is None
    names = [n for n in archive.namelist() if not n.endswith('/')]
    assert len(names) == len(set(names))
    records = json.loads(archive.read('ci/original-file-hashes.json'))
    expected = []
    for entry in records:
        assert entry['path'].startswith('.godot/')
        member = entry['path'][7:]
        expected.append(member)
        value = archive.read(member)
        assert len(value) == entry['bytes'] and sha(value) == entry['sha256'], member
    assert set(expected) == set(names) - {'ci/original-file-hashes.json'}
    return archive, records

def census(archive):
    nested = zipfile.ZipFile(io.BytesIO(archive.read('ci/source-inspection.zip')))
    assert nested.testzip() is None
    source = nested.read(TEST)
    assert blob(source) == BLOB
    declared = re.findall(r'^func (test_\w+)\(', source.decode('utf-8'), re.M)
    root = ET.fromstring(archive.read('ci/apps.xml'))
    cases = list(root.iter('testcase'))
    names = [case.attrib['name'] for case in cases]
    assert len(cases) == 11 and len(set(names)) == 11 and sorted(names) == sorted(declared)
    assert 'test_teardown_probe_distinguishes_queued_children_from_unqueued_survivor' in names
    for tag in ('failure', 'error', 'skipped'):
        assert not list(root.iter(tag)), tag
    # Decimal admits exact zero forms such as 0.0 without truncating nonzero values.
    for suite in [root, *root.iter('testsuite')]:
        for key in ('failures', 'errors', 'skipped'):
            assert Decimal(suite.get(key, '0')) == 0, (key, suite.attrib)
        assert Decimal(suite.get('tests', '11')) == 11
    log = archive.read('phase2r_logs/scene-app-teardown.log').decode('utf-8-sig')
    clean = re.sub(r'\x1b\[[0-9;]*m', '', log)
    for member in ('ci/import.log', 'phase2r_logs/scene-app-teardown.log'):
        assert not re.search(r'SCRIPT ERROR:|ERROR: Failed to load|Unicode parsing error|Unexpected NUL character', archive.read(member).decode('utf-8-sig'))
    snapshots = [json.loads(line) for line in re.findall(r'SCENE_APP_TEARDOWN (\{[^\r\n]*\})', clean)]
    assert len(snapshots) == 11 and all(x['after_two_frames'] == {} for x in snapshots)
    assertions = sum(int(case.get('assertions', '0')) for case in cases)
    gut_assertions = re.findall(r'^Asserts\s+(\d+)\s*$', clean, re.M)
    assert gut_assertions == [str(assertions)]
    assert re.findall(r'^Passing Tests\s+(\d+)\s*$', clean, re.M) == ['11']
    assert 'All tests passed!' in clean
    runner = [json.loads(line) for line in archive.read('ci/apps.jsonl').decode('utf-8-sig').splitlines() if line.strip()]
    assert len(runner) == 1 and runner[0]['exit_code'] == 0
    assert '-gtest=res://' + TEST in runner[0]['argv']
    engine = json.loads(archive.read('ci/engine-receipt.json').decode('utf-8-sig'))
    assert engine['version'] == '4.6.3.stable.official.7d41c59c4'
    assert engine['archive_sha256'] == 'e39986a178d585ce7ac198fb8de6ea436366dc0cc00e594810c2e3e104c04b90'
    assert engine['console_sha256'] == '63b3b2208819714c9677fbfdd8217c5b7dee8ecf5f383502e826bc9e2227ff5a'
    warnings = [line for line in clean.splitlines() if re.search(r'WARNING:|Orphans|leaked', line)]
    return {'cases': 11, 'xml_testcase_assertions': assertions, 'gut_assertions': int(gut_assertions[0]),
        'test_names': names, 'settled_teardown_observations': snapshots, 'diagnostic_warning_lines': warnings,
        'source_sha': SOURCE, 'engine': engine, 'scope': SCOPE, 'new_engine_executions': 0}

def source_check(archive):
    receipt = json.loads(archive.read('ci/source-receipt.json'))
    assert receipt['source_sha'] == SOURCE and receipt['source_tree'] == TREE
    assert receipt['parent'] == BASE and receipt['changed_paths'] == [TEST]
    assert receipt['constituent_blobs'] == {TEST: BLOB}
    assert receipt['run_id'] == '38028858250' and receipt['run_attempt'] == '1'
    assert gtext('rev-parse', 'HEAD') == SOURCE and gtext('rev-parse', 'HEAD^{tree}') == TREE
    assert gtext('rev-parse', 'HEAD^') == BASE
    assert gtext('diff', '--name-only', BASE, SOURCE).splitlines() == [TEST]
    git('diff', '--check', BASE, SOURCE)
    assert archive.read('ci/source.patch') == git('diff', '--binary', '--full-index', BASE, SOURCE)
    controller = receipt['controller_sha']
    assert controller == RUNS[1][2]
    for key, path in [('workflow_blob', '.github/workflows/windows-tests.yml'), ('helper_blob', 'tools/cloud/scene_app_teardown.py')]:
        assert receipt[key] == gtext('rev-parse', f'{controller}:{path}')
    nested = zipfile.ZipFile(io.BytesIO(archive.read('ci/source-inspection.zip')))
    git_blobs = {}
    for item in git('ls-tree', '-rz', '--full-tree', SOURCE).split(b'\0'):
        if not item:
            continue
        metadata, name = item.split(b'\t', 1)
        mode, kind, object_id = metadata.decode().split()
        if kind == 'blob':
            git_blobs[name.decode('utf-8')] = object_id
    inspected = 0
    for name in nested.namelist():
        if name.endswith('/'):
            continue
        assert blob(nested.read(name)) == git_blobs[name], name
        inspected += 1
    assert inspected > 100
    functions = lambda data: dict(re.findall(r'^func (\w+)\([^\n]*\n(.*?)(?=^func |\Z)', data.decode(), re.M | re.S))
    old, new = functions(git('show', f'{BASE}:{TEST}')), functions(nested.read(TEST))
    assert len([x for x in old if x.startswith('test_')]) == 10
    for name, body in old.items():
        if name not in ('before_each', 'after_each'):
            assert new[name] == body, name
    return {'receipt': receipt, 'archived_git_blobs_verified': inspected, 'unchanged_original_test_bodies': 10}

def main():
    retained = []
    for run_id, artifact_id, controller, digest in RUNS:
        meta = json.loads(api(f'actions/artifacts/{artifact_id}'))
        assert meta['workflow_run']['id'] == run_id and not meta['expired']
        assert meta['digest'] == 'sha256:' + digest
        data = api(f'actions/artifacts/{artifact_id}/zip')
        assert sha(data) == digest and len(data) == meta['size_in_bytes']
        archive, records = original_archive(data)
        folder = Path(f'evidence/scene_app_teardown_2026_10_10/{run_id}-1')
        assert not folder.exists(), 'Append-only destination already exists'
        folder.mkdir(parents=True)
        (folder / f'scene-app-teardown-{run_id}-1.zip').write_bytes(data)
        run = json.loads(api(f'actions/runs/{run_id}'))
        assert run['head_sha'] == controller and run['run_attempt'] == 1 and run['conclusion'] == 'failure'
        jobs = json.loads(api(f'actions/runs/{run_id}/jobs?per_page=100'))
        write(folder / 'original-run.json', run)
        write(folder / 'original-jobs.json', jobs)
        for job in jobs['jobs']:
            original_log = api(f"actions/jobs/{job['id']}/logs")
            (folder / f"job-{job['id']}.log").write_bytes(original_log)
            tail = original_log.decode('utf-8-sig', errors='replace')
            if 'Traceback (most recent call last)' in tail:
                print('Original job', job['id'], tail[tail.rfind('Traceback (most recent call last)'):][:2200])
        proof = {'run_id': run_id, 'run_attempt': 1, 'original_run_conclusion': 'failure',
            'artifact_id': artifact_id, 'zip_sha256': digest, 'zip_bytes': len(data),
            'manifest_members_verified': len(records), 'verification_controller': os.environ['CONTROLLER_SHA'],
            'verification_run': os.environ['GITHUB_RUN_ID'], 'new_engine_executions': 0, 'scope': SCOPE}
        if run_id == RUNS[0][0]:
            assert records == []
            proof['disposition'] = 'Pre-engine checkout failure retained, not passing coverage.'
        else:
            source = source_check(archive)
            summary = census(archive)
            write(folder / 'independent-census.json', summary)
            proof.update(source)
            proof['summary'] = summary
            proof['disposition'] = 'Original eleven engine tests pass independently verified; original post-test workflow and retention failures remain recorded as failures.'
        write(folder / 'retention-verification.json', proof)
        (folder / 'README.md').write_text('# Original cloud evidence and independent verification\n\n' +
            proof['disposition'] + '\n\nOriginal ZIP and logs are unchanged. The separate census uses exact zero-value numeric comparisons, not integer truncation. '
            'Source archive Git blobs, the one-file patch, ten original test bodies, declared/executed names, XML, engine log, runner exit, engine identity and eleven settled snapshots are checked. '
            'This verification and retention run executes no Godot and adds no test run to the count.\n\n' + SCOPE + '\n', encoding='utf-8')
        write(folder / 'retained-file-hashes.json', [{'path': p.name, 'sha256': sha(p.read_bytes()), 'bytes': len(p.read_bytes())} for p in sorted(folder.iterdir()) if p.is_file()])
        retained.append(str(folder))
        print(json.dumps(proof, indent=2))
    git('config', 'user.name', 'Siuuuers', cwd='.')
    git('config', 'user.email', '119431590+Siuuuers@users.noreply.github.com', cwd='.')
    git('add', '--', *retained, cwd='.')
    git('commit', '-m', 'evidence: retain original teardown runs with independent no-engine census', cwd='.')
    git('push', 'origin', f'HEAD:refs/heads/{BRANCH}', cwd='.')
    print('EVIDENCE_COMMIT=' + gtext('rev-parse', 'HEAD', cwd='.'))

if __name__ == '__main__':
    main()
