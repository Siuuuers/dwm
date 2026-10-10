"""Fixed, source-pinned evidence for C's one-file settled-teardown increment."""
import hashlib
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import urllib.request
import xml.etree.ElementTree as ET
import zipfile

SOURCE = '69a5cdd70261692b7f1b1e2d4550155141ca6375'
BASE = '68a51519dedbfe572a2ec943926a964a59db6974'
TREE = 'da00da734204d41c10cebbe2cb2295f28e77a016'
TEST = 'tests/integration/test_scene_app_preparation.gd'
BLOB = '38ddc30af3dd5c0beed7deaf3648ea7d1064d1fc'
PREFIX = 'scene-app-teardown'
OUT = Path('.godot/ci')
BRANCH = 'codex/scene-runtime-evidence-20261009'

def git(*args, cwd=None):
    return subprocess.check_output(['git', *args], cwd=cwd)

def text(*args, cwd=None):
    return git(*args, cwd=cwd).decode().strip()

def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')

def sha(data):
    return hashlib.sha256(data).hexdigest()

def source_clean():
    if git('diff', '--name-only', 'HEAD').strip():
        raise RuntimeError('Tracked source changed')
    extras = text('ls-files', '--others', '--exclude-standard')
    if extras:
        raise RuntimeError('Untracked source: ' + extras)

def functions(data):
    return dict(re.findall(r'^func (\w+)\([^\n]*\n(.*?)(?=^func |\Z)', data, re.M | re.S))

def prepare():
    OUT.mkdir(parents=True, exist_ok=True)
    assert text('rev-parse', 'HEAD') == SOURCE
    assert text('rev-parse', 'HEAD^{tree}') == TREE
    assert text('rev-parse', 'HEAD^') == BASE
    assert text('diff', '--name-only', BASE, SOURCE).splitlines() == [TEST]
    assert text('rev-parse', f'HEAD:{TEST}') == BLOB
    assert text('rev-parse', f'{BASE}:{TEST}') == '5bd350238c5f8948839297eee3ded5f96f9a4d70'
    git('diff', '--check', BASE, SOURCE)
    source_clean()
    old = functions(git('show', f'{BASE}:{TEST}').decode())
    new = functions(Path(TEST).read_text(encoding='utf-8'))
    for name, body in old.items():
        if name not in ('before_each', 'after_each'):
            assert new[name] == body, name + ' body changed'
    assert len([x for x in old if x.startswith('test_')]) == 10
    assert len([x for x in new if x.startswith('test_')]) == 11
    (OUT / 'source.patch').write_bytes(git('diff', '--binary', '--full-index', BASE, SOURCE))
    git('archive', '--format=zip', '-o', str(OUT / 'source-inspection.zip'), SOURCE,
        'autoload', 'scripts', 'scenes', 'tests', 'addons', 'tools', 'docs/design',
        'project.godot', '.github/workflows/windows-tests.yml')
    controller = os.environ['CONTROLLER_SHA']
    receipt = {'source_sha': SOURCE, 'source_tree': TREE, 'parent': BASE,
        'changed_paths': [TEST], 'constituent_blobs': {TEST: BLOB},
        'c_source': 'b1a50d8eab7e0fb09e792c6030a54f9052f84686',
        'controller_sha': controller, 'event_sha': os.environ['GITHUB_SHA'],
        'workflow_blob': text('rev-parse', 'HEAD:.github/workflows/windows-tests.yml', cwd='../controller'),
        'helper_blob': text('rev-parse', 'HEAD:tools/cloud/scene_app_teardown.py', cwd='../controller'),
        'run_id': os.environ['GITHUB_RUN_ID'], 'run_attempt': os.environ['GITHUB_RUN_ATTEMPT']}
    write_json(OUT / 'source-receipt.json', receipt)

