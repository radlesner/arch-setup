#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/notify.sh"

collect_valid_files "$@"

if [ "$total" -eq 0 ]; then
    notify_no_files \
        "Peak Check" \
        "No valid files to analyze."
    exit 1
fi

success=true
count=0
failed=0
over_files=0

notification_id="audio-clipping-check"

for file in "${files[@]}"; do
    report="${file%.*}-clipping.txt"
    report=$(get_unique_filename "$report")

    filename=$(basename "$file")

    notify_progress \
        "audio-x-generic" \
        "$notification_id" \
        "Peak / Clipping Analysis" \
        "[$((count + failed + 1))/$total] $filename"

    echo "Analyzing: $filename"

    result=$(ffmpeg -hide_banner \
        -i "$file" \
        -af "astats=metadata=1:reset=0" \
        -f null - 2>&1)

    peak=$(echo "$result" |
        grep "Overall" -A 20 |
        grep "Peak level dB:" |
        tail -1 |
        sed 's/.*Peak level dB: *//')

    min_level=$(echo "$result" |
        grep "Overall" -A 20 |
        grep "Min level:" |
        tail -1 |
        sed 's/.*Min level: *//')

    max_level=$(echo "$result" |
        grep "Overall" -A 20 |
        grep "Max level:" |
        tail -1 |
        sed 's/.*Max level: *//')

    peak_count=$(echo "$result" |
        grep "Overall" -A 20 |
        grep "Peak count:" |
        tail -1 |
        sed 's/.*Peak count: *//')

    abs_peak_count=$(echo "$result" |
        grep "Overall" -A 20 |
        grep "Abs Peak count:" |
        tail -1 |
        sed 's/.*Abs Peak count: *//')

    if [ -z "$peak" ]; then
        success=false
        ((failed++))

        cat > "$report" <<EOF
# Peak / Clipping Analysis

File: $(basename "$file")
Date: $(date)

Unable to determine peak level.
EOF

        continue
    fi

    {
        echo "# Peak / Clipping Analysis"
        echo
        echo "File: $(basename "$file")"
        echo "Date: $(date)"
        echo
        echo "Peak level:        $peak dBFS"
        echo "Minimum level:     $min_level"
        echo "Maximum level:     $max_level"
        echo "Peak count:        $peak_count"
        echo "Absolute peak:     $abs_peak_count"
        echo
    } > "$report"

    if awk "BEGIN {exit !($peak > 0)}"; then
        echo "RESULT: PEAK ABOVE 0 dBFS" >> "$report"
        echo "WARNING: Decoded signal contains samples above 0 dBFS." >> "$report"
        ((over_files++))
    else
        echo "RESULT: NO PEAK ABOVE 0 dBFS" >> "$report"
    fi

    ((count++))
done

if $success; then
    if [ "$over_files" -eq 0 ]; then
        notify_success \
            "audio-x-generic" \
            "Peak Check Complete" \
            "Checked $count file(s).\nNo peaks above 0 dBFS."
    else
        notify_warning \
            "Peak Above 0 dBFS" \
            "Checked: $count\nAbove 0 dBFS: $over_files"
    fi
else
    notify_error \
        "Peak Check Finished" \
        "Checked: $count   Failed: $failed"
fi
