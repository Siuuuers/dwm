#!/usr/bin/env python3
"""Review successor cloud-regenerated inventories and prepare exact-byte adoption paths.

No repository mutation. Does not require unrelated focused jobs to pass: only
this completed regeneration job is admitted, and broad acceptance stays separate.
"""
from __future__ import annotations
import argparse
import io
import json
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import zipfile
from audit_settings_load_inventory import digest, load_parser, clean

ROOTS = ('autoload', 'scripts', 'scenes', 'tests')
SCANNER = 'tools/runtime/PublicSurfaceInventory.gd'
PREDECESSOR_IDENTITY = {'path': 'review_settings_load_inventories.py', 'bytes': 16149, 'sha256': '6347d93dbf836b1af19780c2fdb677a0f8ae6eeed6e10c46563d338fc0a99d3c'}


def scan_blobs(source, require):
    paths = source.git('ls-tree', '-r', '--name-only', source.commit, '--', *ROOTS).decode().splitlines()
    paths = sorted(p for p in paths if PurePosixPath(p).suffix in ('.gd', '.tscn')
                   and not any(part.startswith('.') for part in PurePosixPath(p).parts[:-1]))
    requests = ''.join(source.commit + ':' + p + '\n' for p in paths).encode()
    data = subprocess.check_output(['git', 'cat-file', '--batch'], cwd=source.repo, input=requests)
    stream, result = io.BytesIO(data), {}
    for path in paths:
        header = stream.readline().decode().strip().split()
        require(len(header) == 3 and header[1] == 'blob', 'SOURCE_SCAN_BLOB_MISSING: ' + path)
        raw = stream.read(int(header[2]))
        require(stream.read(1) == b'\n', 'SOURCE_BATCH_BOUNDARY_INVALID')
        result[path] = raw
    require(stream.read() == b'', 'SOURCE_BATCH_EXTRA_BYTES')
    return result


def reference_sets(blobs, facade, symbols):
    result = {symbol: {'static': [], 'dynamic': []} for symbol in symbols}
    if not symbols:
        return result
    pattern = re.compile(r'\b(?:' + '|'.join(re.escape(symbol) for symbol in sorted(symbols, key=len, reverse=True)) + r')\b')
    for root in ROOTS:
        for path in sorted(p for p in blobs if p.startswith(root + '/') and p != facade):
            for number, line in enumerate(blobs[path].decode('utf-8').split('\n'), 1):
                for symbol in set(pattern.findall(line)):
                    kind = 'dynamic' if '"' + symbol + '"' in line else 'static'
                    result[symbol][kind].append(f'{path}:{number}')
    return result


