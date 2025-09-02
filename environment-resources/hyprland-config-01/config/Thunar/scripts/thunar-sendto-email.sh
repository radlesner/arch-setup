#!/bin/bash

# Buduje listę --attach dla wszystkich plików przekazanych jako argumenty
args=""
for f in "$@"; do
    args+=" --attach \"$f\""
done

# Uruchamia xdg-email z gotową listą załączników
eval xdg-email $args
