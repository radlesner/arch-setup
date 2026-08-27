#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/notify.sh"

collect_valid_files "$@"

if [ "$total" -eq 0 ]; then
    notify_no_files \
        "Audio Information" \
        "No valid files to analyze."
    exit 1
fi

success=true
count=0
failed=0

notification_id="audio-info"

for file in "${files[@]}"; do
    output="${file%.*}-audio-info.txt"
    output=$(get_unique_filename "$output")

    filename=$(basename "$file")

    echo "Analyzing: $filename"

    notify_progress \
        "audio-x-generic" \
        "$notification_id" \
        "Audio Information" \
        "[$((count + failed + 1))/$total] $filename"

    format=$(ffprobe -v error \
        -show_entries format=format_name \
        -of default=noprint_wrappers=1:nokey=1 \
        "$file")

    codec=$(ffprobe -v error \
        -select_streams a:0 \
        -show_entries stream=codec_name \
        -of default=noprint_wrappers=1:nokey=1 \
        "$file")

    duration=$(ffprobe -v error \
        -select_streams a:0 \
        -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 \
        "$file")

    sample_rate=$(ffprobe -v error \
        -select_streams a:0 \
        -show_entries stream=sample_rate \
        -of default=noprint_wrappers=1:nokey=1 \
        "$file")

    channels=$(ffprobe -v error \
        -select_streams a:0 \
        -show_entries stream=channels \
        -of default=noprint_wrappers=1:nokey=1 \
        "$file")

    channel_layout=$(ffprobe -v error \
        -select_streams a:0 \
        -show_entries stream=channel_layout \
        -of default=noprint_wrappers=1:nokey=1 \
        "$file")

    bit_depth=$(ffprobe -v error \
        -select_streams a:0 \
        -show_entries stream=bits_per_raw_sample \
        -of default=noprint_wrappers=1:nokey=1 \
        "$file")

    bitrate=$(ffprobe -v error \
        -show_entries format=bit_rate \
        -of default=noprint_wrappers=1:nokey=1 \
        "$file")

    size=$(stat -c '%s' "$file")

    if [ -z "$format" ] || [ -z "$codec" ]; then
        echo "Failed: $filename"

        ((failed++))
        success=false
        continue
    fi

    sample_rate_khz=$(awk "BEGIN {printf \"%.1f\", $sample_rate / 1000}")

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

    bitrate_kbps=$(awk -v bitrate="$bitrate" '
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

    case "$channels" in
        1) channels_text="Mono" ;;
        2) channels_text="Stereo" ;;
        *) channels_text="$channels channels" ;;
    esac

    case "$format" in
        flac)
            format_name="FLAC"
            ;;

        wav)
            format_name="WAV"
            ;;

        mp3)
            format_name="MP3"
            ;;

        *)
            format_name="$format"
            ;;
    esac

    {
        echo "Audio Information"
        echo
        echo "File:          $(basename "$file")"
        echo "Format:        $format_name"
        echo "Codec:         $codec"
        echo "Duration:      $duration_formatted"
        echo "Sample rate:   $sample_rate_khz kHz"

        if [ -n "$bit_depth" ]; then
            echo "Bit depth:     ${bit_depth}-bit"
        fi

        echo "Channels:      $channels_text"

        if [ -n "$channel_layout" ]; then
            echo "Layout:        $channel_layout"
        fi

        echo "Bitrate:       $bitrate_kbps"
        echo "File size:     $size_mb"
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
        "audio-x-generic" \
        "Audio Information Complete" \
        "Successfully created $count report(s)."
else
    notify_error \
        "Audio Information Finished" \
        "Created: $count   Failed: $failed"
fi
