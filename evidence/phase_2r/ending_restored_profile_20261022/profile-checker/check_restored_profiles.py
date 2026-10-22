"""Offline aggregate analysis only; custody/durable qualification is a separate gate."""
import argparse
import json
import re
from pathlib import Path

PREFIX = 'DWM_SCENE_VALIDATION_PROFILE '
MARKER = re.compile(r'ENDING_LOAD_PHASE pid=(\d+) ticks_usec=(\d+) phase=(\S+)')
KINDS = ('configuration', 'compilation', 'physical_proof', 'receipt_validation', 'bundle_validation')
FIELDS = {'operation', 'lifecycle_state', 'playback_stage', 'next_step_index',
          'inclusive_nested', 'elapsed_us', 'ok', 'snapshot_validations'} | {
              f'{kind}_{suffix}' for kind in KINDS for suffix in ('calls', 'us', 'failures')}
PHASES = ('pre_semantic_us', 'guard_prepare_us', 'semantic_us', 'guard_verify_us')
SNAPSHOT_REQUIRED = {'ordinal', 'elapsed_us', 'ok', 'inclusive_nested', *PHASES}
SNAPSHOT_OPTIONAL = {'checkpoint_sequence', 'lifecycle_state', 'playback_stage'}
STATES = ('PLAYING', 'ENDING', 'COMPLETED', 'TERMINAL_PENDING')
STAGES = ('PRIMARY_PENDING', 'PRIMARY_PLAYED', 'EPILOGUE_PLAYED', 'GALLERY_RECORDED')


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def integer(value, field):
    require(type(value) is int and value >= 0, f'nonnegative integer required: {field}')


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, f'duplicate JSON key: {key}')
        result[key] = value
    return result


def extract_raw(log):
    """Call and persist this before validation; includes malformed JSON payloads."""
    return [line[len(PREFIX):] for line in log.splitlines() if line.startswith(PREFIX)]


def validate_record(record, writer, operation, interval_us):
    require(type(record) is dict and set(record) == FIELDS, 'aggregate schema mismatch')
    name = f'ending_writer.{writer}.{operation}'
    require(record['operation'] == name, f'aggregate operation mismatch: {name}')
    require(record['lifecycle_state'] == ('ENDING', 'ENDING', 'COMPLETED')[writer-1]
            and record['playback_stage'] == ('EPILOGUE_PLAYED', 'GALLERY_RECORDED', 'GALLERY_RECORDED')[writer-1],
            f'aggregate lifecycle mismatch: {name}')
    require(record['ok'] is True and record['inclusive_nested'] is True, 'aggregate unsuccessful/noninclusive')
    for field in ('next_step_index', 'elapsed_us'):
        integer(record[field], field)
    require(record['next_step_index'] == 1, 'aggregate step mismatch')
    require(record['elapsed_us'] <= interval_us, 'aggregate exceeds operation interval')
    for kind in KINDS:
        for suffix in ('calls', 'us', 'failures'):
            integer(record[f'{kind}_{suffix}'], f'{kind}_{suffix}')
        calls, duration = record[f'{kind}_calls'], record[f'{kind}_us']
        require(record[f'{kind}_failures'] == 0, f'{kind} failure')
        require(calls != 0 or duration == 0, f'{kind} time without calls')
        if kind in ('physical_proof', 'receipt_validation', 'bundle_validation'):
            require(operation == 'capture' or calls > 0, f'{kind} sample missing')
        # Same-kind wrappers are nonrecursive on the reviewed successful path.
        # Different kinds are inclusive and overlap; never sum their times.
        require(duration <= record['elapsed_us'], f'{kind} exceeds scope')
    snapshots = record['snapshot_validations']
    require(type(snapshots) is list and (operation == 'capture' or snapshots), 'snapshot records missing')
    for ordinal, snapshot in enumerate(snapshots):
        require(type(snapshot) is dict and SNAPSHOT_REQUIRED <= set(snapshot)
                and set(snapshot) <= SNAPSHOT_REQUIRED | SNAPSHOT_OPTIONAL, 'snapshot schema mismatch')
        for field in ('ordinal', 'elapsed_us', *PHASES):
            integer(snapshot[field], field)
        require(snapshot['ordinal'] == ordinal and snapshot['ok'] is True
                and snapshot['inclusive_nested'] is True, 'snapshot completion invalid')
        if 'checkpoint_sequence' in snapshot:
            integer(snapshot['checkpoint_sequence'], 'checkpoint_sequence')
        if 'lifecycle_state' in snapshot:
            require(snapshot['lifecycle_state'] in STATES, 'snapshot lifecycle invalid')
        if 'playback_stage' in snapshot:
            require(snapshot['playback_stage'] in STAGES, 'snapshot stage invalid')
        require(sum(snapshot[field] for field in PHASES) <= snapshot['elapsed_us'] <= record['elapsed_us'],
                'snapshot nesting invalid')


