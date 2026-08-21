extends "res://addons/gut/test.gd"

# Deterministic xorshift32-v1 RNG suite (Plan 02 Task 3, dwm-p2r13). Reference vectors were
# computed independently in Python (sha256 seed derivation + masked xorshift32) and baked into
# tests/fixtures/minesweeper/rng_reference_vectors.v1.json; see task-3-report.md for the
# Python-vs-GDScript cross-check evidence.

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const RNG := preload("res://scripts/domain/minesweeper/DeterministicRng32.gd")

const FIXTURE_PATH := "res://tests/fixtures/minesweeper/rng_reference_vectors.v1.json"

var _fixture: Dictionary


func before_each() -> void:
	_fixture = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_PATH))


func _rng() -> RefCounted:
	return RNG.new()


# ---- Step 3.1 parse proof ----

func test_rng_script_loads() -> void:
	var loaded: Dictionary = PROBE.load_script("res://scripts/domain/minesweeper/DeterministicRng32.gd")
	assert_true(loaded.get("ok", false), "DeterministicRng32.gd must load")


# ---- seed() basics ----

func test_seed_rejects_blank_stream_id() -> void:
	var rng := _rng()
	var result: Dictionary = rng.seed(&"", "nonce")
	assert_false(result.get("ok", true), "blank stream_id must reject")


func test_calls_before_seed_reject_not_seeded() -> void:
	assert_false(_rng().next_u32().get("ok", true), "next_u32 before seed rejects")
	assert_false(_rng().sample_bounded(5).get("ok", true), "sample_bounded before seed rejects")
	assert_false(_rng().capture().get("ok", true), "capture before seed rejects")
	assert_false(_rng().prepare_restore({}).get("ok", true), "prepare_restore before seed rejects")


# ---- reference vector: zero-normalized nonce ----

func test_first_32_words_zero_normalized_nonce() -> void:
	var vector: Dictionary = _fixture["zero_normalized_nonce"]
	var rng := _rng()
	var seeded: Dictionary = rng.seed(StringName(vector["stream_id"]), String(vector["nonce"]))
	assert_true(seeded.get("ok", false), JSON.stringify(seeded))
	assert_eq(seeded["value"]["state"], int(vector["seed_word"]), "seed_word must match the reference")
	_assert_words_match(rng, vector["first_32_words"])


# ---- reference vector: ASCII nonce ----

func test_first_32_words_ascii_nonce() -> void:
	var vector: Dictionary = _fixture["ascii_nonce"]
	var rng := _rng()
	rng.seed(StringName(vector["stream_id"]), String(vector["nonce"]))
	_assert_words_match(rng, vector["first_32_words"])


# ---- reference vector: Unicode nonce ----

func test_first_32_words_unicode_nonce() -> void:
	var vector: Dictionary = _fixture["unicode_nonce"]
	var rng := _rng()
	rng.seed(StringName(vector["stream_id"]), String(vector["nonce"]))
	_assert_words_match(rng, vector["first_32_words"])


func _assert_words_match(rng: RefCounted, expected_words: Array) -> void:
	for index in range(expected_words.size()):
		var drawn: Dictionary = rng.next_u32()
		assert_true(drawn.get("ok", false), JSON.stringify(drawn))
		assert_eq(drawn["value"]["word"], int(expected_words[index]), "word #%d mismatch" % index)


# ---- zero-state replacement (direct, independent of a real sha256 preimage search --
# see task-3-report.md for why a real (stream_id, nonce) collision to hex8 "00000000" is
# computationally infeasible to search for within test time) ----

func test_zero_state_replacement_direct() -> void:
	var vector: Dictionary = _fixture["zero_state_replacement"]
	var replaced: int = RNG._seed_word_from_hex8(String(vector["hex8"]))
	assert_eq(replaced, int(vector["replaced_word"]), "hex8 \"00000000\" must replace to 0x6D2B79F5")
	assert_ne(int(vector["parsed_word_before_replacement"]), replaced,
		"the raw parsed word before replacement is zero, distinct from the replacement")


