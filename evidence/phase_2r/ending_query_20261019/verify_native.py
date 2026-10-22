"""Verify retained native query evidence without executing Godot or PowerShell."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parent
EXPECTED = {
    'native-evidence.zip': '58cb672232da472155de0322ffa024d42f0fd2ee30b6c64e51e2a79b45de32a9',
    'native-sdk.zip': '4eab47f65ddd12f0fba7f41ceef9478c9fc7c376a8064d86d27c2d0d6ad57690',
}

def digest(data):
    return hashlib.sha256(data).hexdigest()

with tempfile.TemporaryDirectory() as temp:
    root = Path(temp)
    archives = {}
    for name, expected in EXPECTED.items():
        data = (ROOT / name).read_bytes()
        assert digest(data) == expected, name
        z = zipfile.ZipFile(ROOT / name)
        names = z.namelist()
        assert len(set(names)) == len(names)
        assert all(not n.startswith('/') and '..' not in n.split('/') for n in names)
        assert z.testzip() is None
        archives[name] = z
    evidence = archives['native-evidence.zip']
    evidence.extractall(root)
    manifest = json.loads((root / 'retained-hashes.json').read_text())
    for name, expected in manifest.items():
        relative = name.removeprefix('ci/')
        if relative in evidence.namelist():
            data = evidence.read(relative)
        else:
            sdk = archives['native-sdk.zip']
            matches = [n for n in sdk.namelist() if n.endswith('lib/windows/x86_64/msvc/static/accesskit.lib')]
            assert relative == 'consumer-sdk/lib/windows/x86_64/msvc/static/accesskit.lib' and len(matches) == 1
            data = sdk.read(matches[0])
            target = root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        assert len(data) == expected['bytes'] and digest(data) == expected['sha256'], name
    origin = json.loads((root / 'audit-origin.json').read_text())
    for name, expected in origin['shared_source_pins'].items():
        data = (root / 'source' / name).read_bytes()
        assert len(data) == expected['bytes'] and digest(data) == expected['sha256'], name
        blob = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
        assert blob == expected['git_blob'], name
    sys.path.insert(0, str(root / 'source/tools/diagnostics/ending-publication-20261019/query_analysis'))
    from bind_query import bind
    replay = bind(root)
    original = json.loads((root / 'query-binding.json').read_text())
    
    replay = json.loads(json.dumps(replay))
    assert replay == original
    assert replay['binding_ok'] and not replay['official_acceptance_established']
    observations = replay['selected_observations']
    result = {
        'manifest_payloads_verified': len(manifest),
        'retained_source_hash_and_git_blob_pins_verified': len(origin['shared_source_pins']),
        'binder_replay_equal': True,
        'navigate_observations': len(observations),
        'navigate_selected_node': sum(x['selected'] is not None for x in observations),
        'caption_selected': sum(x['caption_selected'] for x in observations),
        'consumer_snapshots': len(replay['consumer_binding']['selected_observations']),
        'harness_batches': len(replay['harness_observations']),
        'official_acceptance_established': False,
    }
    print(json.dumps(result, indent=2))
