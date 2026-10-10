#!/usr/bin/env python3
"""Read retained bytes and Git blobs only; no engine, remote calls, or repo edits."""
from pathlib import Path, PureWindowsPath
from collections import Counter
from datetime import datetime
import hashlib
import json
import re
import subprocess
import xml.etree.ElementTree as ET
import zipfile

B = Path('/workspace/scratch/e58f796fe7a3')
OUT = B / 'hospital-broad1-suite-audit'
ART = B / 'hospital-broad1-extracted/artifacts'
HEAD = '1bc4f6afd759e969f82b9c2134eb178479c19d13'
SOURCE = '856520f09440d9b47cc272de3363009924ffedca'
RUN = 37044894986
ALLOWED = 'Unicode parsing error, some characters were replaced with � (U+FFFD): Invalid UTF-8 leading byte (ff)'
ANSI = re.compile(r'\x1b\[[0-?]*[ -/]*[@-~]')
BAD = re.compile(r'SCRIPT ERROR:|(?:^|\s)ERROR:|Unicode parsing error|Unexpected NUL character|Parse Error:|Parser Error:|ObjectDB instances leaked|resources still in use|RID allocations? of type|orphan StringName|Unreferenced static string', re.I)


def ident_bytes(raw):
    return {'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}


def ident(path):
    return {'path': str(path), **ident_bytes(path.read_bytes())}


def readjson(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def git(path):
    return subprocess.check_output(['git', 'show', HEAD + ':' + path], cwd=B / 'dwm')


def line_text(raw):
    return [ANSI.sub('', line).rstrip('\r') for line in raw.decode('utf-8-sig').split('\n')]


def console(path):
    return [re.sub(r'^\d{4}-\d\d-\d\dT\S+Z ', '', line) for line in line_text(path.read_bytes())]


def logcheck(path, allow_corrupt=False):
    raw = path.read_bytes()
    assert raw and b'\0' not in raw, path
    findings = [{'line': i, 'text': line} for i, line in enumerate(line_text(raw), 1) if BAD.search(line)]
    if allow_corrupt:
        assert len(findings) == 1 and findings[0]['text'] == ALLOWED, findings
    else:
        assert not findings, (path, findings)
    return {**ident(path), 'literal_nul_bytes': 0, 'diagnostics': findings,
            'unexpected_diagnostic_count': 0}


def receipt(path, suite_id):
    rows = [json.loads(line) for line in path.read_text(encoding='utf-8-sig').splitlines() if line.strip()]
    assert len(rows) == 1
    row = rows[0]
    assert row['suite_id'] == suite_id and row['exit_code'] == 0
    root, user = PureWindowsPath(row['test_root']), PureWindowsPath(row['user_dir'])
    assert root in user.parents and root.parent.name == 'phase2r_tests'
    assert PureWindowsPath(row['log_path']).name == suite_id + '.log'
    start = datetime.fromisoformat(row['started_at_utc'].replace('Z', '+00:00'))
    end = datetime.fromisoformat(row['ended_at_utc'].replace('Z', '+00:00'))
    assert end > start
    return {**ident(path), 'record': row, 'duration_seconds': (end - start).total_seconds(),
            'isolated_user_dir_strictly_within_test_root': True}


def checkout_observation(lines):
    markers = [(i, line) for i, line in enumerate(lines) if line.startswith('[command]') and line.endswith(' log -1 --format=%H')]
    assert len(markers) == 1, markers
    index, command = markers[0]
    assert lines[index + 1] == HEAD
    return {'command_line': index + 1, 'command': command, 'output_line': index + 2, 'observed': lines[index + 1]}


resolved = readjson(OUT / 'resolved-census.json')
assert resolved['actual_checkout'] == HEAD and resolved['source_commit'] == SOURCE
census = resolved['suite_census']
original = readjson(B / 'hospital-broad1.yml.manifest.json')
assert ident_bytes((B / 'hospital-broad1.yml.manifest.json').read_bytes()) == resolved['initial_manifest']
jobs_path = B / 'hospital-broad1-early-logs/jobs-snapshot.json'
jobs = readjson(jobs_path)['jobs']
by_job = {job['name']: job for job in jobs}
artifact_manifest_path = B / 'hospital-broad1-extracted/artifact-manifest.json'
artifact_manifest = readjson(artifact_manifest_path)
by_art = {a['name']: a for a in artifact_manifest}
all_actual, all_expected = Counter(), Counter()
suites = {}
archives = {}

for name, suite in census['suites'].items():
    paths = list(ART.glob('*/ci/' + name + '.xml'))
    expected = Counter((s['path'], n) for s in suite['scripts'] for n in s['static_test_names'])
    if name == 'endings':
        assert not paths
        continue
    assert len(paths) == 1
    path = paths[0]
    folder = path.parent.parent
    expected_artifact_name = ('public-surfaces' if name == 'public_surfaces' else 'windows-' + name) + '-' + str(RUN) + '-1'
    assert folder.name == expected_artifact_name
    a = by_art[folder.name]
    assert a['workflow_run']['id'] == RUN and a['workflow_run']['head_sha'] == HEAD
    zpath = Path(a['local_zip'])
    zraw = zpath.read_bytes()
    assert len(zraw) == a['size_in_bytes'] and 'sha256:' + hashlib.sha256(zraw).hexdigest() == a['digest']
    with zipfile.ZipFile(zpath) as z:
        assert z.testzip() is None
        members = {i.filename: i for i in z.infolist() if not i.is_dir()}
        retained = []
        for f in sorted(folder.rglob('*')):
            if not f.is_file():
                continue
            rel = f.relative_to(folder).as_posix()
            assert rel in members and f.read_bytes() == z.read(rel), f
            retained.append({'member': rel, **ident_bytes(f.read_bytes())})
        archives[folder.name] = {'api_artifact_id': a['id'], 'archive': ident(zpath), 'api_digest': a['digest'],
                                'zip_crc_ok': True, 'all_retained_members_match_original': True,
                                'original_members': len(members), 'retained_members': retained,
                                'not_retained': sorted(set(members) - {x['member'] for x in retained})}
    tree = ET.parse(path).getroot()
    assert tree.tag == 'testsuites' and int(tree.attrib['tests']) == sum(expected.values())
    for key in ('failures', 'errors', 'skipped', 'disabled'):
        assert int(tree.get(key, '0')) == 0
    actual = Counter()
    script_counts = []
    assert len(tree.findall('testsuite')) == suite['script_count']
    for script in tree.findall('testsuite'):
        script_path = script.attrib['name']
        cases = script.findall('testcase')
        assert int(script.attrib['tests']) == len(cases)
        for key in ('failures', 'errors', 'skipped', 'disabled'):
            assert int(script.get(key, '0')) == 0
        for case in cases:
            assert case.get('status') == 'pass' and case.get('classname') == script_path and not list(case)
            assert int(case.attrib['assertions']) > 0
            actual[(script_path, case.attrib['name'])] += 1
        script_counts.append({'script': script_path, 'test_cases': len(cases), 'passed': len(cases), 'skipped': 0})
    assert actual == expected, (name, actual - expected, expected - actual)
    assert all(v == 1 for v in actual.values())
    all_actual.update((name, *pair) for pair in actual.elements())
    all_expected.update((name, *pair) for pair in expected.elements())
    job_name = 'Windows / public API surface contracts' if name == 'public_surfaces' else 'Windows / ' + name
    job = by_job[job_name]
    assert job['run_id'] == RUN and job['run_attempt'] == 1 and job['head_sha'] == HEAD
    assert job['status'] == 'completed' and job['conclusion'] == 'success'
    assert all(step['conclusion'] == 'success' for step in job['steps']), job_name
    cpath = B / 'hospital-broad1-early-logs/logs' / (str(job['id']) + '.log')
    lines = console(cpath)
    cloud = [(i, json.loads(line[len('CLOUD_GUT_RESULT '):])) for i, line in enumerate(lines, 1) if line.startswith('CLOUD_GUT_RESULT ')]
    assert len(cloud) == 1
    wanted = {'suite': name, 'test_cases': sum(expected.values()), 'passed': sum(expected.values()),
              'skipped': 0, 'requested_scripts': suite['script_count'], 'reported_scripts': suite['script_count'],
              'scripts': script_counts}
    assert cloud[0][1] == wanted, (name, cloud, wanted)
    rec = receipt(path.with_suffix('.jsonl'), 'cloud-' + name)
    scripts_arg = [arg for arg in rec['record']['argv'] if arg.startswith('-gtest=')]
    assert scripts_arg == ['-gtest=' + ','.join('res://' + s['path'] for s in suite['scripts'])]
    assert '-gjunit_xml_file=res://.godot/ci/' + name + '.xml' in rec['record']['argv']
    log_path = folder / 'phase2r_logs' / ('cloud-' + name + '.log')
    engine = logcheck(log_path, name == 'new_account')
    engine_lines = line_text(log_path.read_bytes())
    temp_rows = [line for line in engine_lines if '[INFO]:  using [' in line and '] for temporary output.' in line]
    assert len(temp_rows) == 1 and rec['record']['user_dir'].replace('\\', '/') in temp_rows[0]
    diagnostics = [{'line': i, 'text': line} for i, line in enumerate(lines, 1)
                   if re.match(r'^(SCRIPT ERROR:|ERROR:|Unicode parsing error|Unexpected NUL character|Parse Error:|Parser Error:)', line)]
    assert not diagnostics, (name, diagnostics)
    suites[name] = {'status': 'pass', 'xml': ident(path), 'cases': sum(actual.values()),
                    'script_executions': len(script_counts), 'scripts': script_counts,
                    'named_multiset_exact_after_reviewed_inheritance_correction': True,
                    'missing_cases': [], 'unexpected_cases': [], 'duplicate_cases': [],
                    'failures': 0, 'errors': 0, 'skipped': 0, 'disabled': 0,
                    'isolation_receipt': rec, 'engine_log': engine,
                    'import_log': logcheck(folder / 'ci/import.log'),
                    'actions_log': ident(cpath), 'job_id': job['id'], 'job_name': job_name,
                    'observed_checkout': checkout_observation(lines), 'cloud_gut_result_line': cloud[0][0],
                    'cloud_gut_result': cloud[0][1], 'console_diagnostics': diagnostics,
                    'all_job_steps_success': True}

assert len(suites) == 12 and all_actual == all_expected
assert len(list(ART.glob('*/ci/*.xml'))) == 12
assert sum(all_actual.values()) == 2331
unique_cases = {(script, test) for suite, script, test in all_actual}
unique_scripts = {script for _, script, _ in all_actual}

# Public source inventories and source-scanned observational records.
public = ART / ('public-surfaces-' + str(RUN) + '-1')
pubdir = public / 'ci/public-surfaces'
pub_console_path = B / 'hospital-broad1-early-logs/logs/110963772371.log'
pub_lines = console(pub_console_path)
command = './tools/testing/Invoke-PublicSurfaceValidation.ps1 -EmitPayloads'
assert pub_lines.count('##[group]Run ' + command) == 1
assert sum(line.startswith('##[group]Run ') and 'Invoke-PublicSurfaceValidation.ps1' in line for line in pub_lines) == 1
assert pub_lines.count('PUBLIC_SURFACE_VALIDATION_VERIFIED: both complete-tree inventories reproduce canonical bytes.') == 1
inventories = {}
for target, owner in [('game_state', 'GameState'), ('save_manager', 'SaveManager')]:
    path = pubdir / (target + '_surface.json')
    source_path = 'evidence/phase_2r/runtime/' + target + '_surface.json'
    raw = git(source_path)
    assert path.read_bytes() == raw
    assert ident_bytes(raw) == original['source_file_identities'][source_path]
    rec = receipt(pubdir / (target + '-check.jsonl'), 'cloud-public-surface-' + target + '-check')
    argv = rec['record']['argv']
    assert argv[argv.index('--') + 1:] == [
        '--script=res://autoload/' + owner + '.gd',
        '--required=res://evidence/phase_2r/runtime/' + target + '_required_surface.json',
        '--output=res://evidence/phase_2r/runtime/' + target + '_surface.json',
        '--search-root=res://autoload', '--search-root=res://scripts',
        '--search-root=res://scenes', '--search-root=res://tests', '--check']
    lp = public / 'phase2r_logs' / ('cloud-public-surface-' + target + '-check.log')
    audit = logcheck(lp)
    assert sum(line.startswith('SURFACE_INVENTORY: PASS') for line in line_text(lp.read_bytes())) == 1
    inventories[target] = {'emitted': ident(path), 'source_path': source_path, 'source': ident_bytes(raw),
                           'byte_identical_to_committed_inventory': True, 'check_only_receipt': rec,
                           'log': audit, 'pass_markers': 1}

all_paths = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', HEAD, '--',
                                   'autoload/', 'scripts/', 'tests/', 'tools/testing/', '.github/workflows/', 'scenes/'],
                                  cwd=B / 'dwm', text=True).splitlines()
