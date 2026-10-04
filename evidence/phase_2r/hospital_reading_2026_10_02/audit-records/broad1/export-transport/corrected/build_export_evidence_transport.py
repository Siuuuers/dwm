#!/usr/bin/env python3
"""Build a checkout-free, read-only GitHub artifact transport workflow.

The original ZIP is validated then split without extraction or recompression.
Local self-test exercises the same embedded Python against synthetic ZIP bytes.
"""
from __future__ import annotations

import argparse
import ast
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import tempfile
import zipfile

import yaml


ROOT = Path(__file__).resolve().parent.parent
BRANCH = 'codex/hospital-export-evidence-20261003'
WORKFLOW_PATH = '.github/workflows/hospital-export-evidence.yml'
PUBLICATION_PARENT = '0a22f556120178dddc7b28df1a8abfc8b011bc12'
EXPECTED = {
    'repository': 'Siuuuers/dwm',
    'artifact_id': 11244640103,
    'size_in_bytes': 98850774,
    'sha256': 'e2739823bc11ab4a336072c1a437af8711f54c3dee248a6e388b42c6947d8cc9',
    'run_id': 37044894986,
    'workflow_head': '1bc4f6afd759e969f82b9c2134eb178479c19d13',
}
CHUNK_BYTES = 25 * 1024 * 1024

