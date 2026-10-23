"""Derive only the affected canonical Windows gate after the rendered proof passed."""
import argparse, hashlib, json
from pathlib import Path
import yaml
import build_paused_settings_workflow as original

p = argparse.ArgumentParser()
p.add_argument('--source', required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
root = Path(__file__).parent
workflow, manifest = original.build(a.source, 'codex/paused-settings-f5-cloud-20261002', root/'dwm/.github/workflows/windows-tests.yml')
workflow['name'] = 'Paused Settings F5 focused candidate'
del workflow['jobs']['paused-settings-reading']
workflow['jobs']['focused-tests']['strategy']['matrix']['suite'] = ['reading_delivery']
assert set(workflow['jobs']) == {'public-surfaces', 'focused-tests'}
manifest['scope'] = 'Unit-fixture reset lifecycle correction only; public inventory regeneration plus full canonical Windows reading_delivery. Complete broad acceptance remains required.'
manifest['selection_reason'] = 'Focus2 rendered original and supplemental Settings reading proof and Settings suite passed; only reset unit-fixture scheduling changes in this successor.'
manifest['actual_jobs'] = 2
manifest['expected_xml'] = 2
manifest['job_count'] = 2
manifest['job_definition_count'] = 2
manifest['expected_ordinary_xml_count'] = 2
manifest['focused_suites'] = ['reading_delivery']
manifest['derived_steps'].pop('paused-settings-reading')
for key in ('journey_command', 'retained_journey_artifact_root', 'reading_supplement'):
    manifest.pop(key)
manifest['limits'] = [item for item in manifest['limits'] if 'unchanged reading runner command' not in item]
manifest['limits'].append('No rendered journey or Settings suite runs in this unit-fixture-only successor; all such proofs are required in the final broad gate.')
manifest['selected_suites'] = ['public_surfaces', 'reading_delivery']
manifest['predicted_selected_cases'] = sum(manifest['suite_census']['suites'][n]['static_case_count'] for n in manifest['selected_suites'])
manifest['canonical_suite_census'] = manifest.pop('suite_census')
raw = yaml.safe_dump(workflow, sort_keys=False, width=120).encode()
assert yaml.safe_load(raw) == workflow
manifest['workflow_sha256'] = hashlib.sha256(raw).hexdigest()
manifest['helper_sha256'] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
a.output.parent.mkdir(parents=True, exist_ok=True)
assert not a.output.exists()
a.output.write_bytes(raw)
a.output.with_name(a.output.name+'.manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({'source':a.source,'jobs':2,'xml':2,'cases':manifest['predicted_selected_cases'],'sha256':manifest['workflow_sha256']}))
