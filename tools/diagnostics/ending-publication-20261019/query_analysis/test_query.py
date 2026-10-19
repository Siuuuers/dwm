import copy
import json
import unittest
from read_query import read_query, SOURCE
from bind_query import validate_batch

def ident(n): return dict(local_id=n,tree_id='TreeId(0)')
def record():
    return dict(schema=1,source=SOURCE,event='navigate',pid=17,hwnd='0xabc',adapter_id=1,epoch=1,
        request_id=3,emission_seq=1,thread_id='ThreadId(1)',unix_us=100,capture_end_unix_us=101,
        epoch_started_us=50,armed_us=70,direction=3,source_node=ident(1),root=ident(1),placeholder=False,
        candidates=[dict(identity=ident(2),predicate='filter',filter='Include',role='Button',hidden=False,
            focused=False,raw_label='TEST Seven-day ending. ',label_truncated=False)],
        selected=ident(2),outcome_hresult=0,outcome_ok=True,candidate_count=1,omitted_candidates=0,truncated=False)
def encoded(*rows): return b''.join((json.dumps(r)+'\n').encode() for r in rows)
def batch(rows):
    return dict(schema=1,source='ending-actions-v1',query_ordinal=0,descendants=len(rows),evaluated_count=len(rows),
        observed_count=len(rows),omitted_count=0,complete=True,record_cap_reached=False,byte_cap_reached=False,observer_failed=False,
        record_bytes=100*len(rows),byte_accounting='pretty-json-records-plus-34-bytes-per-line-and-2-per-record;4096-envelope-reserve',
        limits=dict(records=4096,name_utf8_bytes=1024,batch_bytes=1048576),records=rows)
def action(**kw):
    row=dict(ordinal=0,visible=True,enabled=True,name='TEST Seven-day ending.',name_truncated=False,invoke=True,accepted=True)
    row.update(kw);return row

class QueryTests(unittest.TestCase):
    def test_prefix_is_never_absence(self):
        out=read_query(encoded(record()))
        self.assertTrue(out['prefix_valid']);self.assertFalse(out['stream_closed']);self.assertFalse(out['absence_established'])
    def test_completion_order_not_request_order(self):
        a=record();b=record();b.update(request_id=1,emission_seq=2)
        self.assertTrue(read_query(encoded(a,b))['prefix_valid'])
    def test_footer_loss_stays_explicit(self):
        footer=dict(schema=1,source=SOURCE,event='query_footer',pid=17,adapter_id=1,records=1,dropped_records=5,write_failed=True,pre_arm_coverage=False,pre_resolution_coverage=False)
        out=read_query(encoded(record(),footer));self.assertTrue(out['prefix_valid']);self.assertEqual(out['footer']['dropped_records'],5)
        self.assertFalse(out['absence_established'])
        footer['records']=2
        self.assertTrue(read_query(encoded(record(),footer))['prefix_valid'])
        footer['write_failed']=False
        self.assertFalse(read_query(encoded(record(),footer))['prefix_valid'])
    def test_duplicate_gap_mixed_generation_rejected(self):
        for change in [dict(emission_seq=3),dict(request_id=3),dict(pid=18),dict(root=ident(8)),dict(armed_us=80)]:
            b=record();b.update(emission_seq=2,request_id=4);b.update(change)
            with self.subTest(change=change):self.assertFalse(read_query(encoded(record(),b))['prefix_valid'])
    def test_invalid_caps_labels_and_outcome(self):
        changes=[dict(candidate_count=2),dict(omitted_candidates=1,candidate_count=2),dict(outcome_hresult=-1),dict(armed_us=110)]
        for change in changes:
            row=record();row.update(change)
            self.assertFalse(read_query(encoded(row))['prefix_valid'])
        row=record();row['candidates'][0]['raw_label']='界'*342
        self.assertFalse(read_query(encoded(row))['prefix_valid'])
    def test_truncation_preserves_positive_facts_only(self):
        row=record();row.update(candidate_count=2,omitted_candidates=1,truncated=True)
        self.assertTrue(read_query(encoded(row))['prefix_valid'])
        self.assertFalse(read_query(encoded(row))['absence_established'])
    def test_empty_error_zero_hresult_is_not_success(self):
        row=record();row.update(selected=None,outcome_hresult=0,outcome_ok=False)
        self.assertTrue(read_query(encoded(row))['prefix_valid'])
        row['outcome_ok']=True
        self.assertFalse(read_query(encoded(row))['prefix_valid'])
    def test_serialization_cap_accounting_uses_emitted_candidates(self):
        row=record();row.update(candidate_count=256,omitted_candidates=255,truncated=True)
        self.assertTrue(read_query(encoded(row))['prefix_valid'])
    def test_partial_record_rejected(self):
        self.assertFalse(read_query(encoded(record())[:-1])['prefix_valid'])
    def test_harness_all_short_circuits(self):
        rows=[action(visible=False,enabled=None,name=None,invoke=None,accepted=False),
              action(enabled=False,name=None,invoke=None,accepted=False),
              action(name='another',invoke=None,accepted=False),action(invoke=False,accepted=False),action()]
        for i,row in enumerate(rows):row['ordinal']=i
        self.assertEqual(validate_batch(batch(rows),1)['descendants'],5)
    def test_harness_hidden_read_and_match_lies_rejected(self):
        for row,matches in [(action(visible=False),1),(action(),0),(action(name='wrong'),1)]:
            with self.assertRaises(ValueError):validate_batch(batch([row]),matches)
    def test_harness_omission_not_absence(self):
        b=batch([]);b.update(descendants=10,evaluated_count=10,omitted_count=10,complete=False,byte_cap_reached=True)
        self.assertFalse(validate_batch(b,1)['complete'])
    def test_harness_truncated_name_not_exact_match(self):
        b=batch([action(name='x'*1024,name_truncated=True,invoke=None,accepted=False)])
        self.assertTrue(validate_batch(b,0)['complete'])
    def test_harness_limits_and_ordinals(self):
        for change in [dict(ordinal=1),dict(name='界'*342),dict(enabled=None)]:
            with self.assertRaises(ValueError):validate_batch(batch([action(**change)]),1)


