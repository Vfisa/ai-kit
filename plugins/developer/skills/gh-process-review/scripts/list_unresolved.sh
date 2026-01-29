#!/bin/bash
# Lists unresolved review threads from the reviews JSON file
# Usage: list_unresolved.sh <reviews-file> [format]
#
# Formats:
#   summary (default) - One line per thread with file:line and first comment preview
#   full              - Full thread details as JSON
#   ids               - Just thread IDs with PRRT_ prefix (for scripting)
#
# Examples:
#   list_unresolved.sh "$REVIEWS_FILE"
#   list_unresolved.sh "$REVIEWS_FILE" full
#   list_unresolved.sh "$REVIEWS_FILE" ids

set -e

REVIEWS_FILE="${1:?Usage: list_unresolved.sh <reviews-file> [format]}"
FORMAT="${2:-summary}"

if [[ ! -f "$REVIEWS_FILE" ]]; then
  echo "Error: File not found: $REVIEWS_FILE" >&2
  exit 1
fi

# Filter: not resolved on GitHub AND not locally resolved AND not outdated
FILTER='select(.isResolved == false and .local_resolved == false and .isOutdated == false)'

case "$FORMAT" in
  summary)
    jq -r "
      .threads
      | map($FILTER)
      | .[]
      | \"[\(.id | split(\"_\")[-1])]: \(.path):\(.line // \"?\") - \(.comments[0].body | split(\"\n\")[0] | .[0:80])\"
    " "$REVIEWS_FILE"
    ;;
  full)
    jq ".threads | map($FILTER)" "$REVIEWS_FILE"
    ;;
  ids)
    jq -r ".threads | map($FILTER) | .[].id" "$REVIEWS_FILE"
    ;;
  *)
    echo "Error: Unknown format '$FORMAT'. Use: summary, full, or ids" >&2
    exit 1
    ;;
esac
