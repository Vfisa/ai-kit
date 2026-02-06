#!/bin/bash
# Replies to a review thread with the commit hash that fixed the issue
# Usage: reply_with_commit.sh <reviews-file> <thread-id> [commit-hash]
#
# IMPORTANT: Run from the project root directory, NOT from the skill directory.
# Thread ID must include the PRRT_ prefix (full GraphQL ID).
# If commit-hash is omitted, uses HEAD.
#
# Examples:
#   reply_with_commit.sh "$REVIEWS_FILE" PRRT_kwDOAbcd1234
#   reply_with_commit.sh "$REVIEWS_FILE" PRRT_kwDOAbcd1234 abc1234

set -e

# Detect script and skill directory locations
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

REVIEWS_FILE="${1:?Usage: reply_with_commit.sh <reviews-file> <thread-id> [commit-hash]}"
THREAD_ID="${2:?Usage: reply_with_commit.sh <reviews-file> <thread-id> [commit-hash]}"
COMMIT_HASH="${3:-$(git rev-parse HEAD)}"

if [[ ! -f "$REVIEWS_FILE" ]]; then
  echo "Error: File not found: $REVIEWS_FILE" >&2
  echo "Expected path relative to project root or absolute path." >&2
  exit 1
fi

# Validate we're in a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "Error: Not inside a git repository. Run this from your project root." >&2
  exit 1
fi

# Verify thread exists
FOUND=$(jq --arg id "$THREAD_ID" '[.threads[] | select(.id == $id)] | length' "$REVIEWS_FILE")
if [[ "$FOUND" -eq 0 ]]; then
  echo "Error: Thread ID $THREAD_ID not found in $REVIEWS_FILE" >&2
  exit 1
fi

# Get short hash for display
SHORT_HASH=$(git rev-parse --short "$COMMIT_HASH")

# Get PR URL to extract owner/repo
PR_URL=$(jq -r '.pr.url' "$REVIEWS_FILE")
if [[ "$PR_URL" =~ github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
  OWNER="${BASH_REMATCH[1]}"
  REPO="${BASH_REMATCH[2]}"
fi

BODY="Fixed in ${SHORT_HASH}"

# Use GraphQL to add a reply to the review thread
MUTATION='
mutation($threadId: ID!, $body: String!) {
  addPullRequestReviewThreadReply(input: {pullRequestReviewThreadId: $threadId, body: $body}) {
    comment {
      id
      body
    }
  }
}
'

RESPONSE=$(gh api graphql \
  -f query="$MUTATION" \
  -f threadId="$THREAD_ID" \
  -f body="$BODY")

if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
  echo "Error posting reply:" >&2
  echo "$RESPONSE" | jq '.errors' >&2
  exit 1
fi

echo "Replied to thread $THREAD_ID with: $BODY" >&2