class BindingTests(unittest.TestCase):
    def setUp(self):
        from test_consumer import BinderTests
        from bind_query import BASE
        from pathlib import Path
        import bind_consumer
        self.helper=BinderTests();self.helper.setUp();self.addCleanup(self.helper.doCleanups)
        self.folder=self.helper.folder
        origin=json.loads((self.folder/'audit-origin.json').read_text())
        paths=[(bind_consumer.PREFIX+'query_analysis/'+name,Path(__file__).parent/name) for name in ['read_query.py','bind_query.py']]
        paths.append(('tools/testing/Invoke-ExportedGameplay.ps1',BASE.parents[2]/'tools/testing/Invoke-ExportedGameplay.ps1'))
        for name,source in paths:
            content=source.read_bytes();target=self.folder/'source'/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(content)
            origin['shared_source_pins'][name]={'sha256':bind_consumer.digest(content)}
        self.helper.write('audit-origin.json',origin)
        load=json.loads((self.folder/'exported-load/result.json').read_text());load['ending_actions_trace']=True
        self.helper.write('exported-load/result.json',load)
        existing=self.helper.rows[0]
        self.row=record();self.row.update(pid=existing['pid'],hwnd=existing['hwnd'],root=existing['root'],source_node=existing['root'],
            selected=existing['bound'],unix_us=existing['unix_us'],capture_end_unix_us=existing['capture_end_unix_us'])
        self.row['candidates'][0]['identity']=existing['bound']
        self.path=self.folder/'query-trace/query-4242.adapter-1.jsonl';self.path.parent.mkdir();self.path.write_bytes(encoded(self.row))
    def test_bound_positive_and_native_failure_preserved(self):
        from bind_query import bind
        result=bind(self.folder)
        self.assertTrue(result['binding_ok'],result['errors'])
        self.assertTrue(result['selected_observations'][0]['caption_selected'])
        self.assertFalse(result['consumer_binding']['native_outcomes']['load']['result']['ok'])
        self.assertFalse(result['official_acceptance_established'])
    def test_changed_process_generation_and_source_rejected(self):
        from bind_query import bind
        for change in [dict(pid=2),dict(hwnd='0xf'),dict(adapter_id=2),dict(epoch=2),dict(root=ident(88))]:
            row=copy.deepcopy(self.row);row.update(change);self.path.write_bytes(encoded(row))
            with self.subTest(change=change):self.assertFalse(bind(self.folder)['binding_ok'])
        self.path.write_bytes(encoded(self.row))
        p=self.folder/'source/tools/testing/Invoke-ExportedGameplay.ps1';p.write_bytes(p.read_bytes()+b'changed')
        self.assertFalse(bind(self.folder)['binding_ok'])
    def test_missing_query_trace_is_coverage_gap(self):
        from bind_query import bind
        self.path.unlink();result=bind(self.folder)
        self.assertTrue(result['binding_ok'],result['errors']);self.assertEqual(result['trace_files_present'],0)
        self.assertEqual(result['selected_observations'],[])

if __name__=='__main__': unittest.main()
