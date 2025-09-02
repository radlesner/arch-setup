#!/bin/bash

mount_path="/home"

read total used free <<< $(df -P "$mount_path" | awk 'NR==2 {print $2, $3, $4}')
used_percent=$(awk "BEGIN {printf \"%.0f\", ($used / $total) * 100}")

total_gb=$(awk "BEGIN {printf \"%.1f\", $total / 1024 / 1024}")
used_gb=$(awk "BEGIN {printf \"%.1f\", $used / 1024 / 1024}")
free_gb=$(awk "BEGIN {printf \"%.1f\", $free / 1024 / 1024}")

echo "󱂵 ${used_percent}%"

echo "/home: ${used_gb} GiB / ${total_gb} GiB (free: ${free_gb} GiB)"
