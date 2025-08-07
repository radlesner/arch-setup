#!/bin/bash

uptime_pretty=$(uptime -p)
hours=$(echo "$uptime_pretty" | grep -oP '\d+(?= hour)' || echo 0)
minutes=$(echo "$uptime_pretty" | grep -oP '\d+(?= minute)' || echo 0)
printf "%d:%02d\n" "$hours" "$minutes"

echo $(uptime --pretty)