#!/bin/bash
# Fetches PR review threads to a JSON file for processing
# Uses GraphQL to get thread resolution status
# Usage: fetch_reviews.sh <pr-url-or-number> [output-dir]
#
# IMPORTANT: Run from the project root directory, NOT from the skill directory.
# The script detects its own location and operates on the current working directory.
#
# Examples:
#   fetch_reviews.sh "$(! gh pr view --json number -q .number)"  # Current branch PR
#   fetch_reviews.sh 123
#   fetch_reviews.sh https://github.com/owner/repo/pull/123
#   fetch_reviews.sh 123 .scratch/reviews

set -e

# Detect script and skill directory locations
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

PR_REF="${1:?Usage: fetch_reviews.sh <pr-url-or-number> [output-dir]}"
OUTPUT_DIR="${2:-.scratch/reviews}"

# Validate we're in a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "Error: Not inside a git repository. Run this from your project root." >&2
  echo "Usage: $0 <pr-url-or-number> [output-dir]" >&2
  exit 1
fi

# Extract PR number and repo from URL if provided
if [[ "$PR_REF" =~ github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
  OWNER="${BASH_REMATCH[1]}"
  REPO="${BASH_REMATCH[2]}"
  PR_NUMBER="${BASH_REMATCH[3]}"
else
  PR_NUMBER="$PR_REF"
  # Get owner and repo from current directory
  REPO_INFO=$(gh repo view --json owner,name -q '"\(.owner.login)/\(.name)"' 2>/dev/null)
  OWNER=$(echo "$REPO_INFO" | cut -d'/' -f1)
  REPO=$(echo "$REPO_INFO" | cut -d'/' -f2)
fi

if [[ -z "$OWNER" || -z "$REPO" ]]; then
  echo "Error: Could not determine repository. Provide full PR URL or run from a git repo." >&2
  exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Generate output filename
OUTPUT_FILE="$OUTPUT_DIR/${OWNER}-${REPO}-pr-${PR_NUMBER}.json"

echo "Fetching reviews for $OWNER/$REPO PR #$PR_NUMBER..." >&2

# Fetch using GraphQL - gets thread resolution status and nested comments
QUERY='
query($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      number
      title
      url
      headRefName
      baseRefName
      state
      author {
        login
      }
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          startLine
          diffSide
          comments(first: 50) {
            nodes {
              id
              databaseId
              body
              path
              author {
                login
              }
              createdAt
              outdated
            }
          }
        }
      }
      reviews(first: 50) {
        nodes {
          id
          databaseId
          state
          body
          author {
            login
          }
          submittedAt
        }
      }
    }
  }
}
'

RESPONSE=$(gh api graphql \
  -f query="$QUERY" \
  -F owner="$OWNER" \
  -F repo="$REPO" \
  -F pr="$PR_NUMBER")

# Transform into a more usable structure with local tracking fields
echo "$RESPONSE" | jq --arg fetched_at "$(date -Iseconds)" '
  .data.repository.pullRequest as $pr |
  {
    pr: {
      number: $pr.number,
      title: $pr.title,
      url: $pr.url,
      headRefName: $pr.headRefName,
      baseRefName: $pr.baseRefName,
      state: $pr.state,
      author: $pr.author.login
    },
    fetched_at: $fetched_at,
    reviews: ($pr.reviews.nodes | map({
      id: .databaseId,
      graphql_id: .id,
      state: .state,
      body: .body,
      author: .author.login,
      submittedAt: .submittedAt
    })),
    threads: ($pr.reviewThreads.nodes | map({
      id: .id,
      isResolved: .isResolved,
      isOutdated: .isOutdated,
      path: .path,
      line: .line,
      startLine: .startLine,
      diffSide: .diffSide,
      local_resolved: false,
      local_notes: "",
      comments: (.comments.nodes | map({
        id: .databaseId,
        graphql_id: .id,
        body: .body,
        path: .path,
        author: .author.login,
        createdAt: .createdAt,
        outdated: .outdated
      }))
    }))
  }
' > "$OUTPUT_FILE"

THREAD_COUNT=$(jq '.threads | length' "$OUTPUT_FILE")
UNRESOLVED=$(jq '[.threads[] | select(.isResolved == false)] | length' "$OUTPUT_FILE")
echo "Saved $THREAD_COUNT review threads ($UNRESOLVED unresolved) to: $OUTPUT_FILE" >&2
echo "$OUTPUT_FILE"
