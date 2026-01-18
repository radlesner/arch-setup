#!/bin/bash

video=""
audio=""

for file in "$@"; do
    if ffprobe -v error -select_streams v -show_entries stream=codec_type -of csv=p=0 "$file" | grep -q video; then
        video="$file"
    elif ffprobe -v error -select_streams a -show_entries stream=codec_type -of csv=p=0 "$file" | grep -q audio; then
        audio="$file"
    fi
done

if [[ -z "$video" || -z "$audio" ]]; then
    notify-send "Merge failed" "Select one video-only and one audio-only file"
    exit 1
fi

output="${video%.*}_merged.mp4"

ffmpeg -y -i "$video" -i "$audio" -c copy -map 0:v:0 -map 1:a:0 -shortest "$output"

notify-send "Merge complete" "Created: $output"