func test_zero_state_replacement_word_stream() -> void:
	var vector: Dictionary = _fixture["zero_state_replacement"]
	var expected_words: Array = vector["first_8_words_from_replaced_state"]
	# Round-trip the replaced word back through prepare_restore() to prove the production
	# next_u32() pipeline reproduces the same stream once state==0x6D2B79F5, without requiring
	# a real sha256 preimage that hashes to hex8 "00000000".
	var rng := _rng()
	rng.seed(&"minesweeper_placement_v1", "prepare-restore-anchor")
	var restored: Dictionary = rng.prepare_restore({
		"algorithm": RNG.ALGORITHM, "stream_id": &"minesweeper_placement_v1",
		"nonce": "prepare-restore-anchor", "state": int(vector["replaced_word"]), "draw_count": 0,
	})
	assert_true(restored.get("ok", false), JSON.stringify(restored))
	_assert_words_match(rng, expected_words)


func test_seed_word_from_hex8_parses_nonzero_hex_without_replacement() -> void:
	assert_eq(RNG._seed_word_from_hex8("000000ff"), 255)
	assert_eq(RNG._seed_word_from_hex8("ffffffff"), 4294967295)


# ---- domain separation across the three official streams ----

func test_domain_separation_produces_distinct_first_words() -> void:
	var separation: Dictionary = _fixture["domain_separation"]
	var rngs: Dictionary = {}
	for stream_id: String in separation.keys():
		var vector: Dictionary = separation[stream_id]
		var rng := _rng()
		rng.seed(StringName(stream_id), String(vector["nonce"]))
		rngs[stream_id] = rng
		_assert_words_match(rng, vector["first_8_words"])

	var seed_words: Dictionary = {}
	for stream_id: String in separation.keys():
		seed_words[stream_id] = int(separation[stream_id]["seed_word"])
	var values: Array = seed_words.values()
	assert_ne(values[0], values[1], "distinct streams must not share a seed word")
	assert_ne(values[1], values[2], "distinct streams must not share a seed word")
	assert_ne(values[0], values[2], "distinct streams must not share a seed word")


func test_advancing_one_stream_leaves_the_others_captured_bytes_unchanged() -> void:
	var separation: Dictionary = _fixture["domain_separation"]
	var stream_ids: Array = separation.keys()
	var instances: Dictionary = {}
	for stream_id: String in stream_ids:
		var rng := _rng()
		rng.seed(StringName(stream_id), String(separation[stream_id]["nonce"]))
		instances[stream_id] = rng

	var before_a: Dictionary = (instances[stream_ids[1]] as RefCounted).capture()
	var before_b: Dictionary = (instances[stream_ids[2]] as RefCounted).capture()

	(instances[stream_ids[0]] as RefCounted).next_u32()
	(instances[stream_ids[0]] as RefCounted).next_u32()
	(instances[stream_ids[0]] as RefCounted).sample_bounded(7)

	var after_a: Dictionary = (instances[stream_ids[1]] as RefCounted).capture()
	var after_b: Dictionary = (instances[stream_ids[2]] as RefCounted).capture()
	assert_eq(before_a["value"], after_a["value"], "advancing one stream must not touch a sibling stream")
	assert_eq(before_b["value"], after_b["value"], "advancing one stream must not touch a sibling stream")


# ---- reduced 8-bit equal-frequency sampler reference (proves the rejection-sampling formula
# limit=floor(domain/n)*n, result=word%n is exactly unbiased at a fully enumerable scale) ----