def review(a, d):
    require = d.require
    root = a.run_root.resolve()
    run, jobs, api = (d.read(root / name) for name in ('run.json', 'jobs.json', 'artifacts-api.json'))
    require(jobs.get('total_count', len(jobs['jobs'])) == len(jobs['jobs'])
            and api.get('total_count', len(api['artifacts'])) == len(api['artifacts']), 'COMPLETE_API_PAGINATION_REQUIRED')
    selected = [j for j in jobs['jobs'] if j['name'] == a.public_job and j['run_attempt'] == run['run_attempt']]
    require(len(selected) == 1 and selected[0]['status'] == 'completed' and selected[0]['conclusion'] == 'success',
            'EXACT_SUCCESSFUL_REGENERATION_JOB_REQUIRED')
    job = selected[0]
    required_steps = ('Generate affected public inventories for review', 'Verify public inventory drift and read-only contracts')
    for name in required_steps:
        steps = [s for s in job['steps'] if s['name'] == name]
        require(len(steps) == 1 and steps[0]['conclusion'] == 'success', 'REGENERATION_STEP_NOT_PASSED: ' + name)
    log = root / 'logs' / (str(job['id']) + '.log')
    lines = [clean(line) for line in log.read_text(encoding='utf-8-sig').splitlines()]
    checkouts = [lines[i + 1] for i, line in enumerate(lines[:-1]) if 'log -1 --format=%H' in line
                 and re.fullmatch('[0-9a-f]{40}', lines[i + 1])]
    require(checkouts and set(checkouts) == {a.checkout}, 'ACTUAL_REGENERATION_CHECKOUT_NOT_PROVEN')
    require(any('Invoke-PublicSurfaceValidation.ps1 -Regenerate -EmitPayloads' in line for line in lines)
            and lines.count('PUBLIC_SURFACE_VALIDATION_VERIFIED: both complete-tree inventories reproduce canonical bytes.') == 1,
            'EXECUTED_REGENERATE_AND_READ_ONLY_VERIFICATION_REQUIRED')
    name = f"public-surfaces-{run['id']}-{run['run_attempt']}"
    artifacts = [row for row in api['artifacts'] if row['name'] == name]
    require(len(artifacts) == 1, 'EXACT_CURRENT_PUBLIC_ARTIFACT_REQUIRED')
    artifact = artifacts[0]
    require(artifact['workflow_run']['id'] == run['id'] and artifact['workflow_run']['head_sha'] == run['head_sha'],
            'PUBLIC_ARTIFACT_WORKFLOW_IDENTITY_DIFFERS')
    retained = [r for r in d.read(root / 'artifact-manifest.json') if r['id'] == artifact['id'] and r['name'] == name]
    require(len(retained) == 1, 'EXACT_ORIGINAL_PUBLIC_ZIP_REQUIRED')
    archive_path = Path(retained[0]['local_zip'])
    require(d.identity(archive_path) == {'bytes': artifact['size_in_bytes'], 'sha256': artifact['digest'].removeprefix('sha256:')},
            'PUBLIC_ZIP_API_SIZE_OR_DIGEST_DIFFERS')
    folder = root / 'artifacts' / name
    with zipfile.ZipFile(archive_path) as archive:
        members = [row for row in archive.infolist() if not row.is_dir()]
        names = {row.filename for row in members}
        require(len(names) == len(members), 'PUBLIC_ZIP_DUPLICATE_MEMBERS')
        for member in members:
            path = d.contained(folder.resolve(), member.filename)
            require(not stat.S_ISLNK(member.external_attr >> 16) and not path.is_symlink(), 'PUBLIC_ZIP_SYMLINK_FORBIDDEN')
            require(path.read_bytes() == archive.read(member), 'PUBLIC_ZIP_EXTRACTED_BYTES_DIFFER: ' + member.filename)
        require({p.relative_to(folder).as_posix() for p in folder.rglob('*') if p.is_file()} == names, 'EXACT_PUBLIC_EXTRACTED_MEMBER_SET_REQUIRED')
    inspection = inspect_candidates(a, d, folder)
    return {'schema_version': 1, 'inventory_review_pass': True, 'whole_run_acceptance_claimed': False,
        'run_id': run['id'], 'run_attempt': run['run_attempt'], 'workflow_head': run['head_sha'], 'run_conclusion': run['conclusion'],
        'source': a.source, 'checkout': a.checkout, 'baseline': a.baseline, 'public_job_id': job['id'],
        'job_log_identity': d.identity(log), 'executed_steps': list(required_steps),
        'artifact': {'id': artifact['id'], 'name': name, 'original_zip_identity': d.identity(archive_path), 'verified_members': len(members)},
        'inputs': {name: d.identity(root / name) for name in ('run.json', 'jobs.json', 'artifacts-api.json', 'artifact-manifest.json')},
        **inspection,
        'limits': ['This report prepares exact reviewed artifact bytes for adoption and does not write repository files.',
                   'Only changed-symbol references are independently rescanned across the four frozen roots; declarations are compared in full and canonical cloud checks validate complete generated inventories.',
                   'Regeneration does not prove committed inventories were adopted; the final canonical read-only broad gate must verify that later source.',
                   'The scanner classifies quoted-symbol lines as dynamic and other word-boundary matches as static; this is reference inventory, not callgraph or behavior proof.']}


