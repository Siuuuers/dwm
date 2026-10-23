#!/usr/bin/env python3
"""Join bounded Settings F9 acceptance from one exact canonical cloud run.

Reuses successful source-bound component receipts; does not rerun engines,
PowerShell, or the historical non-GUT auditor forest.
"""
from __future__ import annotations
import argparse
from functools import lru_cache
import hashlib
from pathlib import Path, PurePosixPath
import re
import subprocess

import cloud_evidence as c

PREDECESSOR_IDENTITY = {'path': 'join_settings_f9_acceptance.py', 'bytes': 14633, 'sha256': '93a3272f8ce1ba9960bd682008b50298b5c8fb2a16338a355145691d7d6e72e7'}
BASELINE = '2254d6956de778cc54aa42fe610bcdf94f5301a5'
COMPONENTS = {
    'discovery': ('audit/settings-load-discovery-audit.json', 'audit_settings_load_inventory.py'),
    'public': ('audit/settings-load-public-audit.json', 'audit_settings_load_inventory.py'),
    'f9': ('audit/settings-load-journey-v3-audit.json', 'audit_settings_load_journey_v3.py'),
    'physical_v2': ('audit/physical-selector-journey-audit.json', 'audit_physical_selector_journey.py'),
}
OTHER_JOBS = {
    'Windows / paired checkpoint performance', 'Windows / exported release startup',
    'Windows / seven-day retained history producer', 'Windows / seven-day retained history',
    'Rendered desktop and dialogue / Linux software OpenGL',
    'Rendered seven-day, ending, Gallery and Dating journeys',
    'Windows / lazy-normalization comparison', 'Windows / outgoing-normalization comparison',
    'Windows / warm-outgoing-proof comparison', 'Windows / history-region-search comparison',
}
NATIVE_CASES = {
    'test_retiring_partial_native_text_releases_reveal_wait_without_completing_or_touching_fresh_caption',
    'test_synchronous_text_started_retirement_never_installs_a_late_reveal_wait',
}


