#!/usr/bin/env python3
"""Audit the two-job Windows Settings reset-fixture focus gate only.

The rendered reading journey is deliberately absent from this gate. This auditor
cannot admit a failed/partial four-job run or replace final broad acceptance.
Reads retained cloud/Git evidence only; runs no engine or PowerShell.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
from types import SimpleNamespace
import subprocess
import xml.etree.ElementTree as ET

import cloud_evidence as cloud

BASELINE = '5a581fc89121864aead5202e01d6a82423b1b52d'
REGISTRY = 'tools/testing/Invoke-CloudTests.ps1'
SELECTED = ('public_surfaces', 'reading_delivery')
EXPECTED_JOBS = {'Windows / public API surface contracts', 'Windows / reading_delivery'}
NEW_SCRIPT = 'tests/unit/test_production_pause_controller.gd'
NEW_NAMES = {
    'test_paused_settings_binding_capture_never_saves_and_requires_fresh_release',
    'test_paused_settings_option_popup_forwards_release_and_retires_same_frame_save',
    'test_paused_settings_pending_preference_commit_retires_save_until_release',
    'test_paused_settings_quick_load_remains_unavailable_and_cannot_wake_on_exit',
    'test_paused_settings_quick_save_keeps_host_focus_and_exact_canonical_source',
    'test_paused_settings_reset_window_forwards_contacts_without_saving_or_queued_replay',
}


def byte_identity(raw):
    return {'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}


class Source:
    def __init__(self, repo, revision):
        self.repo, self.revision, self.cache, self.case_cache = repo, revision, {}, {}

    def blob(self, path):
        if path not in self.cache:
            self.cache[path] = subprocess.check_output([
                'git', '-C', str(self.repo), 'cat-file', 'blob', self.revision + ':' + path])
        return self.cache[path]

    def text(self, path):
        return self.blob(path).decode('utf-8-sig')

    def registry(self):
        match = re.search(r'(?ms)^\$suites = @\{\r?\n(.*?)^\}', self.text(REGISTRY))
        cloud.require(match is not None, 'EXACT_SOURCE_OWNED_SUITE_REGISTRY_REQUIRED')
        pattern = r'(?ms)^    (\w+) = @\(\r?\n(.*?)^    \)'
        result = {}
        for name, body in re.findall(pattern, match[1]):
            cloud.require(name not in result, 'DUPLICATE_SUITE_REGISTRATION: ' + name)
            paths = []
            for line in body.splitlines():
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                item = re.fullmatch(r"'(tests/[^']+\.gd)'", line)
                cloud.require(item is not None, 'UNKNOWN_SUITE_REGISTRATION_SYNTAX: ' + name)
                paths.append(item[1])
            cloud.require(paths and len(paths) == len(set(paths)), 'EMPTY_OR_DUPLICATE_REGISTERED_SCRIPT: ' + name)
            result[name] = paths
        residue = re.sub(pattern, '', match[1])
        cloud.require(result and all(not line.strip() or line.lstrip().startswith('#') for line in residue.splitlines()),
                      'UNPARSED_SUITE_REGISTRATION')
        return result

    def cases(self, path, ancestors=()):
        cloud.require(path not in ancestors, 'TEST_INHERITANCE_CYCLE: ' + path)
        if path not in self.case_cache:
            text = self.text(path)
            names = re.findall(r'^func (test_\w+)\s*\(', text, re.M)
            cloud.require(len(names) == len(set(names)), 'DUPLICATE_TEST_FUNCTION: ' + path)
            names = set(names)
            parent = re.search(r"^extends [\"']res://(tests/[^\"']+\.gd)[\"']", text, re.M)
            if parent:
                names |= self.cases(parent[1], (*ancestors, path))
            cloud.require(names, 'REGISTERED_SCRIPT_HAS_NO_TESTS: ' + path)
            self.case_cache[path] = names
        return self.case_cache[path]


def source_discovery(repo, source, checkout):
    before, current, tested = (Source(repo, revision) for revision in (BASELINE, source, checkout))
    registry = current.registry()
    cloud.require(before.registry() == registry == tested.registry(), 'EVERY_HISTORICAL_SUITE_REGISTRATION_MUST_REMAIN_EXACT')
    all_scripts = {path for paths in registry.values() for path in paths}
    before_cases = {(path, name) for path in all_scripts for name in before.cases(path)}
    current_cases = {(path, name) for path in all_scripts for name in current.cases(path)}
    cloud.require(before_cases <= current_cases, 'HISTORICAL_REGISTERED_TEST_REMOVED_OR_RENAMED')
    cloud.require(current_cases - before_cases == {(NEW_SCRIPT, name) for name in NEW_NAMES}, 'EXACT_SIX_NEW_SETTINGS_CASES_REQUIRED')
    cloud.require(len(all_scripts) == 194 and len(before_cases) == 2276 and len(current_cases) == 2282,
                  'HISTORICAL_BROAD_STATIC_CASE_OR_SCRIPT_CENSUS_CHANGED')
    for path in {REGISTRY, *all_scripts}:
        cloud.require(current.blob(path) == tested.blob(path), 'SOURCE_AND_PINNED_CHECKOUT_SCRIPT_BYTES_DIFFER: ' + path)
    selected = {name: registry[name] for name in SELECTED}
    selected_cases = {(path, case) for paths in selected.values() for path in paths for case in current.cases(path)}
    cloud.require(len(selected['public_surfaces']) == 1 and len(selected['reading_delivery']) == 31
                  and len(selected_cases) == 400, 'EXACT_FOCUSED_SOURCE_CENSUS_REQUIRED')
    summary = {
        'baseline': BASELINE, 'source': source, 'checkout': checkout,
        'registry_unchanged': True, 'historical_cases_retained': True,
        'historical_unique_cases': len(before_cases), 'candidate_static_unique_cases': len(current_cases),
        'registered_scripts': len(all_scripts),
        'new_cases': [{'script': NEW_SCRIPT, 'test': name} for name in sorted(NEW_NAMES)],
        'selected_suites': selected,
        'selected_case_counts': {name: sum(len(current.cases(path)) for path in paths) for name, paths in selected.items()},
        'source_file_identities': {path: byte_identity(raw) for path, raw in sorted(current.cache.items())},
        'limits': ['Whole-registry comparison is static retention evidence; this run executes only the two selected Windows suites.'],
    }
    return current, selected, summary


def exact_xml(root, gut, source, selected, run):
    seen_suites, seen_cases = set(), set()
    for row in gut['suites']:
        path = root / row['path']
        name = path.stem
        cloud.require(name in selected and name not in seen_suites, 'EXACT_SELECTED_XML_SUITE_REQUIRED')
        seen_suites.add(name)
        expected_family = 'public-surfaces' if name == 'public_surfaces' else 'windows-reading_delivery'
        cloud.require(path.relative_to(root / 'artifacts').parts[0] == f"{expected_family}-{run['id']}-{run['run_attempt']}",
                      'CURRENT_ATTEMPT_XML_ARTIFACT_REQUIRED')
        cloud.require(cloud.identity(path) == {key: row[key] for key in ('bytes', 'sha256')}, 'SELECTED_XML_BYTES_CHANGED')
        tree = ET.parse(path).getroot()
        cloud.require(tree.tag == 'testsuites', 'EXACT_GUT_XML_ROOT_REQUIRED')
        scripts = set()
        total = 0
        for script in tree.findall('testsuite'):
            script_name = script.attrib['name'].removeprefix('res://')
            cloud.require(script_name in selected[name] and script_name not in scripts, 'UNKNOWN_OR_DUPLICATE_XML_SCRIPT')
            scripts.add(script_name)
            cases = script.findall('testcase')
            names = [case.attrib['name'] for case in cases]
            cloud.require(len(names) == len(set(names)) and set(names) == source.cases(script_name),
                          'SOURCE_DECLARED_CASE_SET_NOT_EXECUTED_EXACTLY: ' + script_name)
            cloud.require(int(script.attrib['tests']) == len(cases), 'DECLARED_SCRIPT_CASE_COUNT_MISMATCH')
            for case in cases:
                cloud.require(case.attrib.get('classname', '').removeprefix('res://') == script_name
                              and case.attrib.get('status') == 'pass', 'EXACT_PASSED_CASE_AND_CLASS_REQUIRED')
                seen_cases.add((script_name, case.attrib['name']))
            total += len(cases)
        cloud.require(scripts == set(selected[name]), 'REGISTERED_SELECTED_SCRIPT_NOT_EXECUTED')
        cloud.require(int(tree.attrib['tests']) == total == row['cases'] and len(scripts) == row['scripts'], 'EXACT_XML_TOTALS_REQUIRED')
    cloud.require(seen_suites == set(SELECTED) and len(seen_cases) == 400
                  and {(NEW_SCRIPT, name) for name in NEW_NAMES} <= seen_cases, 'ALL_SIX_NEW_TESTS_AND_400_EXACT_CASES_REQUIRED')
    return {'selected_suite_count': len(seen_suites), 'case_count': len(seen_cases),
            'all_selected_source_cases_executed': True, 'all_six_new_cases_executed': True,
            'new_cases': [{'script': NEW_SCRIPT, 'test': name} for name in sorted(NEW_NAMES)]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run-root', type=Path, required=True)
    parser.add_argument('--repo', type=Path, required=True)
    parser.add_argument('--source', required=True)
    parser.add_argument('--checkout', required=True)
    args = parser.parse_args()
    root = args.run_root.resolve()
    cloud.require(args.source == args.checkout, 'FOCUSED_WINDOWS_GATE_REQUIRES_DIRECT_PINNED_SOURCE_CHECKOUT')
    run = cloud.read(root / 'run.json')
    cloud.require(run['status'] == 'completed' and run['conclusion'] == 'success' and run['event'] == 'push',
                  'COMPLETED_SUCCESSFUL_FOCUSED_PUSH_REQUIRED')
    jobs_api = cloud.read(root / 'jobs.json')
    cloud.require(jobs_api.get('total_count', len(jobs_api['jobs'])) == len(jobs_api['jobs']) == 2,
                  'EXACT_TWO_RAW_JOB_RECORDS_REQUIRED')
    cloud.require({row['name'] for row in jobs_api['jobs']} == EXPECTED_JOBS
                  and all(row.get('run_attempt', 1) == run['run_attempt'] for row in jobs_api['jobs']),
                  'EXACT_CURRENT_ATTEMPT_WINDOWS_JOB_SET_REQUIRED')
    api = cloud.read(root / 'artifacts-api.json')
    artifact_names = {f"public-surfaces-{run['id']}-{run['run_attempt']}",
                      f"windows-reading_delivery-{run['id']}-{run['run_attempt']}"}
    cloud.require(api.get('total_count', len(api['artifacts'])) == len(api['artifacts']) == 2
                  and {row['name'] for row in api['artifacts']} == artifact_names,
                  'EXACT_TWO_CURRENT_ATTEMPT_WINDOWS_ARTIFACTS_REQUIRED')
    manifest = cloud.read(root / 'artifact-manifest.json')
    cloud.require(len(manifest) == 2 and {row['id'] for row in manifest} == {row['id'] for row in api['artifacts']},
                  'EXACT_TWO_DOWNLOADED_ARTIFACTS_REQUIRED')
    attachments = []
    for retained in manifest:
        item = next(row for row in api['artifacts'] if row['id'] == retained['id'])
        path = Path(retained['local_zip'])
        cloud.require(not path.is_symlink() and retained['name'] == item['name']
                      and cloud.identity(path) == {'bytes': item['size_in_bytes'], 'sha256': item['digest'].removeprefix('sha256:')},
                      'RAW_ARTIFACT_ZIP_API_BINDING_REQUIRED')
        attachments.append(path.parent)
    inventory = cloud.artifact_inventory(root, sorted(set(attachments)), {})
    cloud.require(inventory['not_downloaded_artifacts'] == [], 'NO_FOCUSED_ARTIFACT_OMISSIONS_ALLOWED')
    boundary = cloud.source_boundary(SimpleNamespace(repo=args.repo, source=args.source, checkout=args.checkout,
                                                    master=None, allow_source_diff=[]))
    jobs = cloud.job_audit(root, args.checkout, 2, [])
    public_log = (root / next(row['log'] for row in jobs if row['name'] == 'Windows / public API surface contracts')).read_text(encoding='utf-8-sig')
    cloud.require('./tools/testing/Invoke-PublicSurfaceValidation.ps1 -Regenerate -EmitPayloads' in public_log,
                  'ACTUAL_PUBLIC_INVENTORY_REGENERATION_COMMAND_REQUIRED')
    gut = cloud.xml_audit(root, run['id'], 2)
    expected = {'xml_count': 2, 'case_executions': 400, 'unique_cases': 400,
                'script_executions': 32, 'unique_scripts': 32, 'failures': 0, 'errors': 0, 'skipped': 0}
    cloud.require(all(gut[key] == value for key, value in expected.items())
                  and gut['negative_xml_exclusions'] == [], 'EXACT_ZERO_FAILURE_400_CASE_FOCUSED_GUT_GATE_REQUIRED')
    current, selected, discovery = source_discovery(args.repo, args.source, args.checkout)
    executed = exact_xml(root, gut, current, selected, run)
    result = {
        'schema_version': 1, 'generic_audit_pass': True,
        'audit_scope': 'Two-job Windows reset-fixture focus only: source-owned public inventory regeneration and complete reading_delivery GUT suite.',
        'auditor_identity': cloud.identity(Path(__file__)), 'shared_auditor_identity': cloud.identity(Path(cloud.__file__)),
        'raw_metadata_identities': {name: cloud.identity(root / name) for name in ('run.json', 'jobs.json', 'artifacts-api.json')},
        'artifact_manifest_identity': cloud.identity(root / 'artifact-manifest.json'),
        'run': {key: run.get(key) for key in ('id', 'run_number', 'run_attempt', 'head_sha', 'head_branch', 'event', 'html_url', 'status', 'conclusion')},
        'source_boundary': boundary, 'jobs': jobs, 'gut': gut, 'reading': [], 'artifact_inventory': inventory,
        'test_discovery': discovery, 'executed_focused_cases': executed,
        'rendered_reading_executed': False, 'broad_acceptance_claimed': False,
        'limits': [
            'Only this fully successful two-job run is admitted; earlier failed focused runs supply no partial acceptance.',
            'No rendered reading or Settings writer/reader process ran in this focused gate; reading is intentionally empty.',
            'Exactly six new named cases and all historical registry/case identities are retained; whole-registry retention is static evidence only.',
            'Generated inventories require independent review and adoption before final committed-inventory validation.',
            'The final canonical broad gate must rerun all runtime, rendered, storage, performance and export coverage before broad acceptance.',
            'No local Godot, PowerShell or native-input acceptance occurs in this audit.',
        ],
    }
    raw = cloud.encoded(result)
    cloud.scan(raw, 'generic-evidence-audit.json')
    destination = root / 'audit/generic-evidence-audit.json'
    destination.parent.mkdir(parents=True, exist_ok=True)
    for path, content in ((root / 'audit/source-provenance.json', cloud.encoded(boundary)), (destination, raw)):
        cloud.require(not path.exists() or path.read_bytes() == content, 'REFUSING_TO_OVERWRITE_DIFFERENT_RETAINED_AUDIT: ' + str(path))
    (root / 'audit/source-provenance.json').write_bytes(cloud.encoded(boundary))
    destination.write_bytes(raw)
    print(json.dumps({'generic_audit_pass': True, 'scope': 'Windows fixture only; rendered reading not run',
                      'run_id': run['id'], 'jobs': 2, 'cases': 400, 'scripts': 32, 'xml': 2,
                      'six_new_cases_executed': True, 'output': str(destination)}))


if __name__ == '__main__':
    main()