def validate_log(log, expected_pid):
    """Validate one original loader log after independent qualification gates pass."""
    integer(expected_pid, 'expected_pid')
    require(expected_pid > 0, 'positive loader PID required')
    marks, aggregates = [], []
    for line_number, line in enumerate(log.splitlines()):
        if line.startswith('ENDING_LOAD_PHASE'):
            match = MARKER.fullmatch(line)
            require(match is not None, 'malformed phase marker')
            pid, ticks, phase = match.groups()
            require(int(pid) == expected_pid, 'phase PID mismatch')
            marks.append((line_number, int(ticks), phase))
        if line.startswith('DWM_SCENE_VALIDATION_PROFILE'):
            require(line.startswith(PREFIX), 'malformed aggregate prefix')
            aggregates.append((line_number, json.loads(line[len(PREFIX):], object_pairs_hook=unique_object)))
        require(not line.startswith('DWM_CHECKPOINT_PROFILE'), 'unexpected checkpoint profiling')
    require(len(aggregates) == 9, 'exactly nine aggregate records required')
    require(all(a[1] <= b[1] for a, b in zip(marks, marks[1:])), 'nonmonotonic phase markers')

    def marker(name):
        matches = [(line, ticks) for line, ticks, phase in marks if phase == name]
        require(len(matches) == 1, f'exactly one phase required: {name}')
        return matches[0]

    expected = ['ending_completion.begin']
    for writer in range(1, 4):
        base = f'ending_writer.{writer}'
        expected.append(base + '.begin')
        for operation in ('capture', 'prepare', 'commit'):
            expected.extend((base + f'.{operation}.begin', base + f'.{operation}.return'))
        expected.append(base + '.return')
    expected.extend(('ending_completion.accept_return', 'title.ready'))
    sequence = [marker(name) for name in expected]
    require(all(a[0] < b[0] and a[1] <= b[1] for a, b in zip(sequence, sequence[1:])),
            'writer/operation/Accept phase ordering invalid')
    require({phase for _, _, phase in marks if phase.startswith('ending_writer.')} ==
            {name for name in expected if name.startswith('ending_writer.')}, 'unexpected writer phase')
    scopes = []
    cursor = 0
    for writer in range(1, 4):
        for operation in ('capture', 'prepare', 'commit'):
            name = f'ending_writer.{writer}.{operation}'
            begin, end = marker(name + '.begin'), marker(name + '.return')
            line, record = aggregates[cursor]
            cursor += 1
            require(begin[0] < line < end[0], f'aggregate outside matching interval: {name}')
            validate_record(record, writer, operation, end[1] - begin[1])
            scopes.append({'marker_elapsed_us': end[1] - begin[1], 'aggregate': record})
    begin, returned, title = (marker(name)[1] for name in
                              ('ending_completion.begin', 'ending_completion.accept_return', 'title.ready'))
    writers = {str(i): marker(f'ending_writer.{i}.return')[1] - marker(f'ending_writer.{i}.begin')[1]
               for i in range(1, 4)}
    return {'metric_validation': 'passed', 'qualification': 'requires separate custody/census/durable review',
            'loader_pid': expected_pid, 'accept_us': returned - begin, 'title_after_accept_us': title - returned,
            'writer_us': writers, 'sequential_writer_total_us': sum(writers.values()), 'scopes': scopes,
            'interpretation': 'Nested category timings overlap; do not sum them or infer exclusive CPU/I/O costs.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('loader_log', type=Path)
    parser.add_argument('--loader-pid', required=True, type=int)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    log = args.loader_log.read_text(encoding='utf-8-sig')
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / 'raw-aggregate-payloads.json').write_text(json.dumps(extract_raw(log), indent=2) + '\n')
    try:
        result = validate_log(log, args.loader_pid)
    except (ValueError, TypeError, KeyError) as error:
        (args.output / 'metric-result.json').write_text(json.dumps({'metric_validation': 'failed', 'error': str(error)}) + '\n')
        raise SystemExit(str(error))
    (args.output / 'metric-result.json').write_text(json.dumps(result, indent=2) + '\n')


if __name__ == '__main__':
    main()
