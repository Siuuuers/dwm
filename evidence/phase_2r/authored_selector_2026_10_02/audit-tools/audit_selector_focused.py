#!/usr/bin/env python3
"""Audit the two-job fixture/public rerun; no rendered-journey acceptance here."""
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
jobs = c.job_audit(root, a.source, 2, [])
c.require({j['name'] for j in jobs} == {'Windows / public API surface contracts', 'Windows / reading_delivery'}, 'EXACT_FOCUSED_JOBS_REQUIRED')
inventory = c.artifact_inventory(root, a.attachments, {})
gut = c.xml_audit(root, run['id'], 2)
boundary = c.source_boundary(a)
reading = [s for s in gut['suites'] if s['path'].endswith('/reading_delivery.xml')]
c.require(len(reading) == 1 and reading[0]['cases'] == 382 and reading[0]['scripts'] == 31, 'ALL_READING_TESTS_REQUIRED')
c.require(not list((root / 'artifacts').glob('reading-rail-*')), 'THIS_FOCUSED_RUN_HAS_NO_JOURNEY_ARTIFACT')
audit = {'schema_version':1, 'generic_audit_pass':True,
    'audit_scope':__doc__, 'run':{k:run[k] for k in ('id','run_number','run_attempt','head_sha','head_branch','event','html_url','status','conclusion')},
    'raw_metadata_identities':{n:c.identity(root / n) for n in ('run.json','jobs.json','artifacts-api.json')},
    'source_boundary':boundary, 'jobs':jobs, 'gut':gut, 'reading':[], 'artifact_inventory':inventory,
    'limits':['Only affected reading tests and public inventories run here; no rendered journey is attributed to this run.',
              'The required broad gate supplies final integrated acceptance; the original eight-process fixture journey remains a distinct regression proof.']}
out = root / 'audit'
out.mkdir(exist_ok=True)
(out / 'generic-evidence-audit.json').write_bytes(c.encoded(audit))
(out / 'source-provenance.json').write_bytes(c.encoded(boundary))
summary = {'schema_version':1,'run_id':run['id'],'run_number':run['run_number'],'run_url':run['html_url'],
    'source_commit':a.source,'actual_checkout_merge':a.source,'master_parent':None,
    'workflow_run':{k:run[k] for k in ('run_attempt','event','head_sha','status','conclusion')},
    'scope':audit['audit_scope'],'overall_acceptance_pass':True,'overall_accepted':True,
    'expected_job_count':2,'observed_job_count':2,'jobs':jobs,'gut':gut,'source_boundary':boundary,'limits':audit['limits']}
(root / 'acceptance-summary.json').write_bytes(c.encoded(summary))
print(json.dumps({'focused_pass':True,'run':run['run_number'],'jobs':2,'gut':{k:gut[k] for k in ('case_executions','unique_cases','unique_scripts')}}))
