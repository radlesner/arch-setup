#!/bin/bash
# thunderbird-send.sh
thunderbird -compose "attachment='$(IFS=,; echo "$*")'"
