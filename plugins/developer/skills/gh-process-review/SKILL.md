---
name: gh-process-review
description: Process GitHub PR review comments by fetching them to local JSON, implementing fixes, and tracking progress. Use when user invokes /gh-process-review command. Fetches reviews to file to avoid context pollution, uses jq for parsing, commits after each fix. Supports optional "continue" argument to skip fetching and resume with existing reviews file.
---

# GitHub Review Processing

Process PR review threads efficiently by storing them locally and addressing them one by one.

## CRITICAL: Run from project directory

**NEVER `cd` into the skill directory.** All scripts must be called from the project root using the full skill path. The scripts need access to the git repo and `gh` CLI context.

`SKILL_DIR` = directory containing this SKILL.md

## Initial Setup (run automatically)

Fetch reviews for current PR and list unresolved threads:

```bash
REVIEWS_FILE=$("$SKILL_DIR/scripts/fetch_reviews.sh" "$(! gh pr view --json number -q .number)")
"$SKILL_DIR/scripts/list_unresolved.sh" "$REVIEWS_FILE"
```

### Continue mode (`/gh-process-review continue`)

Skip fetching, use existing reviews file for current branch's PR:

```bash
REVIEWS_FILE=".scratch/reviews/$(! gh repo view --json owner,name -q '"\(.owner.login)-\(.name)"')-pr-$(! gh pr view --json number -q .number).json"
"$SKILL_DIR/scripts/list_unresolved.sh" "$REVIEWS_FILE"
```

## Workflow

1. **For each unresolved thread**:
   - Get thread details with `"$SKILL_DIR/scripts/get_thread.sh" "$REVIEWS_FILE" PRRT_...`
   - Read the relevant file and understand the feedback
   - Implement the fix
   - Commit with message referencing the review
   - Push the commit
   - Reply with commit hash: `"$SKILL_DIR/scripts/reply_with_commit.sh" "$REVIEWS_FILE" PRRT_...`
   - Mark resolved with `"$SKILL_DIR/scripts/mark_resolved.sh" "$REVIEWS_FILE" PRRT_...`
2. **Repeat** until all threads addressed

## Scripts

All scripts in `$SKILL_DIR/scripts/`. Call with full path from project directory. Use these instead of inline bash for auto-allow capability.

### fetch_reviews.sh
```bash
# Usage: "$SKILL_DIR/scripts/fetch_reviews.sh" <pr-url-or-number> [output-dir]
# Examples:
"$SKILL_DIR/scripts/fetch_reviews.sh" "$(! gh pr view --json number -q .number)"  # Current PR
"$SKILL_DIR/scripts/fetch_reviews.sh" 123
"$SKILL_DIR/scripts/fetch_reviews.sh" https://github.com/owner/repo/pull/123
```
Uses GraphQL to get thread resolution status. Outputs JSON file path.

### list_unresolved.sh
```bash
# Usage: "$SKILL_DIR/scripts/list_unresolved.sh" <reviews-file> [format]
# Formats: summary (default), full, ids
# Examples:
"$SKILL_DIR/scripts/list_unresolved.sh" "$REVIEWS_FILE"
"$SKILL_DIR/scripts/list_unresolved.sh" "$REVIEWS_FILE" full
"$SKILL_DIR/scripts/list_unresolved.sh" "$REVIEWS_FILE" ids
```
Filters out: already resolved on GitHub, locally resolved, outdated threads.

### get_thread.sh
```bash
# Usage: "$SKILL_DIR/scripts/get_thread.sh" <reviews-file> <thread-id>
# IMPORTANT: Thread ID must include the PRRT_ prefix
# Examples:
"$SKILL_DIR/scripts/get_thread.sh" "$REVIEWS_FILE" PRRT_kwDOAbcd1234
```
Returns: Thread as JSON with `path`, `line`, `comments[]`, `isResolved`, `isOutdated`.

### reply_with_commit.sh
```bash
# Usage: "$SKILL_DIR/scripts/reply_with_commit.sh" <reviews-file> <thread-id> [commit-hash]
# IMPORTANT: Thread ID must include the PRRT_ prefix
# If commit-hash omitted, uses HEAD
# Examples:
"$SKILL_DIR/scripts/reply_with_commit.sh" "$REVIEWS_FILE" PRRT_kwDOAbcd1234
"$SKILL_DIR/scripts/reply_with_commit.sh" "$REVIEWS_FILE" PRRT_kwDOAbcd1234 abc1234
```
Posts reply "Fixed in <short-hash>" to the review thread on GitHub.

### mark_resolved.sh
```bash
# Usage: "$SKILL_DIR/scripts/mark_resolved.sh" <reviews-file> <thread-id> [note]
# IMPORTANT: Thread ID must include the PRRT_ prefix
# Examples:
"$SKILL_DIR/scripts/mark_resolved.sh" "$REVIEWS_FILE" PRRT_kwDOAbcd1234
"$SKILL_DIR/scripts/mark_resolved.sh" "$REVIEWS_FILE" PRRT_kwDOAbcd1234 "Fixed in commit abc123"
```

## JSON Structure

The reviews file contains:
- `pr`: PR metadata (number, title, branch names, url)
- `threads`: Array of review threads with:
  - `id`: GraphQL ID (use for mark_resolved)
  - `path`: File path relative to repo root
  - `line`: Line number in the file
  - `isResolved`: GitHub resolution status
  - `isOutdated`: Whether the thread is on outdated code
  - `local_resolved`: boolean (local tracking)
  - `local_notes`: string (notes about the fix)
  - `comments[]`: Array of comments in the thread
- `reviews`: Review summaries (approve/request changes)

## Key Thread Fields

When processing a thread:
- `id`: GraphQL ID - **always starts with `PRRT_`** (e.g., `PRRT_kwDOAbcd1234`)
- `path`: File path
- `line`: Line number
- `comments[0].body`: First comment (usually the main feedback)
- `comments[0].author`: Who wrote it

## Commit Message Format

```
AI-XXXX Address review: <brief description>

Addresses comment by @<reviewer> on <file>:<line>
```

## Important

- **Commit and push after each fix** - keeps progress atomic
- **Reply with commit hash** - lets reviewers know which commit addresses their feedback
- **Use scripts** instead of inline bash - enables auto-allow
- **Mark resolved locally** - for tracking, not GitHub state