paths = sorted(p for p in all_paths if Path(p).suffix in {'.gd', '.ps1', '.py', '.yml', '.yaml', '.tscn'})
raw_batch = subprocess.check_output(['git', 'cat-file', '--batch'], cwd=B / 'dwm',
                                    input=''.join(HEAD + ':' + p + '\n' for p in paths).encode())
blobs = {}
offset = 0
for p in paths:
    end = raw_batch.index(b'\n', offset)
    header = raw_batch[offset:end].decode().split()
    assert len(header) == 3 and header[1] == 'blob', (p, header)
    size = int(header[2]); offset = end + 1
    blobs[p] = raw_batch[offset:offset + size]
    offset += size + 1
assert offset == len(raw_batch)
observed = readjson(pubdir / 'fixture-version-census.json')
assert observed['checkout_ref'] == HEAD
compiled = {k: re.compile(v) for k, v in observed['patterns'].items()}
records = []; scanned = []
for p in paths:
    if p.startswith('scenes/') or Path(p).suffix not in {'.gd', '.ps1', '.py', '.yml', '.yaml'}:
        continue
    scanned.append(p)
    for number, line in enumerate(blobs[p].decode('utf-8-sig').splitlines(), 1):
        families = [key for key, pattern in compiled.items() if pattern.search(line)]
        if families:
            records.append({'path': p, 'line': number, 'families': families, 'text': line})
