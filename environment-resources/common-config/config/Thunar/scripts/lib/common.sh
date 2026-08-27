#!/bin/bash

get_unique_filename() {
    local file="$1"

    if [ ! -e "$file" ]; then
        echo "$file"
        return
    fi

    local dir
    local base
    local ext
    local i=1

    dir=$(dirname "$file")
    base=$(basename "$file")
    ext=".${base##*.}"
    base="${base%.*}"

    while [ -e "$dir/$base-$i$ext" ]; do
        ((i++))
    done

    echo "$dir/$base-$i$ext"
}

collect_valid_files() {
    files=()

    for file in "$@"; do
        [ -f "$file" ] && files+=("$file")
    done

    total=${#files[@]}
}

script_dir() {
    cd -- "$(dirname -- "${BASH_SOURCE[1]}")" && pwd
}
