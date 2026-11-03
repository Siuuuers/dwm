extends SceneTree

var failures := 0
var checks := 0

func check(value: bool, message: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error(message)

func peak(frames: PackedVector2Array) -> float:
    var result := 0.0
    for frame in frames:
        result = maxf(result, maxf(absf(frame.x), absf(frame.y)))
    return result

func stream_for(id: String) -> AudioStream:
    var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string('res://fixtures/manifest.json'))
    var cue: Dictionary = manifest.fixtures[id]
    return DwmNsfStream.create(FileAccess.get_file_as_bytes('res://fixtures/' + id + '.nsf'),
        cue.end_seconds, cue.intro_seconds, cue.loop_seconds)

func _initialize() -> void:
    var music := stream_for('loop_a')
    check(music != null, 'loop_a stream loads')
    if music == null:
        quit(1)
        return
    var a := music.instantiate_playback()
    var b := music.instantiate_playback()
    check(a != null and b != null and a != b, 'separate playback instances')
    a.start()
    b.start()
    var intro := a.mix_audio(1.0, 44100)
    check(intro == b.mix_audio(1.0, 44100), 'shared stream produces independent identical starts')
    check(peak(intro.slice(0, 13230)) < 0.0001, 'intentional initial silence is not skipped')
    check(peak(intro.slice(22050, 33075)) > 0.005, 'introduction follows initial silence')
    a.mix_audio(1.0, 44100)
    check(a.get_playback_position() > b.get_playback_position() + 0.9, 'advancing one player does not advance another')
    var interval := a.mix_audio(1.0, 44100 * 4)
    check(peak(interval.slice(44100 * 2, 44100 * 2 + 22050)) < 0.0001, 'authored full-pattern rest stays silent')
    check(peak(interval.slice(44100 * 3, 44100 * 3 + 22050)) > 0.005, 'music resumes after rest without ending')
    check(a.is_playing(), 'loop survives intentional silence')
    a.mix_audio(1.0, 44100 * 6)
    check(a.get_loop_count() == 3, 'loop count excludes introduction after multiple passes')
    check(a.get_playback_position() >= 12.0, 'position stays monotonic across loops')

    var finite := stream_for('confirm')
    var effect := finite.instantiate_playback()
    effect.start()
    var effect_pcm := effect.mix_audio(1.0, 44100)
    check(peak(effect_pcm) > 0.005, 'finite effect emits audio')
    check(not effect.is_playing(), 'finite effect finishes')
    check(absf(effect.get_playback_position() - finite.get_length()) < 1.0 / 44100.0, 'finite endpoint is sample rounded')
    check(peak(effect.mix_audio(1.0, 1024)) == 0.0, 'finished effect emits no later audio')

    var long_music := stream_for('loop_b')
    var sequential := long_music.instantiate_playback()
    sequential.start()
    var render_started := Time.get_ticks_usec()
    for second in 120:
        sequential.mix_audio(1.0, 44100)
    var render_us := Time.get_ticks_usec() - render_started
    var expected := sequential.mix_audio(1.0, 44100)
    var restored := long_music.instantiate_playback()
    var seek_started := Time.get_ticks_usec()
    restored.start(120.0)
    var seek_us := Time.get_ticks_usec() - seek_started
    var actual := restored.mix_audio(1.0, 44100)
    check(restored.is_playing(), 'long elapsed restoration starts')
    check(absf(restored.get_playback_position() - sequential.get_playback_position()) < 0.01, 'restored monotonic position matches sequential')
    var max_delta := 0.0
    var squared_delta := 0.0
    for index in range(4, 44100):
        var delta := actual[index] - expected[index]
        max_delta = maxf(max_delta, maxf(absf(delta.x), absf(delta.y)))
        squared_delta += delta.length_squared()
    var rms_delta := sqrt(squared_delta / (2.0 * (44100 - 4)))
    print('NSF_RESTORE render_120s_us=', render_us, ' seek_120s_us=', seek_us,
        ' pcm_max_delta_after_4frames=', max_delta, ' pcm_rms_delta_after_4frames=', rms_delta)
    check(max_delta == 0.0, 'restored waveform exactly matches sequential after interpolation history')
    print('NSF_NATIVE_CHECKS=', checks, ' FAILURES=', failures)
    quit(1 if failures else 0)