func test_reduced_8bit_sampler_is_exactly_equal_frequency() -> void:
	var reduced: Dictionary = _fixture["reduced_8bit_sampler"]
	for bound_key: String in reduced.keys():
		var n := int(bound_key)
		var expected: Dictionary = reduced[bound_key]
		var domain_size := int(expected["domain_size"])
		var expected_limit := int(expected["limit"])
		var limit: int = (domain_size / n) * n
		assert_eq(limit, expected_limit, "limit formula mismatch for n=%d" % n)
		var counts: Dictionary = {}
		for result in range(n):
			counts[str(result)] = 0
		for word in range(domain_size):
			if word < limit:
				var result := word % n
				counts[str(result)] = int(counts[str(result)]) + 1
		var expected_counts: Dictionary = expected["counts"]
		for result_key: String in counts.keys():
			assert_eq(int(counts[result_key]), int(expected_counts[result_key]),
				"equal-frequency mismatch for n=%d result=%s" % [n, result_key])
		var expected_count_each: int = limit / n
		for result_key: String in counts.keys():
			assert_eq(counts[result_key], expected_count_each, "n=%d result=%s frequency" % [n, result_key])


# ---- sample_bounded() behavioral coverage against a real xorshift32 stream ----

func test_sample_bounded_matches_reference_stream_bound_5() -> void:
	var vector: Dictionary = _fixture["ascii_nonce"]
	var expected: Array = _fixture["bounded_samples"]["ascii_nonce_bound_5"]
	var rng := _rng()
	rng.seed(StringName(vector["stream_id"]), String(vector["nonce"]))
	for index in range(expected.size()):
		var drawn: Dictionary = rng.sample_bounded(5)
		assert_true(drawn.get("ok", false), JSON.stringify(drawn))
		assert_eq(drawn["value"]["result"], int(expected[index]), "bounded result #%d mismatch" % index)


func test_sample_bounded_matches_reference_stream_bound_7() -> void:
	var vector: Dictionary = _fixture["ascii_nonce"]
	var expected: Array = _fixture["bounded_samples"]["ascii_nonce_bound_7"]
	var rng := _rng()
	rng.seed(StringName(vector["stream_id"]), String(vector["nonce"]))
	for index in range(expected.size()):
		var drawn: Dictionary = rng.sample_bounded(7)
		assert_true(drawn.get("ok", false), JSON.stringify(drawn))
		assert_eq(drawn["value"]["result"], int(expected[index]), "bounded result #%d mismatch" % index)


func test_sample_bounded_rejects_non_positive_bounds() -> void:
	var rng := _rng()
	rng.seed(&"minesweeper_placement_v1", "bound-check")
	assert_false(rng.sample_bounded(0).get("ok", true), "bound 0 rejects")
	assert_false(rng.sample_bounded(-1).get("ok", true), "negative bound rejects")


func test_sample_bounded_never_uses_engine_rng() -> void:
	# The production implementation must derive every draw from next_u32()'s masked xorshift32
	# state alone; determinism across two independently-seeded instances is the observable proof
	# that no randi()/RandomNumberGenerator/global RNG state leaked in.
	var a := _rng()
	var b := _rng()
	a.seed(&"minesweeper_placement_v1", "determinism-check")
	b.seed(&"minesweeper_placement_v1", "determinism-check")
	for _i in range(10):
		assert_eq(a.sample_bounded(9)["value"]["result"], b.sample_bounded(9)["value"]["result"])


# ---- capture() / prepare_restore() ----

func test_capture_returns_exact_five_member_shape() -> void:
	var rng := _rng()
	rng.seed(&"minesweeper_placement_v1", "capture-shape")
	rng.next_u32()
	var captured: Dictionary = rng.capture()
	assert_true(captured.get("ok", false), JSON.stringify(captured))
	var value: Dictionary = captured["value"]
	assert_eq(value.keys(), ["algorithm", "stream_id", "nonce", "state", "draw_count"])
	assert_eq(value["algorithm"], RNG.ALGORITHM)
	assert_eq(value["draw_count"], 1)


func test_prepare_restore_round_trips_exactly() -> void:
	var original := _rng()
	original.seed(&"minesweeper_placement_v1", "round-trip")
	original.next_u32()
	original.next_u32()
	original.next_u32()
	var checkpoint: Dictionary = original.capture()["value"]
	var expected_next: Dictionary = original.next_u32()
	var expected_next_2: Dictionary = original.next_u32()

	var resumed := _rng()
	resumed.seed(&"minesweeper_placement_v1", "round-trip")
	var restored: Dictionary = resumed.prepare_restore(checkpoint)
	assert_true(restored.get("ok", false), JSON.stringify(restored))
	assert_eq(restored["value"], checkpoint)
	assert_eq(resumed.next_u32()["value"], expected_next["value"])
	assert_eq(resumed.next_u32()["value"], expected_next_2["value"])


