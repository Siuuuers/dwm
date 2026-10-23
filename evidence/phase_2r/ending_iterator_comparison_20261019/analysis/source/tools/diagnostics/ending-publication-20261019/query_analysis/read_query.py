"""Strict reader of observed Navigate calls, never a delivery/absence oracle."""
import hashlib
import json

SOURCE = 'accesskit_windows-0.32.1-query-probe-v1'

def require(ok, message):
    if not ok:
        raise ValueError(message)

def uint(value, name):
    require(type(value) is int and 0 <= value < 2**64, 'Invalid ' + name)
    return value

def identity(value):
    require(type(value) is dict and set(value) == {'local_id', 'tree_id'}, 'Invalid identity')
    uint(value['local_id'], 'local_id')
    require(type(value['tree_id']) is str and 0 < len(value['tree_id']) <= 1024, 'Invalid tree_id')
    return value['tree_id'], value['local_id']

def boolean(value):
    require(type(value) is bool, 'Invalid boolean')

def read_query(data):
    out = dict(prefix_valid=False, stream_closed=False, records=[], problems=[],
        sha256=hashlib.sha256(data).hexdigest(), absence_established=False,
        scope='Observed resolver-entered, armed Navigate callbacks only; not client delivery. Recursive filter internals, pre-arm and pre-resolution failures are uncaptured.')
    try:
        require(len(data) <= 64*1024*1024 + 4096, 'Output cap exceeded')
        require(not data or data.endswith(b'\n'), 'Partial JSONL tail')
        stream = None
        requests = set()
        epochs = {}
        for encoded in data.splitlines():
            require(len(encoded) <= 384*1024, 'Record cap exceeded')
            row = json.loads(encoded)
            require(not out['stream_closed'], 'Record after footer')
            require(row['schema'] == 1 and row['source'] == SOURCE, 'Unknown schema/source')
            key = (uint(row['pid'], 'pid'), uint(row['adapter_id'], 'adapter_id'))
            require(key[0] > 0 and key[1] > 0, 'Zero process/adapter')
            stream = key if stream is None else stream
            require(stream == key, 'Mixed stream identity')
            if row['event'] == 'query_footer':
                uint(row['dropped_records'], 'dropped_records'); boolean(row['write_failed'])
                emitted=uint(row['records'], 'records')
                require(len(out['records'])<=emitted<=len(out['records'])+int(row['write_failed']), 'Footer count mismatch')
                require(row['pre_arm_coverage'] is False and row['pre_resolution_coverage'] is False, 'Unsupported coverage claim')
                out['footer'] = row
                out['stream_closed'] = True
                continue
            require(row['event'] == 'navigate', 'Unknown event')
            require(uint(row['emission_seq'], 'emission_seq') == len(out['records']) + 1, 'Emission sequence gap')
            require(len(out['records']) < 16384, 'Request cap exceeded')
            request = uint(row['request_id'], 'request_id')
            require(request not in requests, 'Duplicate request')
            requests.add(request)
            require(type(row['hwnd']) is str and int(row['hwnd'], 16) > 0, 'Invalid HWND')
            require(type(row['thread_id']) is str and bool(row['thread_id']), 'Invalid thread')
            epoch = uint(row['epoch'], 'epoch'); require(epoch > 0, 'Zero epoch')
            for field in ['unix_us','capture_end_unix_us','epoch_started_us','armed_us']:
                uint(row[field], field)
            require(0 < row['epoch_started_us'] <= row['armed_us'] <= row['unix_us'] <= row['capture_end_unix_us'], 'Invalid capture chronology')
            boolean(row['placeholder']); boolean(row['truncated'])
            root = identity(row['root']); identity(row['source_node'])
            epoch_key = (row['hwnd'], root, row['epoch_started_us'], row['armed_us'], row['placeholder'])
            require(epochs.setdefault(epoch, epoch_key) == epoch_key, 'Epoch identity changed')
            require(type(row['direction']) is int, 'Invalid direction')
            require(type(row['outcome_hresult']) is int and -(2**31) <= row['outcome_hresult'] < 2**31, 'Invalid HRESULT')
            boolean(row['outcome_ok'])
            require(row['outcome_ok'] == (row['selected'] is not None), 'Result/selected identity contradiction')
            if row['selected'] is not None:
                identity(row['selected'])
                require(row['outcome_hresult'] == 0, 'Selected node with failed result')
            candidates = row['candidates']
            require(type(candidates) is list and len(candidates) <= 256, 'Candidate cap exceeded')
            count=uint(row['candidate_count'],'candidate_count'); omitted=uint(row['omitted_candidates'],'omitted_candidates')
            require(count == len(candidates) + omitted, 'Candidate accounting mismatch')
            require(not omitted or row['truncated'], 'Unmarked omitted candidates')
            for candidate in candidates:
                identity(candidate['identity'])
                require(candidate['predicate'] in {'filter','filter_with_root_exception'}, 'Unknown predicate')
                require(candidate['filter'] in {'Include','ExcludeNode','ExcludeSubtree'}, 'Unknown filter')
                require(type(candidate['role']) is str, 'Invalid role')
                for field in ['hidden','focused','label_truncated']: boolean(candidate[field])
                label=candidate['raw_label']
                require(label is None or type(label) is str and len(label.encode('utf-8')) <= 1024, 'Invalid/capped label')
            out['records'].append(row)
        out['prefix_valid'] = True
        out['stream_identity'] = stream
    except (ValueError, KeyError, TypeError, OverflowError) as error:
        out['problems'].append(str(error))
    out['coverage'] = 'Observed calls only; missing records, absent footer, drops or truncation never establish exclusion or absence.'
    return out
