#!/usr/bin/env python3
"""Audit the three-job fixture/public/physical-selector focused gate."""
import argparse
import importlib.util
import json
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--run-root', type=Path, required=True)
p.add_argument('--repo', type=Path, required=True)
p.add_argument('--source', required=True)
p.add_argument('--attachments', type=Path, required=True, action='append')
a = p.parse_args()
a.checkout, a.master, a.allow_source_diff = a.source, None, []
helper = Path(__file__).with_name('cloud_evidence.py')
spec = importlib.util.spec_from_file_location('cloud_evidence', helper)
c = importlib.util.module_from_spec(spec)
spec.loader.exec_module(c)
root = a.run_root.resolve()
run = c.read(root / 'run.json')
c.require(run['status'] == 'completed' and run['conclusion'] == 'success', 'SUCCESS_REQUIRED')
jobs = c.job_audit(root, a.source, 3, [])
c.require({j['name'] for j in jobs} == {'Windows / public API surface contracts', 'Windows / reading_delivery', 'Rendered authored Solo selector Save and fresh-process Load'}, 'EXACT_FOCUSED_JOBS_REQUIRED')
inventory = c.artifact_inventory(root, a.attachments, {})
gut = c.xml_audit(root, run['id'], 2)
boundary = c.source_boundary(a)
reading = [s for s in gut['suites'] if s['path'].endswith('/reading_delivery.xml')]
c.require(len(reading) == 1 and reading[0]['cases'] == 383 and reading[0]['scripts'] == 31, 'ALL_READING_TESTS_REQUIRED')
c.require(not list((root / 'artifacts').glob('reading-rail-*')), 'ORIGINAL_EIGHT_PROCESS_JOURNEY_BELONGS_TO_BROAD_GATE')
physical = c.read(root / 'audit/physical-selector-journey-audit.json')
c.require(physical.get('audit_complete') is True and physical.get('runtime_proof_failures', []) == [], 'INDEPENDENT_PHYSICAL_SELECTOR_AUDIT_REQUIRED')
c.require(physical['run_id'] == run['id'] and physical['run_attempt'] == run['run_attempt'] and physical['source'] == a.source and physical['checkout'] == a.source, 'PHYSICAL_AUDIT_SOURCE_RUN_BINDING_REQUIRED')
audit = {'schema_version':1, 'generic_audit_pass':True,
    'audit_scope':__doc__, 'run':{k:run[k] for k in ('id','run_number','run_attempt','head_sha','head_branch','event','html_url','status','conclusion')},
    'raw_metadata_identities':{n:c.identity(root / n) for n in ('run.json','jobs.json','artifacts-api.json')},
    'source_boundary':boundary, 'jobs':jobs, 'gut':gut, 'reading':[], 'physical_selector':physical, 'physical_selector_audit_identity':c.identity(root / 'audit/physical-selector-journey-audit.json'), 'artifact_inventory':inventory,
    'limits':['The two-process physical selector journey proves its one observed real sweet/exploded path; it is not all production selector or native-platform acceptance.',
              'The required broad gate separately reruns the original eight-process fixture journey and all surrounding required gates.']}
out = root / 'audit'
out.mkdir(exist_ok=True)
(out / 'generic-evidence-audit.json').write_bytes(c.encoded(audit))
(out / 'source-provenance.json').write_bytes(c.encoded(boundary))
summary = {'schema_version':1,'run_id':run['id'],'run_number':run['run_number'],'run_url':run['html_url'],
    'source_commit':a.source,'actual_checkout_merge':a.source,'master_parent':None,
    'workflow_run':{k:run[k] for k in ('run_attempt','event','head_sha','status','conclusion')},
    'scope':audit['audit_scope'],'overall_acceptance_pass':True,'overall_accepted':True,
    'expected_job_count':3,'observed_job_count':3,'jobs':jobs,'gut':gut,'source_boundary':boundary,'physical_selector':physical,'limits':audit['limits']}
(root / 'acceptance-summary.json').write_bytes(c.encoded(summary))
print(json.dumps({'focused_pass':True,'run':run['run_number'],'jobs':3,'gut':{k:gut[k] for k in ('case_executions','unique_cases','unique_scripts')}}))
