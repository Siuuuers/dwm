"""Offline-only analysis; run alongside original-evidence.zip. No runtime execution."""
import json,zipfile,hashlib,datetime,pathlib
p=pathlib.Path(__file__).parent
b=(p/'original-evidence.zip').read_bytes()
assert len(b)==1960221 and hashlib.sha256(b).hexdigest()=='477cef168d3c7e76f76d19198050866dfe132cc4003e5e486c2d9e8bfbf405c3'
z=zipfile.ZipFile(p/'original-evidence.zip');assert z.testzip() is None
read=lambda n:json.loads(z.read(n))
m=read('timing-evidence-manifest.json');assert len(z.namelist())==len(set(z.namelist()))
assert set(z.namelist())=={v['path'] for v in m['files']}|{'timing-evidence-manifest.json'}
for v in m['files']:
 d=z.read(v['path']);assert len(d)==v['bytes'] and hashlib.sha256(d).hexdigest()==v['sha256']
e=read('exported-load/events.json');g=[json.loads(v) for v in z.read('title-timing.jsonl').splitlines()];r=read('exported-load/result.json')
assert all(v['pid']==r['process']['pid'] for v in g)
assert [v['sequence'] for v in g]==list(range(1,7))
assert all(a['ticks_usec']<b['ticks_usec'] for a,b in zip(g,g[1:]))
name='TEST Seven-day ending.'
start=next(v for v in e if v['kind']=='native-caption-wait-start' and v['data']['name']==name)
end=next(v for v in e if v['kind']=='native-caption-wait-end' and v['data']['name']==name)
polls=[v for v in e if v['kind']=='native-boundary' and v['data']['stage']=='caption-before-query: '+name]
assert all(v['data']['pid']==3068 and v['data']['handle']==786872 for v in polls)
origin=datetime.datetime.fromisoformat(start['utc'].replace('Z','+00:00')).timestamp()
rows=[]
for v in g:
 rows.append(dict(sequence=v['sequence'],phase=v['phase'],edge=v['edge'],ticks_usec=v['ticks_usec'],utc=datetime.datetime.fromtimestamp(v['utc_unix'],datetime.timezone.utc).isoformat(),approx_seconds_after_caption_wait_record=round(v['utc_unix']-origin,6),detail=v['detail']))
s=read('exported-load/failure-saves-autosave.json')['current_snapshot']['snapshot']
out=dict(run=39279335309,artifact=12199553825,verified_payloads=len(m['files']),pid=3068,hwnd=786872,caption_wait_start=start,caption_wait_end=end,polls=len(polls),responding_polls=sum(v['data']['responds'] for v in polls),caption_acquisitions=sum(v['kind']=='caption-window-acquisition' and v['data']['name']==name for v in e),caption_enumerations=sum(v['kind']=='caption-action-enumeration' and v['data']['name']==name for v in e),finish_invocations=sum(v['kind']=='invoke' and v['data'].get('purpose')=='finish ending' for v in e),title_anchor_count=sum(v['kind'] in ['finish-ending-invoke-return','ending-title-wait-start','ending-title-wait-end'] for v in e),game_timeline=rows,phase_seconds={'checkpoint':(g[5]['ticks_usec']-g[0]['ticks_usec'])/1e6,'prepare':(g[2]['ticks_usec']-g[1]['ticks_usec'])/1e6,'commit':(g[4]['ticks_usec']-g[3]['ticks_usec'])/1e6},clock_offset_range_seconds=max(v['utc_unix']-v['ticks_usec']/1e6 for v in g)-min(v['utc_unix']-v['ticks_usec']/1e6 for v in g),failure_snapshot={'checkpoint_id':s['checkpoint_id'],'lifecycle':s['lifecycle']['state']},marker_write_warning=any(b'DWM_TITLE_TIMING_WRITE_FAILURE' in z.read(n) for n in z.namelist() if n.startswith('exported-load/') and n.endswith('.log')),limits='Cross-process UTC alignment approximate; caption start is an event record, not an atomic stopwatch origin. No finish-ending/New Acc anchors exist. Late probe is diagnostic only; no successful in-budget acquisition implied.')
(p/'timeline.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2))