def census():
    source_clean()
    root = ET.parse(OUT / 'apps.xml').getroot()
    cases = list(root.iter('testcase'))
    declared = re.findall(r'^func (test_\w+)\(', Path(TEST).read_text(encoding='utf-8'), re.M)
    actual = [case.attrib['name'] for case in cases]
    assert len(cases) == 11 and sorted(actual) == sorted(declared)
    for tag in ('failure', 'error', 'skipped'):
        assert not list(root.iter(tag)), tag
    for suite in root.iter('testsuite'):
        assert all(int(suite.get(key, '0')) == 0 for key in ('failures', 'errors', 'skipped'))
    log = Path('.godot/phase2r_logs/scene-app-teardown.log').read_text(encoding='utf-8-sig')
    snapshots = [json.loads(line) for line in re.findall(r'SCENE_APP_TEARDOWN (\{[^\r\n]*\})', log)]
    assert len(snapshots) == 11, f'Expected 11 teardown observations, got {len(snapshots)}'
    assert all(x['after_two_frames'] == {} for x in snapshots), 'Persistent node observed'
    summary = {'source_sha': SOURCE, 'cases': len(cases),
        'xml_testcase_assertions': sum(int(x.get('assertions', '0')) for x in cases),
        'test_names': actual, 'settled_teardown_observations': snapshots,
        'scope': 'Mounted fixture UI node lifecycle only; no production storage, RefCounted/timer or whole-game memory claim.'}
    write_json(OUT / 'apps-summary.json', summary)
    print(json.dumps(summary, indent=2))

def manifest():
    files = sorted(p for p in OUT.glob('*') if p.is_file() and p.name != 'original-file-hashes.json')
    files += sorted(Path('.godot/phase2r_logs').glob('*.log'))
    write_json(OUT / 'original-file-hashes.json', [
        {'path': p.as_posix(), 'bytes': len(p.read_bytes()), 'sha256': sha(p.read_bytes())} for p in files])

