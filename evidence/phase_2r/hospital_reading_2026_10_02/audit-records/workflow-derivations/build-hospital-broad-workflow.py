#!/usr/bin/env python3
"""Derive a complete canonical gate on an auxiliary push branch, without running it.

Only top-level name/on/concurrency bytes change. The canonical jobs block is
retained byte-for-byte, including checkout behavior: jobs check out the actual
workflow head so the Day7 producer/consumer GITHUB_SHA checks remain meaningful.
No engines, remote writes, repository edits, or checkout pins are introduced.
"""
from __future__ import annotations

import argparse
from copy import deepcopy
import hashlib
import itertools
import json
from pathlib import Path
import re
import subprocess

import yaml
import build_paused_settings_f9_workflow as census_helper


ROOT = Path(__file__).resolve().parent
BASELINE = '732e3fe266be69396bd0835c3e07c7beb06f9e5f'
CANONICAL = '.github/workflows/windows-tests.yml'
WORKFLOW = '.github/workflows/hospital-reading-cloud.yml'
DEFAULT_BRANCH = 'codex/hospital-reading-cloud-20261002'
PUBLIC_COMMAND = './tools/testing/Invoke-PublicSurfaceValidation.ps1 -EmitPayloads'
AGGREGATE_JOB = 'seven-day-history'
INVENTORIES = ('evidence/phase_2r/runtime/game_state_surface.json',
               'evidence/phase_2r/runtime/save_manager_surface.json')
require = census_helper.require
identity = census_helper.identity


class WorkflowLoader(yaml.SafeLoader):
    """Treat GitHub's on key as text, while retaining true/false booleans."""


WorkflowLoader.yaml_implicit_resolvers = deepcopy(yaml.SafeLoader.yaml_implicit_resolvers)
for first, resolvers in WorkflowLoader.yaml_implicit_resolvers.items():
    WorkflowLoader.yaml_implicit_resolvers[first] = [
        item for item in resolvers if item[0] != 'tag:yaml.org,2002:bool'
    ]
WorkflowLoader.add_implicit_resolver('tag:yaml.org,2002:bool',
                                     re.compile(r'^(?:true|false)$', re.I), list('tTfF'))


def unique_mapping(loader: WorkflowLoader, node: yaml.MappingNode, deep: bool = False) -> dict:
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        require(key not in result, 'Duplicate YAML key: ' + str(key))
        result[key] = loader.construct_object(value_node, deep=deep)
    return result


WorkflowLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, unique_mapping)


def parse(raw: bytes) -> dict:
    data = yaml.load(raw, Loader=WorkflowLoader)
    require(isinstance(data, dict), 'Workflow must be a mapping')
    return data


def sections(raw: bytes) -> dict[str, bytes]:
    text = raw.decode('utf-8')
    require(not text.startswith('\ufeff') and '\r' not in text,
            'Expected canonical UTF-8/LF workflow bytes')
    node = yaml.compose(text, Loader=WorkflowLoader)
    require(isinstance(node, yaml.MappingNode), 'Expected top-level workflow mapping')
    keys = [(key.value, key.start_mark.index) for key, _value in node.value]
    require(keys and keys[0][1] == 0, 'Unexpected leading canonical material')
    require(len(keys) == len(set(key for key, _ in keys)), 'Duplicate top-level key')
    return {key: text[start:(keys[index + 1][1] if index + 1 < len(keys) else len(text))].encode('utf-8')
            for index, (key, start) in enumerate(keys)}


