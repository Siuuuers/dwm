"""Fail-closed install into the exact published Windows crate; no dependency edits."""
import argparse, hashlib, pathlib, shutil, json
p=argparse.ArgumentParser(); p.add_argument('--crate-root',type=pathlib.Path,required=True)
a=p.parse_args(); here=pathlib.Path(__file__).resolve().parent
expected='7135ef9045b907f33e675888940b90f2d967fd6a26b1484d69773f2154247187'
for f in [a.crate_root/'src/adapter.rs',here/'baseline/adapter.rs']:
    if hashlib.sha256(f.read_bytes()).hexdigest()!=expected: raise SystemExit(f'baseline hash mismatch: {f}')
manifest=(a.crate_root/'Cargo.toml').read_text()
import tomllib
package=tomllib.loads(manifest)['package']
if (package['name'],package['version'])!=('accesskit_windows','0.32.1'): raise SystemExit('wrong crate')
for name in ['adapter.rs','consumer_probe.rs']:
    shutil.copyfile(here/'candidate'/name,a.crate_root/'src'/name)
print(json.dumps({'schema':1,'baseline_sha256':expected,'installed':{n:hashlib.sha256((a.crate_root/'src'/n).read_bytes()).hexdigest() for n in ['adapter.rs','consumer_probe.rs']}}))
