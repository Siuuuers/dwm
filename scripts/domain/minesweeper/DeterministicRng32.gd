class_name DeterministicRng32
extends RefCounted

## xorshift32-v1 deterministic RNG (Plan 02 Task 3, dwm-p2r13). Seeds from the first eight
## lowercase SHA-256 hex digits of `stream_id + "\n" + nonce`; a zero result is replaced with
## 0x6D2B79F5 so a stream can never start in the degenerate all-zero orbit (xorshift's transform
## fixes 0 to 0 forever). Every draw masks to 32 bits after each xor/shift. Never uses
## randi()/RandomNumberGenerator/global RNG state -- every word comes from this instance's own
## masked xorshift32 state alone.

const ALGORITHM := &"xorshift32-v1"

const _MASK_32 := 0xFFFFFFFF
const _ZERO_REPLACEMENT := 0x6D2B79F5
const _CAPTURE_KEYS := ["algorithm", "stream_id", "nonce", "state", "draw_count"]

var _seeded := false
var _stream_id: StringName = &""
var _nonce: String = ""
var _state: int = 0
var _draw_count: int = 0


func seed(stream_id: StringName, nonce: String) -> Dictionary:
	if String(stream_id).strip_edges().is_empty():
		return _fail(&"invalid_stream_id", "stream_id must be nonblank", {})
	var digest: String = (String(stream_id) + "\n" + nonce).sha256_text()
	var word: int = _seed_word_from_hex8(digest.substr(0, 8))
	_seeded = true
	_stream_id = stream_id
	_nonce = nonce
	_state = word
	_draw_count = 0
	return {"ok": true, "code": &"ok", "value": capture()["value"], "receipt": {}}


func next_u32() -> Dictionary:
	if not _seeded:
		return _fail(&"rng_not_seeded", "seed() must be called before next_u32()", {})
	var x: int = _state
	x = (x ^ (x << 13)) & _MASK_32
	x = (x ^ (x >> 17)) & _MASK_32
	x = (x ^ (x << 5)) & _MASK_32
	_state = x
	_draw_count += 1
	return {"ok": true, "code": &"ok", "value": {"word": x}, "receipt": {}}


func sample_bounded(exclusive_max: int) -> Dictionary:
	if not _seeded:
		return _fail(&"rng_not_seeded", "seed() must be called before sample_bounded()", {})
	if exclusive_max < 1:
		return _fail(&"invalid_bound", "exclusive_max must be >= 1", {"exclusive_max": exclusive_max})
	var limit: int = (4294967296 / exclusive_max) * exclusive_max
	while true:
		var drawn := next_u32()
		if not drawn.get("ok", false):
			return drawn
		var word: int = (drawn["value"] as Dictionary)["word"]
		if word < limit:
			return {"ok": true, "code": &"ok", "value": {"result": word % exclusive_max}, "receipt": {}}
	return _fail(&"unreachable", "sample_bounded rejection loop must always return from within the loop", {})


func capture() -> Dictionary:
	if not _seeded:
		return _fail(&"rng_not_seeded", "seed() must be called before capture()", {})
	return {"ok": true, "code": &"ok", "value": {
		"algorithm": ALGORITHM, "stream_id": _stream_id, "nonce": _nonce,
		"state": _state, "draw_count": _draw_count,
	}, "receipt": {}}


## Restores this instance's progress from a previously captured state. The captured state's
## declared {algorithm, stream_id, nonce} must exactly match this instance's own identity
## (established by seed()) -- a state captured under a different stream_id or nonce is rejected
## even when its numeric `state` word happens to match, so one stream's checkpoint can never be
## smuggled in to continue a different stream's generation.
func prepare_restore(state: Dictionary) -> Dictionary:
	if not _seeded:
		return _fail(&"rng_not_seeded", "seed() must be called before prepare_restore()", {})
	var shape := _exact_keys(state)
	if not shape.get("ok", false):
		return shape
	if StringName(state["algorithm"]) != ALGORITHM:
		return _fail(&"rng_state_algorithm_mismatch", "captured state algorithm does not match", {})
	if StringName(state["stream_id"]) != _stream_id:
		return _fail(&"rng_state_stream_mismatch",
			"captured state belongs to a different stream_id than this instance's own", {})
	if String(state["nonce"]) != _nonce:
		return _fail(&"rng_state_nonce_mismatch",
			"captured state belongs to a different nonce than this instance's own", {})
	var word: Variant = state["state"]
	if typeof(word) != TYPE_INT or int(word) < 0 or int(word) > _MASK_32:
		return _fail(&"rng_state_word_invalid", "captured state word must be an integer in 0..0xFFFFFFFF", {})
	var draw_count: Variant = state["draw_count"]
	if typeof(draw_count) != TYPE_INT or int(draw_count) < 0:
		return _fail(&"rng_state_draw_count_invalid", "captured draw_count must be a nonnegative integer", {})
	_state = int(word)
	_draw_count = int(draw_count)
	return {"ok": true, "code": &"ok", "value": capture()["value"], "receipt": {}}


## Parses an 8-hex-digit slice into its unsigned 32-bit seed word, replacing an all-zero result
## with 0x6D2B79F5. Factored out so the zero-replacement branch is directly testable without
## needing a real sha256 preimage that collides to hex8 "00000000" (an ~2^32-expected-trial
## search; see task-3-report.md).
static func _seed_word_from_hex8(hex8: String) -> int:
	var word: int = ("0x" + hex8).hex_to_int()
	if word == 0:
		return _ZERO_REPLACEMENT
	return word


func _exact_keys(state: Dictionary) -> Dictionary:
	if state.size() != _CAPTURE_KEYS.size():
		return _fail(&"rng_state_shape_invalid",
			"captured state must have exactly %d members" % _CAPTURE_KEYS.size(), {"size": state.size()})
	for key: String in _CAPTURE_KEYS:
		if not state.has(key):
			return _fail(&"rng_state_shape_invalid", "missing member: %s" % key, {"missing": key})
	return {"ok": true}


func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
