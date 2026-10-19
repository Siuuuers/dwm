"""Cloud-only pinned AccessKit iterator regression, not game qualification."""
import hashlib, json, os, pathlib, re, shutil, subprocess, sys, tarfile, urllib.request
ROOT = pathlib.Path(__file__).resolve().parent
OUT = pathlib.Path(sys.argv[1]).resolve()
OUT.mkdir(parents=True, exist_ok=True)
assert os.environ.get('GITHUB_ACTIONS') == 'true', 'Execution must occur in GitHub Actions'
assert sys.platform == 'win32', 'Use the cloud Windows runner'
CHECKSUM='53cf47daed85312e763fbf85ceca136e0d7abc68e0a7e12abe11f48172bc3b10'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def run(label,args,expected=0):
    with (OUT/(label+'.log')).open('w',encoding='utf-8') as stream:
        result=subprocess.run(args,stdout=stream,stderr=subprocess.STDOUT,timeout=600,env=env)
    record={'argv':args,'exit_code':result.returncode,'log_sha256':sha(OUT/(label+'.log'))}
    receipt[label]=record
    (OUT/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    if expected is not None: assert result.returncode==expected,(label,record)
    return (OUT/(label+'.log')).read_text(encoding='utf-8')
receipt={'diagnostic_only':True,'game_executed':False,'official_acceptance_established':False,'run_id':os.environ['GITHUB_RUN_ID'],'source_commit':os.environ['DWM_SOURCE_SHA']}
env=os.environ.copy();env.pop('CARGO_ENCODED_RUSTFLAGS',None);env.pop('RUSTFLAGS',None)
env['CARGO_TARGET_DIR']=str(OUT/'target')
env['CARGO_RESOLVER_INCOMPATIBLE_RUST_VERSIONS']='fallback'
try:
    archive=OUT/'accesskit_consumer-0.35.0.crate'
    urllib.request.urlretrieve('https://static.crates.io/crates/accesskit_consumer/accesskit_consumer-0.35.0.crate',archive)
    assert sha(archive)==CHECKSUM
    with tarfile.open(archive) as tf: tf.extractall(OUT/'vendor',filter='data')
    crate=OUT/'vendor/accesskit_consumer-0.35.0';source=crate/'src/iterators.rs'
    baseline=(ROOT/'iterators.baseline.rs').read_bytes()
    assert source.read_bytes()==baseline, 'Published crate/source mismatch'
    receipt['original_iterators_sha256']=sha(source)
    regression=(ROOT/'regression.rs').read_bytes()
    source.write_bytes(baseline+regression)
    shutil.copyfile(ROOT/'Cargo.seed.lock',crate/'Cargo.lock')
    run('rustup',['rustup','toolchain','install','1.85.0','--profile','minimal'])
    run('rustc',['rustup','run','1.85.0','rustc','-vV'])
    cargo=['rustup','run','1.85.0','cargo']
    run('metadata',cargo+['metadata','--manifest-path',str(crate/'Cargo.toml'),'--format-version','1'])
    import tomllib
    lock=tomllib.loads((crate/'Cargo.lock').read_text())
    common=[p for p in lock['package'] if p['name']=='accesskit']
    assert len(common)==1 and common[0]['version']=='0.24.0' and common[0]['checksum']=='5351dcebb14b579ccab05f288596b2ae097005be7ee50a7c3d4ca9d0d5a66f6a'
    shutil.copyfile(crate/'Cargo.lock',OUT/'Cargo.resolved.lock');locked=sha(crate/'Cargo.lock')
    args=cargo+['test','--locked','--manifest-path',str(crate/'Cargo.toml'),'--lib','iterators::','--','--test-threads=1']
    baseline_log=run('baseline',args,expected=101)
    failures=re.findall(r'^test (\S+) \.\.\. FAILED$',baseline_log,re.M)
    expected=['iterators::dwm_traversal_regression::'+name for name in ['forward_excluded_child_common','forward_excluded_child_explicit','reverse_excluded_child_common','reverse_excluded_child_explicit']]
    assert sorted(failures)==sorted(expected),failures
    assert '4 failed; 0 ignored;' in baseline_log
    receipt['baseline_expected_failures']=failures
    old=b'            if result == FilterResult::ExcludeNode {\n                consider_children = true;\n            }'
    new=b'            consider_children = result == FilterResult::ExcludeNode;'
    assert baseline.count(old)==2
    corrected=baseline.replace(old,new)
    source.write_bytes(corrected+regression)
    (OUT/'iterators.corrected.rs').write_bytes(corrected)
    receipt['corrected_iterators_sha256']=hashlib.sha256(corrected).hexdigest()
    candidate_log=run('candidate',args)
    assert '0 failed; 0 ignored;' in candidate_log
    assert sha(crate/'Cargo.lock')==locked
    receipt['baseline_summary']=re.findall(r'^test result:.*$',baseline_log,re.M)
    receipt['candidate_summary']=re.findall(r'^test result:.*$',candidate_log,re.M)
    receipt['regression_sha256']=hashlib.sha256(regression).hexdigest()
    receipt['ok']=True
finally:
    (OUT/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    shutil.copytree(ROOT,OUT/'source',dirs_exist_ok=True)
    hashes={str(p.relative_to(OUT)).replace('\\','/'):{'bytes':p.stat().st_size,'sha256':sha(p)} for p in OUT.rglob('*') if p.is_file() and 'target' not in p.relative_to(OUT).parts and 'vendor' not in p.relative_to(OUT).parts and p.name!='manifest.json'}
    (OUT/'manifest.json').write_text(json.dumps(hashes,indent=2)+'\n')
