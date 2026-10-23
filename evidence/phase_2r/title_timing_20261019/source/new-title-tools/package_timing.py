#!/usr/bin/env python3
"""Prepare and finish a diagnostic PCK replacement; never execute an engine.

Evidence archive custody is established by the caller before invoking this tool.
The inner package is independently checked against that retained evidence.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import stat
import zipfile

GAME_COMMIT = '81847d8b1560340a3a7769223cee0b46c6bdc0f9'
CORRECTED_ITERATOR = '7d2f876b4744af77b576ea35726ebb5c3943bf8f01b61595e61a9ad8dd1f4fa5'
ARCHIVE_NAME = 'DWM-windows-x86_64-diagnostic.zip'


def require(value, message):
    if not value:
        raise ValueError(message)


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def write(path, value):
    Path(path).write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def identity(path):
    return {'bytes': Path(path).stat().st_size, 'sha256': digest(path)}


def matches(path, entry):
    return Path(path).is_file() and identity(path) == {k: entry[k] for k in ('bytes', 'sha256')}


def safe_name(name):
    parts = PurePosixPath(name).parts
    require(name and not name.startswith('/') and '\\' not in name and ':' not in name
            and all(p not in ('', '.', '..') and not p.endswith((' ', '.')) for p in name.split('/'))
            and all(p.split('.')[0].upper() not in {'CON', 'PRN', 'AUX', 'NUL', *['COM'+str(i) for i in range(1,10)], *['LPT'+str(i) for i in range(1,10)]} for p in parts),
            'Unsafe package path: ' + name)
    return name


def census(root):
    require(not any(p.is_symlink() for p in root.rglob('*')), 'Package contains symlink')
    return {p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file()}


def check_manifest(root, files, extra=()):
    names = [safe_name(e['path']) for e in files]
    require(len(names) == len(set(n.casefold() for n in names)), 'Duplicate manifest path')
    require(census(root) == set(names) | set(extra), 'Package file census mismatch')
    for entry in files:
        require(matches(root / entry['path'], entry), 'Package bytes mismatch: ' + entry['path'])


def manifest(root):
    return [dict(path=name, **identity(root / name)) for name in sorted(census(root))]


def extract(archive, root):
    with zipfile.ZipFile(archive) as source:
        seen = set()
        for entry in source.infolist():
            raw_name = entry.orig_filename
            name = safe_name(raw_name.rstrip('/') if raw_name.endswith('/') else raw_name)
            require(raw_name == entry.filename, 'Archive member name normalized')
            require(name.casefold() not in seen, 'Duplicate archive member')
            seen.add(name.casefold())
            mode = entry.external_attr >> 16
            require(not stat.S_ISLNK(mode), 'Archive symlink forbidden')
            require(not entry.flag_bits & 1, 'Encrypted archive member')
        source.extractall(root)


def prepare(args):
    out = args.output
    require(not out.exists(), 'Output must be fresh')
    require(args.original.name == ARCHIVE_NAME, 'Unexpected inner archive name')
    retained_path = args.evidence / 'native-diagnostic/validation.json'
    retained = read(retained_path)
    require(retained.get('ok') is True and retained.get('diagnostic') is True
            and retained.get('commit') == GAME_COMMIT, 'Retained diagnostic validation mismatch')
    require(retained['archive']['file'] == ARCHIVE_NAME and matches(args.original, retained['archive']),
            'Retained inner archive digest/size mismatch')
    build_path = args.evidence / 'native-build/build-receipt.json'
    build = read(build_path)
    require(build.get('ok') is True and build.get('target') == 'template_release'
            and build.get('architecture') == 'x86_64', 'Invalid native build receipt')
    sdk_path = args.evidence / 'native-build/consumer-sdk-receipt.json'
    sdk = read(sdk_path)
    require(build.get('source_commit') == '35e80b3a8822a9df9be390814b62f44c0a9c69e8'
            and build.get('build_name') == 'dwm_query_probe_v1'
            and build.get('iterator_variant') == sdk.get('iterator_variant') == 'Corrected'
            and build.get('iterator_sha256') == sdk.get('iterator_sha256') == CORRECTED_ITERATOR
            and build.get('consumer_sdk_receipt_sha256') == digest(sdk_path)
            and build.get('consumer_sdk_library_sha256') == sdk['library']['sha256']
            and sdk.get('ok') is True and sdk.get('tests_exit_code') == 0
            and sdk.get('build_exit_code') == 0 and sdk.get('query_tests_exit_code') == 0
            and sdk.get('probe_kind') == 'query_and_consumer', 'Corrected consumer SDK linkage mismatch')
    source_manifest = read(args.source_manifest)
    require(source_manifest.get('base_commit') == GAME_COMMIT and source_manifest.get('diagnostic') is True
            and source_manifest.get('files'), 'Source patch manifest missing pinned diagnostic changes')
    for entry in source_manifest['files']:
        safe_name(entry['path'])
        require(all((k == 'before_sha256' and entry.get(k) is None) or (isinstance(entry.get(k), str) and len(entry[k]) == 64
                    and all(c in '0123456789abcdef' for c in entry[k]))
                    for k in ('before_sha256', 'after_sha256')), 'Invalid source patch hashes')
    require(matches(args.pck, source_manifest['fresh_pck']), 'Fresh PCK differs from source manifest')
    out.mkdir(parents=True)
    package = out / 'package'
    package.mkdir()
    extract(args.original, package)
    original = read(package / 'validation.json')
    require({k:v for k,v in retained.items() if k != 'archive'} == original,
            'Inner validation differs from retained validation')
    check_manifest(package, original['files'], ['validation.json'])
    origin = read(package / 'diagnostic-origin.json')
    require(origin.get('game_commit') == GAME_COMMIT and origin.get('native_build') == build
            and origin.get('native_build_receipt_sha256') == digest(build_path), 'Native build custody mismatch')
    require(matches(package / 'DWM.exe', build['template']), 'Retained EXE differs from build receipt')
    allowed = {'DWM.exe', 'DWM.pck', 'diagnostic-origin.json', 'validation.json'}
    require(all(n in allowed or n.startswith('licenses/') for n in census(package)), 'Unexpected package member')
    require(digest(args.pck) != digest(package / 'DWM.pck'), 'Instrumented PCK must differ')
    shutil.copyfile(package / 'validation.json', out / 'retained-package-validation.json')
    shutil.copyfile(package / 'diagnostic-origin.json', out / 'retained-diagnostic-origin.json')
    shutil.copyfile(args.source_manifest, out / 'source-patch-manifest.json')
    (package / 'validation.json').unlink()
    shutil.copyfile(args.pck, package / 'DWM.pck')
    new_origin = {
        'schema_version': 1, 'kind': 'isolated_title_timing_diagnostic', 'game_commit': GAME_COMMIT,
        'retained_archive': retained['archive'], 'retained_validation_sha256': digest(retained_path),
        'native_build': build, 'native_build_receipt_sha256': digest(build_path),
        'source_patch_manifest': source_manifest, 'source_patch_manifest_sha256': digest(args.source_manifest),
        'qualification': ['Diagnostic only; does not qualify the official executable or authorize runtime promotion.',
                          'EXE and notices retained byte-for-byte; instrumented PCK requires fresh startup smoke.',
                          'Source patch manifest records export custody; this tool does not perform a runtime pack audit.'],
    }
    write(package / 'diagnostic-origin.json', new_origin)
    write(out / 'stage.json', {'schema_version': 1, 'diagnostic': True, 'engine_banner': retained['engine_banner'],
                              'retained_files': original['files'], 'files': manifest(package)})
    print(json.dumps({'prepared': True, 'pck': identity(package / 'DWM.pck')}))


def finish(args):
    out = args.output
    package = out / 'package'
    require(not (package / 'validation.json').exists() and not (out / ARCHIVE_NAME).exists(), 'Already finalized')
    stage = read(out / 'stage.json')
    check_manifest(package, stage['files'])
    for entry in stage['retained_files']:
        if entry['path'] not in ('DWM.pck', 'diagnostic-origin.json'):
            require(matches(package / entry['path'], entry), 'Retained EXE/notice changed')
    smoke = read(args.smoke_result)
    require(smoke.get('ok') is True and smoke.get('version') == stage['engine_banner']
            and smoke.get('exit_code') == 0 and smoke.get('timed_out') is False
            and smoke.get('isolated_profile_created') is True, 'Fresh diagnostic startup smoke failed')
    require(smoke.get('executable_sha256') == digest(package / 'DWM.exe')
            and smoke.get('pck_sha256') == digest(package / 'DWM.pck'), 'Smoke does not identify fresh EXE/PCK')
    origin = read(package / 'diagnostic-origin.json')
    validation = {'schema_version': 1, 'ok': True, 'diagnostic': True, 'commit': GAME_COMMIT,
                  'engine': '4.6.3.stable', 'engine_banner': stage['engine_banner'], 'architecture': 'x86_64',
                  'signed': False, 'scope': 'Instrumented PCK timing diagnostic and fresh isolated startup only',
                  'limitations': origin['qualification'], 'smoke': smoke,
                  'pack_custody': {'ok': True, 'audit_reexecuted': False, 'method': 'Source patch manifest and fresh PCK digest',
                                   'pck': identity(package / 'DWM.pck'),
                                   'source_patch_manifest_sha256': origin['source_patch_manifest_sha256']},
                  'files': stage['files']}
    write(package / 'validation.json', validation)
    archive = out / ARCHIVE_NAME
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as target:
        for name in sorted(census(package)):
            target.write(package / name, name)
    validation['archive'] = dict(file=archive.name, **identity(archive))
    write(out / 'validation.json', validation)
    print(json.dumps({'ok': True, 'diagnostic': True, 'archive': validation['archive']}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='phase', required=True)
    prep = commands.add_parser('prepare')
    for name in ('original', 'evidence', 'pck', 'source-manifest', 'output'):
        prep.add_argument('--' + name, type=Path, required=True)
    done = commands.add_parser('finish')
    done.add_argument('--output', type=Path, required=True)
    done.add_argument('--smoke-result', type=Path, required=True)
    args = parser.parse_args()
    {'prepare': prepare, 'finish': finish}[args.phase](args)


if __name__ == '__main__':
    main()

