#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/notify.sh"

timestamp="00:00:05"

# If first argument looks like a timestamp, use it.
# Otherwise treat all arguments as video files.
if [[ "$1" =~ ^[0-9]+(:[0-9]{2}){1,2}([.][0-9]+)?$ ]]; then
    timestamp="$1"
    shift
fi

collect_valid_files "$@"

if [ "$total" -eq 0 ]; then
    notify_no_files \
        "Frame Extraction" \
        "No valid video files selected."
    exit 1
fi

success=true
count=0
failed=0

notification_id="frame-extraction"

for file in "${files[@]}"; do
    output="${file%.*}-frame.png"
    output=$(get_unique_filename "$output")

    filename=$(basename "$file")

    echo "Extracting frame: $filename"
    echo "Timestamp: $timestamp"

    notify_progress \
        "image-x-generic" \
        "$notification_id" \
        "Frame Extraction" \
        "[$((count + failed + 1))/$total] $filename\nTime: $timestamp"

    if ffmpeg -hide_banner -loglevel warning \
        -ss "$timestamp" \
        -noaccurate_seek \
        -i "$file" \
        -frames:v 1 \
        "$output"
    then
        ((count++))
    else
        ((failed++))
        success=false

        rm -f "$output"

        notify_error \
            "Frame Extraction Failed" \
            "$filename\nTimestamp: $timestamp"
    fi
done

if $success; then
    notify_success \
        "image-x-generic" \
        "Frame Extraction Complete" \
        "Successfully extracted $count frame(s)."
else
    notify_error \
        "Frame Extraction Finished" \
        "Extracted: $count   Failed: $failed"
fi