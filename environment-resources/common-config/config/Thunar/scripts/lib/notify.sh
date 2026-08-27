#!/bin/bash

notify_progress() {
    local icon="$1"
    local notification_id="$2"
    local title="$3"
    local message="$4"

    notify-send \
        -i "$icon" \
        -h string:x-canonical-private-synchronous:"$notification_id" \
        "$title" \
        "$message"
}

notify_success() {
    local icon="$1"
    local title="$2"
    local message="$3"

    notify-send \
        -i "$icon" \
        "$title" \
        "$message"
}

notify_error() {
    local title="$1"
    local message="$2"

    notify-send \
        -u critical \
        -i dialog-error \
        "$title" \
        "$message"
}

notify_warning() {
    local title="$1"
    local message="$2"

    notify-send \
        -u critical \
        -i dialog-warning \
        "$title" \
        "$message"
}

notify_no_files() {
    local title="$1"
    local message="$2"

    notify-send \
        -u critical \
        -i dialog-error \
        "$title" \
        "$message"
}