func test_prepare_restore_rejects_a_state_under_another_stream_id_even_with_matching_numeric_state() -> void:
	var instance_a := _rng()
	instance_a.seed(&"minesweeper_placement_v1", "cross-stream-nonce")
	instance_a.next_u32()
	var captured_a: Dictionary = instance_a.capture()["value"]

	# Forge a captured state that carries a DIFFERENT stream_id but the SAME numeric state and
	# nonce as a legitimately captured stream-A checkpoint.
	var forged: Dictionary = captured_a.duplicate(true)
	forged["stream_id"] = &"minesweeper_debug_v1"

	var restore_attempt: Dictionary = instance_a.prepare_restore(forged)
	assert_false(restore_attempt.get("ok", true),
		"restoring a state whose declared stream_id differs from the instance's own stream must reject")
	assert_eq(restore_attempt.get("code"), &"rng_state_stream_mismatch")


func test_prepare_restore_rejects_a_state_under_another_nonce() -> void:
	var instance_a := _rng()
	instance_a.seed(&"minesweeper_placement_v1", "nonce-a")
	var captured_a: Dictionary = instance_a.capture()["value"]
	var forged: Dictionary = captured_a.duplicate(true)
	forged["nonce"] = "nonce-b"
	var restore_attempt: Dictionary = instance_a.prepare_restore(forged)
	assert_false(restore_attempt.get("ok", true))
	assert_eq(restore_attempt.get("code"), &"rng_state_nonce_mismatch")


func test_prepare_restore_rejects_wrong_algorithm() -> void:
	var rng := _rng()
	rng.seed(&"minesweeper_placement_v1", "algo-check")
	var captured: Dictionary = rng.capture()["value"]
	var forged: Dictionary = captured.duplicate(true)
	forged["algorithm"] = &"xorshift32-v2"
	var restore_attempt: Dictionary = rng.prepare_restore(forged)
	assert_false(restore_attempt.get("ok", true))
	assert_eq(restore_attempt.get("code"), &"rng_state_algorithm_mismatch")


func test_prepare_restore_rejects_malformed_shape() -> void:
	var rng := _rng()
	rng.seed(&"minesweeper_placement_v1", "shape-check")
	var captured: Dictionary = rng.capture()["value"]

	var missing_key: Dictionary = captured.duplicate(true)
	missing_key.erase("draw_count")
	assert_false(rng.prepare_restore(missing_key).get("ok", true), "missing member rejects")

	var extra_key: Dictionary = captured.duplicate(true)
	extra_key["extra"] = 1
	assert_false(rng.prepare_restore(extra_key).get("ok", true), "extra member rejects")

	var bad_word: Dictionary = captured.duplicate(true)
	bad_word["state"] = -1
	assert_false(rng.prepare_restore(bad_word).get("ok", true), "negative state word rejects")

	var overflow_word: Dictionary = captured.duplicate(true)
	overflow_word["state"] = 4294967296
	assert_false(rng.prepare_restore(overflow_word).get("ok", true), "state word above 0xFFFFFFFF rejects")

	var bad_draw_count: Dictionary = captured.duplicate(true)
	bad_draw_count["draw_count"] = -1
	assert_false(rng.prepare_restore(bad_draw_count).get("ok", true), "negative draw_count rejects")


func test_seeding_twice_with_the_same_identity_is_fully_deterministic() -> void:
	var a := _rng()
	var b := _rng()
	a.seed(&"minesweeper_placement_v1", "same-identity")
	b.seed(&"minesweeper_placement_v1", "same-identity")
	for _i in range(16):
		assert_eq(a.next_u32()["value"]["word"], b.next_u32()["value"]["word"])