SPLITTER = r'''import hashlib
import json
import os
from pathlib import Path
import zipfile


def require(condition, detail):
    if not condition:
        raise ValueError(detail)


def strict_json(text):
    def pairs(values):
        result = {}
        for key, value in values:
            require(key not in result, 'DUPLICATE_JSON_KEY')
            result[key] = value
        return result
    return json.loads(text, object_pairs_hook=pairs)


def sha256(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def verify_split(archive, metadata, destination, expected, chunk_bytes, transport):
    require(metadata.get('id') == expected['artifact_id'], 'SOURCE_ARTIFACT_ID_MISMATCH')
    require(metadata.get('expired') is False, 'SOURCE_ARTIFACT_EXPIRED')
    require(metadata.get('size_in_bytes') == expected['size_in_bytes'], 'SOURCE_API_SIZE_MISMATCH')
    require(metadata.get('digest') == 'sha256:' + expected['sha256'], 'SOURCE_API_DIGEST_MISMATCH')
    source_run = metadata.get('workflow_run', {})
    require(source_run.get('id') == expected['run_id'], 'SOURCE_RUN_MISMATCH')
    require(source_run.get('head_sha') == expected['workflow_head'], 'SOURCE_WORKFLOW_HEAD_MISMATCH')
    require(isinstance(metadata.get('name'), str) and bool(metadata['name']), 'SOURCE_ARTIFACT_NAME_REQUIRED')
    require(archive.is_file() and not archive.is_symlink(), 'ORIGINAL_ZIP_REQUIRED')
    require(archive.stat().st_size == expected['size_in_bytes'], 'ORIGINAL_ZIP_SIZE_MISMATCH')
    require(sha256(archive) == expected['sha256'], 'ORIGINAL_ZIP_SHA256_MISMATCH')
    require(type(chunk_bytes) is int and 0 < chunk_bytes <= 25 * 1024 * 1024, 'BOUNDED_CHUNK_SIZE_REQUIRED')
    with zipfile.ZipFile(archive) as opened:
        require(bool(opened.infolist()), 'EMPTY_ORIGINAL_ZIP')
        require(opened.testzip() is None, 'ORIGINAL_ZIP_CRC_MISMATCH')
        member_count = len(opened.infolist())
    # No chunk exists until metadata, original bytes and every member CRC pass.
    require(not destination.exists(), 'REFUSE_EXISTING_TRANSPORT_OUTPUT')
    destination.mkdir(parents=True)
    chunks = []
    with archive.open('rb') as stream:
        offset = 0
        for index in range(1, (expected['size_in_bytes'] + chunk_bytes - 1) // chunk_bytes + 1):
            data = stream.read(chunk_bytes)
            require(bool(data), 'UNEXPECTED_SHORT_ARCHIVE')
            name = f'original.zip.part{index:03d}'
            path = destination / name
            with path.open('xb') as output:
                output.write(data)
            chunks.append({'index': index, 'file': name, 'offset': offset,
                           'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
            offset += len(data)
        require(stream.read(1) == b'' and offset == expected['size_in_bytes'], 'SPLIT_BYTE_COUNT_MISMATCH')
    # Independently stream all written chunk files in order; never replace/repack ZIP.
    combined = hashlib.sha256()
    combined_bytes = 0
    for chunk in chunks:
        path = destination / chunk['file']
        require(path.stat().st_size == chunk['bytes'] and sha256(path) == chunk['sha256'], 'WRITTEN_CHUNK_MISMATCH')
        with path.open('rb') as stream:
            while data := stream.read(1024 * 1024):
                combined.update(data)
                combined_bytes += len(data)
    require(combined_bytes == expected['size_in_bytes'] and combined.hexdigest() == expected['sha256'],
            'REASSEMBLED_ORIGINAL_IDENTITY_MISMATCH')
    manifest = {
        'schema_version': 1,
        'purpose': 'Exact original GitHub artifact ZIP transport; no engine execution or evidence reinterpretation.',
        'source_artifact': {
            'repository': expected['repository'], 'id': metadata['id'], 'name': metadata['name'],
            'size_in_bytes': metadata['size_in_bytes'], 'digest': metadata['digest'],
            'run_id': source_run['id'], 'workflow_head': source_run['head_sha'],
        },
        'original_zip': {'bytes': expected['size_in_bytes'], 'sha256': expected['sha256'],
                         'crc_verified': True, 'member_count': member_count},
        'chunk_size_limit': chunk_bytes, 'chunk_count': len(chunks), 'chunks': chunks,
        'ordered_chunk_reassembly_matches_original': True,
        'transport_execution': transport,
        'reassembly': 'Concatenate raw chunk contents in ascending index, verify each chunk and final original size/SHA256, then verify original ZIP CRC before normal extraction/audit.',
        'limits': ['Transport success is not original workflow or exported-build acceptance.',
                   'Uploaded chunk artifacts are wrappers; use their extracted raw part files for original ZIP reconstruction.'],
    }
    manifest_path = destination / 'transport-manifest.json'
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    require(strict_json(manifest_path.read_text(encoding='utf-8')) == manifest, 'MANIFEST_JSON_ROUNDTRIP_MISMATCH')
    return manifest


if __name__ == '__main__':
    expected = EXPECTED_PLACEHOLDER
    root = Path(os.environ['DWM_EXPORT_TRANSPORT_ROOT'])
    metadata = strict_json((root / 'source-metadata.json').read_text(encoding='utf-8'))
    transport = {key: os.environ.get(key, '') for key in
                 ('GITHUB_REPOSITORY', 'GITHUB_RUN_ID', 'GITHUB_RUN_ATTEMPT', 'GITHUB_SHA', 'GITHUB_JOB')}
    manifest = verify_split(root / 'original.zip', metadata, root / 'parts', expected, CHUNK_PLACEHOLDER, transport)
    require(manifest['chunk_count'] == 4, 'EXPECTED_EXACTLY_FOUR_CHUNKS')
    print(json.dumps({'original_sha256': manifest['original_zip']['sha256'],
                      'original_bytes': manifest['original_zip']['bytes'],
                      'chunk_count': manifest['chunk_count'], 'crc_verified': True,
                      'reassembly_verified': True}))
'''.replace('EXPECTED_PLACEHOLDER', repr(EXPECTED)).replace('CHUNK_PLACEHOLDER', str(CHUNK_BYTES))