def derive(canonical_raw: bytes, branch: str) -> tuple[bytes, dict]:
    require(re.fullmatch(r'codex/[A-Za-z0-9][A-Za-z0-9_/-]*', branch)
            and '//' not in branch and not branch.endswith('/'),
            'Explicit codex auxiliary branch required')
    pieces = sections(canonical_raw)
    canonical = parse(canonical_raw)
    require(set(pieces) == {'name', 'on', 'permissions', 'concurrency', 'jobs'},
            'Unexpected top-level canonical keys; review before deriving')
    require(canonical['permissions'] == {'contents': 'read'}, 'Canonical read-only permissions changed')
    replacements = {
        'name': b'name: Hospital reading complete canonical candidate\n\n',
        'on': ('on:\n  push:\n    branches: [' + branch + ']\n\n').encode(),
        'concurrency': b'concurrency:\n  group: hospital-reading-${{ github.ref }}\n  cancel-in-progress: true\n\n',
    }
    raw = b''.join(replacements.get(key, part) for key, part in pieces.items())
    derived = parse(raw)
    expected = deepcopy(canonical)
    expected.update({'name': 'Hospital reading complete canonical candidate',
                     'on': {'push': {'branches': [branch]}},
                     'concurrency': {'group': 'hospital-reading-${{ github.ref }}',
                                     'cancel-in-progress': True}})
    require(derived == expected, 'Unexpected semantic workflow change')
    actual_sections = sections(raw)
    require(actual_sections['jobs'] == pieces['jobs'], 'Canonical jobs bytes changed')
    require(actual_sections['permissions'] == pieces['permissions'], 'Canonical permission bytes changed')
    changed = [key for key in pieces if pieces[key] != actual_sections[key]]
    require(set(changed) == set(replacements), 'Unexpected changed top-level sections')
    return raw, {
        'changed_top_level_sections': changed,
        'canonical_jobs_block': identity(pieces['jobs']),
        'derived_jobs_block': identity(actual_sections['jobs']),
        'jobs_byte_identical': True,
        'jobs_semantically_identical': derived['jobs'] == canonical['jobs'],
        'all_other_top_level_sections_byte_identical': True,
    }


def matrix_rows(job: dict) -> list[dict]:
    matrix = job.get('strategy', {}).get('matrix')
    if matrix is None:
        return [{}]
    require(isinstance(matrix, dict) and matrix, 'Static nonempty matrix required')
    if set(matrix) == {'include'}:
        rows = matrix['include']
        require(isinstance(rows, list) and rows and all(isinstance(row, dict) for row in rows),
                'Expected literal include-only matrix rows')
        return rows
    require(not set(matrix).intersection({'include', 'exclude'}),
            'Mixed include/exclude matrix needs explicit reviewed expansion')
    require(all(isinstance(values, list) and values for values in matrix.values()),
            'Literal nonempty matrix axes required')
    return [dict(zip(matrix, combination)) for combination in itertools.product(*matrix.values())]


def job_census(jobs: dict) -> dict:
    definitions = {}
    instances = []
    require(AGGREGATE_JOB in jobs, 'Canonical checkout-free history aggregate missing')
    for job_id, job in jobs.items():
        rows = matrix_rows(job)
        steps = job.get('steps', [])
        checkouts = [step for step in steps if step.get('uses', '').startswith('actions/checkout@')]
        if job_id == AGGREGATE_JOB:
            require(not checkouts and job.get('if') == 'always()', 'Aggregate contract changed')
        else:
            require(len(checkouts) == 1 and checkouts[0]['uses'] == 'actions/checkout@v7',
                    'Exactly one canonical checkout@v7 required: ' + job_id)
            require('ref' not in checkouts[0].get('with', {}),
                    'Broad gate must check out actual workflow head, never a source pin: ' + job_id)
        needs = job.get('needs', [])
        needs = [needs] if isinstance(needs, str) else needs
        require(isinstance(needs, list) and set(needs).issubset(jobs), 'Unknown job dependency')
        definitions[job_id] = {
            'name': job.get('name', job_id), 'runs_on': job.get('runs-on'),
            'expanded_count': len(rows), 'needs': needs,
            'strategy': job.get('strategy'), 'timeout_minutes': job.get('timeout-minutes'),
            'checkout': checkouts[0] if checkouts else None,
            'steps': [{'name': step.get('name'), 'uses': step.get('uses'), 'if': step.get('if'),
                       'timeout_minutes': step.get('timeout-minutes'),
                       **({'command': identity(step['run'].encode())} if 'run' in step else {})}
                      for step in steps],
            'artifact_uploads': [{'if': step.get('if'), 'with': step.get('with')}
                                 for step in steps if step.get('uses', '').startswith('actions/upload-artifact@')],
        }
        for row in rows:
            name = job.get('name', job_id)
            for key, value in row.items():
                name = re.sub(r'\$\{\{\s*matrix\.' + re.escape(key) + r'\s*\}\}', str(value), name)
            require('${{' not in name, 'Unexpanded job display name: ' + name)
            instances.append({'job_id': job_id, 'name': name, 'matrix': row,
                              'checkout_required': bool(checkouts)})
    require(len({row['name'] for row in instances}) == len(instances), 'Duplicate expanded job names')
    return {'definitions': definitions, 'instances': instances,
            'job_definition_count': len(jobs), 'job_count': len(instances),
            'engine_checkout_job_count': sum(row['checkout_required'] for row in instances)}


