#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/notify.sh"

notify_progress \
    "video-x-generic" \
    "merge-media" \
    "Merging media files" \
    "Detecting selected video and audio files..."

video=""
audio=""

for file in "$@"; do
    if ffprobe -v error \
        -select_streams v \
        -show_entries stream=codec_type \
        -of csv=p=0 \
        "$file" | grep -q video
    then
        video="$file"

    elif ffprobe -v error \
        -select_streams a \
        -show_entries stream=codec_type \
        -of csv=p=0 \
        "$file" | grep -q audio
    then
        audio="$file"
    fi
done

if [[ -z "$video" || -z "$audio" ]]; then
    notify_error \
        "Merge failed" \
        "Select one video-only and one audio-only file"
    exit 1
fi

output="${video%.*}_merged.mp4"
output=$(get_unique_filename "$output")

if ffmpeg -y \
    -i "$video" \
    -i "$audio" \
    -c copy \
    -map 0:v:0 \
    -map 1:a:0 \
    -shortest \
    "$output"
then
    notify_success \
        "emblem-ok" \
        "Merge complete" \
        "Created: $output"
else
    rm -f "$output"

    notify_error \
        "Merge failed" \
        "Unable to merge the selected video and audio."
    exit 1
fi
