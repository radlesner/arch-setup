#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/notify.sh"

collect_valid_files "$@"

if [ "$total" -eq 0 ]; then
    notify_no_files \
        "Audio Extraction" \
        "No valid video files selected."
    exit 1
fi

success=true
count=0
failed=0

notification_id="audio-extraction"

for file in "${files[@]}"; do
    filename=$(basename "$file")
    basename="${file%.*}"

    codec=$(ffprobe -v error \
        -select_streams a:0 \
        -show_entries stream=codec_name \
        -of default=noprint_wrappers=1:nokey=1 \
        "$file")

    if [ -z "$codec" ]; then
        success=false
        ((failed++))

        notify_error \
            "Audio Extraction Failed" \
            "$filename\nNo audio stream found."

        echo "No audio stream: $filename"
        continue
    fi

    case "$codec" in
        flac)
            extension="flac"
            ;;

        mp3)
            extension="mp3"
            ;;

        aac)
            extension="m4a"
            ;;

        alac)
            extension="m4a"
            ;;

        opus)
            extension="opus"
            ;;

        vorbis)
            extension="ogg"
            ;;

        ac3)
            extension="ac3"
            ;;

        eac3)
            extension="eac3"
            ;;

        pcm_s16le|pcm_s24le|pcm_s32le)
            extension="wav"
            ;;

        *)
            extension="mka"
            ;;
    esac

    output="${basename}-audio.${extension}"
    output=$(get_unique_filename "$output")

    notify_progress \
        "audio-x-generic" \
        "$notification_id" \
        "Extracting Audio" \
        "[$((count + failed + 1))/$total] $filename\nCodec: $codec"

    echo "Extracting audio: $filename"
    echo "Codec: $codec"
    echo "Output: $(basename "$output")"

    if ffmpeg -hide_banner \
        -i "$file" \
        -map 0:a:0 \
        -c:a copy \
        "$output" \
        -y
    then
        ((count++))
    else
        success=false
        ((failed++))

        rm -f "$output"

        notify_error \
            "Audio Extraction Failed" \
            "$filename"

        echo "Failed: $filename"
    fi
done

if $success; then
    notify_success \
        "audio-x-generic" \
        "Audio Extraction Complete" \
        "Extracted audio from $count file(s)."
else
    notify_warning \
        "Audio Extraction Finished" \
        "Extracted: $count\nFailed: $failed"
fi
