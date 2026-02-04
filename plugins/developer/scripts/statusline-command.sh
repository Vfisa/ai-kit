#!/bin/bash

# Read JSON input
input=$(cat)

# Extract values from JSON
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
model=$(echo "$input" | jq -r '.model.display_name')
session_id=$(echo "$input" | jq -r '.session_id')
transcript=$(echo "$input" | jq -r '.transcript_path')

cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // 0' 2>/dev/null)

# Context progress bar
pct=$(echo "$input" | jq '.context_window.used_percentage // empty' 2>/dev/null)
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

    context_bar="${color}${bar}\033[0m ${pct}%"
else
    context_bar="¯\\_(ツ)_/¯"
fi

# Shorten directory path if too long
short_cwd="$cwd"
if [ ${#cwd} -gt 35 ]; then
    short_cwd="...${cwd: -32}"
fi

# Build status line: cwd | cost | context bar
printf '\033[34m%s\033[0m \033[90m|\033[0m \033[32m$%.3f\033[0m \033[90m|\033[0m %b\n\n' \
    "$short_cwd" "$cost_usd" "$context_bar"
