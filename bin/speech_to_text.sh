#!/usr/bin/env bash
set -e

AUDIO=/tmp/whisper_input.wav
TEXT=/tmp/whisper_out.txt
MODEL=~/projects/whisper.cpp/models/ggml-base.en.bin
WHISPER=~/projects/whisper.cpp/build/bin/whisper-cli
PIDFILE=/tmp/whisper_rec.pid
WINFILE=/tmp/whisper_win.id

# File mode: convert and transcribe a file, output to stdout
if [ -n "$1" ]; then
    ffmpeg -y -i "$1" -ar 16000 -ac 1 "$AUDIO" 2>/dev/null
    $WHISPER -m "$MODEL" -f "$AUDIO" --no-timestamps --language en 2>/dev/null \
        | sed 's/^[[:space:]]*//' | sed '/^$/d'
    exit 0
fi

# Toggle: if already recording, stop and transcribe
if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    rm -f "$PIDFILE"
    TARGET_WIN=$(cat "$WINFILE" 2>/dev/null || true)
    rm -f "$WINFILE"

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

    # Copy to clipboard
    printf "%s" "$RESULT" | xclip -selection clipboard

    # Auto-paste for GUI apps, just notify for terminals
    WM_CLASS=$(xdotool getwindowclassname "$TARGET_WIN" 2>/dev/null || true)
    case "$WM_CLASS" in
        *terminal*|*Terminal*|*alacritty*|*kitty*|*konsole*|*xterm*|*tmux*)
            notify-send "Text copied to clipboard" "$RESULT" ;;
        *)
            if [ -n "$TARGET_WIN" ]; then
                xdotool windowactivate --sync "$TARGET_WIN"
            fi
            xdotool key ctrl+v ;;
    esac
else
    # Save the focused window so we can return to it after transcription
    xdotool getactivewindow > "$WINFILE" 2>/dev/null || true

    # Start recording in background
    notify-send "Recording... (press Super+Shift+S to stop)"
    setsid sox -t alsa default -r 16000 -c 1 -b 16 "$AUDIO" trim 0 120 &
    echo $! > "$PIDFILE"
fi
