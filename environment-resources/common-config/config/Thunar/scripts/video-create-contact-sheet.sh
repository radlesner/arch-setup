#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/notify.sh"

collect_valid_files "$@"

if [ "$total" -eq 0 ]; then
    notify_no_files \
        "Contact Sheet" \
        "No valid video files selected."
    exit 1
fi

success=true
count=0
failed=0

notification_id="contact-sheet"

for file in "${files[@]}"; do
    output="${file%.*}-contact-sheet.jpg"
    output=$(get_unique_filename "$output")

    filename=$(basename "$file")

    echo "Creating contact sheet: $filename"

    notify_progress \
        "image-x-generic" \
        "$notification_id" \
        "Contact Sheet" \
        "[$((count + failed + 1))/$total] $filename"

    # Get video duration
    duration=$(ffprobe -v error \
        -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 \
        "$file")

    if [ -z "$duration" ] || ! [[ "$duration" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        ((failed++))
        success=false

        notify_error \
            "Contact Sheet Failed" \
            "$filename"

        continue
    fi

    # Number of thumbnails
    frame_count=16

    # Temporary directory
    temp_dir=$(mktemp -d)

    frame_failed=false

    # Keep thumbnails away from the very beginning/end.
    interval=$(awk "BEGIN { print $duration / ($frame_count + 1) }")

    echo "Duration: ${duration}s"
    echo "Generating $frame_count thumbnails..."

    # Generate thumbnails.
    #
    # -ss before -i       = fast input seeking
    # -noaccurate_seek     = don't decode from keyframe to exact timestamp
    # -frames:v 1          = decode only one frame
    #
    # Four thumbnails are generated simultaneously.
    max_parallel=4
    running=0

    for ((i=1; i<=frame_count; i++)); do
        timestamp=$(awk "BEGIN { print $interval * $i }")

        frame="$temp_dir/frame-$(printf '%02d' "$i").jpg"

        ffmpeg -hide_banner -loglevel error \
            -ss "$timestamp" \
            -noaccurate_seek \
            -i "$file" \
            -frames:v 1 \
            -vf "scale=480:-1" \
            -q:v 3 \
            "$frame" &

        ((running++))

        if [ "$running" -ge "$max_parallel" ]; then
            wait || frame_failed=true
            running=0
        fi
    done

    # Wait for remaining jobs
    if [ "$running" -gt 0 ]; then
        wait || frame_failed=true
    fi

    if $frame_failed; then
        ((failed++))
        success=false

        rm -rf "$temp_dir"

        notify_error \
            "Contact Sheet Failed" \
            "$filename"

        continue
    fi

    # Check that all thumbnails were created
    thumbnail_count=$(find "$temp_dir" -type f -name 'frame-*.jpg' | wc -l)

    if [ "$thumbnail_count" -ne "$frame_count" ]; then
        ((failed++))
        success=false

        rm -rf "$temp_dir"

        notify_error \
            "Contact Sheet Failed" \
            "$filename"

        continue
    fi

    # Assemble contact sheet
    if ffmpeg -hide_banner -loglevel error \
        -framerate 1 \
        -i "$temp_dir/frame-%02d.jpg" \
        -vf "tile=4x4:padding=4:margin=4" \
        -frames:v 1 \
        -q:v 3 \
        "$output"
    then
        ((count++))
    else
        ((failed++))
        success=false

        rm -f "$output"

        notify_error \
            "Contact Sheet Failed" \
            "$filename"
    fi

    rm -rf "$temp_dir"
done

if $success; then
    notify_success \
        "image-x-generic" \
        "Contact Sheet Complete" \
        "Successfully created $count contact sheet(s)."
else
    notify_error \
        "Contact Sheet Finished" \
        "Created: $count   Failed: $failed"
fi
