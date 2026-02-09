#!/bin/bash

# Read JSON input
input=$(cat)

# Context progress bar
pct=$(echo "$input" | jq '.context_window.used_percentage // empty | floor' 2>/dev/null)
if [ -n "$pct" ] && [ "$pct" != "null" ] && [ "$pct" -ge 0 ] 2>/dev/null; then
    bar_width=10
    filled=$((pct * bar_width / 100))
    [ "$filled" -gt "$bar_width" ] && filled=$bar_width
    empty=$((bar_width - filled))

    # Color based on level
    if [ "$pct" -gt 95 ]; then
        color=$'\033[5;31m'  # blinking red
    elif [ "$pct" -gt 85 ]; then
        color=$'\033[38;5;208m'  # orange
    elif [ "$pct" -gt 70 ]; then
        color=$'\033[33m'  # yellow
    else
        color=$'\033[32m'  # green
    fi

    # Build bar
    bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done

    printf '%b' "${color}${bar}\033[0m ${pct}%"
else
    printf '%s' "¯\\_(ツ)_/¯"
fi