def inspect_candidates(a, d, folder):
    require = d.require
    root = a.run_root.resolve()
    baseline, source, checkout = (d.Source(a.repo.resolve(), sha) for sha in (a.baseline, a.source, a.checkout))
    source.git('merge-base', '--is-ancestor', a.baseline, a.source)
    require(source.blob(SCANNER) == baseline.blob(SCANNER) == checkout.blob(SCANNER), 'CHANGED_SCANNER_REQUIRES_REVIEW')
    candidates, changed_symbols = {}, set()
    for filename in ('game_state_surface.json', 'save_manager_surface.json'):
        source_path = 'evidence/phase_2r/runtime/' + filename
        path = folder / 'ci/public-surfaces' / filename
        current, old = d.read(path), json.loads(baseline.blob(source_path))
        require(source.blob(source_path) == checkout.blob(source_path), 'COMMITTED_SOURCE_CHECKOUT_INVENTORY_DIFFERS')
        committed = json.loads(source.blob(source_path))
        def declarations(document):
            return [{k: v for k, v in row.items() if k != 'call_sites'} for row in document['records']]
        require(current['ok'] is True and current['errors'] == [] and committed['ok'] is True and committed['errors'] == []
                and declarations(current) == declarations(committed) == declarations(old)
                and current['required'] == committed['required'] == old['required']
                and current['script'] == committed['script'] == old['script'], 'REGENERATED_OR_COMMITTED_PUBLIC_DECLARATIONS_CHANGED')
        old_records = {r['symbol']: r for r in old['records']}
        new_records = {r['symbol']: r for r in current['records']}
        require(len(new_records) == len(current['records']) == len(old_records), 'DUPLICATE_OR_CHANGED_PUBLIC_RECORDS')
        committed_records = {r['symbol']: r for r in committed['records']}
        require(len(committed_records) == len(committed['records']) == len(old_records)
                and set(committed['dynamic_references']) <= set(committed_records), 'INVALID_COMMITTED_PUBLIC_SYMBOL_SET')
        changes, committed_changes = {}, {}
        for symbol in new_records:
            before = {'static': old_records[symbol]['call_sites'], 'dynamic': old['dynamic_references'].get(symbol, [])}
            after = {'static': new_records[symbol]['call_sites'], 'dynamic': current['dynamic_references'].get(symbol, [])}
            prior_adopted = {'static': committed_records[symbol]['call_sites'], 'dynamic': committed['dynamic_references'].get(symbol, [])}
            if prior_adopted != after:
                committed_changes[symbol] = {'before_committed': prior_adopted, 'after_generated': after}
            if before != after or prior_adopted != after:
                changes[symbol] = {'before': before, 'after': after, 'differs_from_baseline': before != after}
        changed_symbols.update(changes)
        require(set(current['dynamic_references']) <= set(new_records), 'UNKNOWN_DYNAMIC_PUBLIC_SYMBOL')
        candidates[filename] = (path, source_path, current['script'].removeprefix('res://'), changes, len(new_records), committed_changes)
    before_blobs, after_blobs = scan_blobs(baseline, require), scan_blobs(source, require)
    tested_blobs = scan_blobs(checkout, require) if a.checkout != a.source else after_blobs
    require(after_blobs == tested_blobs, 'SCANNER_ROOT_SOURCE_CHECKOUT_BYTES_DIFFER')
    reviewed, touched = {}, set()
    for filename, (path, source_path, facade, changes, count, committed_changes) in candidates.items():
        before_refs = reference_sets(before_blobs, facade, set(changes))
        after_refs = reference_sets(after_blobs, facade, set(changes))
        for symbol, change in changes.items():
            require(change['before'] == before_refs[symbol], 'BASELINE_REFERENCE_SET_DIFFERS: ' + filename + '/' + symbol)
            require(change['after'] == after_refs[symbol], 'GENERATED_REFERENCE_SET_DIFFERS: ' + filename + '/' + symbol)
            evidence = {}
            for kind in ('static', 'dynamic'):
                removed = sorted(set(change['before'][kind]) - set(change['after'][kind]))
                added = sorted(set(change['after'][kind]) - set(change['before'][kind]))
                def observations(sites, blobs):
                    result = []
                    for site in sites:
                        name, number = site.rsplit(':', 1)
                        touched.add(name)
                        result.append({'path': name, 'line': int(number), 'text': blobs[name].decode('utf-8').split('\n')[int(number) - 1],
                                       'blob_identity': digest(blobs[name])})
                    return result
                evidence[kind] = {'added': observations(added, after_blobs), 'removed': observations(removed, before_blobs)}
            change['source_evidence'] = evidence
        reviewed[filename] = {'artifact_file': path.relative_to(root).as_posix(), 'adoption_source': str(path),
            'adoption_destination': str(a.repo.resolve() / source_path), 'repository_path': source_path,
            'adoption_identity': d.identity(path), 'prior_committed_identity': digest(source.blob(source_path)),
            'accepted_baseline_inventory_identity': digest(baseline.blob(source_path)),
            'committed_inventory_equals_checkout': True,
            'committed_to_generated_diff': committed_changes,
            'committed_inventory_bytes_already_current': path.read_bytes() == source.blob(source_path),
            'public_declarations_unchanged': True, 'record_count': count, 'changed_symbols': changes,
            'every_changed_static_and_dynamic_reference_reconciled': True}
    return {'source': a.source, 'checkout': a.checkout, 'baseline': a.baseline,
        'scanner': {'path': SCANNER, **digest(source.blob(SCANNER)), 'unchanged_from_baseline': True},
        'scanned_source_files': {'baseline': len(before_blobs), 'candidate': len(after_blobs)},
        'inventories': reviewed, 'predecessor_helper_identity': PREDECESSOR_IDENTITY,
        'successor_reason': 'Committed inventories may contain a previously reviewed intermediate adoption; exact source/checkout bytes remain required, and accepted baseline/current/committed declarations must all agree.',
        'auditor_identity': d.identity(Path(__file__)), 'parser_identity': d.identity(a.parser)}



