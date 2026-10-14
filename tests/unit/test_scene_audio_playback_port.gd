extends "res://addons/gut/test.gd"
## Native start-position proof using a silent seekable WAV; no audible output.

const PORT = preload("res://scripts/audio/AudioPlaybackPort.gd")
const FAKE = preload("res://tests/support/FakeAudioPlaybackPort.gd")
const PLAYER: StringName = &"SceneAudioPositionFixture"

var _port: RefCounted


func before_each() -> void:
	_port = PORT.new()
	assert_true(_port.ensure_player(PLAYER, &"Master").get("ok", false))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = 4 * stream.mix_rate
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(stream.loop_end * 2)
	stream.data = bytes
	assert_true(_port.assign_stream(PLAYER, stream).get("ok", false))


func after_each() -> void:
	var runtime: Node = _port.get("_root")
	if is_instance_valid(runtime):
		runtime.free()
	_port = null


func test_legacy_one_argument_play_starts_at_zero() -> void:
	assert_true(_port.play(PLAYER).get("ok", false))
	var player: AudioStreamPlayer = _port.get("_players")[PLAYER]
	player.stream_paused = true
	assert_true(player.has_stream_playback())
	assert_almost_eq(player.get_playback_position(), 0.0, 0.1)


func test_explicit_load_anchor_starts_native_playback_at_one_second() -> void:
	assert_true(_port.play(PLAYER, 1.0).get("ok", false))
	var player: AudioStreamPlayer = _port.get("_players")[PLAYER]
	player.stream_paused = true
	assert_true(player.has_stream_playback())
	assert_almost_eq(player.get_playback_position(), 1.0, 0.1,
		"the real seekable stream starts at the authored anchor, not its entrance")


func test_invalid_positions_preserve_native_playback_without_restart() -> void:
	assert_true(_port.play(PLAYER, 1.0).get("ok", false))
	var player: AudioStreamPlayer = _port.get("_players")[PLAYER]
	player.stream_paused = true
	var playback: AudioStreamPlayback = player.get_stream_playback()
	var stream: AudioStream = player.stream
	var position: float = player.get_playback_position()
	var invalid_positions: Array[float] = [-0.01, INF, -INF, NAN]
	for invalid: float in invalid_positions:
		var result: Dictionary = _port.play(PLAYER, invalid)
		assert_false(result.get("ok", true))
		assert_eq(result.get("code"), &"invalid_audio_runtime")
		assert_same(player.get_stream_playback(), playback)
		assert_same(player.stream, stream)
		assert_true(player.stream_paused)
		assert_eq(player.get_playback_position(), position)


func test_fake_records_default_and_explicit_positions_and_refuses_invalid_input() -> void:
	var fake: RefCounted = FAKE.new()
	assert_true(fake.ensure_player(PLAYER, &"Master").get("ok", false))
	assert_true(fake.play(PLAYER).get("ok", false))
	assert_eq(fake.players[PLAYER].playback_position, 0.0)
	assert_eq(fake.operations.back().arguments.from_position, 0.0)
	assert_true(fake.play(PLAYER, 1.0).get("ok", false))
	assert_eq(fake.players[PLAYER].playback_position, 1.0)
	assert_eq(fake.operations.back().arguments.from_position, 1.0)
	var players: Dictionary = fake.players.duplicate(true)
	var operation_count: int = fake.operations.size()
	var invalid_positions: Array[float] = [-0.01, INF, -INF, NAN]
	for invalid: float in invalid_positions:
		assert_false(fake.play(PLAYER, invalid).get("ok", true))
		assert_eq(fake.players, players)
		assert_eq(fake.operations.size(), operation_count)
