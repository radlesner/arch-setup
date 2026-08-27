#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/notify.sh"

collect_valid_files "$@"

if [ "$total" -eq 0 ]; then
    notify_no_files \
        "Subtitle Extraction" \
        "No valid video files selected."
    exit 1
fi

success=true
count=0
failed=0

notification_id="subtitle-extraction"

for file in "${files[@]}"; do
    filename=$(basename "$file")
    basename="${file%.*}"

    subtitle_count=$(ffprobe -v error \
        -select_streams s \
        -show_entries stream=index \
        -of csv=p=0 \
        "$file" | wc -l)

    if [ "$subtitle_count" -eq 0 ]; then
        success=false
        ((failed++))

        notify_error \
            "Subtitle Extraction Failed" \
            "$filename\nNo subtitle streams found."

        echo "No subtitle streams: $filename"
        continue
    fi

    stream_number=0

    while IFS= read -r stream_index; do
        codec=$(ffprobe -v error \
            -select_streams "s:$stream_number" \
            -show_entries stream=codec_name \
            -of default=noprint_wrappers=1:nokey=1 \
            "$file")

        language=$(ffprobe -v error \
            -select_streams "s:$stream_number" \
            -show_entries stream_tags=language \
            -of default=noprint_wrappers=1:nokey=1 \
            "$file")

        title=$(ffprobe -v error \
            -select_streams "s:$stream_number" \
            -show_entries stream_tags=title \
            -of default=noprint_wrappers=1:nokey=1 \
            "$file")

        case "$codec" in
            subrip)
                extension="srt"
                ;;

            ass)
                extension="ass"
                ;;

            ssa)
                extension="ssa"
                ;;

            webvtt)
                extension="vtt"
                ;;

            mov_text)
                extension="srt"
                ;;

            *)
                extension="sub"
                ;;
        esac

        suffix="subtitle-$((stream_number + 1))"

        if [ -n "$language" ]; then
            suffix="${suffix}-${language}"
        fi

        if [ -n "$title" ]; then
            safe_title=$(echo "$title" | tr '/\\:*?"<>|' '_')
            suffix="${suffix}-${safe_title}"
        fi

        output="${basename}-${suffix}.${extension}"
        output=$(get_unique_filename "$output")

        notify_progress \
            "text-x-generic" \
            "$notification_id" \
            "Subtitle Extraction" \
            "[$((count + failed + 1))/$total] $filename\nSubtitle: $((stream_number + 1))/$subtitle_count"

        echo "Extracting subtitle stream $stream_index from $filename"
        echo "Codec: $codec"
        echo "Output: $(basename "$output")"

        if ffmpeg -hide_banner -loglevel warning \
            -i "$file" \
            -map "0:s:$stream_number" \
            -c:s copy \
            "$output"
        then
            ((count++))
        else
            ((failed++))
            success=false

            rm -f "$output"

            notify_error \
                "Subtitle Extraction Failed" \
                "$filename\nSubtitle stream: $((stream_number + 1))"
        fi

        ((stream_number++))

    done < <(
        ffprobe -v error \
            -select_streams s \
            -show_entries stream=index \
            -of csv=p=0 \
            "$file"
    )
done

if $success; then
    notify_success \
        "text-x-generic" \
        "Subtitle Extraction Complete" \
        "Successfully extracted $count subtitle stream(s)."
else
    notify_error \
        "Subtitle Extraction Finished" \
        "Extracted: $count   Failed: $failed"
fi