def prepare_artifact(a, d):
    require = d.require
    root = a.run_root.resolve()
    artifact = d.read(a.artifact_metadata)
    require(artifact['workflow_run']['head_sha'] == a.workflow_head, 'EXACT_ARTIFACT_WORKFLOW_HEAD_REQUIRED')
    require(artifact['name'] == f"public-surfaces-{artifact['workflow_run']['id']}-{a.attempt}", 'EXACT_ARTIFACT_RUN_ATTEMPT_REQUIRED')
    archive_path = Path(artifact['local_zip'])
    require(d.identity(archive_path) == {'bytes': artifact['size_in_bytes'], 'sha256': artifact['digest'].removeprefix('sha256:')},
            'PUBLIC_ZIP_API_SIZE_OR_DIGEST_DIFFERS')
    folder = root / 'artifacts' / artifact['name']
    with zipfile.ZipFile(archive_path) as archive:
        members = [row for row in archive.infolist() if not row.is_dir()]
        names = {row.filename for row in members}
        require(len(names) == len(members), 'PUBLIC_ZIP_DUPLICATE_MEMBERS')
        for member in members:
            path = d.contained(folder.resolve(), member.filename)
            require(not stat.S_ISLNK(member.external_attr >> 16) and not path.is_symlink(), 'PUBLIC_ZIP_SYMLINK_FORBIDDEN')
            path.parent.mkdir(parents=True, exist_ok=True)
            raw = archive.read(member)
            if path.exists(): require(path.read_bytes() == raw, 'PRIOR_EXTRACTION_DIFFERS')
            else: path.write_bytes(raw)
            require(path.read_bytes() == raw, 'PUBLIC_ZIP_EXTRACTED_BYTES_DIFFER')
        require({p.relative_to(folder).as_posix() for p in folder.rglob('*') if p.is_file()} == names, 'EXACT_PUBLIC_EXTRACTED_MEMBER_SET_REQUIRED')
    inspection = inspect_candidates(a, d, folder)
    return {'schema_version': 1, 'inventory_review_pass': True, 'whole_run_acceptance_claimed': False,
        'job_execution_audit_pending': True, 'run_id': artifact['workflow_run']['id'], 'run_attempt': a.attempt,
        'workflow_head': a.workflow_head, 'artifact': {'id': artifact['id'], 'name': artifact['name'],
            'original_zip_identity': d.identity(archive_path), 'verified_members': len(members)},
        'metadata_identity': d.identity(a.artifact_metadata), **inspection,
        'limits': ['Early artifact-only preparation: final retained API jobs/log audit must still establish the actual regeneration checkout and successful steps.',
                   'Exact ZIP/API digest and extracted bytes are verified; source semantics are independently checked against supplied exact commit objects.',
                   'No repository files are written. Later adoption still requires the canonical committed-inventory broad gate.']}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--run-root', type=Path, required=True)
    p.add_argument('--repo', type=Path, required=True)
    p.add_argument('--source', required=True)
    p.add_argument('--checkout', required=True)
    p.add_argument('--baseline', required=True)
    p.add_argument('--artifact-metadata', type=Path)
    p.add_argument('--workflow-head')
    p.add_argument('--attempt', type=int, default=1)
    p.add_argument('--public-job', default='Windows / public API surface contracts')
    p.add_argument('--parser', type=Path, default=Path(__file__).parent / 'settings_f5_review_adapters_v2/audit_coverage_test_discovery.py')
    p.add_argument('--output', type=Path)
    a = p.parse_args()
    d = load_parser(a.parser)
    for sha in (a.source, a.checkout, a.baseline): d.full_sha(sha)
    target = a.output or a.run_root / 'audit/settings-load-inventory-adoption-review.json'
    target.parent.mkdir(parents=True, exist_ok=True)
    try:
        report = prepare_artifact(a, d) if a.artifact_metadata else review(a, d)
    except Exception as error:
        target.write_text(json.dumps({'inventory_review_pass': False, 'source': a.source, 'checkout': a.checkout,
                                      'failure': {'type': type(error).__name__, 'message': str(error)}}, indent=2) + '\n')
        raise
    target.write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
    print(json.dumps({'inventory_review_pass': True, 'output': str(target),
        'changed_symbols': {name: len(row['changed_symbols']) for name, row in report['inventories'].items()}}))


if __name__ == '__main__':
    main()
