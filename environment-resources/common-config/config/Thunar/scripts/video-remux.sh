#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/notify.sh"

target="$1"
shift

case "$target" in
    mp4)
        extension="mp4"
        format="MP4"
        ;;

    mkv)
        extension="mkv"
        format="Matroska"
        ;;

    webm)
        extension="webm"
        format="WebM"
        ;;

    *)
        notify_error \
            "Video Remux Error" \
            "Unknown target container: $target"
        exit 1
        ;;
esac

collect_valid_files "$@"

if [ "$total" -eq 0 ]; then
    notify_no_files \
        "Video Remux" \
        "No valid video files to process."
    exit 1
fi

success=true
count=0
failed=0

notification_id="video-remux"

for file in "${files[@]}"; do
    output="${file%.*}.${extension}"
    output=$(get_unique_filename "$output")

    filename=$(basename "$file")

    echo "Remuxing: $filename → $(basename "$output")"

    notify_progress \
        "video-x-generic" \
        "$notification_id" \
        "Video Remux" \
        "$format\n[$((count + failed + 1))/$total] $filename"

    if ffmpeg -hide_banner -loglevel warning \
        -i "$file" \
        -map 0 \
        -c copy \
        "$output"
    then
        ((count++))
    else
        ((failed++))
        success=false

        rm -f "$output"

        notify_error \
            "Video Remux Failed" \
            "$filename"
    fi
done

if $success; then
    notify_success \
        "video-x-generic" \
        "Video Remux Complete" \
        "$format\nSuccessfully remuxed $count file(s)."
else
    notify_error \
        "Video Remux Finished" \
        "$format\nRemuxed: $count   Failed: $failed"
fi
