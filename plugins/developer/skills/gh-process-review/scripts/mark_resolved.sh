#!/bin/bash
# Marks a review thread as resolved in the local JSON file
# Usage: mark_resolved.sh <reviews-file> <thread-id> [note]
#
# IMPORTANT: Run from the project root directory, NOT from the skill directory.
# Thread ID must include the PRRT_ prefix (full GraphQL ID).
#
# Examples:
#   mark_resolved.sh "$REVIEWS_FILE" PRRT_kwDOAbcd1234
#   mark_resolved.sh "$REVIEWS_FILE" PRRT_kwDOAbcd1234 "Fixed in commit abc123"

set -e

# Detect script and skill directory locations
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

REVIEWS_FILE="${1:?Usage: mark_resolved.sh <reviews-file> <thread-id> [note]}"
THREAD_ID="${2:?Usage: mark_resolved.sh <reviews-file> <thread-id> [note]}"
NOTE="${3:-}"

if [[ ! -f "$REVIEWS_FILE" ]]; then
  echo "Error: File not found: $REVIEWS_FILE" >&2
  echo "Expected path relative to project root or absolute path." >&2
  exit 1
fi

# Check if thread exists
FOUND=$(jq --arg id "$THREAD_ID" '[.threads[] | select(.id == $id)] | length' "$REVIEWS_FILE")

if [[ "$FOUND" -eq 0 ]]; then
  echo "Error: Thread ID $THREAD_ID not found in $REVIEWS_FILE" >&2
  exit 1
fi

# Update the thread's local_resolved field
jq --arg id "$THREAD_ID" --arg note "$NOTE" '
  .threads |= map(
    if .id == $id then
      .local_resolved = true | .local_notes = $note
    else
      .
    end
  )
' "$REVIEWS_FILE" > "${REVIEWS_FILE}.tmp" && mv "${REVIEWS_FILE}.tmp" "$REVIEWS_FILE"

echo "Marked thread $THREAD_ID as resolved" >&2