def identity(raw: bytes) -> dict:
    return {'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}


def build() -> bytes:
    steps = [
        {'name': 'Download original artifact ZIP with read-only workflow token',
         'env': {'GH_TOKEN': '${{ github.token }}'},
         'run': "set -euo pipefail\nexport DWM_EXPORT_TRANSPORT_ROOT=\"$RUNNER_TEMP/hospital-export-evidence\"\nmkdir -p \"$DWM_EXPORT_TRANSPORT_ROOT\"\n"
                "gh api repos/Siuuuers/dwm/actions/artifacts/11244640103 --jq '{id,name,size_in_bytes,digest,expired,workflow_run:{id:.workflow_run.id,head_sha:.workflow_run.head_sha}}' > \"$DWM_EXPORT_TRANSPORT_ROOT/source-metadata.json\"\n"
                "gh api repos/Siuuuers/dwm/actions/artifacts/11244640103/zip > \"$DWM_EXPORT_TRANSPORT_ROOT/original.zip\"\n"},
        {'name': 'Verify original identity and CRC, split raw bytes, and verify reassembly',
         'run': "set -euo pipefail\nexport DWM_EXPORT_TRANSPORT_ROOT=\"$RUNNER_TEMP/hospital-export-evidence\"\npython3 - <<'PY'\n" + SPLITTER + 'PY\n'},
    ]
    for index in range(1, 5):
        steps.append({'name': f'Upload original ZIP raw chunk {index:03d}', 'uses': 'actions/upload-artifact@v4',
                      'with': {'name': f'hospital-export-original-part{index:03d}-${{{{ github.run_id }}}}-${{{{ github.run_attempt }}}}',
                               'path': '${{ runner.temp }}/hospital-export-evidence/parts/' + f'original.zip.part{index:03d}',
                               'compression-level': 0, 'if-no-files-found': 'error', 'retention-days': 7}})
    steps.append({'name': 'Upload verified original and chunk identity manifest', 'uses': 'actions/upload-artifact@v4',
                  'with': {'name': 'hospital-export-transport-manifest-${{ github.run_id }}-${{ github.run_attempt }}',
                           'path': '${{ runner.temp }}/hospital-export-evidence/parts/transport-manifest.json',
                           'compression-level': 0, 'if-no-files-found': 'error', 'retention-days': 7}})
    workflow = {'name': 'Hospital original export artifact transport', 'on': {'push': {'branches': [BRANCH]}},
                'permissions': {'contents': 'read', 'actions': 'read'},
                'concurrency': {'group': 'hospital-export-evidence-${{ github.ref }}', 'cancel-in-progress': False},
                'jobs': {'transport-original-export': {
                    'name': 'Transport verified original Windows export evidence', 'runs-on': 'ubuntu-24.04',
                    'timeout-minutes': 15, 'defaults': {'run': {'shell': 'bash'}},
                    'steps': steps}}}
    raw = yaml.safe_dump(workflow, sort_keys=False, width=120).encode()
    assert yaml.safe_load(raw) == workflow
    assert not any(step.get('uses', '').startswith('actions/checkout') for step in steps)
    assert len([step for step in steps if step.get('uses') == 'actions/upload-artifact@v4']) == 5
    # runner context is allowed in step inputs, not jobs.<job_id>.env.
    assert 'env' not in workflow['jobs']['transport-original-export']
    assert all('export DWM_EXPORT_TRANSPORT_ROOT="$RUNNER_TEMP/hospital-export-evidence"' in step['run']
               for step in steps if 'run' in step)
    ast.parse(SPLITTER)
    return raw


def self_test() -> dict:
    namespace = {'__name__': 'transport_selftest'}
    exec(compile(SPLITTER, '<embedded-splitter>', 'exec'), namespace)
    verify_split = namespace['verify_split']
    with tempfile.TemporaryDirectory(prefix='hospital-export-transport-') as temporary:
        root = Path(temporary)
        archive = root / 'synthetic.zip'
        with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_STORED) as output:
            timestamp = (2000, 1, 1, 0, 0, 0)
            output.writestr(zipfile.ZipInfo('raw-data.bin', timestamp), bytes(range(256)) * 40)
            output.writestr(zipfile.ZipInfo('nested/receipt.json', timestamp), '{"ok":true}\n')
        raw = archive.read_bytes()
        expected = dict(EXPECTED, size_in_bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest())
        metadata = {'id': expected['artifact_id'], 'name': 'synthetic-original', 'expired': False,
                    'size_in_bytes': len(raw), 'digest': 'sha256:' + expected['sha256'],
                    'workflow_run': {'id': expected['run_id'], 'head_sha': expected['workflow_head']}}
        manifest = verify_split(archive, metadata, root / 'valid-parts', expected, 3072, {})
        assert manifest['chunk_count'] == 4
        assert json.loads((root / 'valid-parts/transport-manifest.json').read_text()) == manifest
        reconstructed = b''.join((root / 'valid-parts' / item['file']).read_bytes() for item in manifest['chunks'])
        assert reconstructed == raw and archive.read_bytes() == raw
        # Deliberate mismatches must refuse before emitting any chunks.
        negative_checks = []
        for name, changed in [('id', dict(metadata, id=0)), ('size', dict(metadata, size_in_bytes=1)),
                              ('digest', dict(metadata, digest='sha256:' + '0' * 64)),
                              ('expired', dict(metadata, expired=True)),
                              ('source_run', dict(metadata, workflow_run={'id': 0, 'head_sha': expected['workflow_head']}))]:
            destination = root / ('reject-' + name)
            try:
                verify_split(archive, changed, destination, expected, 3072, {})
            except ValueError:
                assert not destination.exists()
                negative_checks.append(name)
            else:
                raise AssertionError('Did not reject ' + name)
        corrupted = root / 'corrupted.zip'
        bad = bytearray(raw)
        bad[60] ^= 1  # Stored payload byte: central directory remains readable, CRC fails.
        corrupted.write_bytes(bad)
        crc_expected = dict(expected, sha256=hashlib.sha256(bad).hexdigest())
        crc_metadata = dict(metadata, digest='sha256:' + crc_expected['sha256'])
        try:
            verify_split(corrupted, crc_metadata, root / 'reject-crc', crc_expected, 3072, {})
        except (ValueError, zipfile.BadZipFile):
            assert not (root / 'reject-crc').exists()
            negative_checks.append('member_crc_despite_matching_outer_digest')
        else:
            raise AssertionError('Did not reject CRC failure')
        # Original digest refusal is distinct from matching metadata with bad CRC.
        try:
            verify_split(corrupted, metadata, root / 'reject-bytes', expected, 3072, {})
        except ValueError:
            assert not (root / 'reject-bytes').exists()
            negative_checks.append('downloaded_original_sha256')
        else:
            raise AssertionError('Did not reject changed original bytes')
        return {'passed': True, 'synthetic_zip': identity(raw), 'member_count': 2,
                'chunk_count': 4, 'ordered_reassembly_byte_identical': True,
                'original_untouched': True, 'saved_manifest_json_roundtrip': True,
                'refusals_before_chunk_creation': negative_checks}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'hospital-export-transport.yml')
    args = parser.parse_args()
    raw = build()
    tests = self_test()
    review = {'schema_version': 1, 'scope': 'Static workflow and synthetic split/reassembly validation only.',
              'workflow_repository_path': WORKFLOW_PATH, 'branch': BRANCH,
              'expected_publication_parent': PUBLICATION_PARENT, 'expected_source_artifact': EXPECTED,
              'prior_invalid_workflow_run': 37046971060,
              'permissions': {'contents': 'read', 'actions': 'read'}, 'checkout_required': False,
              'github_context_placement': 'No job-level runner context; shell steps export RUNNER_TEMP-derived path. runner.temp appears only in upload step inputs.',
              'engine_execution': False, 'original_zip_preserved': True,
              'chunk_bytes': CHUNK_BYTES, 'expected_chunk_lengths': [CHUNK_BYTES] * 3 + [20207574],
              'upload_count': 5, 'upload_compression_level': 0,
              'secret_handling': 'GH_TOKEN exists only in read-only download step environment; no tokens or signed URLs included in manifest or logs by script.',
              'workflow': identity(raw), 'embedded_splitter': identity(SPLITTER.encode()),
              'helper': {'path': str(Path(__file__).resolve()), **identity(Path(__file__).read_bytes())},
              'static_and_synthetic_checks': tests,
              'pending': ['Root review/publication.', 'Actual cloud download, identity/CRC and split validation.',
                          'Download five small transport artifacts, verify wrapper ZIPs, reassemble raw parts, verify exact original identity/CRC, then normal export evidence audit.']}
    report_path = args.output.with_name(args.output.name + '.static-review.json')
    outputs = ((args.output, raw), (report_path, (json.dumps(review, indent=2) + '\n').encode()))
    for path, data in outputs:
        if path.exists() and path.read_bytes() != data:
            raise ValueError('Refuse differing retained output: ' + str(path))
    for path, data in outputs:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    print(json.dumps({'workflow': str(args.output), 'static_review': str(report_path),
                      'workflow_identity': identity(raw), 'helper_identity': review['helper'],
                      'synthetic_checks_passed': True}))


if __name__ == '__main__':
    main()
