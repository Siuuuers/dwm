class_name CryptoDesktopNamespaceSource
extends RefCounted


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
