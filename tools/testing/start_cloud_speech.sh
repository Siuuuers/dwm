#!/usr/bin/env bash
# Real Linux TTS dependencies for rendered cloud journeys. This verifies voice
# enumeration, not audible output or Windows accessibility acceptance.
# Godot 4.6 requires Speech Dispatcher on Linux:
# https://docs.godotengine.org/en/4.6/tutorials/audio/text_to_speech.html
set -euo pipefail

dwm_speech_root="${RUNNER_TEMP:?}/dwm-cloud-speech"
dwm_speech_output="${GITHUB_WORKSPACE:?}/.godot/ci/cloud-speech"
mkdir -p "$dwm_speech_root" "$dwm_speech_output"
cp -a /etc/speech-dispatcher "$dwm_speech_root/config"
cat >> "$dwm_speech_root/config/speechd.conf" <<'CONFIG'
AudioOutputMethod "pulse"
DefaultModule espeak-ng
CONFIG

# Give the native synthesizer a real software audio endpoint on this runner.
# No speech backend is replaced and the game's own voice capability is retained.
pulseaudio --start --exit-idle-time=-1 --log-target="file:$dwm_speech_output/pulseaudio.log"
pactl load-module module-null-sink sink_name=dwm_ci > "$dwm_speech_output/sink-module.txt"
pactl set-default-sink dwm_ci
pactl list short sinks > "$dwm_speech_output/sinks.txt"

export SPEECHD_ADDRESS="unix_socket:$dwm_speech_root/speechd.sock"
speech-dispatcher --run-daemon --timeout 0 \
  --communication-method unix_socket --socket-path "$dwm_speech_root/speechd.sock" \
  --pid-file "$dwm_speech_root/speechd.pid" \
  --config-dir "$dwm_speech_root/config" --log-dir "$dwm_speech_output"
python3 - "$dwm_speech_output" <<'PY'
from pathlib import Path
import re
import subprocess
import sys
import time

output = Path(sys.argv[1])
deadline = time.monotonic() + 45
attempt = 0
while time.monotonic() < deadline:
    attempt += 1
    try:
        result = subprocess.run(["spd-say", "--list-synthesis-voices"],
                                capture_output=True, text=True, errors="replace",
                                timeout=min(5, deadline - time.monotonic()))
        (output / "voices.txt").write_text(result.stdout)
        (output / f"voices-attempt-{attempt}.stderr.txt").write_text(result.stderr)
        rows = [line.split() for line in result.stdout.splitlines()]
        voices = [row for row in rows if len(row) >= 2
                  and any(re.fullmatch(r"[a-z]{2,3}(?:[-_][A-Za-z0-9]+)*", field)
                          for field in row[1:])]
        if result.returncode == 0 and voices:
            print(f"CLOUD_SPEECH_NATIVE_VOICES count={len(voices)} attempts={attempt}")
            break
    except subprocess.TimeoutExpired:
        (output / f"voices-attempt-{attempt}.stderr.txt").write_text("Voice query timed out.\n")
    time.sleep(min(0.5, max(0, deadline - time.monotonic())))
else:
    raise SystemExit("CLOUD_SPEECH_NO_NATIVE_VOICES")
PY
timeout 30 spd-say --list-output-modules > "$dwm_speech_output/modules.txt"
printf 'SPEECHD_ADDRESS=%s\n' "$SPEECHD_ADDRESS" >> "${GITHUB_ENV:?}"
