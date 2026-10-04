#!/usr/bin/env python3
"""Preserve early failed gates with explicit API-proven skipped jobs.

Diagnostic-only adapter around the unchanged generic evidence packager.
No acceptance entry point, invented logs or executed-source claims for skipped jobs.
"""
from __future__ import annotations
import argparse
from collections import Counter
import json
from pathlib import Path
import re
import cloud_evidence as cloud


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for flag in ('run-root','repo','output'): p.add_argument('--'+flag,type=Path,required=True)
    for flag in ('source','checkout','master','workflow-head','name','diagnosis'): p.add_argument('--'+flag,required=True)
    p.add_argument('--expected-jobs',type=int,required=True)
    p.add_argument('--no-checkout-job',action='append',default=[])
    p.add_argument('--allow-source-diff',action='append',default=[])
    a=p.parse_args()
    a.command='diagnostic-package'
    root=a.run_root.resolve()
    run=cloud.read(root/'run.json')
    api=cloud.read(root/'jobs.json')
    cloud.require(run['status']=='completed' and run['conclusion']!='success'
                  and run['head_sha']==a.workflow_head,'EXACT_COMPLETED_FAILED_RUN_REQUIRED')
    rows=api['jobs']
    cloud.require(api['total_count']==len(rows)==a.expected_jobs,'EXACT_ALL_API_JOB_RECORDS_REQUIRED')
    cloud.require(len({j['id'] for j in rows})==len(rows)
                  and all(j.get('run_attempt',1)==run['run_attempt'] for j in rows),
                  'ADAPTER_REQUIRES_EXACT_SINGLE_ATTEMPT_JOB_SET')
    executed, skipped=[],[]
    for job in rows:
        cloud.require(job['status']=='completed','COMPLETED_JOB_REQUIRED')
        path=root/'logs'/f"{job['id']}.log"
        metadata={k:job.get(k) for k in ('id','name','run_attempt','status','conclusion','started_at','completed_at')}
        if job['conclusion']=='skipped':
            cloud.require(job.get('steps')==[] and not path.exists(),'SKIPPED_JOB_MUST_HAVE_NO_STEPS_OR_INVENTED_LOG')
            skipped.append(metadata|{'execution_state':'skipped-before-runner','log':None,'checkout_shas':[],
                'source_executed':False,'reason':'GitHub API reports skipped with an empty steps array; no job log exists or is manufactured.'})
            continue
        cloud.require(path.is_file() and not path.is_symlink(),'EXECUTED_JOB_LOG_REQUIRED')
        lines=[cloud.clean(line) for line in path.read_text(encoding='utf-8-sig').splitlines()]
        checkouts=[lines[i+1] for i,line in enumerate(lines[:-1]) if 'log -1 --format=%H' in line
                   and re.fullmatch('[0-9a-f]{40}',lines[i+1])]
        if job['name'] in a.no_checkout_job:
            cloud.require(not checkouts,'EXPLICIT_AGGREGATE_MUST_NOT_HAVE_CHECKOUT')
        else:
            cloud.require(checkouts and set(checkouts)=={a.checkout},'EXECUTED_CHECKOUT_NOT_PROVEN')
        executed.append(metadata|{'execution_job_id':job['id'],'execution_attempt':job.get('run_attempt',1),
            'log':path.relative_to(root).as_posix(),'log_identity':cloud.identity(path),'checkout_shas':checkouts,
            'checkout_exemption':'explicit checkout-free aggregate' if job['name'] in a.no_checkout_job else None})
    cloud.require(set(a.no_checkout_job)<={j['name'] for j in executed},'UNKNOWN_CHECKOUT_FREE_AGGREGATE')
    cloud.require(skipped,'THIS_ADAPTER_REQUIRES_SKIPPED_JOBS')
    a.attachments=sorted({Path(row['local_zip']).parent for row in cloud.read(root/'artifact-manifest.json')})
    a.omissions=root/'omissions.json'
    inventory=cloud.artifact_inventory(root,a.attachments,cloud.read(a.omissions))
    report={'schema_version':1,'diagnostic_only':True,'acceptance':False,'generic_audit_pass':False,
        'audit_scope':'Early failed gate: preserve executed failure evidence and API-proven unexecuted skipped jobs separately.',
        'reported_diagnosis':a.diagnosis,'reported_diagnosis_scope':'Investigator explanation; separate from automated provenance verification.',
        'raw_metadata_identities':{name:cloud.identity(root/name) for name in ('run.json','jobs.json','artifacts-api.json')},
        'run':{key:run.get(key) for key in ('id','run_number','run_attempt','head_sha','head_branch','event','html_url','status','conclusion')},
        'source_boundary':cloud.source_boundary(a),'jobs':executed,'skipped_jobs':skipped,
        'job_conclusions':dict(Counter(j['conclusion'] for j in rows)),
        'api_job_records':len(rows),'executed_job_records':len(executed),'skipped_job_records':len(skipped),
        'artifact_inventory':inventory,'adapter_identity':cloud.identity(Path(__file__)),
        'generic_helper_identity':cloud.identity(Path(cloud.__file__)),
        'limits':['DIAGNOSTIC ONLY: no candidate, GUT, rendered or full-gate acceptance is claimed.',
                  'The jobs list contains executed jobs only; skipped_jobs explicitly retains every API skipped record, including unexpanded matrix placeholders.',
                  'Skipped jobs have no steps, no retained log and no executed-source claim. No successful test execution is inferred from source checkout.',
                  'Original artifact ZIP and extracted bytes are verified. Local work uses Git/Python inspection only; no Godot or PowerShell executes.',
                  'The ordinary passing generic audit is unchanged and cannot admit skipped or failed jobs.']}
    target=root/'audit/diagnostic-evidence.json'
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_bytes(cloud.encoded(report))
    (root/'audit/skipped-jobs.json').write_bytes(cloud.encoded({'diagnostic_only':True,'run_id':run['id'],
        'jobs_metadata_identity':cloud.identity(root/'jobs.json'),'skipped_jobs':skipped}))
    cloud.package(a,reviewed=report,audit_path=target)


if __name__=='__main__':main()
