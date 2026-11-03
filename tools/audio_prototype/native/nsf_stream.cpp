#include <godot_cpp/classes/audio_stream.hpp>
#include <godot_cpp/classes/audio_stream_playback_resampled.hpp>
#include <godot_cpp/classes/audio_frame.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <gme.h>
#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <cstring>

using namespace godot;

class DwmNsfPlayback : public AudioStreamPlaybackResampled {
    GDCLASS(DwmNsfPlayback, AudioStreamPlaybackResampled)
    Music_Emu *emulator = nullptr;
    std::array<short, 2048> samples{};
    std::atomic<int64_t> rendered{0};
    std::atomic<bool> active{false};
    int64_t end_frame = 0;
    int64_t intro_frame = 0;
    int64_t loop_frames = 0;
    static constexpr int sample_rate = 44100;
protected:
    static void _bind_methods() {}
public:
    ~DwmNsfPlayback() { if (emulator) gme_delete(emulator); }
    bool prepare(const PackedByteArray &payload, double duration, double intro, double loop) {
        if (gme_open_data(payload.ptr(), payload.size(), &emulator, sample_rate)) return false;
        gme_ignore_silence(emulator, 1);
        gme_set_autoload_playback_limit(emulator, 0);
        intro_frame = int64_t(std::llround(intro * sample_rate));
        loop_frames = int64_t(std::llround(loop * sample_rate));
        end_frame = duration > 0 ? int64_t(std::llround(duration * sample_rate)) : 0;
        return true;
    }
    void _start(double from_position) override {
        active.store(false);
        if (!emulator || !std::isfinite(from_position) || from_position < 0 ||
            from_position > 86400) return;
        if (gme_start_track(emulator, 0)) return;
        const auto frame = int64_t(std::llround(from_position * sample_rate));
        // libgme's fast seek skips oscillator/filter state; replay preserves the waveform.
        for (int64_t remaining = frame; remaining > 0;) {
            int count = int(std::min<int64_t>(remaining, samples.size() / 2));
            if (gme_play(emulator, count * 2, samples.data())) return;
            remaining -= count;
        }
        rendered.store(frame);
        active.store(end_frame == 0 || frame < end_frame);
        begin_resample();
    }
    void _stop() override { active.store(false); }
    bool _is_playing() const override { return active.load(); }
    double _get_playback_position() const override { return double(rendered.load()) / sample_rate; }
    int32_t _get_loop_count() const override {
        return loop_frames ? int32_t(std::max<int64_t>(0, rendered.load() - intro_frame) / loop_frames) : 0;
    }
    void _seek(double position) override { _start(position); }
    float _get_stream_sampling_rate() const override { return sample_rate; }
    int32_t _mix_resampled(AudioFrame *buffer, int32_t frame_count) override {
        int completed = 0;
        while (completed < frame_count && active.load()) {
            int count = std::min(frame_count - completed, int(samples.size() / 2));
            const auto position = rendered.load();
            if (end_frame) count = int(std::min<int64_t>(count, end_frame - position));
            if (count <= 0 || gme_play(emulator, count * 2, samples.data())) {
                active.store(false);
                break;
            }
            for (int i = 0; i < count; ++i) {
                buffer[completed + i].left = samples[i * 2] / 32768.0f;
                buffer[completed + i].right = samples[i * 2 + 1] / 32768.0f;
            }
            completed += count;
            rendered.store(position + count);
            if (end_frame && position + count >= end_frame) active.store(false);
        }
        for (int i = completed; i < frame_count; ++i) buffer[i] = AudioFrame{};
        return completed;
    }
};

class DwmNsfStream : public AudioStream {
    GDCLASS(DwmNsfStream, AudioStream)
    PackedByteArray payload;
    double duration = 0;
    double intro = 0;
    double loop = 0;
protected:
    static void _bind_methods() {
        ClassDB::bind_static_method("DwmNsfStream", D_METHOD("create", "payload", "duration_seconds", "intro_seconds", "loop_seconds"), &DwmNsfStream::create, DEFVAL(0.0), DEFVAL(0.0), DEFVAL(0.0));
    }
public:
    static Ref<DwmNsfStream> create(const PackedByteArray &bytes, double duration_seconds, double intro_seconds, double loop_seconds) {
        // Trusted build output only; the exporter owns score and sample-data validation.
        if (bytes.size() < 128 || std::memcmp(bytes.ptr(), "NESM\x1a", 5) != 0 ||
            bytes[6] != 1 || bytes[122] != 0 || bytes[123] != 1 ||
            !std::isfinite(duration_seconds) || duration_seconds < 0 || duration_seconds > 86400 ||
            !std::isfinite(intro_seconds) || intro_seconds < 0 || intro_seconds > 86400 ||
            !std::isfinite(loop_seconds) || loop_seconds < 0 || loop_seconds > 86400) return {};
        Ref<DwmNsfStream> stream;
        stream.instantiate();
        stream->payload = bytes;
        stream->duration = duration_seconds;
        stream->intro = intro_seconds;
        stream->loop = loop_seconds;
        return stream;
    }
    Ref<AudioStreamPlayback> _instantiate_playback() const override {
        Ref<DwmNsfPlayback> playback;
        playback.instantiate();
        if (!playback->prepare(payload, duration, intro, loop)) return {};
        return playback;
    }
    String _get_stream_name() const override { return "DWM NSF prototype"; }
    double _get_length() const override { return duration; }
    bool _is_monophonic() const override { return false; }
    bool _has_loop() const override { return duration == 0; }
};

static void initialize(ModuleInitializationLevel level) {
    if (level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
    ClassDB::register_class<DwmNsfPlayback>();
    ClassDB::register_class<DwmNsfStream>();
}
static void uninitialize(ModuleInitializationLevel) {}
extern "C" GDExtensionBool GDE_EXPORT dwm_nsf_init(GDExtensionInterfaceGetProcAddress get_proc_address,
        GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(get_proc_address, library, initialization);
    init.register_initializer(initialize);
    init.register_terminator(uninitialize);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
