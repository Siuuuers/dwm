class_name FakeDesktopNamespaceSource
extends RefCounted

## Test double for CryptoDesktopNamespaceSource (Plan 02 Task 1, dwm-p2r.16).
##
## Duck-typed `extends RefCounted` rather than inheriting the production class, matching all 13
## existing tests/support fakes (dwm-p2r.16 DECISION 8.5). Full working body per DECISION 9.2: a
## behavioral test that fails because the FAKE is unimplemented proves nothing, so the only reason
## a Step 1.1 behavioral assertion may fail is that production is still a skeleton.
##
## The plan declares no interface for this class. Its single method is derived from the only frozen
## consumer call site, `DesktopIssuerRootStore.configure(storage, namespace_source)`. The success
## value is the bare 64-character lowercase-hex String rather than a wrapper Dictionary, following
## the `TemporaryStorage.create()` precedent of returning a bare String in `value`.
##
## The seed is 64 lowercase hex characters, per the plan's own
## `_issuer_with_namespace("11".repeat(32), 7)` fixture.

const NAMESPACE_HEX_LENGTH := 64

var namespace_hex: String = ""

## Spy surface. `generate_calls` proves the root store obtains a namespace EXACTLY once and never
## reconstructs one later (plan line 535: a new namespace "is obtained only from the injected
## cryptographic namespace source, persisted before counter 1 is issued, and never reconstructed
## from a clock or global RNG").
var generate_calls: int = 0

var _armed_failure_code: StringName = &""


func _init(seed_namespace_hex: String = "") -> void:
	namespace_hex = seed_namespace_hex


## Arms this and every later call to fail, so the root store's behavior when it cannot obtain a
## namespace is observable. The code is a fake-local invention and MUST NOT be asserted as though
## it were a frozen production code (dwm-p2r.16 DECISION 9.9).
func fail_with(code: StringName = &"fake_namespace_source_unavailable") -> void:
	_armed_failure_code = code


func generate_namespace() -> Dictionary:
	generate_calls += 1
	if _armed_failure_code != &"":
		return {
			"ok": false,
			"code": _armed_failure_code,
			"message": "FakeDesktopNamespaceSource armed failure",
		}
	return {"ok": true, "value": namespace_hex}