assert len(scanned) == observed['scanned_files'] == 963
assert records == observed['matches'] and len(records) == 908
console_records = [json.loads(line[len('FIXTURE_VERSION_CENSUS_MATCH: '):]) for line in pub_lines if line.startswith('FIXTURE_VERSION_CENSUS_MATCH: ')]
assert records == console_records
summary_rows = [json.loads(line[len('FIXTURE_VERSION_CENSUS_SUMMARY: '):]) for line in pub_lines if line.startswith('FIXTURE_VERSION_CENSUS_SUMMARY: ')]
assert len(summary_rows) == 1 and summary_rows[0]['checkout_ref'] == HEAD
assert summary_rows[0]['scanned_files'] == 963 and summary_rows[0]['matching_lines'] == summary_rows[0]['logged_lines'] == 908
retired = readjson(pubdir / 'retirement-audit.json')
assert retired['checkout_ref'] == HEAD and len(retired['retired_symbols']) == 10
retire_paths = [p for p in paths if Path(p).suffix in {'.gd', '.tscn'} and p.split('/')[0] in retired['search_roots']]
retire_pattern = re.compile(r'\b(?:' + '|'.join(re.escape(s) for s in retired['retired_symbols']) + r')\b')
retire_hits = []
for p in retire_paths:
    for i, line in enumerate(blobs[p].decode('utf-8-sig').splitlines(), 1):
        if retire_pattern.search(line):
            retire_hits.append({'path': p, 'line': i, 'text': line})
