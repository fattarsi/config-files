#!/usr/bin/env bash
set -e

AUDIO=/tmp/whisper_input.wav
TEXT=/tmp/whisper_out.txt
MODEL=~/projects/whisper.cpp/models/ggml-base.en.bin
WHISPER=~/projects/whisper.cpp/build/bin/whisper-cli

# Record 10 seconds max, stop on silence
echo "Recording..."
notify-send "Recording..."
sox -d -r 16000 -c 1 -b 16 $AUDIO \
  silence 1 0.1 5% 1 2.5 5% trim 0 120

# Transcribe
echo "Transcribing..."
notify-send "Transcribing..."
$WHISPER -m "$MODEL" -f "$AUDIO" --no-timestamps --language en > "$TEXT"

# Extract text line
RESULT=$(<"$TEXT")   # or: RESULT=$(cat "$TEXT")
RESULT="${RESULT#"${RESULT%%[![:space:]]*}"}"  # trim leading whitespace
RESULT="${RESULT%"${RESULT##*[![:space:]]}"}"  # trim trailing whitespace

echo "TRANSCRIPTION: $RESULT"

# Copy to clipboard
echo "Copying to clipboard..."
printf "%s" "$RESULT" | xclip -selection clipboard

# Paste into focused window
xdotool key ctrl+v

