extends RefCounted
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

static func scene_closure_outcome(record: Dictionary, targets: Dictionary) -> String:
	if record.is_empty(): return "never_started"
	if record.state == "in_progress": return "unfinished"
	if record.state == "won" and targets.has("perfect") and not perfect_reasons(record.board).is_empty():
		return "perfect"
	return str(record.state)
