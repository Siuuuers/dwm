#!/usr/bin/env python3
"""Apply diagnostic-only timing to a disposable DWM checkout; never product source.

Run with an explicit checkout path. Refuses already-instrumented source. The JSON
manifest records original and instrumented SHA256 for every touched source.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

HELPER_PATH = 'scripts/narrative/DiagnosticSaveTiming.gd'
HELPER = '''extends RefCounted
# Diagnostic controller only. Exclusive totals partition instrumented call time;
# inclusive totals overlap. Neither replaces complete Save/Load measurements.
static var _active := false
static var _stack: Array = []
static var _totals: Dictionary = {}
static var _root_parents: Dictionary = {}
static var _context: Dictionary = {}

static func begin_scope(operation: String, state: String, stage: String, step: int) -> void:
\t_active = true
\t_stack = []
\t_totals = {}
\t_root_parents = {}
\t_context = {"operation": operation, "state": state, "stage": stage, "step": step}

static func enter(kind: String) -> int:
\tif not _active: return -1
\tvar parent := "outside_instrumented_methods" if _stack.is_empty() else str(_stack.back().kind)
\t_stack.append({"kind": kind, "children_us": 0, "parent": parent})
\treturn Time.get_ticks_usec()

static func leave(kind: String, started: int, ok: bool) -> void:
\tif started < 0: return
\tvar elapsed := Time.get_ticks_usec() - started
\tvar frame: Dictionary = _stack.pop_back()
\tassert(frame.kind == kind)
\tif not _stack.is_empty(): _stack.back().children_us += elapsed
\tif not _totals.has(kind):
\t\t_totals[kind] = {"calls": 0, "inclusive_us": 0, "exclusive_us": 0, "failures": 0}
\tvar total: Dictionary = _totals[kind]
\ttotal.calls += 1
\ttotal.inclusive_us += elapsed
\ttotal.exclusive_us += elapsed - int(frame.children_us)
\tif not ok: total.failures += 1
\tif kind == "root_capture":
\t\tif not _root_parents.has(frame.parent): _root_parents[frame.parent] = {"calls": 0, "us": 0}
\t\t_root_parents[frame.parent].calls += 1
\t\t_root_parents[frame.parent].us += elapsed

static func end_scope(ok: bool) -> void:
\tassert(_stack.is_empty())
\t_active = false
\tprint("DWM_SAVE_DIAGNOSTIC " + JSON.stringify({"context": _context, "ok": ok,
\t\t"timings": _totals, "root_capture_parent": _root_parents,
\t\t"note": "diagnostic overhead present; inclusive timings overlap; exclusive timings omit uninstrumented outer work"}))
'''

TARGETS = {
    'scripts/domain/narrative/SceneEventContract.gd': [
        ('_validate_scene_receipts_registered', 'receipt_ledger', 'receipts, bundle, registered, issuer, creation_owner, contacts, selected_registration'),
        ('_validate_committed_initial_admission', 'committed_initial_admission', 'receipt, registered, issuer, creation_owner'),
        ('_validate_initial_materials', 'initial_materials', 'candidate, profile, issuer'),
        ('_validate_scene_initial_admission_registered', 'initial_reconstruction', 'receipt, allocation_candidate, profile_material, registered, issuer'),
    ],
    'autoload/SaveManager.gd': [
        ('capture_committed_scene_creation', 'committed_creation_proof', 'transaction_id'),
    ],
    'scripts/application/desktop/DesktopIdentityNonceIssuer.gd': [
        ('_resolve_parent', 'issuer_parent_lookup', 'parent_receipt_id'),
    ],
    'scripts/infrastructure/identity/DesktopIssuerRootStore.gd': [
        ('capture', 'root_capture', ''),
    ],
}

def sha(content):
    return hashlib.sha256(content).hexdigest()

def add_preload(text):
    text, count = re.subn(r'(?m)^(extends [^\n]+)\n',
                         r'\1\nconst _DIAGNOSTIC_TIMING := preload("res://' + HELPER_PATH + '")\n',
                         text, count=1)
    assert count == 1, 'exact extends declaration required'
    return text

def instrument(root):
    changes = {}
    for path, methods in TARGETS.items():
        before = (root / path).read_bytes()
        text = before.decode()
        assert '_DIAGNOSTIC_TIMING' not in text, f'already instrumented: {path}'
        text = add_preload(text)
        for name, kind, args in methods:
            pattern = r'(?m)^((?:static )?func )' + re.escape(name) + r'(\([^)]*\) -> Dictionary:)\n'
            matches = list(re.finditer(pattern, text))
            assert len(matches) == 1, (path, name, len(matches))
            m = matches[0]
            wrapper = (m.group(0) + '\tvar diagnostic_started: int = _DIAGNOSTIC_TIMING.enter("' + kind + '")\n'
                       + '\tvar diagnostic_result: Dictionary = ' + name + '_diagnostic_body(' + args + ')\n'
                       + '\t_DIAGNOSTIC_TIMING.leave("' + kind + '", diagnostic_started, bool(diagnostic_result.get("ok", false)))\n'
                       + '\treturn diagnostic_result\n\n'
                       + m.group(1) + name + '_diagnostic_body' + m.group(2) + '\n')
            text = text[:m.start()] + wrapper + text[m.end():]
        changes[path] = (before, text.encode())
    path = 'scripts/narrative/SceneValidationTiming.gd'
    before = (root / path).read_bytes()
    text = before.decode()
    assert '_DIAGNOSTIC_TIMING' not in text
    text = add_preload(text)
    assert text.count('\t_active = true\n') == 1
    text = text.replace('\t_active = true\n', '\t_active = true\n\t_DIAGNOSTIC_TIMING.begin_scope(operation, state, stage, step)\n')
    assert text.count('\t_active = false\n') == 1
    text = text.replace('\t_active = false\n', '\t_DIAGNOSTIC_TIMING.end_scope(ok)\n\t_active = false\n')
    changes[path] = (before, text.encode())
    assert not (root / HELPER_PATH).exists()
    changes[HELPER_PATH] = (b'', HELPER.encode())
    return changes

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('checkout', type=Path)
    parser.add_argument('--apply', action='store_true', help='write diagnostic sources; omit for validation-only')
    args = parser.parse_args()
    changes = instrument(args.checkout)
    manifest = {p: {'before_sha256': sha(a), 'after_sha256': sha(b), 'bytes': len(b)} for p, (a, b) in changes.items()}
    if args.apply:
        for p, (_, after) in changes.items():
            (args.checkout / p).write_bytes(after)
    print(json.dumps({'applied': args.apply, 'files': manifest}, indent=2))

if __name__ == '__main__':
    main()
