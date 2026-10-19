"""Synthetic wire tests only; these are not Windows or Godot evidence."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import sys
sys.path.insert(0,str(Path(__file__).parent))
from read_trace import read_trace
from bind_consumer import bind, digest, PREFIX, PRE_BANNER_SOURCE, PRE_BANNER_BINDER_SHA256, PRE_BANNER_TREE


def ident(n): return {'tree_id':'Root','local_id':n}


def row(seq=1,epoch=1,cause='initial',status='present'):
    return dict(schema=1,event='consumer_commit',source='accesskit_windows-0.32.1-consumer-probe-v1',pid=4242,
        hwnd='0x800d5',adapter_id=1,epoch=epoch,seq=seq,unix_us=1792353602000000,capture_end_unix_us=1792353602010000,
        cause=cause,placeholder=False,binding_state=status,candidates=[ident(9007199254740993)],
        bound=ident(9007199254740993),discovery_overflow=False,path_truncated=False,label_truncated=False,
        host_focused=True,root=ident(7),nodes=[
            dict(identity=ident(9007199254740993),parent=ident(7),raw_label='TEST Seven-day ending.',role='Button',hidden=False,focused=False,filter='Include',geometry='Rect'),
            dict(identity=ident(7),parent=None,raw_label=None,role='Window',hidden=False,focused=True,filter='Include',geometry='Rect')])


def wire(rows): return ('\n'.join(json.dumps(r) for r in rows)+'\n').encode()


class ReaderTests(unittest.TestCase):
    def test_large_ids_prefix(self):
        result=read_trace(wire([row()]))
        self.assertTrue(result['prefix_valid'])
        self.assertFalse(result['stream_closed'])
        self.assertEqual(result['records'][0]['bound']['local_id'],9007199254740993)
    def test_absent_requires_prior_identity(self):
        r=row(2,cause='update',status='absent'); r['nodes']=[]
        self.assertTrue(read_trace(wire([row(),r]))['prefix_valid'])
        r['bound']=None
        self.assertFalse(read_trace(wire([row(),r]))['prefix_valid'])
    def test_unbound_is_not_absent(self):
        r=row(status='unbound'); r.update(candidates=[],bound=None,nodes=[])
        result=read_trace(wire([r]))
        self.assertTrue(result['prefix_valid'])
        self.assertEqual(result['records'][0]['observation_status'],'unbound')
    def test_ambiguity_sticky_but_new_epoch_resets(self):
        r=row(2,cause='update',status='ambiguous'); r.update(candidates=[ident(9007199254740993),ident(2)],bound=None,nodes=[])
        self.assertFalse(read_trace(wire([row(),r,row(3,cause='update')]))['prefix_valid'])
        self.assertTrue(read_trace(wire([row(),r,row(3,2,'placeholder_replacement')]))['prefix_valid'])
    def test_gaps_epoch_and_paths_rejected(self):
        for mutate in [lambda r:r.update(seq=3),lambda r:r.update(epoch=2),
            lambda r:r['nodes'][0].update(parent=ident(8)), lambda r:r['nodes'][1].update(identity=ident(9)),
            lambda r:r.update(pid=True)]:
            r=row();mutate(r)
            self.assertFalse(read_trace(wire([r]))['prefix_valid'])
    def test_loss_and_partial_json_rejected(self):
        footer=dict(schema=1,event='consumer_footer',pid=4242,adapter_id=1,seq=1,records=1,dropped_records=1,write_failed=False)
        self.assertFalse(read_trace(wire([row(),footer]))['prefix_valid'])
        self.assertFalse(read_trace(wire([row()])[:-1])['prefix_valid'])
        footer['dropped_records']=0
        self.assertTrue(read_trace(wire([row(),footer]))['stream_closed'])
    def test_truncation_not_absence_and_filters_retained(self):
        r=row();r['label_truncated']=True;r['nodes'][0]['filter']='ExcludeNode'
        result=read_trace(wire([r]))
        self.assertEqual(result['records'][0]['observation_status'],'incomplete')
        self.assertEqual(result['records'][0]['nodes'][0]['filter'],'ExcludeNode')


class BinderTests(unittest.TestCase):
    def setUp(self):
        location=Path(__file__).resolve().parents[1]/'tests/synthetic_fixture.py'
        spec=importlib.util.spec_from_file_location('synthetic_fixture',location)
        self.fixture=importlib.util.module_from_spec(spec);spec.loader.exec_module(self.fixture)
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.folder=Path(self.temp.name)
        data=self.fixture.fixture(Path(__file__).parent/'read_trace.py')
        self.fixture.write_fixture(self.folder,data)
        origin=data['documents']['audit-origin.json']
        for name in ['read_trace.py','bind_consumer.py']:
            path=PREFIX+'consumer_analysis/'+name
            content=(Path(__file__).parent/name).read_bytes()
            target=self.folder/'source'/path;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(content)
            origin['shared_source_pins'][path]={'sha256':digest(content)}
        content=b'SYNTHETIC SDK SOURCE ONLY'
        manifest=[]
        for probe_path in ['candidate/adapter.rs','candidate/consumer_probe.rs','candidate/query_probe.rs','candidate/node.rs','candidate/context.rs','baseline/node.rs','baseline/context.rs','baseline/adapter.rs','apply_probe.py']:
            path=PREFIX+'consumer-probe/'+probe_path
            target=self.folder/'source'/path;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(content)
            origin['shared_source_pins'][path]={'sha256':digest(content)}
            manifest.append({'path':probe_path,'sha256':digest(content)})
        self.write('audit-origin.json',origin)
        sdk=dict(schema_version=1,ok=True,source_commit='72460cd52d1b24492393cdf54a6f19d2fd63e258',
            crate_sha256='eff7009f1a532e917d66970a1e80c965140c6cfbbabbdde3d64e5431e6c78e21',
            original_lock_sha256='50a70648b398f0ee2331b37834a308e3b38d4ca7051310cb95b2ecfd04ebc2b8',
            target='x86_64-pc-windows-msvc',rust_toolchain='1.85.0',rustflags='-C target-feature=+crt-static',
            probe_kind="query_and_consumer",query_tests_exit_code=0,tests_exit_code=0,build_exit_code=0,probe_manifest=manifest,library={'sha256':'synthetic_library'})
        self.write('consumer-sdk/sdk-receipt.json',sdk)
        build=data['documents']['native-build/build-receipt.json']
        build.update(build_name='dwm_query_probe_v1',consumer_sdk_library_sha256=sdk['library']['sha256'],
            consumer_sdk_receipt_sha256=digest((self.folder/'consumer-sdk/sdk-receipt.json').read_bytes()))
        self.write('native-build/build-receipt.json',build)
        stdout=self.folder/'exported-load/game.stdout.log'
        stdout.write_text(stdout.read_text().replace('dwm_publication_probe_v1','dwm_query_probe_v1').replace(' - synthetic fixture',' - https://godotengine.org'))
        self.rows=[row()]
        self.rows[0].update(hwnd=hex(self.fixture.HWND),unix_us=self.fixture.BASE_US+2000000,capture_end_unix_us=self.fixture.BASE_US+2010000)
        self.trace()
    def write(self,name,value):
        p=self.folder/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(value))
    def trace(self):
        p=self.folder/'consumer-trace/trace-4242.jsonl';p.parent.mkdir(exist_ok=True);p.write_bytes(wire(self.rows))
    def test_failed_and_successful_original_outcomes_preserved(self):
        result=bind(self.folder)
        self.assertTrue(result['binding_ok'],result['errors'])
        self.assertFalse(result['native_outcomes']['load']['result']['ok'])
        load=result['native_outcomes']['load']['result'];load.update(ok=True,exit_code=0,clean_player_exit=True,forced_cleanup=False,failure=None)
        self.write('exported-load/result.json',load)
        self.write('load-process.json',{'exit_code':0,'diagnostic_native':True,'trace_enabled':True})
        result=bind(self.folder)
        self.assertTrue(result['binding_ok'],result['errors'])
        self.assertTrue(result['native_outcomes']['load']['result']['ok'])
        self.assertFalse(result['official_acceptance_established'])
    def test_exact_dated_banner_and_reject_noncanonical(self):
        target=self.folder/'exported-load/game.stdout.log'
        original=target.read_text()
        target.write_text(original.replace(' - https://godotengine.org', ' (2026-05-20 13:47:53 UTC) - https://godotengine.org',1))
        result=bind(self.folder)
        self.assertTrue(result['binding_ok'],result['errors'])
        for suffix in [' - unexpected source',' (2026-05-21 13:47:53 UTC) - https://godotengine.org',' - https://godotengine.org extra']:
            target.write_text(original.replace(' - https://godotengine.org',suffix,1))
            self.assertFalse(bind(self.folder)['binding_ok'])
    def test_explicit_known_pre_banner_correction_only(self):
        reference=(Path(__file__).parent/'pre_banner_binding_reference.py.txt').read_bytes()
        self.assertEqual(digest(reference),PRE_BANNER_BINDER_SHA256)
        relative=PREFIX+'consumer_analysis/bind_consumer.py'
        target=self.folder/'source'/relative
        target.write_bytes(reference)
        origin=json.loads((self.folder/'audit-origin.json').read_text())
        origin['tool_source']=PRE_BANNER_SOURCE
        origin['tool_tree']=PRE_BANNER_TREE
        origin['shared_source_pins'][relative]['sha256']=PRE_BANNER_BINDER_SHA256
        self.write('audit-origin.json',origin)
        self.assertFalse(bind(self.folder)['binding_ok'])
        result=bind(self.folder,allow_pre_banner_analysis=True)
        self.assertTrue(result['binding_ok'],result['errors'])
        identity=result['analysis_sources']['consumer_analysis/bind_consumer.py']
        self.assertFalse(identity['same_source'])
        self.assertTrue(identity['offline_pre_banner_correction'])
        self.assertNotEqual(identity['running_sha256'],identity['retained_sha256'])
        self.assertFalse(result['official_acceptance_established'])
        origin['tool_source']='0'*40;self.write('audit-origin.json',origin)
        self.assertFalse(bind(self.folder,allow_pre_banner_analysis=True)['binding_ok'])
        origin['tool_source']=PRE_BANNER_SOURCE
        altered=reference+b'\n# alteration\n';target.write_bytes(altered)
        origin['shared_source_pins'][relative]['sha256']=digest(altered)
        self.write('audit-origin.json',origin)
        self.assertFalse(bind(self.folder,allow_pre_banner_analysis=True)['binding_ok'])
    def test_late_snapshot_is_not_in_wait(self):
        self.rows[0]['capture_end_unix_us']=self.fixture.BASE_US+32000000;self.trace()
        self.assertFalse(bind(self.folder)['binding_ok'])
    def test_wrong_rid_and_namespace_rejected(self):
        for field in ['local_id','tree_id']:
            with self.subTest(field=field):
                original=copy.deepcopy(self.rows)
                for item in [self.rows[0]['bound'],self.rows[0]['candidates'][0],self.rows[0]['nodes'][0]['identity']]:
                    item[field]=123 if field=='local_id' else 'Graft'
                self.trace();self.assertFalse(bind(self.folder)['binding_ok'])
                self.rows=original
    def test_empty_incomplete_duplicate_manifest_rejected(self):
        original=json.loads((self.folder/'consumer-sdk/sdk-receipt.json').read_text())
        for manifest in [[],original['probe_manifest'][:-1],original['probe_manifest']+[original['probe_manifest'][0]]]:
            with self.subTest(manifest=manifest):
                sdk=copy.deepcopy(original);sdk['probe_manifest']=manifest
                self.write('consumer-sdk/sdk-receipt.json',sdk)
                build=json.loads((self.folder/'native-build/build-receipt.json').read_text())
                build['consumer_sdk_receipt_sha256']=digest((self.folder/'consumer-sdk/sdk-receipt.json').read_bytes())
                self.write('native-build/build-receipt.json',build)
                result=bind(self.folder)
                self.assertFalse(result['binding_ok'])
                self.assertIn('SDK probe manifest',result['errors'][0])
    def test_changed_sdk_and_source_pin_rejected(self):
        target=self.folder/'source'/(PREFIX+'consumer-probe/candidate/consumer_probe.rs')
        target.write_bytes(b'changed')
        self.assertFalse(bind(self.folder)['binding_ok'])
    def test_unbound_remains_valid_observation_not_absence(self):
        self.rows[0].update(binding_state='unbound',bound=None,candidates=[],nodes=[]);self.trace()
        result=bind(self.folder)
        self.assertTrue(result['binding_ok'],result['errors'])
        self.assertEqual(result['selected_observations'][0]['observation_status'],'unbound')


if __name__=='__main__': unittest.main()
