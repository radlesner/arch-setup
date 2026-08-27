#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/notify.sh"

collect_valid_files "$@"

if [ "$total" -eq 0 ]; then
    notify_no_files \
        "Cover Extraction" \
        "No valid files to process."
    exit 1
fi

success=true
count=0
failed=0

notification_id="cover-extraction"

for file in "${files[@]}"; do
    dir="$(dirname "$file")"
    output="$dir/cover.jpg"
    output=$(get_unique_filename "$output")

    filename=$(basename "$file")

    echo "Extracting cover: $filename"

    notify_progress \
        "image-x-generic" \
        "$notification_id" \
        "Cover Extraction" \
        "[$((count + failed + 1))/$total] $filename"

    if ffmpeg -hide_banner -loglevel warning \
        -i "$file" \
        -map 0:v:0 \
        -frames:v 1 \
        -q:v 2 \
        "$output"
    then
        ((count++))
    else
        ((failed++))
        success=false

        rm -f "$output"

        notify_error \
            "Cover Extraction Failed" \
            "$filename"
    fi
done

if $success; then
    notify_success \
        "emblem-ok" \
        "Cover Extraction Complete" \
        "Successfully extracted $count cover image(s)."
else
    notify_error \
        "Cover Extraction Finished" \
        "Extracted: $count   Failed: $failed"
fi