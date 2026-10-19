#!/usr/bin/env python3
"""Bind observed query intervals to independently checked consumer provenance."""
import argparse
import json
from pathlib import Path
import sys
from read_query import read_query, require, uint, boolean, identity
BASE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BASE/'consumer_analysis'))
import bind_consumer
CAPTION = bind_consumer.CAPTION

def validate_batch(batch, matches):
    require(batch['schema']==1 and batch['source']=='ending-actions-v1', 'Unknown harness batch')
    require(batch['limits']==dict(records=4096,name_utf8_bytes=1024,batch_bytes=1048576), 'Changed harness caps')
    for field in ['query_ordinal','descendants','evaluated_count','observed_count','omitted_count','record_bytes']:
        uint(batch[field],field)
    for field in ['complete','record_cap_reached','byte_cap_reached','observer_failed']: boolean(batch[field])
    require(batch['byte_accounting']=='pretty-json-records-plus-34-bytes-per-line-and-2-per-record;4096-envelope-reserve', 'Unknown byte accounting')
    rows=batch['records']
    require(type(rows) is list and len(rows)==batch['observed_count']<=4096, 'Harness record count')
    require(batch['descendants']==batch['evaluated_count']==batch['observed_count']+batch['omitted_count'], 'Harness count contradiction')
    require(batch['complete']==(batch['omitted_count']==0), 'Harness completeness contradiction')
    require(batch['record_bytes']<=1048576-4096, 'Harness byte cap')
    accepted=0
    for index,row in enumerate(rows):
        require(row['ordinal']==index, 'Non-prefix harness ordinals')
        boolean(row['visible']); boolean(row['accepted']); boolean(row['name_truncated'])
        for field in ['enabled','invoke']:
            require(row[field] is None or type(row[field]) is bool, 'Invalid optional predicate')
        require(row['name'] is None or type(row['name']) is str and len(row['name'].encode('utf-8'))<=1024, 'Invalid name')
        if not row['visible']:
            require(row['enabled'] is None and row['name'] is None and row['invoke'] is None and not row['accepted'], 'Invisible short circuit')
        elif row['enabled'] is False:
            require(row['name'] is None and row['invoke'] is None and not row['accepted'], 'Disabled short circuit')
        else:
            require(row['enabled'] is True and row['name'] is not None, 'Missing evaluated name')
            if not row['name_truncated'] and row['name'] != CAPTION:
                require(row['invoke'] is None and not row['accepted'], 'Wrong-name short circuit')
            elif not row['name_truncated']:
                require(type(row['invoke']) is bool and row['accepted']==row['invoke'], 'Invoke short circuit')
        require(not row['accepted'] or row['visible'] and row['enabled'] is True and row['invoke'] is True, 'Acceptance contradiction')
        accepted += row['accepted']
    require(type(matches) is int and accepted<=matches<=accepted+batch['omitted_count'], 'Matches contradiction')
    return batch

