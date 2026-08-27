#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/notify.sh"

mode="$1"
shift

case "$mode" in
    webp-jpg)
        options=(-quality 95)
        extension="jpg"
        description="WebP → JPG"
        icon="image-jpeg"
        ;;

    webp-png)
        options=()
        extension="png"
        description="WebP → PNG"
        icon="image-png"
        ;;

    webp-tiff)
        options=(-compress lzw)
        extension="tiff"
        description="WebP → TIFF"
        icon="image-tiff"
        ;;

    jpg-webp)
        options=(-quality 95)
        extension="webp"
        description="JPG → WebP"
        icon="image-webp"
        ;;

    jpg-png)
        options=()
        extension="png"
        description="JPG → PNG"
        icon="image-png"
        ;;

    jpg-tiff)
        options=(-compress lzw)
        extension="tiff"
        description="JPG → TIFF"
        icon="image-tiff"
        ;;

    png-jpg)
        options=(-quality 95)
        extension="jpg"
        description="PNG → JPG"
        icon="image-jpeg"
        ;;

    png-webp)
        options=(-quality 95)
        extension="webp"
        description="PNG → WebP"
        icon="image-webp"
        ;;

    png-tiff)
        options=(-compress lzw)
        extension="tiff"
        description="PNG → TIFF"
        icon="image-tiff"
        ;;

    tiff-jpg)
        options=(-quality 95)
        extension="jpg"
        description="TIFF → JPG"
        icon="image-jpeg"
        ;;

    tiff-png)
        options=()
        extension="png"
        description="TIFF → PNG"
        icon="image-png"
        ;;

    tiff-webp)
        options=(-quality 95)
        extension="webp"
        description="TIFF → WebP"
        icon="image-webp"
        ;;

    bmp-jpg)
        options=(-quality 95)
        extension="jpg"
        description="BMP → JPG"
        icon="image-jpeg"
        ;;

    bmp-png)
        options=()
        extension="png"
        description="BMP → PNG"
        icon="image-png"
        ;;

    bmp-webp)
        options=(-quality 95)
        extension="webp"
        description="BMP → WebP"
        icon="image-webp"
        ;;

    avif-jpg)
        options=(-quality 95)
        extension="jpg"
        description="AVIF → JPG"
        icon="image-jpeg"
        ;;

    avif-png)
        options=()
        extension="png"
        description="AVIF → PNG"
        icon="image-png"
        ;;

    avif-webp)
        options=(-quality 95)
        extension="webp"
        description="AVIF → WebP"
        icon="image-webp"
        ;;

    gif-jpg)
        options=(-quality 95)
        extension="jpg"
        description="GIF → JPG"
        icon="image-jpeg"
        ;;

    gif-png)
        options=()
        extension="png"
        description="GIF → PNG"
        icon="image-png"
        ;;

    gif-webp)
        options=(-quality 95)
        extension="webp"
        description="GIF → WebP"
        icon="image-webp"
        ;;

    *)
        notify_error \
            "Image Conversion Error" \
            "Unknown conversion mode: $mode"
        exit 1
        ;;
esac

collect_valid_files "$@"

if [ "$total" -eq 0 ]; then
    notify_no_files \
        "Image Conversion" \
        "No valid files to process."
    exit 1
fi

success=true
count=0
failed=0

notification_id="image-conversion"

for file in "${files[@]}"; do
    output="${file%.*}.${extension}"
    output=$(get_unique_filename "$output")

    filename=$(basename "$file")

    echo "Converting: $filename → $(basename "$output")"

    notify_progress \
        "$icon" \
        "$notification_id" \
        "Image Conversion" \
        "$description\n[$((count + failed + 1))/$total] $filename"

    input="$file"

    case "$mode" in
        gif-jpg|gif-png|gif-webp)
            input="${file}[0]"
            ;;
    esac

    if magick "$input" \
        "${options[@]}" \
        "$output"
    then
        ((count++))
    else
        ((failed++))
        success=false

        notify_error \
            "Image Conversion Failed" \
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