#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/notify.sh"

collect_valid_files "$@"

if [ "$total" -eq 0 ]; then
    notify_no_files \
        "Spectrum Generation" \
        "No valid files to process."
    exit 1
fi

success=true
count=0
failed=0

notification_id="spectrum-generation"

for file in "${files[@]}"; do
    output="${file%.*}-spectrum.png"
    output=$(get_unique_filename "$output")

    filename=$(basename "$file")

    echo "Generating spectrum: $filename"

    notify_progress \
        "image-x-generic" \
        "$notification_id" \
        "Spectrum Generation" \
        "[$((count + failed + 1))/$total] $filename"

    if ffmpeg -hide_banner -loglevel warning \
        -i "$file" \
        -lavfi "showspectrumpic=s=2400x1400:legend=1:scale=log" \
        "$output"
    then
        ((count++))
    else
        ((failed++))
        success=false

        notify_error \
            "Spectrum Generation Failed" \
            "$filename"
    fi
done

if $success; then
    notify_success \
        "emblem-ok" \
        "Spectrum Generation Complete" \
        "Successfully generated $count spectrum image(s)."
else
    notify_error \
        "Spectrum Generation Finished" \
        "Generated: $count   Failed: $failed"
fi
