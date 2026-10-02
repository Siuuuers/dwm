#!/usr/bin/env python3
"""Derive an exact-source Hospital focus from canonical public/Windows/Hospital jobs.

No engines, remote mutations or repository edits. Every changed GUT fixture must
be registered in a selected canonical suite before a source can be emitted.
"""
from __future__ import annotations
import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import re
import subprocess
import yaml
import build_paused_settings_f9_workflow as census_helper

ROOT = Path(__file__).resolve().parent
BASELINE = '732e3fe266be69396bd0835c3e07c7beb06f9e5f'
WORKFLOW = '.github/workflows/hospital-reading-cloud.yml'
CANONICAL = '.github/workflows/windows-tests.yml'
DEFAULT_SUITES = ('reading_delivery', 'persistence')
DEFAULT_BRANCH = 'codex/hospital-reading-cloud-20261002'
DRIVER = 'tests/integration/verify_hospital_reading_journey.gd'
RUNNER = 'tools/testing/run_hospital_reading_journey.py'
ARTIFACT_ROOT = '.godot/ci/hospital-reading/'
REQUIRED_FIXTURES = (
    'tests/unit/test_hospital_presentation_port.gd',
    'tests/unit/test_dialogic_presentation_owner_adapter.gd',
    'tests/integration/test_hospital_dating_adapter_negative_contract.gd',
    'tests/integration/test_hospital_reading_session_runtime.gd',
    'tests/unit/test_solo_reading_session.gd',
    'tests/unit/test_hospital_frozen_context.gd',
    'tests/unit/test_reading_pause_save.gd',
    'tests/unit/test_production_pause_controller.gd',
    'tests/integration/test_narrative_pause_frontier.gd',
    'tests/scene/test_hospital_scene.gd',
    'tests/unit/test_frozen_run_context.gd',
    'tests/unit/test_reading_restore_admission.gd',
)
require = census_helper.require
identity = census_helper.identity


