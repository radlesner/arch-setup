#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/notify.sh"

mode="$1"
shift

case "$mode" in
    wav-flac-16)
        codec=(-c:a flac -sample_fmt s16 -compression_level 8)
        description="WAV → FLAC (16-bit)"
        icon="audio-x-flac"
        ;;

    wav-flac-24)
        codec=(-c:a flac -sample_fmt s32 -compression_level 8)
        description="WAV → FLAC (24-bit)"
        icon="audio-x-flac"
        ;;

    flac-wav-16)
        codec=(-c:a pcm_s16le)
        description="FLAC → WAV (16-bit)"
        icon="audio-x-wav"
        ;;

    flac-wav-24)
        codec=(-c:a pcm_s24le)
        description="FLAC → WAV (24-bit)"
        icon="audio-x-wav"
        ;;

    wav-mp3)
        codec=(-c:a libmp3lame -q:a 2)
        description="WAV → MP3"
        icon="audio-mpeg"
        ;;

    flac-mp3)
        codec=(-c:a libmp3lame -q:a 2)
        description="FLAC → MP3"
        icon="audio-mpeg"
        ;;

    mp3-wav-16)
        codec=(-c:a pcm_s16le)
        description="MP3 → WAV (16-bit)"
        icon="audio-x-wav"
        ;;

    mp3-wav-24)
        codec=(-c:a pcm_s24le)
        description="MP3 → WAV (24-bit)"
        icon="audio-x-wav"
        ;;

    *)
        notify_error \
            "Audio Conversion Error" \
            "Unknown conversion mode: $mode"
        exit 1
        ;;
esac

collect_valid_files "$@"

if [ "$total" -eq 0 ]; then
    notify_no_files \
        "Audio Conversion" \
        "No valid files to process."
    exit 1
fi

success=true
count=0
failed=0

notification_id="audio-conversion"

for file in "${files[@]}"; do
    output="${file%.*}"

    case "$mode" in
        wav-flac-16|wav-flac-24)
            output="${output}.flac"
            ;;

        flac-mp3|wav-mp3)
            output="${output}.mp3"
            ;;

        flac-wav-16|flac-wav-24|mp3-wav-16|mp3-wav-24)
            output="${output}.wav"
            ;;
    esac

    output=$(get_unique_filename "$output")

    filename=$(basename "$file")

    echo "Converting: $filename → $(basename "$output")"

    notify_progress \
        "$icon" \
        "$notification_id" \
        "Audio Conversion" \
        "$description\n[$((count + failed + 1))/$total] $filename"

    if ffmpeg -hide_banner -loglevel warning \
        -i "$file" \
        "${codec[@]}" \
        -map_metadata 0 \
        "$output"
    then
        ((count++))
    else
        ((failed++))
        success=false

        notify_error \
            "Audio Conversion Failed" \
            "$filename"
    fi
done

if $success; then
    notify_success \
        "$icon" \
        "Conversion Complete" \
        "$description\nSuccessfully converted $count file(s)."
else
    notify_error \
        "Conversion Finished" \
        "$description\nConverted: $count   Failed: $failed"
fi
