#!/bin/bash

args=""
for f in "$@"; do
    args+=" --attach \"$f\""
done

eval xdg-email $args