assert len(retire_paths) == retired['source_files'] == 954
assert retire_hits == retired['references'] == []
source_scan = [{'path': p, **ident_bytes(blobs[p])} for p in sorted(set(scanned + retire_paths))]
(OUT / 'public-source-scan-identities.json').write_text(json.dumps({'checkout': HEAD, 'files': source_scan}, indent=2) + '\n')

# Independently re-open the delegated control evidence and bind the exact report.
negative_path = OUT / 'negative-controls-subaudit.json'
negative = readjson(negative_path)
assert negative['status'] == 'pass_bounded_negative_controls_and_standalone'
assert negative['run_id'] == RUN and negative['attempt'] == 1 and negative['expected_checkout'] == HEAD
negative_xmls = sorted(ART.glob('*/ci/storage-refusal/*/tests.xml'))
assert len(negative_xmls) == 2
for path in negative_xmls:
    root = ET.parse(path).getroot()
    cases = root.findall('.//testcase')
    fails = [case for case in cases if case.find('failure') is not None]
    assert len(cases) == 83 and len(fails) == 80
    assert all('test_root_missing' in ET.tostring(case, encoding='unicode') for case in fails)
    assert not root.findall('.//error') and not root.findall('.//skipped')
    before = path.parent / 'repository-before.json'; after = path.parent / 'repository-after.json'
    assert before.read_bytes() == after.read_bytes()

