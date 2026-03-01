#!/usr/bin/env bash
set -e

AUDIO=/tmp/whisper_input.wav
TEXT=/tmp/whisper_out.txt
MODEL=~/projects/whisper.cpp/models/ggml-base.en.bin
WHISPER=~/projects/whisper.cpp/build/bin/whisper-cli
PIDFILE=/tmp/whisper_rec.pid

# Toggle: if already recording, stop and transcribe
if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    rm -f "$PIDFILE"

    # Stop recording (SIGINT so sox writes a valid WAV header)
    if kill -0 "$PID" 2>/dev/null; then
        kill -INT "$PID"
        # Wait for sox to finish writing the WAV header
        tail --pid="$PID" -f /dev/null 2>/dev/null
    fi

    # Transcribe
    notify-send "Transcribing..."
    $WHISPER -m "$MODEL" -f "$AUDIO" --no-timestamps --language en > "$TEXT"

    # Extract and trim text
    RESULT=$(<"$TEXT")
    RESULT="${RESULT#"${RESULT%%[![:space:]]*}"}"
    RESULT="${RESULT%"${RESULT##*[![:space:]]}"}"

    # Copy to clipboard and paste
    printf "%s" "$RESULT" | xclip -selection clipboard
    xdotool key ctrl+v
else
    # Start recording in background
    notify-send "Recording... (press Super+Shift+S to stop)"
    setsid sox -t alsa default -r 16000 -c 1 -b 16 "$AUDIO" trim 0 120 &
    echo $! > "$PIDFILE"
fi
