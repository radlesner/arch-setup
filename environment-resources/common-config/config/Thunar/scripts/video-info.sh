#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/notify.sh"

collect_valid_files "$@"

if [ "$total" -eq 0 ]; then
    notify_no_files \
        "Video Information" \
        "No valid video files to analyze."
    exit 1
fi

success=true
count=0
failed=0

notification_id="video-info"

for file in "${files[@]}"; do
    output="${file%.*}-video-info.txt"
    output=$(get_unique_filename "$output")

    filename=$(basename "$file")

    echo "Analyzing: $filename"

    notify_progress \
        "video-x-generic" \
        "$notification_id" \
        "Video Information" \
        "[$((count + failed + 1))/$total] $filename"

    format=$(ffprobe -v error \
        -show_entries format=format_name \
        -of default=noprint_wrappers=1:nokey=1 \
        "$file")

    format_long=$(ffprobe -v error \
        -show_entries format=format_long_name \
        -of default=noprint_wrappers=1:nokey=1 \
        "$file")

    duration=$(ffprobe -v error \
        -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 \
        "$file")

    bitrate=$(ffprobe -v error \
        -show_entries format=bit_rate \
        -of default=noprint_wrappers=1:nokey=1 \
        "$file")

    size=$(stat -c '%s' "$file")

    video_streams=$(ffprobe -v error \
        -select_streams v \
        -show_entries stream=index,codec_name,codec_long_name,width,height,r_frame_rate,bit_rate,pix_fmt \
        -of default=noprint_wrappers=1 \
        "$file")

    audio_streams=$(ffprobe -v error \
        -select_streams a \
        -show_entries stream=index,codec_name,codec_long_name,sample_rate,channels,channel_layout,bit_rate \
        -of default=noprint_wrappers=1 \
        "$file")

    subtitle_streams=$(ffprobe -v error \
        -select_streams s \
        -show_entries stream=index,codec_name,codec_long_name:stream_tags=language,title \
        -of default=noprint_wrappers=1 \
        "$file")

    if [ -z "$format" ]; then
        echo "Failed: $filename"

        ((failed++))
        success=false
        continue
    fi

    duration_formatted=$(awk -v duration="$duration" '
        BEGIN {
            total = int(duration)
            hours = int(total / 3600)
            minutes = int((total % 3600) / 60)
            seconds = total % 60

            if (hours > 0)
                printf "%02d:%02d:%02d", hours, minutes, seconds
            else
                printf "%02d:%02d", minutes, seconds
        }
    ')

    bitrate_formatted=$(awk -v bitrate="$bitrate" '
        BEGIN {
            if (bitrate > 0)
                printf "%.0f kb/s", bitrate / 1000
            else
                printf "N/A"
        }
    ')

    size_mb=$(awk -v size="$size" '
        BEGIN {
            printf "%.2f MB", size / 1024 / 1024
        }
    ')

    {
        echo "# Video Information"
        echo
        echo "File:          $(basename "$file")"
        echo "Format:        $format"
        echo "Container:     $format_long"
        echo "Duration:      $duration_formatted"
        echo "Bitrate:       $bitrate_formatted"
        echo "File size:     $size_mb"
        echo

        echo "## Video Streams"
        echo

        if [ -n "$video_streams" ]; then
            echo "$video_streams"
        else
            echo "No video streams."
        fi

        echo
        echo "## Audio Streams"
        echo

        if [ -n "$audio_streams" ]; then
            echo "$audio_streams"
        else
            echo "No audio streams."
        fi

        echo
        echo "## Subtitle Streams"
        echo

        if [ -n "$subtitle_streams" ]; then
            echo "$subtitle_streams"
        else
            echo "No subtitle streams."
        fi

        echo
        echo "## Metadata"
        echo

        ffprobe -v error \
            -show_entries format_tags \
            -of default=noprint_wrappers=1 \
            "$file"

    } > "$output"

    if [ $? -eq 0 ]; then
        ((count++))
        echo "Created: $output"
    else
        ((failed++))
        success=false
        echo "Failed to create report: $output"
    fi
done

if $success; then
    notify_success \
        "video-x-generic" \
        "Video Information Complete" \
        "Successfully created $count report(s)."
else
    notify_error \
        "Video Information Finished" \
        "Created: $count   Failed: $failed"
fi
