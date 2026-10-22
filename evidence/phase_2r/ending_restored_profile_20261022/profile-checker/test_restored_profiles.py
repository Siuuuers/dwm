"""Offline checker tests. Synthesized phase envelopes are never gameplay evidence."""
import copy
import json
import unittest
from pathlib import Path

from check_restored_profiles import extract_raw, validate_log, PREFIX

RETAINED = Path(__file__).with_name('retained-aggregate-payloads.json')


def envelope(records):
    """Put real short-route records into synthetic restored-route marker intervals."""
    lines, tick = [], 1000

    def mark(name):
        nonlocal tick
        tick += 10
        lines.append(f'ENDING_LOAD_PHASE pid=123 ticks_usec={tick} phase={name}')

    mark('ending_completion.begin')
    for i in range(1, 4):
        mark(f'ending_writer.{i}.begin')
        for j, operation in enumerate(('capture', 'prepare', 'commit')):
            name = f'ending_writer.{i}.{operation}'
            record = records[(i-1)*3+j]
            mark(name + '.begin')
            lines.append(PREFIX + json.dumps(record))
            tick += record['elapsed_us']
            mark(name + '.return')
        mark(f'ending_writer.{i}.return')
    mark('ending_completion.accept_return')
    mark('title.ready')
    return '\n'.join(lines)


class Profiles(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.records = [json.loads(raw) for raw in json.loads(RETAINED.read_text())]
        assert len(cls.records) == 9

    def rejects(self, log):
        with self.assertRaises(ValueError):
            validate_log(log, 123)

    def test_retained_records_synthetic_envelope(self):
        result = validate_log(envelope(self.records), 123)
        self.assertEqual(len(result['scopes']), 9)
        self.assertLessEqual(result['sequential_writer_total_us'], result['accept_us'])

    def test_empty_capture_dynamic_counts_historical_labels(self):
        records = copy.deepcopy(self.records)
        for record in records:
            if record['operation'].endswith('capture'):
                record['snapshot_validations'] = []
                for field in record:
                    if field.endswith(('_calls', '_us', '_failures')):
                        record[field] = 0
            else:
                record['bundle_validation_calls'] += 17
                for kind in ('configuration', 'compilation'):
                    record[kind + '_calls'] = 0
                    record[kind + '_us'] = 0
                record['snapshot_validations'][0]['lifecycle_state'] = 'PLAYING'
                record['snapshot_validations'][0]['playback_stage'] = 'PRIMARY_PENDING'
        validate_log(envelope(records), 123)

    def test_malformed_record_fields(self):
        changes = [
            ('missing field', lambda r: r.pop('ok')),
            ('extra field', lambda r: r.update(extra=1)),
            ('negative', lambda r: r.update(receipt_validation_calls=-1)),
            ('boolean integer', lambda r: r.update(bundle_validation_calls=True)),
            ('float integer', lambda r: r.update(bundle_validation_calls=1.0)),
            ('failure', lambda r: r.update(physical_proof_failures=1)),
            ('unsuccessful', lambda r: r.update(ok=False)),
            ('noninclusive', lambda r: r.update(inclusive_nested=False)),
            ('missing samples', lambda r: r.update(receipt_validation_calls=0, receipt_validation_us=0)),
            ('time without calls', lambda r: r.update(bundle_validation_calls=0, bundle_validation_us=1)),
            ('scope nesting', lambda r: r.update(bundle_validation_us=r['elapsed_us']+1)),
            ('wrong lifecycle', lambda r: r.update(lifecycle_state='COMPLETED')),
            ('wrong step', lambda r: r.update(next_step_index=0)),
            ('wrong operation', lambda r: r.update(operation='ending_writer.2.prepare')),
            ('missing snapshots', lambda r: r.update(snapshot_validations=[])),
            ('snapshot ordinal', lambda r: r['snapshot_validations'][0].update(ordinal=1)),
            ('snapshot phase missing', lambda r: r['snapshot_validations'][0].pop('semantic_us')),
            ('snapshot sum', lambda r: r['snapshot_validations'][0].update(semantic_us=r['elapsed_us']+1)),
            ('snapshot optional label', lambda r: r['snapshot_validations'][0].update(playback_stage='INVALID')),
            ('snapshot sequence type', lambda r: r['snapshot_validations'][0].update(checkpoint_sequence=True)),
        ]
        for name, change in changes:
            with self.subTest(name=name):
                records = copy.deepcopy(self.records)
                change(records[1])
                self.rejects(envelope(records))

    def test_bad_associations_and_missing_returns(self):
        log = envelope(self.records)
        lines = log.splitlines()
        aggregate = next(i for i, line in enumerate(lines) if line.startswith(PREFIX))
        moved = lines.copy()
        moved.insert(0, moved.pop(aggregate))
        variants = [
            '\n'.join(moved),
            '\n'.join(lines[:aggregate] + lines[aggregate+1:]),
            log + '\n' + lines[aggregate],
            log.replace('pid=123', 'pid=124', 1),
            log.replace('phase=ending_writer.1.commit.return', 'phase=missing.return'),
            log.replace('phase=ending_writer.2.begin', 'phase=ending_writer.1.begin'),
            log.replace('ticks_usec=1010', 'ticks_usec=999999999999'),
            log.replace('phase=ending_completion.accept_return', 'phase=other.accept_return'),
            log.replace('phase=title.ready', 'phase=other.title'),
            log + '\nDWM_CHECKPOINT_PROFILE {}',
            log + '\nENDING_LOAD_PHASE malformed',
            log.replace(PREFIX + '{', PREFIX + '{"ok":true,', 1),
            log.replace(PREFIX + '{', PREFIX + 'BROKEN{', 1),
        ]
        for i, variant in enumerate(variants):
            with self.subTest(variant=i):
                self.rejects(variant)

    def test_raw_payload_kept_before_parse(self):
        self.assertEqual(extract_raw(PREFIX + 'BROKEN{'), ['BROKEN{'])


if __name__ == '__main__':
    unittest.main()
