#!/usr/bin/env python3
"""Parameterised source/XML discovery and public-inventory evidence join.

Read-only Git/Python inspection; no engine, PowerShell, network or repository edits.
The accepted discovery parser is reused by hash-bound import rather than copied.
"""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess


def load_parser(path):
    spec = importlib.util.spec_from_file_location('accepted_discovery', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def clean(line):
    return re.sub(r'^\ufeff?\d{4}-\d\d-\d\dT\S+\s', '',
                  re.sub(r'\x1b\[[0-9;]*m', '', line)).strip()


def digest(raw):
    return {'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}


def common(a, d):
    root = a.run_root.resolve()
    run = d.read(root / 'run.json')
    generic = d.read(root / 'audit/generic-evidence-audit.json')
    boundary = d.read(root / 'audit/source-provenance.json')
    d.require(generic.get('generic_audit_pass') is True, 'PASSING_GENERIC_AUDIT_REQUIRED')
    d.require(boundary == generic['source_boundary'] and boundary['source'] == a.source
              and boundary['tested_checkout'] == a.checkout, 'EXACT_SOURCE_CHECKOUT_REQUIRED')
    d.require(boundary['all_unlisted_paths_byte_identical'] is True, 'SOURCE_EQUIVALENCE_REQUIRED')
    d.require(all(generic['run'][k] == run[k] for k in
        ('id', 'run_number', 'run_attempt', 'event', 'head_sha', 'status', 'conclusion')), 'RUN_METADATA_MISMATCH')
    d.require(run['status'] == 'completed' and run['conclusion'] == 'success', 'SUCCESSFUL_FINAL_RUN_REQUIRED')
    for name, expected in generic['raw_metadata_identities'].items():
        d.require(d.identity(d.contained(root, name)) == expected, 'RAW_METADATA_CHANGED: ' + name)
    sources = [d.Source(a.repo.resolve(), value) for value in (a.baseline, a.source, a.checkout)]
    sources[1].git('merge-base', '--is-ancestor', a.baseline, a.source)
    report = {'schema_version': 1, 'audit_complete': False, 'run_id': run['id'],
        'run_attempt': run['run_attempt'], 'source': a.source, 'tested_checkout': a.checkout,
        'workflow_head': run['head_sha'], 'baseline': a.baseline,
        'input_identities': {name: d.identity(root / name) for name in
            ('run.json', 'audit/source-provenance.json', 'audit/generic-evidence-audit.json')},
        'auditor_identity': d.identity(Path(__file__)), 'accepted_parser_identity': d.identity(a.parser),
        'limits': ['Only selected completed cloud artifacts establish execution.',
                   'Workflow helper head is separately recorded and need not equal actual tested source.',
                   'No Godot or PowerShell executes in this auditor.']}
    return root, run, generic, sources, report


def discovery(a, d):
    root, run, generic, (baseline, source, checkout), out = common(a, d)
    all_suites = source.suites()
    names = a.suite or sorted(all_suites)
    d.require(len(set(names)) == len(names) and set(names) <= set(all_suites), 'UNKNOWN_OR_DUPLICATE_SELECTED_SUITE')
    suites = {name: all_suites[name] for name in names}
    observed, counts, xml = d.selected_xml(root, generic, suites, source)
    expected = source.counts(suites)
    d.require(counts == expected, 'SOURCE_DECLARED_AND_OBSERVED_COUNTS_DIFFER')
    d.require(all_suites == checkout.suites(), 'SOURCE_CHECKOUT_REGISTRY_DIFFERS')
    registered = {path for paths in all_suites.values() for path in paths}
    complete = [{'suite': name, 'script': path, 'tests': sorted(source.effective(path))}
                for name in sorted(all_suites) for path in all_suites[name]]
    observed_rows = [{'script': path, 'test': name, 'selected_xml': files}
                     for (path, name), files in sorted(observed.items())]
    changed = source.git('diff', '--name-only', '--no-renames', a.baseline, a.source, '--', 'tests').decode().splitlines()
    added, removed = [], []
    for path in changed:
        if not path.endswith('.gd'):
            continue
        before, after = baseline.declared(path), source.declared(path)
        for name in sorted(after - before):
            d.require(path in registered, 'NEW_TEST_UNREGISTERED: ' + path + '/' + name)
            selected = path in {p for paths in suites.values() for p in paths}
            if selected:
                d.require((path, name) in observed, 'ADDED_TEST_UNDISCOVERED: ' + path + '/' + name)
            added.append({'script': path, 'test': name, 'selected': selected,
                          'selected_xml': observed.get((path, name), [])})
        removed += [{'script': path, 'test': name} for name in sorted(before - after)]
    new_scripts = sorted(path for path in source.paths - baseline.paths if path.endswith('.gd') and source.declared(path))
    d.require(set(new_scripts) <= registered, 'NEW_TEST_SCRIPT_UNREGISTERED')
    identities = []
    for path in sorted(source.blobs):
        raw = source.blob(path)
        d.require(raw == checkout.blob(path), 'TESTED_CHECKOUT_SOURCE_DIFFERS: ' + path)
        identities.append({'path': path, **digest(raw)})
    before_suites = baseline.suites()
    before_counts = baseline.counts(before_suites)
    out.update(audit_complete=True, selected_suites=sorted(suites), is_complete_registered_suite_set=set(suites) == set(all_suites),
        baseline_registered_counts=before_counts, source_registered_counts=source.counts(all_suites),
        source_selected_counts=expected, observed_counts=counts,
        complete_registered_identities=complete, observed_case_identities=observed_rows,
        added_test_functions=added, removed_test_functions=removed, new_test_scripts=new_scripts,
        all_selected_added_functions_discovered_and_passed=True,
        source_checkout_test_equivalence=identities, selected_xml=xml,
        duplicate_execution_identities=[row for row in observed_rows if len(row['selected_xml']) > 1],
        registry_changed=before_suites != all_suites)
    out['limits'].append('Static parser covers top-level test_* declarations and explicit quoted test-script inheritance; each selected XML must match complete effective case identities.')
    return out


def public(a, d):
    root, run, generic, (baseline, source, checkout), out = common(a, d)
    jobs = [row for row in generic['jobs'] if row['name'] == a.public_job]
    d.require(len(jobs) == 1 and jobs[0]['conclusion'] == 'success' and set(jobs[0]['checkout_shas']) == {a.checkout}, 'SUCCESSFUL_BOUND_PUBLIC_JOB_REQUIRED')
    selected = jobs[0]
    jobs_api = d.read(root / 'jobs.json')['jobs']
    matching = [row for row in jobs_api if row['id'] == selected['execution_job_id']]
    d.require(len(matching) == 1, 'EXACT_EXECUTED_PUBLIC_JOB_REQUIRED')
    job = matching[0]
    steps = ('Verify committed public inventories without regeneration', 'Verify public inventory drift and read-only contracts')
    for name in steps:
        found = [step for step in job['steps'] if step['name'] == name]
        d.require(len(found) == 1 and found[0]['conclusion'] == 'success', 'READ_ONLY_PUBLIC_STEP_MISSING: ' + name)
    log = d.contained(root, selected['log'])
    d.require(d.identity(log) == selected['log_identity'], 'PUBLIC_LOG_IDENTITY_CHANGED')
    name = f"public-surfaces-{run['id']}-{selected['execution_attempt']}"
    artifacts = [row for row in generic['artifact_inventory']['artifacts'] if row['name'] == name]
    d.require(len(artifacts) == 1 and artifacts[0]['zip_and_extraction_verified'] is True, 'VERIFIED_ORIGINAL_PUBLIC_ARCHIVE_REQUIRED')
    files = {row['path']: row for row in generic['artifact_inventory']['files']}
    def retained(relative):
        key = 'artifacts/' + name + '/' + relative
        path = d.contained(root, key)
        d.require(key in files and d.identity(path) == {k: files[key][k] for k in ('bytes', 'sha256')}, 'PUBLIC_BYTES_CHANGED: ' + key)
        return path
    inventories = {}
    for filename in ('game_state_surface.json', 'save_manager_surface.json'):
        path = retained('ci/public-surfaces/' + filename)
        source_path = 'evidence/phase_2r/runtime/' + filename
        raw = path.read_bytes()
        d.require(raw == source.blob(source_path) == checkout.blob(source_path), 'INVENTORY_ADOPTION_OR_CHECKOUT_MISMATCH: ' + filename)
        current = d.read(path)
        old = json.loads(baseline.blob(source_path))
        d.require(current['ok'] is True and current['errors'] == [], 'PUBLIC_INVENTORY_FAILURE')
        def declarations(document):
            return [{k: v for k, v in row.items() if k != 'call_sites'} for row in document['records']]
        d.require(declarations(current) == declarations(old) and current['required'] == old['required']
                  and current['script'] == old['script'], 'PUBLIC_DECLARATION_CHANGE_REQUIRES_REVIEW: ' + filename)
        old_records = {r['symbol']: r for r in old['records']}
        references = {}
        for row in current['records']:
            before, after = old_records[row['symbol']].get('call_sites', []), row.get('call_sites', [])
            if before != after:
                references[row['symbol']] = {'before': before, 'after': after}
        inventories[filename] = {'path': path.relative_to(root).as_posix(), **digest(raw),
            'record_count': len(current['records']), 'contract_declarations_unchanged': True,
            'artifact_equals_source_and_tested_commit': True, 'changed_call_sites': references,
            'dynamic_references_before': old['dynamic_references'], 'dynamic_references_after': current['dynamic_references']}
    source_paths = ('tools/runtime/generate_public_surface_inventory.gd', 'tools/testing/Invoke-PublicSurfaceValidation.ps1',
                    'autoload/GameState.gd', 'autoload/SaveManager.gd', 'evidence/phase_2r/runtime/game_state_required_surface.json',
                    'evidence/phase_2r/runtime/save_manager_required_surface.json')
    bound = {}
    for path in source_paths:
        raw = source.blob(path)
        d.require(raw == checkout.blob(path), 'PUBLIC_AUDITOR_OR_DECLARATION_CHECKOUT_DIFFERS: ' + path)
        bound[path] = digest(raw)
    retirement_path = retained('ci/public-surfaces/retirement-audit.json')
    retirement = d.read(retirement_path)
    d.require(retirement['checkout_ref'] == a.checkout and retirement['references'] == [], 'PUBLIC_RETIREMENT_NOT_CLEAN')
    census_path = retained('ci/public-surfaces/fixture-version-census.json')
    census = d.read(census_path)
    d.require(census['checkout_ref'] == a.checkout, 'FIXTURE_CENSUS_CHECKOUT_DIFFERS')
    out.update(audit_complete=True, job=selected, passed_read_only_steps=list(steps), artifact=artifacts[0],
        inventories=inventories, public_source_equivalence=bound,
        retirement={'file': retirement_path.relative_to(root).as_posix(), **d.identity(retirement_path), 'report': retirement},
        fixture_census={'file': census_path.relative_to(root).as_posix(), **d.identity(census_path)})
    out['limits'] += ['Caller reference changes and exact generated inventory adoption are recorded separately from unchanged public declarations.',
                      'Canonical cloud read-only inventory checks validate references; this Python join does not execute or reimplement the GDScript scanner.']
    return out


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('kind', choices=('discovery', 'public'))
    p.add_argument('--run-root', type=Path, required=True)
    p.add_argument('--repo', type=Path, required=True)
    p.add_argument('--source', required=True)
    p.add_argument('--checkout', required=True)
    p.add_argument('--baseline', required=True)
    p.add_argument('--suite', action='append')
    p.add_argument('--public-job', default='Windows / public API surface contracts')
    p.add_argument('--parser', type=Path, default=Path(__file__).parent / 'settings_f5_review_adapters_v2/audit_coverage_test_discovery.py')
    p.add_argument('--output', type=Path)
    a = p.parse_args()
    d = load_parser(a.parser)
    for value in (a.source, a.checkout, a.baseline):
        d.full_sha(value)
    target = a.output or a.run_root / ('audit/settings-load-' + a.kind + '-audit.json')
    target.parent.mkdir(parents=True, exist_ok=True)
    try:
        report = (discovery if a.kind == 'discovery' else public)(a, d)
    except Exception as error:
        target.write_text(json.dumps({'audit_complete': False, 'source': a.source, 'tested_checkout': a.checkout,
            'failure': {'type': type(error).__name__, 'message': str(error)}}, indent=2) + '\n')
        raise
    target.write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
    print(json.dumps({'audit_complete': True, 'kind': a.kind, 'output': str(target),
                      'observed_counts': report.get('observed_counts')}))


if __name__ == '__main__':
    main()
