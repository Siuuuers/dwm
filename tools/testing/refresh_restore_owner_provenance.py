"""Reproduce the finite reviewed current-owner inverse, never a runtime migration.

Run from repository root: python tools/testing/refresh_restore_owner_provenance.py
Use --write to replace only the existing inverse helper. This deliberately pins
one reviewed owner; a future owner requires a new explicit provenance review.
"""
import argparse
import difflib
import hashlib
import json
import pathlib
import subprocess

SOURCE = '7d2db1fb05a5b298f9fc14b47cdf3a5b6f890e7e'
ACCEPTED = '23d8b3dfdd63948549af318917df5f4a84ac5120'
SOURCE_HASH = 'fd26d735c2c5ffa62aefdb5ca56ddd08985da5f4534c327f5c7237acb286f3b9'
ACCEPTED_HASH = '6cbd8f935e2fb6c02db5e78cbafd915d5cd2971712d061c5d9e8f336bbea100f'
OWNER = 'autoload/GameState.gd'
TEST = 'tests/integration/test_run_restore_isolation.gd'

def git_bytes(ref, path):
    return subprocess.check_output(['git', 'show', ref + ':' + path]).replace(b'\r\n', b'\n')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    parser.add_argument('--report', type=pathlib.Path)
    args = parser.parse_args()
    current, accepted = git_bytes(SOURCE, OWNER), git_bytes(ACCEPTED, OWNER)
    assert hashlib.sha256(current).hexdigest() == SOURCE_HASH
    assert hashlib.sha256(accepted).hexdigest() == ACCEPTED_HASH
    assert pathlib.Path(OWNER).read_bytes().replace(b'\r\n', b'\n') == current
    a, b = current.splitlines(keepends=True), accepted.splitlines(keepends=True)
    # One unchanged boundary line makes every replacement a nonempty span,
    # including historical insertions, under the existing helper's strict bounds.
    groups = []
    for tag, i, j, k, l in difflib.SequenceMatcher(None, a, b, autojunk=False).get_opcodes():
        if tag == 'equal':
            continue
        if i and k:
            i -= 1
            k -= 1
        if j < len(a) and l < len(b):
            j += 1
            l += 1
        if groups and i <= groups[-1][1]:
            groups[-1][1] = max(j, groups[-1][1])
            groups[-1][3] = max(l, groups[-1][3])
        else:
            groups.append([i, j, k, l])
    spans = [[len(b''.join(a[:i])), len(b''.join(a[:j])), b''.join(b[k:l]).decode()] for i,j,k,l in groups]
    assert len(spans) == 21
    result, cursor = b'', 0
    for start, end, replacement in spans:
        assert cursor <= start < end <= len(current)
        result += current[cursor:start] + replacement.encode()
        cursor = end
    result += current[cursor:]
    assert result == accepted
    baseline = git_bytes(SOURCE, TEST).decode()
    begin = baseline.index('func _without_authenticated_scene_composition(')
    end = baseline.index('\n\nfunc ', begin)
    helper = baseline[begin:end]
    helper = helper.replace("# Fixed inverse of d1d8313's owner to the accepted 23d8b3df owner.",
                            '# Fixed inverse of reviewed 7d2db1fb owner to accepted 23d8b3df.')
    hash_start = helper.index('\tconst CURRENT_SHA256 := ')
    hash_end = helper.index('\n', hash_start)
    helper = helper[:hash_start] + '\tconst CURRENT_SHA256 := "' + SOURCE_HASH + '"' + helper[hash_end:]
    span_start = helper.index('\tconst SPANS := [')
    span_end = helper.index('\n\t]', span_start) + len('\n\t]')
    declaration = '\tconst SPANS := [\n' + ''.join('\t\t' + json.dumps(row, ensure_ascii=False) + ',\n' for row in spans) + '\t]'
    helper = helper[:span_start] + declaration + helper[span_end:]
    expected = baseline[:begin] + helper + baseline[end:]
    actual = pathlib.Path(TEST).read_text(encoding='utf-8')
    actual_begin = actual.index('func _without_authenticated_scene_composition(')
    actual_end = actual.index('\n\nfunc ', actual_begin)
    assert actual[:actual_begin] == baseline[:begin] and actual[actual_end:] == baseline[end:], 'historical layers or test bodies changed'
    if args.write:
        pathlib.Path(TEST).write_text(expected, encoding='utf-8', newline='\n')
    else:
        assert actual == expected, 'finite helper requires explicit --write regeneration'
    report = {'source_commit': SOURCE, 'accepted_commit': ACCEPTED,
              'source_sha256': SOURCE_HASH, 'accepted_sha256': ACCEPTED_HASH,
              'source_bytes': len(current), 'accepted_bytes': len(accepted),
              'span_count': len(spans), 'spans': spans,
              'removed_bytes': sum(end-start for start,end,_ in spans),
              'replacement_bytes': sum(len(value.encode()) for _,_,value in spans),
              'byte_exact_reconstruction': result == accepted,
              'unchanged_historical_layers_and_test_bodies': True}
    if args.report:
        args.report.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k != 'spans'}))

if __name__ == '__main__':
    main()