def bind(folder):
    out=dict(binding_ok=False,provenance_verified=False,observation_coverage='unverified',official_acceptance_established=False,errors=[],query_streams=[],
        selected_observations=[],harness_observations=[],
        qualification='Diagnostic interval association only. Native request IDs and harness ordinals are not shared. No client delivery, exclusion cause, absence or official acceptance is established.')
    try:
        consumer=bind_consumer.bind(folder,False)
        out['consumer_binding']=consumer
        require(consumer['binding_ok'], 'Consumer/provenance binding failed: '+str(consumer['errors']))
        origin=json.loads((folder/'audit-origin.json').read_text(encoding='utf-8-sig'))
        for filename in ['read_query.py','bind_query.py']:
            path=bind_consumer.PREFIX+'query_analysis/'+filename
            retained=(folder/'source'/path).read_bytes()
            retained_sha=bind_consumer.digest(retained)
            require(retained_sha==origin['shared_source_pins'][path]['sha256'], 'Retained query source pin mismatch')
            require(retained_sha==bind_consumer.digest((Path(__file__).parent/filename).read_bytes()) or bind_consumer.source_exception(origin, 'query_analysis/'+filename, retained_sha), 'Query source pin mismatch')
        harness='tools/testing/Invoke-ExportedGameplay.ps1'
        retained=(folder/'source'/harness).read_bytes()
        require(bind_consumer.digest(retained)==origin['shared_source_pins'][harness]['sha256']==bind_consumer.digest((Path(__file__).resolve().parents[4]/harness).read_bytes()), 'Harness source pin mismatch')
        require(consumer['native_outcomes']['load']['result'].get('ending_actions_trace') is True, 'Harness observation not enabled')
        wait=consumer['original_wait']; start=bind_consumer.utc_us(wait['start']['utc']); end=bind_consumer.utc_us(wait['end']['utc'])
        pid=consumer['native_outcomes']['load']['result']['process']['pid']; hwnd=wait['hwnd']
        owners={}
        for row in consumer['selected_observations']:
            key=(row['adapter_id'],row['epoch'])
            owners.setdefault(key,set()).add(identity(row['root']))
        require(all(len(roots)==1 for roots in owners.values()), 'Ambiguous consumer generation root')
        target_rid=consumer['caption_samples'][0]['rid']
        earliest=max(start,min(s['snapshot_unix_us'] for s in consumer['caption_samples']))
        paths=sorted((folder/'query-trace').glob('*.jsonl'))
        out['trace_files_present']=len(paths)
        request_ids=set(); adapters=set(); process_bytes=sum(p.stat().st_size for p in paths)
        require(process_bytes<=64*1024*1024, 'Process query byte cap exceeded')
        for path in paths:
            replay=read_query(path.read_bytes())
            out['query_streams'].append(dict(path=path.name,**{k:v for k,v in replay.items() if k!='records'}))
            require(replay['prefix_valid'], 'Invalid query trace: '+str(replay['problems']))
            if replay['stream_identity'] is not None:
                require(replay['stream_identity'] not in adapters, 'Duplicate adapter streams')
                adapters.add(replay['stream_identity'])
            for row in replay['records']:
                require(row['request_id'] not in request_ids, 'Duplicate process request ID')
                request_ids.add(row['request_id'])
                require(len(request_ids)<=16384, 'Process request cap exceeded')
                require(row['pid']==pid and int(row['hwnd'],16)==hwnd, 'Query PID/HWND mismatch')
                if not earliest<=row['unix_us']<=row['capture_end_unix_us']<=end: continue
                key=(row['adapter_id'],row['epoch'])
                require(key in owners and identity(row['root']) in owners[key], 'Query adapter/epoch/root mismatch')
                target=(row['root']['tree_id'],target_rid)
                selected=dict(row)
                selected['caption_selected']=row['selected'] is not None and identity(row['selected'])==target
                selected['caption_predicate_observations']=[c for c in row['candidates'] if identity(c['identity'])==target]
                out['selected_observations'].append(selected)
        events=json.loads((folder/'exported-load/events.json').read_text(encoding='utf-8-sig'))
        previous={i:-1 for i in range(len(consumer['validated_waits']))}
        for event_index,event in enumerate(events):
            if event['kind']!='caption-action-enumeration' or event.get('data',{}).get('name')!=CAPTION: continue
            data=event['data']
            if 'ending_actions' not in data: continue
            ordinal=next((i for i,w in enumerate(consumer['validated_waits']) if w['start_event_index']<event_index<w['end_event_index']),None)
            require(ordinal is not None, 'Harness event outside wait')
            require(type(data['started_seconds']) in (int,float) and type(data['finished_seconds']) in (int,float)
                and 0<=data['started_seconds']<=data['finished_seconds'], 'Harness query chronology')
            batch=validate_batch(data['ending_actions'],data['matches'])
            require(batch['query_ordinal']==previous[ordinal]+1,'Harness query ordinal gap'); previous[ordinal]=batch['query_ordinal']
            if ordinal==0: out['harness_observations'].append(event)
        out['validated_harness_query_counts']={str(i):n+1 for i,n in previous.items()}
        out['analysis_qualification']={'kind':'Offline-only ordered-wait correction','original_tool_source':bind_consumer.source_exception.__globals__['SOURCE'],'selection':'First complete ordered ending wait; every wait and per-wait ordinal validated; later waits excluded from first-interval observations','original_native_run_unchanged':True}
        out['provenance_verified']=True
        out['observation_coverage']='observed_intervals_only' if out['selected_observations'] or out['harness_observations'] else 'inconclusive_no_eligible_observations'
        out['binding_ok']=True
    except (OSError,ValueError,KeyError,TypeError,IndexError) as error:
        out['errors'].append(type(error).__name__+': '+str(error))
    return out

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence',type=Path,required=True)
    args=parser.parse_args(); result=bind(args.evidence)
    with (args.evidence/'query-binding.json').open('x',encoding='utf-8') as stream:
        stream.write(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ['binding_ok','official_acceptance_established','errors']}))
    raise SystemExit(0 if result['binding_ok'] else 2)
