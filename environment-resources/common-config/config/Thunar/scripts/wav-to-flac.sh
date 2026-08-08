#!/bin/bash

success=true
count=0

for file in "$@"; do
    [ -f "$file" ] || continue

    output="${file%.*}.flac"

    echo "Converting: $(basename "$file")"

    if ffmpeg -hide_banner -loglevel warning \
        -i "$file" \
        -c:a flac \
        -compression_level 8 \
        -map_metadata 0 \
        "$output"
    then
        ((count++))
    else
        success=false
    fi
done

if $success; then
    notify-send -i audio-x-flac \
        "Conversion Complete" \
        "Successfully converted $count file(s) to FLAC."
else
    notify-send -u critical -i dialog-error \
        "Conversion Failed" \
        "One or more files could not be converted. Check the terminal for details."
fi