endings = by_job['Windows / endings']
assert endings['head_sha'] == HEAD and endings['run_id'] == RUN and endings['run_attempt'] == 1
assert endings['conclusion'] == 'failure'
failed_steps = [s['name'] for s in endings['steps'] if s['conclusion'] == 'failure']
assert failed_steps == ['Install Godot 4.6.3 standard'], failed_steps
endlog = B / 'hospital-broad1-early-logs/logs' / (str(endings['id']) + '.log')
endlines = console(endlog)
assert not any(line.startswith('CLOUD_GUT_RESULT ') for line in endlines)

result = {
    'schema_version': 1, 'status': 'pass_bounded_12_suite_public_and_negative_control_evidence',
    'run_id': RUN, 'attempt': 1, 'actual_checkout': HEAD, 'runtime_source': SOURCE,
    'scope': 'Read-only local audit of this attempt’s 12 available ordinary/public suites, public inventories/censuses, exact negative controls and standalone receipts; not whole broad acceptance.',
    'method': 'Reparsed actual XML/JSON/JSONL/log bytes, compared exact named multisets with source-derived recursive ancestry, verified original archive digest/CRC/retained members, independently scanned exact checkout Git blobs. No engine, PowerShell, connector or remote call.',
    'inputs': {'checklist': ident(B / 'hospital-broad1-review/checklist.md'),
               'checklist_identities': ident(B / 'hospital-broad1-review/checklist-identities.json'),
               'initial_manifest': ident(B / 'hospital-broad1.yml.manifest.json'),
               'resolved_census': ident(OUT / 'resolved-census.json'),
               'jobs_snapshot': ident(jobs_path), 'artifact_manifest': ident(artifact_manifest_path),
               'audit_script': ident(Path(__file__))},
    'census_correction': {'initial_prediction': census['initial_lexical_prediction'],
                          'corrected_full_prediction': {key: value for key, value in census.items() if key.startswith('predicted_')},
                          'adjustments': census['inheritance_adjustments'],
                          'original_manifest_preserved': True,
                          'product_or_test_source_changed_by_audit': False,
                          'explanation': 'The original lexical helper counted only own methods. Both Shop scene fixtures inherit the same eight base tests. All other suite predictions, including unexecuted Endings 106, are unchanged.'},
    'actual_totals': {'ordinary_xml': 12, 'case_executions': sum(all_actual.values()),
                      'script_executions': sum(s['script_executions'] for s in suites.values()),
                      'unique_script_test_pairs': len(unique_cases), 'unique_scripts': len(unique_scripts),
                      'failures': 0, 'errors': 0, 'skipped': 0, 'disabled': 0,
                      'intentional_negative_executions_excluded': 166},
    'suites': suites, 'archive_integrity': archives,
    'public': {'command': command, 'command_count': 1, 'regeneration': False,
               'canonical_reproduction_receipt_count': 1, 'inventories': inventories,
               'fixture_census': {'artifact': ident(pubdir / 'fixture-version-census.json'),
                                 'scanned_source_files': len(scanned), 'matching_lines': len(records),
                                 'family_memberships': dict(Counter(f for row in records for f in row['families'])),
                                 'all_source_records_and_console_records_match': True,
                                 'console_summary': summary_rows[0],
                                 'review': ['Four legacy prepared-fixture mentions are one explicit v5-based current-schema builder and three v6 refusal/skip tests; they do not establish runtime migration.',
                                            'Eight valid_day3 seed mentions are test construction inputs. Their builders supply current required context or extract component inputs; the untouched historical filename is not a production acceptance receipt.',
                                            'Two literal empty-contacts records are owner-candidate attestation and local snapshot-composer inputs, not admission of a full saved run with empty contacts.',
                                            'Schema/version references remain observational. Reproduction of the 908-line census is not independent semantic acceptance of every migration or production content path.']},
               'retirement': {'artifact': ident(pubdir / 'retirement-audit.json'), 'source_files': 954,
                              'symbols': retired['retired_symbols'], 'independently_recomputed_references': []},
               'source_scan_identities': ident(OUT / 'public-source-scan-identities.json')},
    'negative_controls_and_standalone': {'subaudit': ident(negative_path), 'status': negative['status'],
                                        'scope': negative['scope'], 'independent_spot_checks': 'Reparsed both 83/80/3 XMLs and failure text, matched each complete before/after repository snapshot; ordinary new-account log independently admits exactly the one ff diagnostic.'},
    'endings_absent': {'expected_cases': 106, 'expected_scripts': 12, 'job_id': endings['id'],
                       'status': 'not_executed_installation_failure', 'failed_step': failed_steps[0],
                       'actions_log': ident(endlog), 'observed_checkout': checkout_observation(endlines),
                       'cloud_gut_receipts': 0, 'xml_present': False,
                       'retry': 'Parent reports this head superseded; no old-head Endings retry required.'},
    'whole_broad_acceptance': False,
    'limits': ['Parent reports warm/region benchmark guards are stale after the cold-lease repair; broad1 remains blocked/superseded pending corrected-source full broad2.',
               'The supplied job snapshot contains only 18 completed jobs. This audit makes no complete-24-job success claim.',
               'No Endings engine execution or XML exists in this attempt; its 106 cases are static prediction only.',
               'The Hospital rendered semantic audit and other rendered/performance/export components are separate; this report does not replace them.',
               'Passing fixtures and public byte inventories do not admit production Hospital prose, unexercised ingresses/conditions, all days, pair/ending continuity, graphical Windows or native accessibility.']}
