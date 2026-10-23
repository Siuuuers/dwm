#!/usr/bin/env python3
"""Bind applied-state snapshots to retained diagnostic provenance and original wait."""
import argparse
from datetime import datetime, timezone
from decimal import Decimal
import hashlib
import json
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from prepare_package import GAME_COMMIT, GAME_TREE, ENGINE_COMMIT, ENGINE_TREE, ORIGINAL
from read_trace import read_trace, require
CAPTION = 'TEST Seven-day ending.'
PREFIX = 'tools/diagnostics/ending-publication-20261019/'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def utc_us(value):
    stamp = datetime.fromisoformat(value.replace('Z', '+00:00'))
    require(stamp.tzinfo is not None, 'Unzoned timestamp')
    delta = stamp.astimezone(timezone.utc) - datetime(1970,1,1,tzinfo=timezone.utc)
    return (delta.days*86400+delta.seconds)*1000000+delta.microseconds


def bind(folder):
    report = dict(schema_version=1, binding_ok=False, official_acceptance_established=False,
        scope='Applied-state observations; not a UIA projection or official-build acceptance.',
        input_files={}, native_outcomes={}, errors=[], selected_observations=[])
    def raw(name):
        data=(folder/name).read_bytes()
        report['input_files'][name]={'sha256':digest(data),'bytes':len(data)}
        return data
    def read(name):
        return json.loads(raw(name).decode('utf-8-sig'))
    try:
        origin=read('audit-origin.json')
        build=read('native-build/build-receipt.json')
        sdk=read('consumer-sdk/sdk-receipt.json')
        package=read('native-diagnostic/validation.json')
        require(origin['game_commit']==GAME_COMMIT and origin['game_tree']==GAME_TREE, 'Game identity mismatch')
        require(build['ok'] is True and build['source_commit']==ENGINE_COMMIT and build['source_tree']==ENGINE_TREE
            and build['build_name']=='dwm_consumer_probe_v1', 'Engine identity mismatch')
        require(sdk['ok'] is True and sdk['target']=='x86_64-pc-windows-msvc' and sdk['rust_toolchain']=='1.85.0'
            and sdk['source_commit']=='72460cd52d1b24492393cdf54a6f19d2fd63e258'
            and sdk['crate_sha256']=='eff7009f1a532e917d66970a1e80c965140c6cfbbabbdde3d64e5431e6c78e21'
            and sdk['original_lock_sha256']=='50a70648b398f0ee2331b37834a308e3b38d4ca7051310cb95b2ecfd04ebc2b8'
            and sdk['rustflags']=='-C target-feature=+crt-static' and sdk['tests_exit_code']==0 and sdk['build_exit_code']==0, 'SDK build not qualified')
        require(build['consumer_sdk_receipt_sha256']==report['input_files']['consumer-sdk/sdk-receipt.json']['sha256']
            and build['consumer_sdk_library_sha256']==sdk['library']['sha256'], 'SDK linkage receipt mismatch')
        require(package['ok'] is True and package['diagnostic'] is True and package['commit']==GAME_COMMIT
            and package['original_package']==ORIGINAL, 'Package identity mismatch')
        files={v['path']:v for v in package['files']}
        require(len(files)==len(package['files']) and files['DWM.exe']['sha256']==build['template']['sha256']
            and files['DWM.pck']['sha256']==ORIGINAL['pck_sha256'], 'Package executable/PCK mismatch')
        # The retained source is the implementation actually reviewed and built.
        for filename in ['consumer_analysis/read_trace.py','consumer_analysis/bind_consumer.py']:
            source=PREFIX+filename
            require(digest(raw('source/'+source))==origin['shared_source_pins'][source]['sha256']
                ==digest((Path(__file__).parent/Path(filename).name).read_bytes()), 'Analysis source pin mismatch')
        manifest = sdk['probe_manifest']
        paths = [entry['path'] for entry in manifest]
        required_paths = {'candidate/adapter.rs', 'candidate/consumer_probe.rs', 'baseline/adapter.rs', 'apply_probe.py'}
        require(len(paths) == len(set(paths)) and required_paths.issubset(paths),
            'SDK probe manifest is incomplete or has duplicate paths')
        require(all(isinstance(path, str) and not Path(path).is_absolute() and '..' not in Path(path).parts
            for path in paths), 'Invalid SDK probe manifest path')
        for entry in manifest:
            source=PREFIX+'consumer-probe/'+entry['path']
            require(digest(raw('source/'+source))==entry['sha256']==origin['shared_source_pins'][source]['sha256'],
                'SDK probe source pin mismatch')
        for mode in ['capability','create','load']:
            result=read('exported-'+mode+'/result.json')
            process=read(mode+'-process.json')
            report['native_outcomes'][mode]={'result':result,'process_receipt':process}
            require(result['source_commit']==GAME_COMMIT and result['archive_sha256']==package['archive']['sha256']
                and result['executable_sha256']==build['template']['sha256'] and result['pck_sha256']==ORIGINAL['pck_sha256'],
                'Driver identity mismatch: '+mode)
            require(result['renderer_request']=='ProjectDefault' and result['accessibility_request']=='Always'
                and result['audio_request']=='Dummy', 'Driver settings changed')
            if mode!='load':
                require(result['ok'] is True and result['clean_player_exit'] is True and result['forced_cleanup'] is False
                    and result['exit_code']==0 and process['exit_code']==0, 'Prerequisite failed: '+mode)
        load=report['native_outcomes']['load']['result']
        # Deliberately no assertion about load.ok, failure, clean exit or cleanup.
        # A diagnostic success must remain a diagnostic success, never official acceptance.
        pid=int(load['process']['pid'])
        events=read('exported-load/events.json')
        starts=[e for e in events if e['kind']=='native-caption-wait-start' and e.get('data',{}).get('name')==CAPTION]
        ends=[e for e in events if e['kind']=='native-caption-wait-end' and e.get('data',{}).get('name')==CAPTION]
        require(len(starts)==len(ends)==1 and starts[0]['data']['deadline_seconds']==30, 'Original wait missing or changed')
        start,end=utc_us(starts[0]['utc']),utc_us(ends[0]['utc'])
        require(utc_us(load['process']['started_utc'])<start<end, 'Original wait chronology invalid')
        windows={int(e['data']['handle']) for e in events if e['kind']=='native-boundary'
            and e.get('data',{}).get('stage')=='caption-before-query: '+CAPTION
            and int(e['data']['pid'])==pid and start<=utc_us(e['utc'])<=end}
        require(len(windows)==1 and next(iter(windows))>0, 'Original wait HWND missing or ambiguous')
        hwnd=next(iter(windows))
        report['original_wait']={'start':starts[0],'end':ends[0],'hwnd':hwnd,
            'note':'Logged wait interval only; no assertion of strict Stopwatch deadline admission.'}
        stdout=raw('exported-load/game.stdout.log').decode('utf-8-sig')
        require(stdout.splitlines()[0].startswith('Godot Engine v4.6.3.stable.dwm_consumer_probe_v1.'+ENGINE_COMMIT[:9]+' - '),
            'Load engine banner mismatch')
        samples=[]
        for line in stdout.splitlines():
            if not line.startswith('DWM_ENDING_PUBLICATION_TRACE '): continue
            sample=json.loads(line.split(' ',1)[1])
            require(int(sample['pid'])==pid and sample['caption_text']==CAPTION, 'Caption process/text mismatch')
            update=sample.get('last_accessibility_updates',{}).get('caption_accessibility',{})
            f=update.get('fields',{})
            if not f: continue
            require(f['element_read'] is True and f['element_valid'] is True and f['provider_valid'] is True
                and f['name_written']==CAPTION and f['role_written']=='button', 'Invalid current caption callback')
            node=sample['caption_ancestors'][0]
            require(node['id']==f['node_id'] and node['inside_tree'] is True and node['visible_in_tree'] is True
                and node['queued_for_deletion'] is False and sample['canvas']['inside_tree'] is True
                and sample['canvas']['visible_in_tree'] is True and sample['state']['canvas_withdrawn'] is False,
                'Caption snapshot not live')
            require(0<=update['ticks_us']<=sample['ticks_us'], 'Callback chronology invalid')
            samples.append(dict(rid=f['element_id'],node_id=f['node_id'],callback_ticks_us=update['ticks_us'],
                snapshot_unix_us=int(Decimal(str(sample['unix_seconds']))*1000000), window_id=sample['window_id']))
        require(samples and len({(s['rid'],s['node_id'],s['window_id']) for s in samples})==1, 'Current caption identity missing or ambiguous')
        report['caption_samples']=samples
        trace_path='consumer-trace/trace-'+str(pid)+'.jsonl'
        require(sorted(p.name for p in (folder/'consumer-trace').glob('*.jsonl'))==['trace-'+str(pid)+'.jsonl'], 'Trace PID census mismatch')
        replay=read_trace(raw(trace_path))
        report['reader']={k:v for k,v in replay.items() if k!='records'}
        require(replay['prefix_valid'] is True and replay['pid']==pid, 'Invalid consumer trace')
        eligible=[r for r in replay['records'] if int(r['hwnd'],16)==hwnd and
            max(start,min(s['snapshot_unix_us'] for s in samples))<=r['unix_us']<=r['capture_end_unix_us']<=end]
        require(eligible, 'No complete snapshot after current caption registration within logged wait')
        require(len({r['adapter_id'] for r in eligible})==1, 'Multiple adapters claim original HWND')
        for row in eligible:
            selected=dict(row)
            if row['bound'] is not None:
                selected['current_caption_rid_match']=row['bound']['local_id']==samples[0]['rid']
                # A local RID alone is insufficient in an embedded/grafted namespace.
                selected['root_namespace_match']=row['bound']['tree_id']==row['root']['tree_id']
                require(selected['current_caption_rid_match'] and selected['root_namespace_match'], 'Consumer binding is not current root-tree caption')
            selected['caption_label_and_role_match']=bool(row['nodes']) and row['nodes'][0]['raw_label'] is not None and row['nodes'][0]['raw_label'].rstrip()==CAPTION and row['nodes'][0]['role']=='Button'
            report['selected_observations'].append(selected)
        report['binding_ok']=True
    except (OSError, ValueError, KeyError, TypeError, IndexError) as error:
        report['errors'].append(type(error).__name__+': '+str(error))
    return report


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence',type=Path,required=True)
    args=parser.parse_args()
    result=bind(args.evidence)
    (args.evidence/'consumer-binding.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ['binding_ok','official_acceptance_established','errors']}))
    raise SystemExit(0 if result['binding_ok'] else 2)
