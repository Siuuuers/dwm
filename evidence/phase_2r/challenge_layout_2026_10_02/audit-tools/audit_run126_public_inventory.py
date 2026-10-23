#!/usr/bin/env python3
"""Verify source-bound Run126 inventories, then adopt exactly the two generated JSONs."""
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import subprocess
from types import SimpleNamespace
import zipfile

import cloud_evidence as cloud

ROOT = Path('/workspace/scratch/e169b180163f')
REPO = ROOT / 'dwm'
RUN = ROOT / 'run126'
BASE = '638f2aab3cbceaa13729793760dfc85dc8842e93'
SOURCE = '6cac4882ab68c2b16d658e7b95da5e93b328eee4'
ALLOWED_REFERENCE_FILE = 'tests/integration/verify_reading_rail_journey.gd'


def git(path, commit):
    return subprocess.check_output(['git', 'show', f'{commit}:{path}'], cwd=REPO)


def identity(raw):
    return {'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}


def delta(before, after):
    return {'added': [value for value in after if value not in before],
            'removed': [value for value in before if value not in after]}


def main():
    args = SimpleNamespace(repo=REPO, source=SOURCE, checkout=SOURCE, master=None, allow_source_diff=[])
    raw_run = cloud.read(RUN / 'run.json')
    assert raw_run['run_number'] == 126 and raw_run['status'] == 'completed' and raw_run['conclusion'] == 'success'
    inventory = cloud.artifact_inventory(RUN, [ROOT / 'attachments'], cloud.read(RUN / 'omissions.json'))
    jobs = cloud.job_audit(RUN, SOURCE, 1, [])
    gut = cloud.xml_audit(RUN, raw_run['id'], 1)
    assert gut['case_executions'] == gut['unique_cases'] == 11
    assert gut['unique_scripts'] == 1
    assert jobs[0]['name'] == 'Windows / public API surface contracts'
    boundary = cloud.source_boundary(args)
    generic = {'schema_version': 1, 'generic_audit_pass': True,
        'audit_scope': 'Intentional public-inventory-only cloud gate; no reading artifact is required or claimed.',
        'raw_metadata_identities': {name: cloud.identity(RUN / name) for name in ('run.json', 'jobs.json', 'artifacts-api.json')},
        'run': {key: raw_run.get(key) for key in ('id', 'run_number', 'run_attempt', 'head_sha', 'head_branch', 'event', 'html_url', 'status', 'conclusion')},
        'source_boundary': boundary, 'jobs': jobs, 'gut': gut, 'reading': [], 'artifact_inventory': inventory,
        'limits': ['This is the focused public-inventory gate, not the rendered journey or broad game gate.',
            'The workflow head is distinct from the exact source checkout.',
            'No Godot or PowerShell executed locally during audit and adoption.']}
    artifact = next(row for row in cloud.read(RUN / 'artifact-manifest.json') if row['name'].startswith('public-surfaces-'))
    assert artifact['workflow_run']['id'] == raw_run['id']
    assert artifact['workflow_run']['head_sha'] == raw_run['head_sha']
    archive = Path(artifact['local_zip'])
    archive_identity = identity(archive.read_bytes())
    assert archive_identity['bytes'] == artifact['size_in_bytes']
    assert 'sha256:' + archive_identity['sha256'] == artifact['digest']
    folder = RUN / 'artifacts' / artifact['name'] / 'ci/public-surfaces'
    unchanged = ['autoload/GameState.gd', 'autoload/SaveManager.gd', 'tools/runtime/PublicSurfaceInventory.gd',
        'evidence/phase_2r/runtime/game_state_required_surface.json',
        'evidence/phase_2r/runtime/save_manager_required_surface.json']
    unchanged_identities = {}
    for path in unchanged:
        old = git(path, BASE)
        assert old == git(path, SOURCE), f'Changed owner/scanner/required contract: {path}'
        unchanged_identities[path] = identity(old)
    report = {'schema_version': 1, 'audit_pass': False, 'run_id': raw_run['id'], 'run_number': 126,
        'baseline': BASE, 'tested_source': SOURCE, 'workflow_head': raw_run['head_sha'],
        'artifact': {'id': artifact['id'], 'name': artifact['name'], **archive_identity},
        'source_checkout_verified': True, 'gut': gut, 'unchanged_owner_scanner_required_files': unchanged_identities,
        'reference_semantics': 'The scanner is lexical, not receiver-aware. Existing references retain exactly the same source text and only line numbers move.',
        'inventories': {}, 'adopted_paths': []}
    prepared = []
    for stem, count in [('game_state', 236), ('save_manager', 74)]:
        name = stem + '_surface.json'
        path = 'evidence/phase_2r/runtime/' + name
        old_raw = git(path, BASE)
        assert git(path, SOURCE) == old_raw, f'Source unexpectedly already changed inventory: {path}'
        assert (REPO / path).read_bytes() == old_raw, f'Local inventory changed before adoption: {path}'
        new_raw = (folder / name).read_bytes()
        with zipfile.ZipFile(archive) as zipped:
            members = [member for member in zipped.namelist() if member.endswith('/' + name)]
            assert len(members) == 1 and zipped.read(members[0]) == new_raw
        old, new = cloud.strict_json(old_raw), cloud.strict_json(new_raw)
        assert new['ok'] is True and new['errors'] == []
        assert len(old['records']) == len(new['records']) == count
        contracts = lambda document: [{key: value for key, value in row.items() if key != 'call_sites'} for row in document['records']]
        assert contracts(old) == contracts(new), f'Changed declarations/contracts: {stem}'
        assert {key: value for key, value in old.items() if key not in ('records', 'dynamic_references')} == {
            key: value for key, value in new.items() if key not in ('records', 'dynamic_references')}
        old_rows = {row['symbol']: row for row in old['records']}
        new_rows = {row['symbol']: row for row in new['records']}
        assert len(old_rows) == len(new_rows) == count
        changes, evidence = {'call_sites': [], 'dynamic_references': []}, []
        for kind, before, after in [
                ('call_sites', {key: row['call_sites'] for key, row in old_rows.items()}, {key: row['call_sites'] for key, row in new_rows.items()}),
                ('dynamic_references', old['dynamic_references'], new['dynamic_references'])]:
            for symbol in sorted(before.keys() | after.keys()):
                difference = delta(before.get(symbol, []), after.get(symbol, []))
                if not any(difference.values()):
                    assert before.get(symbol, []) == after.get(symbol, []), 'Unexpected reference reorder'
                    continue
                changes[kind].append({'symbol': symbol, **difference})
                for direction in ('added', 'removed'):
                    for site in difference[direction]:
                        file, line = site.rsplit(':', 1)
                        assert file == ALLOWED_REFERENCE_FILE, f'Unexpected reference file: {site}'
                        text = git(file, SOURCE if direction == 'added' else BASE).decode().splitlines()[int(line) - 1]
                        assert re.search(r'(?<![A-Za-z0-9_])' + re.escape(symbol) + r'(?![A-Za-z0-9_])', text), (site, symbol)
                        evidence.append({'kind': kind, 'symbol': symbol, 'direction': direction, 'site': site, 'source_line': text})
                # Adjacent references can retain a numeric location while a different
                # original line moves into it. Compare the complete scoped multisets,
                # not only the set difference of path:line strings.
                def source_texts(sites, revision):
                    source_lines = git(ALLOWED_REFERENCE_FILE, revision).decode().splitlines()
                    return Counter(source_lines[int(site.rsplit(':', 1)[1]) - 1]
                        for site in sites if site.rsplit(':', 1)[0] == ALLOWED_REFERENCE_FILE)
                assert source_texts(before.get(symbol, []), BASE) == source_texts(after.get(symbol, []), SOURCE), f'Non-relocation reference delta: {stem}/{symbol}'
        report['inventories'][stem] = {'declarations': count, 'all_contracts_unchanged': True,
            'all_reference_deltas_are_exact_source_line_relocations': True, 'baseline': identity(old_raw),
            'generated': identity(new_raw), 'deltas': changes, 'source_reference_evidence': evidence,
            **{direction + '_' + kind: sum(len(item[direction]) for item in changes[kind])
               for direction in ('added', 'removed') for kind in changes}}
        prepared.append((path, new_raw, old_raw))
    # Every source, archive, job, test and declaration/reference check precedes mutations.
    for path, new_raw, old_raw in prepared:
        if new_raw != old_raw:
            (REPO / path).write_bytes(new_raw)
            assert (REPO / path).read_bytes() == new_raw
            report['adopted_paths'].append(path)
    report['audit_pass'] = True
    (RUN / 'audit').mkdir(exist_ok=True)
    for name, value in [('generic-evidence-audit.json', generic), ('public-inventory-audit.json', report)]:
        encoded = cloud.encoded(value)
        cloud.scan(encoded, name)
        (RUN / 'audit' / name).write_bytes(encoded)
    print(json.dumps({'audit_pass': True, 'adopted_paths': report['adopted_paths'], 'gut_cases': gut['case_executions'],
        'declarations': {key: value['declarations'] for key, value in report['inventories'].items()}}))


if __name__ == '__main__':
    main()
