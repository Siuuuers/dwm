"""Pinned cloud-only composition, census and original-artifact retention for A.

This controller does not run an engine locally or move A's product branch.
"""
from __future__ import annotations
import hashlib
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
import zipfile

A = '665971ffc25bf6acd5e393ac37c6cf627a33c545'
A_TREE = 'aaeacf4e338e1d876157e19fce239259b4093899'
C_BASE = 'ae82ccd951ca4c6797b5ea18dcbfba6035fd60fb'
C = 'ccbd363d68bc28fbfc88cc56ea1080f8cdb84745'
C_TREE = 'fb775316f43f40016c41c1090f8b174cb0e4e736'
EVIDENCE = 'c8fa301d5888d83c021a9963bc78b2f8e03cdbe4'
PATHS = '''scripts/domain/desktop/DesktopAppRegistry.gd
scripts/ui/BackupApp.gd
scripts/ui/ComputerDesktop.gd
scripts/ui/ContactListApp.gd
scripts/ui/MinesweeperApp.gd
scripts/ui/SettingsApp.gd
scripts/ui/SettingsContent.gd
scripts/ui/SettingsTheme.gd
scripts/ui/ShopApp.gd
scripts/ui/ShopItemBox.gd
scripts/ui/backup/BackupTheme.gd
scripts/ui/contacts/ContactsPanel.gd
scripts/ui/contacts/ContactsTheme.gd
scripts/ui/minesweeper/MinesweeperCell.gd
scripts/ui/minesweeper/MinesweeperDock.gd
scripts/ui/minesweeper/MinesweeperGrid.gd
scripts/ui/minesweeper/MinesweeperInformationSheet.gd
scripts/ui/minesweeper/MinesweeperPanel.gd
scripts/ui/minesweeper/MinesweeperRegister.gd
scripts/ui/minesweeper/MinesweeperTheme.gd
scripts/ui/minesweeper/MinesweeperWorksheet.gd
scripts/ui/shop/ShopTheme.gd
tests/integration/test_scene_app_preparation.gd
tests/integration/test_scene_desktop_consumer.gd
tests/support/SceneAppPreparationFixture.gd
tests/support/SceneDesktopConsumerFixture.gd'''.splitlines()
UIDS = [p + '.uid' for p in PATHS if p.startswith('tests/')]
SUITES = {'tests/integration/test_scene_app_preparation.gd': 10,
          'tests/integration/test_scene_desktop_consumer.gd': 8}
SCOPE = ('Composed app presentation and cached desktop protocol only. Lower storage, '
         'app ports and preparation are injected. No connected production Backup, '
         'physical Save/Load, playable producer, rendered or release acceptance.')
OUT = Path('.godot/ci')

def require(value: bool, message: str) -> None:
    if not value:
        raise RuntimeError(message)

def git(*args: str, binary: bool = False):
    value = subprocess.check_output(['git', *args])
    return value if binary else value.decode('utf-8').strip()

