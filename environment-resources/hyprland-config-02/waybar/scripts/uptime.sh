#!/bin/bash

bash -c 'u=$(uptime -p); h=$(echo $u | grep -oP "\\d+(?= hour)" || echo 0); m=$(echo $u | grep -oP "\\d+(?= minute)" || echo 0); printf "%d:%02d\n" "$h" "$m"'

echo $(uptime --pretty)