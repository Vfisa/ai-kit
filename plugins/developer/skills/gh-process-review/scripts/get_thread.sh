#!/bin/bash
# Gets one or more review thread details from the reviews JSON file
# Usage: get_thread.sh <reviews-file> <thread-id> [thread-id...]
#
# IMPORTANT: Run from the project root directory, NOT from the skill directory.
# Thread IDs must include the PRRT_ prefix (full GraphQL ID).
# When multiple IDs are given, outputs a JSON array.
#
# Examples:
#   get_thread.sh "$REVIEWS_FILE" PRRT_kwDOAbcd1234
#   get_thread.sh "$REVIEWS_FILE" PRRT_kwDOAbcd1234 PRRT_kwDOEfgh5678
#   get_thread.sh .scratch/reviews/owner-repo-pr-123.json PRRT_kwDONmF1dG8...

set -e

# Detect script and skill directory locations
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

REVIEWS_FILE="${1:?Usage: get_thread.sh <reviews-file> <thread-id> [thread-id...]}"
shift

if [[ $# -eq 0 ]]; then
  echo "Error: At least one thread ID is required" >&2
  echo "Usage: get_thread.sh <reviews-file> <thread-id> [thread-id...]" >&2
  exit 1
fi

if [[ ! -f "$REVIEWS_FILE" ]]; then
  echo "Error: File not found: $REVIEWS_FILE" >&2
  echo "Expected path relative to project root or absolute path." >&2
  exit 1
fi

# Build jq array of requested IDs
IDS_JSON=$(printf '%s\n' "$@" | jq -R . | jq -s .)

RESULT=$(jq --argjson ids "$IDS_JSON" '
  [.threads[] | select(.id as $tid | $ids | index($tid))]
' "$REVIEWS_FILE")

# Check for missing IDs
FOUND_COUNT=$(echo "$RESULT" | jq 'length')
REQUESTED_COUNT=$#

if [[ "$FOUND_COUNT" -eq 0 ]]; then
  echo "Error: None of the requested thread IDs were found" >&2
  exit 1
fi

if [[ "$FOUND_COUNT" -lt "$REQUESTED_COUNT" ]]; then
  FOUND_IDS=$(echo "$RESULT" | jq -r '.[].id')
  for id in "$@"; do
    if ! echo "$FOUND_IDS" | grep -q "^${id}$"; then
      echo "Warning: Thread ID $id not found" >&2
    fi
  done
fi

# Single ID: output the object directly (backwards compatible)
# Multiple IDs: output as array
if [[ $REQUESTED_COUNT -eq 1 ]]; then
  echo "$RESULT" | jq '.[0]'
else
  echo "$RESULT"
fi
