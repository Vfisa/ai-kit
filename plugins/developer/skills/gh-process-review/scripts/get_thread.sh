#!/bin/bash
# Gets a single review thread's details from the reviews JSON file
# Usage: get_thread.sh <reviews-file> <thread-id>
#
# IMPORTANT: Run from the project root directory, NOT from the skill directory.
# Thread ID must include the PRRT_ prefix (full GraphQL ID).
#
# Examples:
#   get_thread.sh "$REVIEWS_FILE" PRRT_kwDOAbcd1234
#   get_thread.sh .scratch/reviews/owner-repo-pr-123.json PRRT_kwDONmF1dG8...

set -e

# Detect script and skill directory locations
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

REVIEWS_FILE="${1:?Usage: get_thread.sh <reviews-file> <thread-id>}"
THREAD_ID="${2:?Usage: get_thread.sh <reviews-file> <thread-id>}"

if [[ ! -f "$REVIEWS_FILE" ]]; then
  echo "Error: File not found: $REVIEWS_FILE" >&2
  echo "Expected path relative to project root or absolute path." >&2
  exit 1
fi

THREAD=$(jq --arg id "$THREAD_ID" '.threads[] | select(.id == $id)' "$REVIEWS_FILE")

if [[ -z "$THREAD" || "$THREAD" == "null" ]]; then
  echo "Error: Thread ID $THREAD_ID not found" >&2
  exit 1
fi

echo "$THREAD"