def build(repo: Path, source_sha: str, baseline: str, branch: str) -> tuple[bytes, dict]:
    source = census_helper.Source(repo, source_sha, baseline)
    canonical_raw = source.read(CANONICAL)
    canonical = parse(canonical_raw)
    raw, derivation = derive(canonical_raw, branch)
    jobs = canonical['jobs']
    require('focused-tests' in jobs and 'public-surfaces' in jobs
            and 'rendered-hospital-reading' in jobs, 'Required canonical jobs missing')
    ordinary = jobs['focused-tests']
    require(set(ordinary['strategy']['matrix']) == {'suite'}, 'Canonical ordinary matrix shape changed')
    selected = tuple(ordinary['strategy']['matrix']['suite'])
    require(ordinary['needs'] == 'public-surfaces', 'Canonical ordinary public dependency changed')
    public_steps = jobs['public-surfaces']['steps']
    commands = [step.get('run', '').strip() for step in public_steps]
    require(commands.count(PUBLIC_COMMAND) == 1, 'Exactly one canonical read-only public validation required')
    require(not any('-Regenerate' in command for command in commands), 'Public regeneration forbidden in broad gate')
    require(commands.count('./tools/testing/Invoke-CloudTests.ps1 -Suite public_surfaces') == 1,
            'Canonical public inventory regression suite missing')
    for job_id in ('seven-day-history-producer', 'history-comparisons'):
        require(any('$checkoutRef -cne $env:GITHUB_SHA' in step.get('run', '')
                    for step in jobs[job_id]['steps']), 'Day7 exact workflow-head guard missing: ' + job_id)
    changed_fixtures = source.changed_fixtures()
    suites = census_helper.suite_census(source, selected, changed_fixtures)
    census = job_census(jobs)
    changed = subprocess.check_output(['git', '-C', str(source.repo), 'diff', '--name-only',
                                      '--diff-filter=ACMRT', '-z', baseline, source_sha]).decode().split('\0')
    for path in sorted(set(changed) - {''}):
        source.read(path)
    for path in INVENTORIES:
        source.read(path)
    source_tree = subprocess.check_output(['git', '-C', str(source.repo), 'rev-parse',
                                          source_sha + '^{tree}'], text=True).strip()
    manifest = {
        'schema_version': 1, 'source_commit': source_sha, 'source_tree': source_tree,
        'accepted_baseline': baseline, 'trigger_branch': branch,
        'workflow_repository_path': WORKFLOW,
        'canonical_workflow': {'path': CANONICAL, **identity(canonical_raw)},
        'workflow_sha256': hashlib.sha256(raw).hexdigest(),
        'derivation': derivation,
        'job_definition_count': census['job_definition_count'], 'job_count': census['job_count'],
        'expected_ordinary_xml_count': len(selected) + 1,
        'canonical_suites': list(selected), 'public_regeneration': False,
        'public_inventory_command': PUBLIC_COMMAND,
        'all_canonical_jobs_required': True, 'canonical_dependencies_retained': True,
        'canonical_job_census': census, 'suite_census': suites,
        'automatically_discovered_changed_fixtures': list(changed_fixtures),
        'source_file_identities': source.inventory,
        'derivation_helpers': [{'path': str(path.resolve()), **identity(path.read_bytes())}
                               for path in (Path(__file__), Path(census_helper.__file__))],
        'publication_and_checkout_contract': {
            'source_is_not_checkout_pin': True,
            'expected_engine_checkout': 'Actual auxiliary workflow head / GITHUB_SHA',
            'checkout_free_job': jobs[AGGREGATE_JOB]['name'],
            'required_ordered_parents': ['Exact previous auxiliary head', source_sha],
            'allowed_source_to_workflow_head_tree_difference': [WORKFLOW],
            'required_tree_diff_status': 'Workflow path only, with blob bytes matching workflow_sha256',
            'publication_and_observed_checkouts_audit_pending': True,
            'pr_branch_stays_at_accepted_checkpoint_until_validated': True,
        },
        'scope': [
            'Complete current canonical workflow: all ordinary/public suites, exported Windows startup, paired checkpoint performance, retained Day7 producer/comparisons/aggregate, and every rendered job.',
            'Original rendered Solo/F5/F9, authored selectors, full cloud journeys, Hospital journey and UI/desktop/localization audits retain exact canonical commands and dependencies.',
            'Read-only committed public inventory validation; regenerated inventory adoption must precede this source commit.',
            'Every canonical timeout, shell, installation checksum, strict process/error check, upload condition and history input-provenance guard is retained byte-for-byte.',
        ],
        'limits': [
            'This manifest records static derivation only; no engine, PowerShell or cloud execution occurred in this helper.',
            'After publication independently verify full ordered parents, the sole allowed workflow tree difference, and every engine checkout against actual workflow head.',
            'Static named test census is not a pass. Compare actual strict XML names/counts and reject failures, errors, skips, missing fixtures and skipped mandatory jobs.',
            'Audit original artifact ZIPs, raw process logs, provenance, save bytes and journey semantics; successful workflow status alone is insufficient.',
            'Hospital remains the bounded noncanonical Schedule-Done/Sylvia-present fixture; broad regression success does not admit production prose or unexercised ingresses, no-Sylvia timing, pair/ending continuity, all days or native accessibility.',
            'Linux software rendering and synthesized Godot events do not establish native Windows graphics or hardware input-to-paint acceptance.',
        ],
    }
    return raw, manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, default=ROOT.parent / 'dwm')
    parser.add_argument('--source', required=True)
    parser.add_argument('--baseline', default=BASELINE)
    parser.add_argument('--branch', default=DEFAULT_BRANCH)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    raw, manifest = build(args.repo, args.source, args.baseline, args.branch)
    manifest_path = args.output.with_name(args.output.name + '.manifest.json')
    manifest_raw = (json.dumps(manifest, indent=2, ensure_ascii=False) + '\n').encode()
    for path, data in ((args.output, raw), (manifest_path, manifest_raw)):
        require(not path.exists() or path.read_bytes() == data, 'Refuse differing retained output: ' + str(path))
    for path, data in ((args.output, raw), (manifest_path, manifest_raw)):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    print(json.dumps({'workflow': str(args.output.resolve()), 'manifest': str(manifest_path.resolve()),
                      'source': args.source, 'jobs': manifest['job_count'],
                      'job_definitions': manifest['job_definition_count'],
                      'expected_xml': manifest['expected_ordinary_xml_count'],
                      'predicted_cases': manifest['suite_census']['predicted_case_executions'],
                      'jobs_byte_identical': manifest['derivation']['jobs_byte_identical'],
                      'workflow_sha256': manifest['workflow_sha256']}))


if __name__ == '__main__':
    main()