def write_json(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')

def commit(message: str) -> None:
    git('config', 'user.name', 'github-actions[bot]')
    git('config', 'user.email', '41898282+github-actions[bot]@users.noreply.github.com')
    date = git('-C', '../controller', 'show', '-s', '--format=%cI', 'HEAD')
    os.environ['GIT_AUTHOR_DATE'] = date
    os.environ['GIT_COMMITTER_DATE'] = date
    git('commit', '-m', message)

def record() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    paths = git('diff', '--name-only', A, 'HEAD').splitlines()
    require(set(paths) in (set(PATHS), set(PATHS + UIDS)), 'Unexpected product path set')
    for path in PATHS:
        require(git('rev-parse', 'HEAD:' + path) == git('rev-parse', C + ':' + path),
                'Constituent drift: ' + path)
    git('merge-base', '--is-ancestor', A, 'HEAD')
    value = dict(source_sha=git('rev-parse', 'HEAD'), source_tree=git('rev-parse', 'HEAD^{tree}'),
                 parent=git('rev-parse', 'HEAD^'), a_base=A, a_tree=A_TREE, c_base=C_BASE,
                 c_source=C, c_tree=C_TREE, changed_paths=paths,
                 constituent_blobs={p: git('rev-parse', 'HEAD:' + p) for p in paths},
                 controller_sha=os.environ['CONTROLLER_SHA'], controller_event_sha=os.environ['GITHUB_SHA'],
                 controller_workflow_blob=git('-C', '../controller', 'rev-parse', 'HEAD:.github/workflows/windows-tests.yml'),
                 run_id=os.environ['GITHUB_RUN_ID'], run_attempt=os.environ['GITHUB_RUN_ATTEMPT'], scope=SCOPE)
    write_json(OUT / 'source-receipt.json', value)
    (OUT / 'source.patch').write_bytes(git('diff', '--binary', '--full-index', A, 'HEAD', binary=True))
    git('archive', '-o', str(OUT / 'source-inspection.zip'), 'HEAD',
        'scripts', 'autoload', 'tests', 'tools', 'docs', 'project.godot', '.github', 'scenes')

def compose() -> None:
    require(git('rev-parse', 'HEAD') == A, 'Wrong A checkout')
    require(git('rev-parse', 'HEAD^{tree}') == A_TREE, 'Wrong A tree')
    require(git('ls-remote', '--heads', 'origin', 'refs/heads/codex/scene-runtime-integration-20261009').split()[0] == A,
            'A advanced; recompose rather than overwrite')
    git('fetch', 'origin', C)
    require(git('rev-parse', C + '^{tree}') == C_TREE, 'Wrong C tree')
    require(set(git('diff', '--name-only', C_BASE, C).splitlines()) == set(PATHS), 'Wrong C delta')
    for path in PATHS:
        require(git('ls-tree', A, '--', path) == git('ls-tree', C_BASE, '--', path),
                'Shared-path divergence requires reconciliation: ' + path)
    OUT.mkdir(parents=True, exist_ok=True)
    patch = OUT / 'c-source.patch'
    patch.write_bytes(git('diff', '--binary', '--full-index', C_BASE, C, binary=True))
    git('apply', '--index', str(patch))
    require(set(git('diff', '--cached', '--name-only').splitlines()) == set(PATHS), 'Wrong staged paths')
    git('diff', '--cached', '--check')
    commit('feat(desktop): compose reviewed C scene app presentation on current A')
    record()

def uids() -> None:
    for path in UIDS:
        require(Path(path).is_file(), 'Imported companion missing: ' + path)
        require(re.fullmatch(r'uid://[a-z0-9]+\s*', Path(path).read_text(encoding='utf-8')) is not None,
                'Invalid imported UID: ' + path)
    require(len({Path(p).read_text().strip() for p in UIDS}) == len(UIDS), 'Duplicate imported companions')
    git('diff', '--exit-code', 'HEAD')
    git('add', '--', *UIDS)
    require(set(git('diff', '--cached', '--name-only').splitlines()) == set(UIDS), 'Wrong UID paths')
    git('diff', '--cached', '--check')
    commit('test(desktop): retain four engine-imported scene app UID companions')
    record()

def census() -> None:
    xml = ET.parse(OUT / 'apps.xml')
    require(not any(xml.findall('.//' + tag) for tag in ('failure', 'error', 'skipped')), 'XML failure/error/skip')
    actual = [s for s in xml.iter('testsuite') if s.findall('testcase')]
    require(len(actual) == len(SUITES), 'Wrong executed suite count')
    totals = []
    for path, count in SUITES.items():
        declared = re.findall(r'^func (test_[A-Za-z0-9_]+)\(', Path(path).read_text(encoding='utf-8'), re.M)
        matches = [s for s in actual if s.get('name', '').removeprefix('res://') == path]
        require(len(matches) == 1, 'Missing/repeated suite: ' + path)
        cases = matches[0].findall('testcase')
        require(len(declared) == count and len(set(declared)) == count, 'Declared count drift: ' + path)
        require(sorted(c.get('name') for c in cases) == sorted(declared), 'Executed census drift: ' + path)
        totals.append(dict(script=path, cases=len(cases), xml_assertions=sum(int(c.get('assertions', '0')) for c in cases),
                           declared_tests=declared))
    git('diff', '--exit-code', 'HEAD')
    require(git('diff', '--name-only', A, 'HEAD').splitlines() == sorted(PATHS + UIDS), 'Final path drift')
    write_json(OUT / 'apps-summary.json', dict(suites=totals, cases=sum(s['cases'] for s in totals),
               xml_assertions=sum(s['xml_assertions'] for s in totals), failures=0, errors=0, skips=0, scope=SCOPE))
    source = git('rev-parse', 'HEAD')
    ref = 'refs/heads/codex/scene-app-composed-candidate-20261010'
    existing = git('ls-remote', '--heads', 'origin', ref)
    require(not existing or existing.split()[0] == source, 'Candidate changed; refuse overwrite')
    git('push', 'origin', 'HEAD:' + ref)
    write_json(OUT / 'candidate-publication.json', dict(branch=ref, source_sha=source, product_branch_moved=False))

def manifest() -> None:
    paths = [p for folder in (OUT, Path('.godot/phase2r_logs')) if folder.exists()
             for p in folder.iterdir() if p.is_file() and p.name != 'original-file-hashes.json']
    write_json(OUT / 'original-file-hashes.json', [dict(path=p.as_posix(), bytes=p.stat().st_size,
               sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in sorted(paths)])

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

def api(path: str, binary: bool = False):
    req = urllib.request.Request('https://api.github.com/repos/Siuuuers/dwm/' + path,
          headers={'Authorization': 'Bearer ' + os.environ['GH_TOKEN'], 'Accept': 'application/vnd.github+json',
                   'X-GitHub-Api-Version': '2022-11-28', 'User-Agent': 'dwm-cloud-evidence'})
    try:
        with urllib.request.build_opener(NoRedirect).open(req, timeout=90) as response:
            data = response.read()
    except urllib.error.HTTPError as error:
        if error.code not in (301, 302, 303, 307, 308) or not binary:
            raise
        # Signed artifact redirects are fetched without forwarding repository credentials.
        location = error.headers['Location']
        require(location.startswith('https://'), 'Unsafe artifact redirect')
        with urllib.request.urlopen(location, timeout=90) as response:
            data = response.read()
    return data if binary else json.loads(data)

def retain() -> None:
    run, attempt = os.environ['GITHUB_RUN_ID'], os.environ['GITHUB_RUN_ATTEMPT']
    name = f'scene-app-composed-{run}-{attempt}'
    artifacts = api(f'actions/runs/{run}/artifacts?per_page=100')['artifacts']
    found = [a for a in artifacts if a['name'] == name and not a['expired']]
    require(len(found) == 1, 'Original artifact missing or duplicated')
    artifact = found[0]
    data = api(f"actions/artifacts/{artifact['id']}/zip", binary=True)
    digest = hashlib.sha256(data).hexdigest()
    require(len(data) == artifact['size_in_bytes'], 'Archive size mismatch')
    require(artifact.get('digest') == 'sha256:' + digest, 'Archive digest mismatch')
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        require(archive.testzip() is None, 'ZIP CRC failure')
        names = [n for n in archive.namelist() if not n.endswith('/')]
        require(len(names) == len(set(names)), 'Duplicate archive members')
        members = json.loads(archive.read('ci/original-file-hashes.json').decode('utf-8-sig'))
        expected = {'ci/original-file-hashes.json'}
        for member in members:
            path = member['path'].removeprefix('.godot/')
            require(path not in expected, 'Duplicate manifest member')
            expected.add(path)
            body = archive.read(path)
            require(len(body) == member['bytes'] and hashlib.sha256(body).hexdigest() == member['sha256'],
                    'Manifest mismatch: ' + path)
        require(set(names) == expected, 'Manifest coverage mismatch')
        source = json.loads(archive.read('ci/source-receipt.json').decode('utf-8-sig'))
        summary = json.loads(archive.read('ci/apps-summary.json').decode('utf-8-sig'))
    require(git('rev-parse', 'HEAD') == EVIDENCE, 'Wrong evidence checkout')
    ref = 'refs/heads/codex/scene-runtime-evidence-20261009'
    require(git('ls-remote', '--heads', 'origin', ref).split()[0] == EVIDENCE, 'Evidence advanced; reconcile')
    folder = Path('evidence/scene_app_composed_2026_10_10')
    require(not folder.exists(), 'Evidence folder already exists')
    folder.mkdir(parents=True)
    (folder / ('original-' + name + '.zip')).write_bytes(data)
    verification = dict(artifact_id=artifact['id'], archive_bytes=len(data), archive_sha256=digest,
                        verified_manifest_members=len(members), source=source, summary=summary)
    write_json(folder / 'retention-verification.json', verification)
    (folder / 'README.md').write_text(
        '# Original composed scene app evidence\n\n'
        f"Run {run}, attempt {attempt}; artifact {artifact['id']}. Original ZIP SHA256 `{digest}`.\n\n"
        f"Source `{source['source_sha']}`, tree `{source['source_tree']}`. "
        f"Exact C26 paths on A `{A}`, plus four engine-imported UID companions.\n\n"
        f"{summary['cases']} executed cases, {summary['xml_assertions']} XML testcase assertions; "
        'zero failure/error/skip. GUT-log assertion totals remain separately reported in the original log.\n\n'
        f'All {len(members)} original manifest members rehashed; originals were not reconstructed.\n\n'
        + SCOPE + '\n\nIndependent D acceptance remains separate. No engine rerun during retention.\n', encoding='utf-8')
    require(not git('diff', '--name-only'), 'Existing evidence changed')
    added = git('ls-files', '--others', '--exclude-standard').splitlines()
    expected_paths = sorted(str(p.as_posix()) for p in folder.iterdir())
    require(sorted(added) == expected_paths, 'Unexpected evidence additions')
    git('add', '--', folder.as_posix())
    commit('docs(evidence): retain original composed scene app and desktop cloud proof')
    git('push', 'origin', 'HEAD:' + ref)
    print('EVIDENCE_COMMIT=' + git('rev-parse', 'HEAD'))

if __name__ == '__main__':
    require(len(sys.argv) == 2 and sys.argv[1] in ('compose', 'uids', 'census', 'manifest', 'retain'), 'Choose one mode')
    globals()[sys.argv[1]]()
