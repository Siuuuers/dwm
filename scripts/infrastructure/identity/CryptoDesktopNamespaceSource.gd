class_name CryptoDesktopNamespaceSource
extends RefCounted

## Production cryptographic namespace source for the desktop issuer root (Plan 02 Task 1,
## dwm-p2r.16).
##
## Mints the root namespace with an owned `Crypto` instance: 32 fresh bytes rendered as 64 lowercase
## hex characters, matching the plan's own `_issuer_with_namespace("11".repeat(32), 7)` fixture. Plan
## line 1682 requires exactly this, and `DesktopIssuerRootStore` persists the value before counter 1
## is ever issued.
##
## SOLE REVIEWED EXCEPTION. Step 1.4 sweeps this entire directory for identity fallbacks: engine
## clock reads, global pseudo-random helpers, and object-handle values pressed into service as
## identity. This file is the one path permitted to mint fresh entropy, so it is reviewed directly
## rather than excluded from the sweep -- dwm-p2r.16 DECISION 12.13 verified that the sweep does
## cover it and that the owned cryptographic call below matches none of its patterns.
##
## This header DESCRIBES those patterns instead of quoting them. DECISION 12.14 found that the
## earlier wording spelled all four out verbatim, which made a GREEN gate fail on prose rather than
## on code; DECISION 13.6 binds the present phrasing.
##
## The plan declares no interface for this class. Its single method is derived from the only frozen
## consumer call site, `DesktopIssuerRootStore.configure(storage, namespace_source)`, under
## dwm-p2r.16 DECISION 8.5. The success envelope carries the bare 64-character lowercase-hex String
## in `value`, matching `FakeDesktopNamespaceSource` and the `TemporaryStorage.create()` precedent.

## 32 bytes is the plan-frozen width; `hex_encode()` renders it as the 64 lowercase hex characters
## the root document stores.
const NAMESPACE_BYTE_LENGTH := 32


func generate_namespace() -> Dictionary:
	var crypto := Crypto.new()
	var bytes: PackedByteArray = crypto.generate_random_bytes(NAMESPACE_BYTE_LENGTH)
	if bytes.size() != NAMESPACE_BYTE_LENGTH:
		return {
			"ok": false,
			"code": &"namespace_entropy_unavailable",
			"message": "CryptoDesktopNamespaceSource.generate_namespace produced %d of %d bytes" % [
				bytes.size(), NAMESPACE_BYTE_LENGTH,
			],
		}
	return {"ok": true, "value": bytes.hex_encode()}
