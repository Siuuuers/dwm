#!/usr/bin/env python3
"""Package existing Broad2 audits deterministically. Never execute their auditors."""
from pathlib import Path
from collections import Counter
import argparse
import gzip
import hashlib
import io
import json
import tarfile


def identity(raw):
    return {'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}


def encoded(value):
    return (json.dumps(value, sort_keys=True, ensure_ascii=False, indent=2) + '\n').encode()


def put_immutable(path, raw):
    if path.exists():
        if path.read_bytes() != raw:
            raise ValueError('Refusing to replace differing retained package: ' + str(path))
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(raw)


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--workspace', type=Path, default=Path('/workspace/scratch/e58f796fe7a3'))
args = parser.parse_args()
B = args.workspace.resolve()
DEST = B / 'dwm/evidence/phase_2r/hospital_reading_2026_10_02'
RUN = 37048318182
SOURCE = 'a24f71766a624b57601814dda487b53c66518c39'
HEAD = 'c9c013397f2e309b48fc1548490b401e54938c6c'
generic_path = B / 'hospital-broad2-package/hospital-broad2-evidence.tar.gz'
generic_raw = generic_path.read_bytes()
generic_identity = identity(generic_raw)
assert generic_identity == {'bytes': 28877911, 'sha256': '221a811b8266832cea52f9ae3cceeac2db956258a599c6f40cbba05f639f848a'}
generic_members = {}
with tarfile.open(fileobj=io.BytesIO(generic_raw), mode='r:gz') as tar:
    for member in tar.getmembers():
        assert member.isfile() and member.name not in generic_members
        generic_members[member.name] = identity(tar.extractfile(member).read())
assert len(generic_members) == 749

payload = {}
inventory = {}
exclusions = []


def add(path, role, member=None):
    path = path.resolve()
    assert B in path.parents and path.is_file() and not path.is_symlink()
    relative = path.relative_to(B).as_posix()
    member = member or relative
    assert member not in payload and not Path(member).is_absolute() and '..' not in Path(member).parts
    raw = path.read_bytes()
    assert len(raw) <= 8 * 1024 * 1024, ('Unexpected bulk input', relative)
    item = identity(raw)
    if member in generic_members:
        assert generic_members[member] == item, ('Conflicting additive archive member', member)
    payload[member] = raw
    inventory[member] = {'archive_member': member, 'source_relative_path': relative,
                         'source_path': str(path), 'role': role, **item,
                         'identical_member_already_in_generic_archive': member in generic_members}


audit_dirs = ['hospital-broad2-semantic-audit', 'hospital-broad2-suite-audit',
              'hospital-broad2-original-reading-audit', 'hospital-broad2-selector-audit',
              'hospital-broad2-retained-history-audit', 'hospital-broad2-review',
              'hospital-broad2-performance-audit', 'hospital-broad2-rendered-audit',
              'hospital-broad2-normalization-audit', 'hospital-broad2-export-audit']
for dirname in audit_dirs:
    folder = B / dirname
    assert folder.is_dir()
    for path in sorted(folder.rglob('*')):
        if not path.is_file():
            continue
        relative = path.relative_to(B).as_posix()
        if '__pycache__' in path.parts or path.suffix == '.pyc':
            exclusions.append({'source_relative_path': relative, **identity(path.read_bytes()),
                               'reason': 'Generated Python bytecode; reproducible source included.'})
            continue
        if 'validator-copies' in path.parts:
            originals = list((B / 'hospital-broad2/artifacts/solo-authored-selector-37048318182-1').glob('*/' + path.name))
            original, = originals
            assert path.read_bytes() == original.read_bytes()
            original_member = original.relative_to(B).as_posix()
            assert generic_members[original_member] == identity(path.read_bytes())
            exclusions.append({'source_relative_path': relative, **identity(path.read_bytes()),
                               'reason': 'Byte-identical validator copy; original remains in generic archive.',
                               'retained_generic_member': original_member})
            continue
        if path.name == 'audit_export.strict-initial.py':
            exclusions.append({'source_relative_path': relative, **identity(path.read_bytes()),
                               'reason': 'Superseded initial exporter auditor; final qualified auditor is included. Root separately retains diagnostic history and erratum.'})
            continue
        assert path.suffix in {'.json', '.md', '.py'}, ('Review new audit file before packaging', relative)
        add(path, 'independent_auditor' if path.suffix == '.py' else 'audit_report_or_bound_input')

for relative in ['hospital-broad2/audit', 'hospital-broad2/infrastructure-audit.json',
                 'hospital-broad2-root-visual-review.json', 'hospital-broad2.yml',
                 'hospital-broad2.yml.manifest.json', 'hospital-broad2-expected-tree.json',
                 'hospital-broad2-package/manifest.json', 'hospital-broad2-package/bundle-receipt.json',
                 'hospital-broad2-package/SHA256SUMS.txt']:
    add(B / relative, 'generic_audit_or_source_provenance')
for path in sorted((B / 'hospital-source9').rglob('*')):
    if path.is_file():
        assert path.suffix in {'.json', '.ps1'}
        add(path, 'source9_frozen_identity_or_exact_powershell_source')
for relative in ['hospital-tools/build_hospital_broad_workflow.py',
                 'hospital-tools/build_paused_settings_f9_workflow.py',
                 'hospital-tools/build_layout_workflow.py', 'hospital-tools/cloud_evidence.py',
                 'hospital-tools/build_reusable_export_evidence_transport.py',
                 'hospital-export2-transport.yml', 'hospital-export2-transport.yml.static-review.json',
                 'hospital-export2-source-metadata.json', 'hospital-export2-publication.json']:
    add(B / relative, 'reproducible_helper_or_export2_provenance')

transport_root = B / 'hospital-export2-transport-capture'
for path in sorted(transport_root.rglob('*')):
    if not path.is_file():
        continue
    if reassembly_part := path.name.startswith('original.zip.part'):
        exclusions.append({'source_relative_path': path.relative_to(B).as_posix(), **identity(path.read_bytes()),
                           'reason': 'Original export binary transport chunk; excluded by packaging scope.'})
        continue
    assert path.suffix in {'.json', '.log'}
    add(path, 'export2_capture_metadata_console_or_reassembly_receipt')

visual = json.loads((B / 'hospital-broad2-root-visual-review.json').read_text())
assert visual['run_id'] == RUN and visual['source'] == SOURCE and visual['checkout'] == HEAD
assert visual['status'] == 'pass_bounded_visual_review' and len(visual['captures']) == 11
for capture in visual['captures']:
    path = B / 'hospital-broad2/artifacts' / capture['path']
    assert identity(path.read_bytes()) == {key: capture[key] for key in ['bytes', 'sha256']}
    add(path, 'selected_original_visual_review_frame')
assert sum('hospital-reading-' in item['archive_member'] for item in inventory.values()
           if item['role'] == 'selected_original_visual_review_frame') == 5

public_art = B / 'hospital-broad2/artifacts/public-surfaces-37048318182-1/ci/public-surfaces'
for filename in ['game_state_surface.json', 'save_manager_surface.json']:
    path = public_art / filename
    add(path, 'source_bound_public_inventory_omitted_by_generic_packager')

helper_path = Path(__file__).resolve()
add(helper_path, 'reproducible_supplement_packager')
export_audit = json.loads((B / 'hospital-broad2-export-audit/windows-export-audit.json').read_text())
assert export_audit['status'] == 'pass_qualified_bounded_export_only'
assert export_audit['exporter_lifetime_acceptance'] is False and export_audit['unqualified_clean_diagnostic_claim'] is False
assert export_audit['source'] == SOURCE and export_audit['checkout'] == HEAD and export_audit['run_id'] == RUN
source9 = json.loads((B / 'hospital-source9/manifest.json').read_text())
for item in source9['files']:
    assert identity((B / 'hospital-source9' / item['path']).read_bytes()) == {key: item[key] for key in ['bytes', 'sha256']}

instructions = f'''Broad2 independent audit supplement

Run {RUN}, attempt 1. Runtime source {SOURCE}; actual checkout {HEAD}.

This is an additive evidence package, not an aggregate acceptance receipt. It
preserves exact final auditor/report bytes, workflow/source9 provenance, root
visual observations, eleven original selected PNGs (all five Hospital frames),
the two source-bound public inventories, generic audit and infrastructure review,
and export2 transport provenance/metadata/reassembly receipts.

Extract this archive and the raw-part-reassembled hospital-broad2-evidence.tar.gz
into the same workspace parent. Their overlapping members are byte-identical.
Auditors preserve their original workspace/source/capture path assumptions and
Git SHA checks; consult the bound source checkout and each auditor before reuse.
Some audits require verified original ZIPs. Packaging does not remove that
requirement and does not run any engine or PowerShell code.

Excluded: raw Windows executable/PCK/nested or original export ZIP, export2 raw
transport chunks/wrapper ZIPs, duplicate selector validator copies, generated
bytecode, and the superseded initial exporter auditor. Source inputs and original
archives remain unchanged. The transport receipt describes original-byte
delivery only; no binary bytes are reinterpreted or replaced.

The final exporter result is qualified: its ObjectDB shutdown warning remains
unresolved. Root independently retains exporter diagnostic review and Broad1
erratum under audit-records/exporter-diagnostic; this supplement intentionally
does not duplicate those records. No warning-free/leak-free exporter claim.

Deterministic tar: sorted regular members, uid/gid 0, blank owner/group names,
mode 0644, mtime 0; gzip filename empty, mtime 0, compression level 9. All members
were reread and hash-matched after packing, and a second build produced identical
bytes. Source report timestamps are preserved as content, never regenerated.
'''.encode()
readme_name = 'BROAD2-INDEPENDENT-SUPPLEMENT.txt'
payload[readme_name] = instructions
inventory[readme_name] = {'archive_member': readme_name, 'source_relative_path': None,
                          'source_path': None, 'role': 'generated_package_instructions',
                          **identity(instructions), 'identical_member_already_in_generic_archive': False}
limits = ['No original Windows binary, original export ZIP, nested archive, transport raw chunk or wrapper ZIP is included.',
          'Generic archive exclusions remain documented by its own unchanged manifest; eleven selected PNGs and public inventory bytes are restored additively here.',
          'Exporter diagnostic review and Broad1 erratum are root-owned external materials, deliberately not duplicated.',
          'No final aggregate receipt, root README, focused evidence or Broad1 evidence was edited by this packager.',
          'Static preparation/checklist records are retained as history; final actual audit reports do not inherit a whole-run acceptance claim.']
internal = {'schema_version': 1, 'package_kind': 'additive_broad2_independent_audit_supplement',
            'run_id': RUN, 'attempt': 1, 'runtime_source': SOURCE, 'actual_checkout': HEAD,
            'generic_archive': {'workspace_relative_path': generic_path.relative_to(B).as_posix(), **generic_identity},
            'members': [inventory[name] for name in sorted(inventory)],
            'excluded_source_files': exclusions,
            'external_exporter_diagnostic_review_identity': export_audit['diagnostic_review'],
            'limits': limits,
            'deterministic_metadata': {'tar_format': 'PAX', 'member_order': 'sorted', 'uid': 0, 'gid': 0,
                                       'uname': '', 'gname': '', 'mode_octal': '0644', 'mtime': 0,
                                       'gzip_filename': '', 'gzip_mtime': 0, 'gzip_level': 9}}
internal_name = 'BROAD2-INDEPENDENT-SUPPLEMENT-MANIFEST.json'
payload[internal_name] = encoded(internal)


def make_archive():
    output = io.BytesIO()
    with gzip.GzipFile(fileobj=output, mode='wb', filename='', mtime=0, compresslevel=9) as compressed:
        with tarfile.open(fileobj=compressed, mode='w', format=tarfile.PAX_FORMAT) as tar:
            for name in sorted(payload):
                raw = payload[name]
                info = tarfile.TarInfo(name)
                info.size = len(raw); info.mode = 0o644; info.uid = info.gid = 0
                info.uname = info.gname = ''; info.mtime = 0
                tar.addfile(info, io.BytesIO(raw))
    return output.getvalue()


archive_raw = make_archive()
assert archive_raw == make_archive(), 'Nondeterministic archive rebuild'
assert len(archive_raw) <= 8 * 1024 * 1024, 'Supplement requires separately reviewed splitting'
verified = []
with tarfile.open(fileobj=io.BytesIO(archive_raw), mode='r:gz') as tar:
    assert tar.getnames() == sorted(payload)
    for member in tar.getmembers():
        assert member.isfile() and member.uid == member.gid == member.mtime == 0 and member.mode == 0o644
        raw = tar.extractfile(member).read()
        assert raw == payload[member.name]
        verified.append({'archive_member': member.name, **identity(raw)})
# Force gzip trailer/CRC validation through EOF independently of tar end padding.
gzip.decompress(archive_raw)
for item in inventory.values():
    if item['source_path']:
        assert identity(Path(item['source_path']).read_bytes()) == {key: item[key] for key in ['bytes', 'sha256']}
assert identity(generic_path.read_bytes()) == generic_identity

archive_path = DEST / 'broad2-independent-audits.tar.gz'
manifest_path = DEST / 'broad2-independent-audits.manifest.json'
external = {**internal, 'archive': {'file': archive_path.name, **identity(archive_raw)},
            'archive_member_count': len(payload), 'payload_file_count': len(inventory),
            'payload_total_bytes': sum(len(raw) for name, raw in payload.items() if name != internal_name),
            'role_counts': dict(sorted(Counter(item['role'] for item in inventory.values()).items())),
            'internal_manifest': {'archive_member': internal_name, **identity(payload[internal_name])},
            'round_trip_verified': True, 'repeated_build_byte_identical': True,
            'all_source_bytes_unchanged': True, 'gzip_crc_verified': True,
            'archive_member_identities': verified}
put_immutable(archive_path, archive_raw)
put_immutable(manifest_path, encoded(external))
print(json.dumps({'archive': {'path': str(archive_path), **identity(archive_raw)},
                  'manifest': {'path': str(manifest_path), **identity(manifest_path.read_bytes())},
                  'archive_members': len(payload), 'payload_files': len(inventory),
                  'payload_bytes': external['payload_total_bytes'], 'excluded_source_files': len(exclusions),
                  'selected_original_visual_frames': 11, 'all_sources_unchanged': True,
                  'deterministic_rebuild_equal': True, 'round_trip_verified': True}, indent=2))
