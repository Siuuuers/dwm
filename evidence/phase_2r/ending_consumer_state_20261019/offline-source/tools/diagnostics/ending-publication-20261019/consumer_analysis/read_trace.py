#!/usr/bin/env python3
"""Read applied AccessKit observations. This is not a UIA query or acceptance gate."""
import argparse
import hashlib
import json
from pathlib import Path


def require(ok, message):
    if not ok:
        raise ValueError(message)


def uint(value, field):
    require(type(value) is int and 0 <= value < 2**64, 'Invalid uint64: ' + field)
    return value


def identity(value):
    require(isinstance(value, dict) and set(value) == {'local_id', 'tree_id'}, 'Invalid composite identity')
    uint(value['local_id'], 'local_id')
    require(isinstance(value['tree_id'], str) and bool(value['tree_id']), 'Invalid tree_id')
    return value['tree_id'], value['local_id']


def read_trace(data):
    report = dict(schema_version=1, trace_sha256=hashlib.sha256(data).hexdigest(), prefix_valid=False,
        stream_closed=False, official_acceptance_established=False, records=[], problems=[],
        scope='Applied consumer snapshots only; filter observations are not Windows UIA query projections.')
    adapters = {}
    pid = None
    try:
        require(data.endswith(b'\n'), 'Truncated final JSONL record')
        for line, encoded in enumerate(data.splitlines(), 1):
            row = json.loads(encoded)
            require(row['schema'] == 1, 'Unsupported schema')
            current_pid = uint(row['pid'], 'pid')
            pid = current_pid if pid is None else pid
            require(pid == current_pid, 'Mixed processes')
            adapter = uint(row['adapter_id'], 'adapter_id')
            state = adapters.setdefault(adapter, dict(seq=0, epoch=0, closed=False, records=0, ambiguous=False, bound=None, candidates=set(), overflow=False, hwnd=None))
            require(not state['closed'], 'Record after adapter footer')
            require(uint(row['seq'], 'seq') == state['seq'] + (row['event'] != 'consumer_footer'), 'Missing, reordered or duplicate adapter sequence')
            state['seq'] = row['seq']
            if row['event'] == 'consumer_footer':
                require(uint(row['records'], 'records') == state['records'], 'Footer count mismatch')
                require(uint(row['dropped_records'], 'dropped_records') == 0 and row['write_failed'] is False,
                        'Trace lost records')
                state['closed'] = True
                continue
            require(row['event'] == 'consumer_commit', 'Unknown event')
            require(isinstance(row['hwnd'], str) and int(row['hwnd'], 16) > 0, 'Invalid HWND')
            require(row['source'] == 'accesskit_windows-0.32.1-consumer-probe-v1', 'Unknown observer source')
            require(state['hwnd'] in (None, row['hwnd']), 'Adapter HWND changed')
            state['hwnd'] = row['hwnd']
            uint(row['unix_us'], 'unix_us')
            require(uint(row['capture_end_unix_us'], 'capture_end_unix_us') >= row['unix_us'], 'Capture clock reversed')
            epoch = uint(row['epoch'], 'epoch')
            require(epoch >= 1 and state['epoch'] <= epoch <= state['epoch'] + 1, 'Invalid context epoch')
            initial = epoch != state['epoch']
            require(row['cause'] in {'initial','placeholder_initial','placeholder_replacement','update','focus','placeholder_focus'}, 'Unknown cause')
            if initial:
                require(row['cause'] in {'initial','placeholder_initial','placeholder_replacement'}, 'Epoch lacks construction')
                state.update(epoch=epoch, ambiguous=False, bound=None, candidates=set(), overflow=False)
            else:
                require(row['cause'] not in {'initial','placeholder_initial','placeholder_replacement'}, 'Repeated construction')
            for field in ['placeholder','discovery_overflow','path_truncated','label_truncated','host_focused']:
                require(type(row[field]) is bool, 'Invalid boolean ' + field)
            candidates = [identity(v) for v in row['candidates']]
            require(len(set(candidates)) == len(candidates), 'Duplicate candidate identity')
            require(state['candidates'].issubset(set(candidates)), 'Candidate history lost within epoch')
            require(not state['overflow'] or row['discovery_overflow'], 'Discovery overflow lost within epoch')
            state['candidates'], state['overflow'] = set(candidates), row['discovery_overflow']
            bound = identity(row['bound']) if row['bound'] is not None else None
            status = row['binding_state']
            require(status in {'unbound','ambiguous','present','absent'}, 'Unknown binding state')
            require(not state['ambiguous'] or status == 'ambiguous', 'Ambiguity lost within epoch')
            if status == 'unbound':
                require(not candidates and bound is None, 'Unbound identity contradiction')
            elif status == 'ambiguous':
                require(len(candidates) >= 2 or row['discovery_overflow'], 'Ambiguity lacks evidence')
                state['ambiguous'] = True
            else:
                require(len(candidates) == 1 and bound == candidates[0] and not row['discovery_overflow'], 'Unique binding not established')
                require(state['bound'] in (None, bound), 'Bound identity changed within epoch')
                state['bound'] = bound
            root = identity(row['root'])
            nodes = row['nodes']
            if status == 'present':
                require(nodes and identity(nodes[0]['identity']) == bound, 'Present path lacks target')
            elif status in {'absent','unbound','ambiguous'}:
                require(not nodes, 'Nonpresent state has target path')
            seen = set()
            for index, node in enumerate(nodes):
                key = identity(node['identity'])
                require(key not in seen, 'Path cycle')
                seen.add(key)
                parent = identity(node['parent']) if node['parent'] is not None else None
                if index + 1 < len(nodes):
                    require(parent == identity(nodes[index+1]['identity']), 'Disconnected path')
                elif not row['path_truncated']:
                    require(key == root and parent is None, 'Path does not terminate at root')
                for field in ['hidden','focused']:
                    require(type(node[field]) is bool, 'Invalid node boolean')
                require(node['filter'] in {'Include','ExcludeNode','ExcludeSubtree'}, 'Unknown filter')
                require(node['raw_label'] is None or isinstance(node['raw_label'], str), 'Invalid raw label')
                require(isinstance(node['role'], str) and isinstance(node['geometry'], str), 'Invalid node metadata')
            state['records'] += 1
            row = dict(row, source_line=line, observation_status='incomplete' if any(row[f] for f in
                ['discovery_overflow','path_truncated','label_truncated']) else status)
            report['records'].append(row)
        require(bool(report['records']), 'No consumer snapshots')
        report['prefix_valid'] = True
        report['stream_closed'] = all(v['closed'] for v in adapters.values())
        report['pid'] = pid
    except (ValueError, KeyError, TypeError, OverflowError) as error:
        report['problems'].append(str(error))
    report['coverage'] = 'Closed observed stream' if report['stream_closed'] else 'Complete prefix only; no final or continuous coverage guarantee'
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--trace', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = read_trace(args.trace.read_bytes())
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    raise SystemExit(0 if result['prefix_valid'] else 2)