def join(a):
    root, repo, helpers = a.run_root.resolve(), a.repo.resolve(), a.helpers.resolve()
    def path(relative):
        p = PurePosixPath(relative)
        c.require(not p.is_absolute() and '..' not in p.parts and '\\' not in relative, 'RELATIVE_EVIDENCE_PATH_REQUIRED')
        value = root / p
        c.require(value.resolve().is_relative_to(root) and not value.is_symlink(), 'CONTAINED_EVIDENCE_FILE_REQUIRED')
        return value
    def bind(relative, expected):
        c.require(c.identity(path(relative)) == expected, 'EVIDENCE_HASH_CHANGED: ' + relative)
    def metadata(records):
        for relative, expected in records.items(): bind(relative, expected)
    @lru_cache(None)
    def blob(revision, relative):
        return subprocess.check_output(['git', '-C', str(repo), 'show', revision + ':' + relative])
    def source_files(records):
        for relative, expected in records.items():
            raw = blob(a.source, relative)
            c.require(raw == blob(a.checkout, relative)
                      and expected == {'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()},
                      'SOURCE_FILE_BINDING_CHANGED: ' + relative)
    for sha in (a.source, a.checkout, a.baseline):
        c.require(re.fullmatch('[0-9a-f]{40}', sha), 'EXACT_COMMIT_REQUIRED')
    run = c.read(path('run.json'))
    generic = c.read(path('audit/generic-evidence-audit.json'))
    boundary = c.read(path('audit/source-provenance.json'))
    c.require(run['status'] == 'completed' and run['conclusion'] == 'success'
              and run['event'] == 'pull_request' and run['head_sha'] == a.source
              and run['path'] == '.github/workflows/windows-tests.yml', 'SUCCESSFUL_EXACT_CANONICAL_PR_RUN_REQUIRED')
    c.require(generic['generic_audit_pass'] is True and generic['source_boundary'] == boundary
              and boundary['source'] == a.source and boundary['tested_checkout'] == a.checkout
              and boundary['master'] and boundary['checkout_parents'] == [boundary['master'], a.source]
              and boundary['all_unlisted_paths_byte_identical'] is True, 'EXACT_SUCCESSFUL_GENERIC_MERGE_BOUNDARY_REQUIRED')
    c.require(all(generic['run'][key] == run[key] for key in generic['run']), 'GENERIC_RUN_DIFFERS')
    metadata(generic['raw_metadata_identities'])
    for row in generic['artifact_inventory']['files']:
        bind(row['path'], {key: row[key] for key in ('bytes', 'sha256')})
    c.require(blob(a.source, run['path']) == blob(a.checkout, run['path']) == blob(a.baseline, run['path']),
              'UNCHANGED_CANONICAL_GATE_REQUIRED')
    jobs = generic['jobs']
    c.require(len(jobs) == len({j['name'] for j in jobs}) == 23
              and all(j['conclusion'] == 'success' for j in jobs), 'ALL_23_CANONICAL_JOBS_MUST_PASS')
    by_execution = {j['execution_job_id']: j for j in jobs}
    for job in jobs:
        bind(job['log'], job['log_identity'])
        c.require(job['checkout_shas'] == [] if job['name'] == 'Windows / seven-day retained history'
                  else bool(job['checkout_shas']) and set(job['checkout_shas']) == {a.checkout}, 'JOB_CHECKOUT_DIFFERS')
    api_jobs = {row['id']: row for row in c.read(path('jobs.json'))['jobs']}
    for job in jobs:
        actual = api_jobs[job['execution_job_id']]
        c.require(actual['name'] == job['name'] and actual['status'] == 'completed'
                  and actual['conclusion'] == 'success' and actual['run_id'] == run['id']
                  and actual['head_sha'] == run['head_sha'], 'ACTUAL_JOB_RUN_OR_SUCCESS_DIFFERS')
    artifacts = {row['id']: row for row in generic['artifact_inventory']['artifacts']}
    def artifact(record):
        actual = artifacts[record['id']]
        c.require(record['name'] == actual['name'] and actual['workflow_run_head_sha'] == run['head_sha']
                  and actual['zip_and_extraction_verified'] is True
                  and record['workflow_head'] == run['head_sha']
                  and record['zip_identity'] == {'bytes': actual['size_in_bytes'], 'sha256': actual['zip_sha256']},
                  'COMPONENT_ARCHIVE_DIFFERS_FROM_GENERIC')
    def job_binding(record):
        execution_id = record['execution_job_id'] if 'execution_job_id' in record else record['job_id']
        actual = by_execution[execution_id]
        c.require(all(record[key] == actual[key] for key in ('name', 'log', 'log_identity', 'checkout_shas')),
                  'COMPONENT_JOB_DIFFERS_FROM_GENERIC')
    reports, bindings = {}, {}
    for name, (relative, auditor) in COMPONENTS.items():
        value = c.read(path(relative))
        c.require(value['audit_complete'] is True and value['run_id'] == run['id']
                  and value['run_attempt'] == run['run_attempt'] and value['source'] == a.source
                  and value.get('checkout', value.get('tested_checkout')) == a.checkout,
                  'COMPONENT_RUN_SOURCE_OR_CHECKOUT_DIFFERS: ' + name)
        c.require(value['auditor_identity'] == c.identity(helpers / auditor), 'COMPONENT_AUDITOR_HASH_DIFFERS: ' + name)
        for field in ('input_identities', 'metadata_identities'):
            if field in value: metadata(value[field])
        if 'workflow_head' in value: c.require(value['workflow_head'] == run['head_sha'], 'COMPONENT_WORKFLOW_HEAD_DIFFERS')
        if 'source_files' in value: source_files(value['source_files'])
        if 'job' in value: job_binding(value['job'])
        if 'artifact_identity' in value: artifact(value['artifact_identity'])
        bindings[name] = {'file': relative, **c.identity(path(relative)), 'auditor': {'file': auditor, **value['auditor_identity']}}
        reports[name] = value
    discovery, public, f9, physical = (reports[key] for key in ('discovery', 'public', 'f9', 'physical_v2'))
    parser_identity = c.identity(helpers / 'settings_f5_review_adapters_v2/audit_coverage_test_discovery.py')
    c.require(discovery['accepted_parser_identity'] == public['accepted_parser_identity'] == parser_identity,
              'ACCEPTED_SOURCE_DISCOVERY_PARSER_HASH_DIFFERS')
    c.require(discovery['baseline'] == public['baseline'] == a.baseline
              and discovery['is_complete_registered_suite_set'] is True
              and discovery['source_registered_counts'] == discovery['source_selected_counts'] == discovery['observed_counts']
              and discovery['all_selected_added_functions_discovered_and_passed'] is True, 'COMPLETE_SOURCE_DERIVED_TEST_DISCOVERY_REQUIRED')
    expected_pairs = {(row['script'], test) for row in discovery['complete_registered_identities'] for test in row['tests']}
    observed_pairs = {(row['script'], row['test']) for row in discovery['observed_case_identities']}
    c.require(expected_pairs == observed_pairs and all(row['selected_xml'] for row in discovery['observed_case_identities'])
              and discovery['observed_counts']['xml_count'] == 13, 'EXACT_COMPLETE_REGISTERED_CASE_IDENTITIES_REQUIRED')
    c.require(all(discovery['observed_counts'][key] == generic['gut'][key]
                  for key in ('case_executions', 'unique_cases', 'unique_scripts', 'xml_count')), 'GENERIC_XML_COUNTS_DIFFER')
    suite_jobs = {'Windows / ' + name for name in discovery['selected_suites'] if name != 'public_surfaces'}
    c.require({job['name'] for job in jobs} == OTHER_JOBS | suite_jobs | {'Windows / public API surface contracts'},
              'EXACT_CANONICAL_JOB_SET_REQUIRED')
    source_files({row['path']: {k: row[k] for k in ('bytes', 'sha256')} for row in discovery['source_checkout_test_equivalence']})
    native_path = 'tests/integration/test_narrative_pause_frontier.gd'
    c.require({(native_path, name) for name in NATIVE_CASES} <= observed_pairs, 'BOTH_NATIVE_RETIREMENT_CASES_REQUIRED')
    c.require(set(public['inventories']) == {'game_state_surface.json', 'save_manager_surface.json'}
              and all(row['artifact_equals_source_and_tested_commit'] is True
                      and row['contract_declarations_unchanged'] is True for row in public['inventories'].values()),
              'EXACT_COMMITTED_PUBLIC_ADOPTION_REQUIRED')
    c.require(public['artifact'] == artifacts[public['artifact']['id']], 'PUBLIC_ARTIFACT_DIFFERS_FROM_GENERIC')
    for row in public['inventories'].values(): bind(row['path'], {k: row[k] for k in ('bytes', 'sha256')})
    source_files(public['public_source_equivalence'])
    f5 = f9['preserved_f5_and_original_audit']
    c.require(f5['audit_complete'] is True
              and (f5['run_id'], f5['run_attempt'], f5['source'], f5['checkout'])
                  == (run['id'], run['run_attempt'], a.source, a.checkout), 'PRESERVED_F5_AND_ORIGINAL_RUN_DIFFERS')
    c.require(f9['accepted_f5_auditor_identity'] == c.identity(helpers / 'audit_settings_quick_journey.py'), 'ACCEPTED_F5_AUDITOR_HASH_DIFFERS')
    c.require(set(f5['original_process_ids']) == {'write', 'read', 'repeat', 'variant', 'witness-read', 'next-unseen', 'next', 'next-read'}
              and set(f5['process_ids']) == {'settings-write', 'settings-read'}
              and f5['semantic_assertions']['original_eight_modes_and_seal_unchanged'] is True,
              'EXACT_ORIGINAL_EIGHT_AND_F5_PAIR_REQUIRED')
    bind(f5['generic_audit_binding']['file'], {k: f5['generic_audit_binding'][k] for k in ('bytes', 'sha256')})
    metadata(f5['metadata_identities']); artifact(f5['artifact_identity']); job_binding(f5['job']); source_files(f5['source_files'])
    required_lifecycle = {'addons/dialogic/Modules/Text/event_text.gd', 'addons/dialogic/Core/DialogicGameHandler.gd',
                          'addons/dialogic/Resources/timeline.gd', native_path}
    c.require(required_lifecycle <= set(f9['source_files']), 'NATIVE_RETIREMENT_OWNER_SOURCE_BINDINGS_REQUIRED')
    c.require(physical['runtime_proof_failures'] == [] and physical['caption_count'] == physical['canonical_witness_hashes'] == 4
              and physical['trace_entries'] == 12 and physical['restored_speech_admissions'] == 0,
              'PRESERVED_BOUNDED_PHYSICAL_V2_COMPONENT_REQUIRED')
    return {'schema_version': 1, 'bounded_settings_f9_acceptance': True, 'run_id': run['id'], 'run_attempt': run['run_attempt'],
        'source': a.source, 'tested_checkout': a.checkout, 'workflow_head': run['head_sha'], 'baseline': a.baseline,
        'generic_audit': {'file': 'audit/generic-evidence-audit.json', **c.identity(path('audit/generic-evidence-audit.json'))},
        'source_provenance': {'file': 'audit/source-provenance.json', **c.identity(path('audit/source-provenance.json'))},
        'component_bindings': bindings, 'complete_discovery_counts': discovery['observed_counts'],
        'registered_case_identities_report': bindings['discovery'], 'canonical_successful_job_count': len(jobs),
        'other_canonical_job_scoped_passes': [{'name': j['name'], 'execution_job_id': j['execution_job_id'],
            'log': j['log'], 'log_identity': j['log_identity'], 'scope': 'Canonical cloud command/step success; no additional independent payload semantics claimed by this join.',
            'successful_steps': [step['name'] for step in api_jobs[j['execution_job_id']]['steps'] if step['conclusion'] == 'success']}
            for j in jobs if j['name'] in OTHER_JOBS],
        'auditor_identity': c.identity(Path(__file__)), 'predecessor_auditor_identity': PREDECESSOR_IDENTITY,
        'limits': ['Bounded Settings F9 increment only. Every required component belongs to this exact successful canonical run; earlier focused/failed runs confer no final acceptance.',
                   'Original eight-mode catalogue-v1, F5 writer/reader and bounded physical catalogue-v2 remain separately scoped; this join does not widen their literal or history guarantees.',
                   'Recovery proof includes exact primary-file neutrality, existing internal bookkeeping and raw endpoints; it does not establish arbitrary-filesystem or actual OS-crash behavior.',
                   'Other canonical jobs are linked at observed command/step-success scope. This join does not repeat their historical independent auditor forest.',
                   'Linux software rendering and Windows automated tests do not establish all native input/accessibility, production replay, final visual polish, or completion of every Beads task.']}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--run-root', type=Path, required=True); p.add_argument('--repo', type=Path, required=True)
    p.add_argument('--source', required=True); p.add_argument('--checkout', required=True)
    p.add_argument('--baseline', default=BASELINE)
    p.add_argument('--helpers', type=Path, default=Path(__file__).parent)
    p.add_argument('--output', type=Path)
    a = p.parse_args()
    result = join(a)
    target = a.output or a.run_root / 'acceptance-summary.json'
    c.require(not target.exists() or c.read(target) == result, 'REFUSE_DIFFERING_EXISTING_ACCEPTANCE_JOIN')
    target.write_bytes(c.encoded(result))
    print(c.encoded({'output': str(target), 'bounded_settings_f9_acceptance': True, 'counts': result['complete_discovery_counts']}).decode())


if __name__ == '__main__':
    main()