out = OUT / 'hospital-broad1-suite-audit.json'
out.write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n')
rows = '\n'.join('| ' + name + ' | ' + str(info['cases']) + ' | ' + str(info['script_executions']) + ' |' for name, info in suites.items())
md = f'''# Broad1 ordinary suite and public evidence audit

**Bounded evidence passes: 12 available suites, 2,331 ordinary executions, 192 script executions, 2,327 unique script/test pairs and 191 unique scripts.** Every actual named multiset matches the recursively corrected source census; failures, errors, skips and disabled cases are zero. This is **not whole-run acceptance**.

Run `{RUN}`, attempt 1; actual checkout `{HEAD}`; runtime source `{SOURCE}`. All 12 successful jobs independently report the actual checkout immediately after `git log -1 --format=%H`. Each XML agrees with its exact `CLOUD_GUT_RESULT`, isolated exit-zero runner receipt and retained engine/import logs. Original ZIP digest, size, CRC and every retained extracted file match.

| Suite | Executed cases | Script executions |
|---|---:|---:|
{rows}
| Endings | Not executed (106 predicted) | Not executed (12 predicted) |

## Explicit census correction

The initial helper counted only methods declared in each fixture: full prediction 2,421 executions / 2,417 unique cases, Shop 128. Both `tests/scene/test_shop_card.gd` and `tests/scene/test_shop_plate.gd` extend `tests/unit/test_shop_catalog_projection.gd`, which extends `addons/gut/test.gd`. Each scene fixture inherits the same eight base tests, giving **Shop 144**, a corrected full prediction of **2,437 executions / 2,433 unique cases**, and 2,331 currently observed executions. No other suite prediction changes, including Endings 106.

`resolved-census.json` retains every suite/script/test, declaring source line, source hash and complete ancestry. The helper now resolves recursive inheritance with child overrides and refuses unknown bases. Initial helper/checklist/identity copies and the original manifest remain preserved. No product/test source was changed to fit a count.

## Public evidence

The actual job ran `Invoke-PublicSurfaceValidation.ps1 -EmitPayloads` once, without regeneration. Both emitted inventories equal their committed source bytes: GameState 568,948 bytes, SHA256 `804ca7f1bbe1b929b8c6ce59de390ab15c00f521ddc6290df1fed0a175157631`; SaveManager 151,143 bytes, SHA256 `ccb1a6e576801c4f62cd4c159e89a9e4d9c814cbcf364140c61fc2338365c4d0`. Both check-only receipts exit zero and each engine log contains one inventory PASS; one console receipt confirms canonical reproduction.

An independent scan of the actual checkout reproduces **all 908 records across 963 files**, including exact path, source line, text, family ordering and console records. Family memberships: 887 schema/version, eight historical Day3 seeds, seven BackupSnapshotFixture references, four older prepared fixtures and two empty-contacts literals. The older prepared references comprise an explicit current-schema fixture builder and three refusal/skip tests. Empty contacts appear in bounded attestation/composer inputs. These are observational references, not proof of production migration. A separate scan reproduces **954 files / ten retired symbols / zero references**.

## Exact intentional controls and standalone work

`negative-controls-subaudit.json` binds the independently reviewed control bytes, source and four Actions logs. The audit reopens both negative XMLs and their complete repository snapshots; it independently scans the ordinary new-account process log.

- Exactly two Settings refusal XMLs each contain **83 cases: 80 `test_root_missing` failures and three storage-free passes**, zero errors/skips; both children exit 1. All four complete repository snapshots are identical. These **166 intentional executions are excluded** from ordinary totals.
- Exactly one new-account `ff` invalid-UTF8 diagnostic belongs to `test_prepare_counts_nonempty_unreadable_autosave_but_not_zero_bytes`; one `CORRUPT_SAVE_DIAGNOSTIC_VERIFIED` receipt corroborates it. No other Unicode/NUL, script, parse or lifetime diagnostic is exempt.
- Public isolation records one `fixture-timeout`, exit 124, **20.025938 seconds**, with two retained nonempty logs. The source-bound `ISOLATION_HELPER: PASS` follows checks of four intentional forbidden argument/path exit-124 children and cleanup. Individual forbidden-child receipts are internal, so that part is source-bound PASS corroboration, not separately retained child receipts.
- Manual witness storage: one PASS, **61,180 assertions / 94 snapshots**, exit zero. Save/load capture: one PASS, **136 checks / zero failures**, exit zero. Latency: exactly fresh/replacement samples, `ok=true`, positive button-to-desktop times and nonnegative frame gaps. These assertions are excluded from GUT totals.

## Remaining limits

Endings job `110965240440` failed during **Install Godot 4.6.3 standard**, before test execution; no XML or GUT receipt exists. Its 106 cases remain predicted. Parent reports broad1 is superseded because warm/region benchmark guards need repair after the cold-lease change; corrected-source broad2 must supply its own complete evidence. This audit preserves component results and does not combine them into whole-run acceptance.

No engine, PowerShell, connector or remote calls were used. The full JSON binds source identities, original archive identities, every retained member, receipts, XML and log hashes. Rendered semantics, visual review, other performance/export components, production Hospital content and native accessibility remain outside this report.
'''
(OUT / 'hospital-broad1-suite-audit.md').write_text(md)
print(json.dumps({'json': ident(out), 'markdown': ident(OUT / 'hospital-broad1-suite-audit.md'), 'actual_totals': result['actual_totals']}, indent=2))