def build(repo: Path, source_sha: str, baseline: str, branch: str,
          selected: tuple[str, ...], regenerate_public: bool) -> tuple[dict, dict]:
    require(re.fullmatch(r'codex/[A-Za-z0-9][A-Za-z0-9_/-]*', branch) and '//' not in branch,
            'Explicit codex auxiliary branch required')
    source = census_helper.Source(repo, source_sha, baseline)
    canonical_raw = source.read(CANONICAL)
    canonical = yaml.safe_load(canonical_raw)
    names = ('public-surfaces', 'focused-tests', 'rendered-hospital-reading')
    jobs = {name: deepcopy(canonical['jobs'][name]) for name in names}
    ordinary = jobs['focused-tests']
    require(ordinary['strategy']['matrix'].keys() == {'suite'}, 'Unexpected canonical matrix shape')
    require(set(selected).issubset(ordinary['strategy']['matrix']['suite']), 'Missing canonical selected suite')
    require(ordinary['needs'] == 'public-surfaces', 'Canonical Windows public dependency changed')
    require(jobs['rendered-hospital-reading']['needs'] == 'public-surfaces', 'Canonical Hospital public dependency changed')
    ordinary['strategy']['matrix']['suite'] = list(selected)
    public_command = './tools/testing/Invoke-PublicSurfaceValidation.ps1 -EmitPayloads'
    steps = [x for x in jobs['public-surfaces']['steps'] if x.get('run', '').strip() == public_command]
    require(len(steps) == 1, 'Expected canonical read-only inventory command')
    if regenerate_public:
        steps[0]['run'] = './tools/testing/Invoke-PublicSurfaceValidation.ps1 -Regenerate -EmitPayloads'
    hospital = jobs['rendered-hospital-reading']
    require(hospital['runs-on'] == 'ubuntu-24.04', 'Canonical Hospital platform changed')
    require(sum(x.get('run', '').strip() == 'python3 ' + RUNNER for x in hospital['steps']) == 1,
            'Exactly one canonical Hospital runner command required')
    require(any(x.get('with', {}).get('path') == ARTIFACT_ROOT for x in hospital['steps']), 'Hospital evidence path changed')
    for name, job in jobs.items():
        checkouts = [x for x in job['steps'] if x.get('uses') == 'actions/checkout@v7']
        require(len(checkouts) == 1, 'Exactly one checkout required for ' + name)
        checkouts[0].setdefault('with', {}).update({'ref': source_sha, 'fetch-depth': 0})
        for step in job['steps']:
            if step.get('uses', '').startswith('actions/upload-artifact@'):
                require(step.get('if') == 'always()' and step.get('with', {}).get('include-hidden-files') is True,
                        'Always upload hidden evidence required')
    changed_fixtures = source.changed_fixtures()
    census = census_helper.suite_census(source, selected, tuple(dict.fromkeys((*REQUIRED_FIXTURES, *changed_fixtures))))
    # Bind every added/modified source path, including runtime owners and driver,
    # to the pinned commit. Do not infer engine validity from these byte checks.
    changed = subprocess.check_output(['git', '-C', str(source.repo), 'diff', '--name-only',
                                      '--diff-filter=ACMRT', '-z', baseline, source_sha]).decode().split('\0')
    for path in sorted(set(changed) - {''}):
        source.read(path)
    source.read(RUNNER)
    source.read(DRIVER)
    workflow = {'name': 'Hospital reading focused candidate',
                'on': {'push': {'branches': [branch]}},
                'permissions': {'contents': 'read'},
                'concurrency': {'group': 'hospital-reading-${{ github.ref }}', 'cancel-in-progress': True},
                'jobs': jobs}
    # Verify only the declared mechanical derivations changed each canonical job.
    for name, job in jobs.items():
        expected = deepcopy(canonical['jobs'][name])
        checkout = next(x for x in expected['steps'] if x.get('uses') == 'actions/checkout@v7')
        checkout.setdefault('with', {}).update({'ref': source_sha, 'fetch-depth': 0})
        if name == 'focused-tests': expected['strategy']['matrix']['suite'] = list(selected)
        if name == 'public-surfaces' and regenerate_public:
            step = next(x for x in expected['steps'] if x.get('run', '').strip() == public_command)
            step['run'] = './tools/testing/Invoke-PublicSurfaceValidation.ps1 -Regenerate -EmitPayloads'
        require(job == expected, 'Unreviewed canonical job alteration: ' + name)
    manifest = {
        'schema_version': 1, 'source_checkout': source_sha, 'accepted_baseline': baseline,
        'trigger_branch': branch, 'workflow_repository_path': WORKFLOW,
        'canonical_workflow': {'path': CANONICAL, **identity(canonical_raw)},
        'job_definition_count': 3, 'job_count': len(selected) + 2,
        'expected_ordinary_xml_count': len(selected) + 1,
        'focused_suites': list(selected), 'public_regeneration': regenerate_public,
        'all_selected_jobs_required': True, 'canonical_dependencies_retained': True,
        'canonical_job_content_verification': 'Only pinned checkout/fetch depth, selected matrix and optional explicit public regeneration differ.',
        'suite_census': census, 'automatically_discovered_changed_fixtures': list(changed_fixtures),
        'source_file_identities': source.inventory,
        'hospital_command': 'python3 ' + RUNNER, 'hospital_fixture': DRIVER,
        'hospital_artifact_root': ARTIFACT_ROOT,
        'derivation_helpers': [{'path': str(p.resolve()), **identity(p.read_bytes())}
                               for p in (Path(__file__), Path(census_helper.__file__))],
        'limits': [
            'Focused diagnostic subset only; canonical broad gate remains final acceptance and reruns original Solo/F5/F9 and all other jobs.',
            'No original Solo/F5/F9 rendered command is run by this focused subset; its previous seals are not changed or resealed.',
            'Static named suite census is not execution evidence; actual XML must show every expected fixture/case with zero failure/error/skip.',
            'Hospital semantic, saved-authority, raw file, speech and strict process-lifetime evidence requires independent source-bound audit.',
            'Regeneration, if selected, requires payload review/adoption and subsequent committed-inventory canonical validation.',
            'Workflow head differs from source checkout; bind all jobs to observed logs and original artifact identities.',
            'Noncanonical Schedule-Done/Sylvia-present fixture does not admit production prose, other ingresses, no-Sylvia timing, endings, all days or native accessibility.',
        ],
    }
    return workflow, manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, default=ROOT.parent / 'dwm')
    parser.add_argument('--source', required=True)
    parser.add_argument('--baseline', default=BASELINE)
    parser.add_argument('--branch', default=DEFAULT_BRANCH)
    parser.add_argument('--suites', nargs='+', default=list(DEFAULT_SUITES))
    parser.add_argument('--regenerate-public', action='store_true')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    workflow, manifest = build(args.repo, args.source, args.baseline, args.branch,
                               tuple(args.suites), args.regenerate_public)
    raw = yaml.safe_dump(workflow, sort_keys=False, width=120).encode()
    require(yaml.safe_load(raw) == workflow, 'Workflow YAML did not roundtrip')
    manifest['workflow_sha256'] = hashlib.sha256(raw).hexdigest()
    manifest_path = args.output.with_name(args.output.name + '.manifest.json')
    manifest_raw = (json.dumps(manifest, indent=2, ensure_ascii=False) + '\n').encode()
    for path, data in ((args.output, raw), (manifest_path, manifest_raw)):
        require(not path.exists() or path.read_bytes() == data, 'Refuse differing retained output: ' + str(path))
    for path, data in ((args.output, raw), (manifest_path, manifest_raw)):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    print(json.dumps({'workflow': str(args.output.resolve()), 'manifest': str(manifest_path.resolve()),
                      'source': args.source, 'jobs': manifest['job_count'],
                      'expected_xml': manifest['expected_ordinary_xml_count'],
                      'predicted_cases': manifest['suite_census']['predicted_case_executions'],
                      'workflow_sha256': manifest['workflow_sha256']}))


if __name__ == '__main__': main()
