extends RefCounted
## Dating dispositions and shared board classification; no relationship input changes performance.
const PERFORMANCE := preload("res://scripts/domain/minesweeper/BoardPerformance.gd")
const RNG := preload("res://scripts/domain/minesweeper/DeterministicRng32.gd")
const DISPOSITIONS := ["hatred", "upset", "amused"]

static func dispositions(spec: Dictionary, mine_count: int) -> Array:
	var rng: RefCounted = RNG.new()
	rng.seed(StringName(spec.explosion_stream_id), str(spec.explosion_nonce))
	var result: Array = []
	for _index in mine_count:
		var sampled: Dictionary = rng.sample_bounded(3)
		result.append(DISPOSITIONS[int(sampled.value.result)])
	return result

static func perfect_reasons(board: Dictionary) -> Array:
	return PERFORMANCE.perfect_reasons(board)

static func three_bv(board: Dictionary) -> int:
	return PERFORMANCE.three_bv(board)
