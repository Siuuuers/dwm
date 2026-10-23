#!/usr/bin/env python3
"""Source-pinned Focus4 derivative: preserve all five jobs; parallelize only rendered diagnostics."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import subprocess
import yaml
import build_paused_settings_f9_workflow as base

ROOT = Path(__file__).resolve().parent
SOURCE = '5e43e68afa04a31a53bc25cf5fe8893ff39d82af'
PARENT = 'd702c456177f76fe90cb73993af93949d7335b7e'
TREE = 'ffb743578e071a1996e6e1d3d3c383ba5882e250'
REPO = ROOT / 'dwm'
OUTPUT = ROOT / 'settings-f9-focus4.yml'

def git(*args):
    return subprocess.check_output(['git', '-C', str(REPO), *args])

base.require(git('rev-parse', SOURCE + '^').decode().strip() == PARENT, 'Unexpected source4 parent')
base.require(git('rev-parse', SOURCE + '^{tree}').decode().strip() == TREE, 'Unexpected source4 tree')
# HEAD can precede the imported commit. Compare tracked working bytes against the supplied source.
tracked_differences = git('diff', '--name-only', SOURCE, '--').decode().splitlines()
base.require(not tracked_differences, 'Tracked working bytes differ from source4: ' + repr(tracked_differences))
workflow, manifest = base.build(SOURCE, REPO, base.DEFAULT_BASELINE, base.DEFAULT_BRANCH,
                                base.DEFAULT_SUITES, base.DEFAULT_FIXTURES)
original = deepcopy(workflow)
rendered = workflow['jobs']['paused-settings-reading']
base.require(rendered.pop('needs') == 'public-surfaces', 'Unexpected auxiliary rendered dependency')
expected = deepcopy(original)
del expected['jobs']['paused-settings-reading']['needs']
base.require(workflow == expected, 'Unexpected derived job changes')
base.require(workflow['jobs']['focused-tests']['needs'] == 'public-surfaces', 'Windows public gate dependency changed')
source = base.Source(REPO, SOURCE, base.DEFAULT_BASELINE)
for path in ('addons/dialogic/Modules/Text/event_text.gd', 'tests/integration/test_narrative_pause_frontier.gd'):
    source.read(path)
manifest['source_file_identities'].update(source.inventory)
native = next(item for item in manifest['suite_census']['suites']['reading_delivery']['scripts']
              if item['path'] == 'tests/integration/test_narrative_pause_frontier.gd')
base.require(native['static_case_count'] == 21, 'Unexpected native fixture census')
base.require(manifest['suite_census']['predicted_case_executions'] == 916, 'Unexpected Focus4 static census')
manifest['focus_number'] = 4
manifest['source_parent'] = PARENT
manifest['source_tree'] = TREE
manifest['source_delta_from_parent'] = git('diff', '--name-only', PARENT, SOURCE, '--').decode().splitlines()
manifest['working_tree_verification'] = {'tracked_paths_equal_source': True, 'untracked_evidence_ignored': True}
manifest['diagnostic_parallelism'] = {
    'removed_auxiliary_dependency': {'job': 'paused-settings-reading', 'needs': 'public-surfaces'},
    'reason': 'Public regeneration and rendered diagnostics use independent exact-source checkouts. Rendered diagnostics consume no generated public payload. Parallel execution reduces diagnostic delay while every selected job remains required.',
    'retained_windows_dependency': {'job': 'focused-tests', 'needs': 'public-surfaces'},
    'required_successful_jobs': ['public-surfaces', 'focused-tests (reading_delivery)', 'focused-tests (settings)', 'focused-tests (localization)', 'paused-settings-reading'],
    'single_job_success_is_focus_acceptance': False,
    'canonical_workflow_changed': False,
    'job_steps_environments_timeouts_assertions_unchanged': True,
}
manifest['native_reveal_cancellation_regression'] = {
    'runtime': 'addons/dialogic/Modules/Text/event_text.gd',
    'fixture': native['path'], 'registered_suite': 'reading_delivery', 'static_case_count': native['static_case_count'],
    'scope': 'Event-owned reveal wait cancellation and native partial-reveal retirement regression; actual cloud XML and strict rendered shutdown must prove acceptance.'
}
manifest['derivation_helpers'].append({'path': str(Path(__file__).resolve()), **base.identity(Path(__file__).read_bytes())})
manifest['limits'].append('All five selected jobs are mandatory for focused acceptance. Canonical broad committed-inventory validation, all suites and rendered gates remain required for final acceptance.')
raw = yaml.safe_dump(workflow, sort_keys=False, width=120).encode()
base.require(yaml.safe_load(raw) == workflow, 'YAML roundtrip failed')
manifest['workflow_sha256'] = hashlib.sha256(raw).hexdigest()
manifest_path = OUTPUT.with_name(OUTPUT.name + '.manifest.json')
manifest_raw = (json.dumps(manifest, indent=2, ensure_ascii=False) + '\n').encode()
for path, content in ((OUTPUT, raw), (manifest_path, manifest_raw)):
    base.require(not path.exists() or path.read_bytes() == content, 'Refuse differing retained artifact: ' + str(path))
    path.write_bytes(content)
print(json.dumps({'workflow': str(OUTPUT), 'manifest': str(manifest_path), 'source': SOURCE,
                  'jobs': manifest['job_count'], 'expected_xml': manifest['expected_ordinary_xml_count'],
                  'predicted_cases': manifest['suite_census']['predicted_case_executions'],
                  'predicted_scripts': manifest['suite_census']['predicted_script_executions'],
                  'workflow_sha256': manifest['workflow_sha256'], 'manifest_sha256': hashlib.sha256(manifest_raw).hexdigest()}))