def api(path):
    req = urllib.request.Request('https://api.github.com/repos/Siuuuers/dwm/' + path,
        headers={'Authorization': 'Bearer ' + os.environ['GH_TOKEN'],
                 'Accept': 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28'})
    with urllib.request.urlopen(req, timeout=120) as response:
        return response.read()

def retain_failed_checkout():
    """Retain the original pre-engine failure; it is never counted as a test pass."""
    folder = Path('evidence/scene_app_teardown_2026_10_10/38028509673-1')
    original = folder / 'scene-app-teardown-38028509673-1.zip'
    digest = '16eea0d4d1c06fe887fe3669db51349246ed238c19d450e76989fa36ed1e4c99'
    if folder.exists():
        assert sha(original.read_bytes()) == digest
        assert (folder / 'failed-checkout-verification.json').is_file()
        return
    data = api('actions/artifacts/11660909076/zip')
    assert sha(data) == digest
    archive = zipfile.ZipFile(io.BytesIO(data))
    assert archive.testzip() is None
    assert archive.namelist() == ['ci/original-file-hashes.json']
    assert json.loads(archive.read('ci/original-file-hashes.json')) == []
    folder.mkdir(parents=True)
    original.write_bytes(data)
    run = json.loads(api('actions/runs/38028509673'))
    assert run['head_sha'] == '18d37922553c6fef38a736c591fa1e20cac7b03d'
    assert run['conclusion'] == 'failure'
    write_json(folder / 'run.json', run)
    jobs = json.loads(api('actions/runs/38028509673/jobs?per_page=100'))
    write_json(folder / 'jobs.json', jobs)
    for job in (114144350803, 114144490256):
        (folder / f'job-{job}.log').write_bytes(api(f'actions/jobs/{job}/logs'))
    proof = {'run_id': 38028509673, 'run_attempt': 1,
        'artifact_id': 11660909076, 'zip_sha256': digest,
        'manifest_members_verified': 0, 'engine_executed': False,
        'reason': 'Checkout immediate credential removal hit malformed inherited gitlink metadata; source verification and all engine steps skipped. Original retention then lacked a source receipt.',
        'files': [{'path': p.name, 'bytes': len(p.read_bytes()), 'sha256': sha(p.read_bytes())}
                  for p in sorted(folder.iterdir()) if p.is_file()]}
    write_json(folder / 'failed-checkout-verification.json', proof)
    (folder / 'README.md').write_text('# Original pre-engine checkout failure\n\n'
        'Run38028509673/1 failed during checkout credential removal before source validation or Godot. '
        'No engine test executed. The original empty-manifest ZIP and both original job logs are retained. '
        'The controller-only correction defers credential cleanup until the existing disposable-index cleanup; '
        'candidate69a5cdd7 and every test assertion are unchanged.\n', encoding='utf-8')
    git('config', 'user.name', 'Siuuuers')
    git('config', 'user.email', '119431590+Siuuuers@users.noreply.github.com')
    git('add', '--', str(folder))
    git('commit', '-m', 'evidence: retain original pre-engine checkout failure38028509673')
    git('push', 'origin', f'HEAD:refs/heads/{BRANCH}')
    print(json.dumps({'failure_evidence_sha': text('rev-parse', 'HEAD'), **proof}, indent=2))

def retain():
    retain_failed_checkout()
    run, attempt = os.environ['GITHUB_RUN_ID'], os.environ['GITHUB_RUN_ATTEMPT']
    name = f'{PREFIX}-{run}-{attempt}'
    artifacts = json.loads(api(f'actions/runs/{run}/artifacts?per_page=100'))['artifacts']
    matches = [x for x in artifacts if x['name'] == name and not x['expired']]
    assert len(matches) == 1
    meta = matches[0]
    data = api(f"actions/artifacts/{meta['id']}/zip")
    archive = zipfile.ZipFile(io.BytesIO(data))
    assert archive.testzip() is None
    names = [n for n in archive.namelist() if not n.endswith('/')]
    assert len(names) == len(set(names))
    records = json.loads(archive.read('ci/original-file-hashes.json'))
    expected = []
    for entry in records:
        member = entry['path'].removeprefix('.godot/')
        expected.append(member)
        content = archive.read(member)
        assert len(content) == entry['bytes'] and sha(content) == entry['sha256'], member
    assert set(expected) == set(names) - {'ci/original-file-hashes.json'}
    source = json.loads(archive.read('ci/source-receipt.json'))
    assert source['source_sha'] == SOURCE and source['source_tree'] == TREE
    folder = Path(f'evidence/scene_app_teardown_2026_10_10/{run}-{attempt}')
    assert not folder.exists(), 'Append-only evidence destination already exists'
    folder.mkdir(parents=True)
    (folder / f'{name}.zip').write_bytes(data)
    summary = json.loads(archive.read('ci/apps-summary.json')) if 'ci/apps-summary.json' in names else None
    proof = {'artifact_id': meta['id'], 'zip_bytes': len(data), 'zip_sha256': sha(data),
        'manifest_members_verified': len(records), 'source': source, 'summary': summary,
        'engine_execution': 'No engine execution in retention job'}
    write_json(folder / 'retention-verification.json', proof)
    status = 'Targeted census passed' if summary else 'No passing census; original failure retained'
    (folder / 'README.md').write_text(f'# Scene app settled-teardown evidence\n\n{status}.\n\n'
        f'Source `{SOURCE}`, parent `{BASE}`, exact one C test-file blob `{BLOB}`.\n'
        f'Original Actions run {run}/{attempt}, artifact {meta["id"]}; ZIP SHA256 `{sha(data)}`.\n'
        f'All {len(records)} manifest members rehashed. See retention-verification.json for original source and counts.\n\n'
        'Only the changed 11-case app lane runs. Prior 8-case desktop acceptance is reused, not rerun. '
        'This is bounded fixture UI-node evidence, not whole-game memory, production storage or playable acceptance.\n', encoding='utf-8')
    git('config', 'user.name', 'Siuuuers')
    git('config', 'user.email', '119431590+Siuuuers@users.noreply.github.com')
    git('add', '--', str(folder))
    git('commit', '-m', f'evidence: retain original settled-teardown run {run}/{attempt}')
    git('push', 'origin', f'HEAD:refs/heads/{BRANCH}')
    print(json.dumps({'evidence_sha': text('rev-parse', 'HEAD'), **proof}, indent=2))

if __name__ == '__main__':
    modes = {'prepare': prepare, 'census': census, 'manifest': manifest, 'retain': retain}
    if len(sys.argv) != 2 or sys.argv[1] not in modes:
        raise SystemExit('Expected prepare, census, manifest, or retain')
    modes[sys.argv[1]]()
