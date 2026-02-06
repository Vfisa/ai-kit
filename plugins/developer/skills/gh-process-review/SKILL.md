---
name: gh-process-review
description: Process GitHub PR review comments by fetching them to local JSON, implementing fixes, and tracking progress. Use when user invokes /gh-process-review command. Fetches reviews to file to avoid context pollution, uses jq for parsing, commits each fix separately. Starts in planning mode by default. Supports optional "continue" argument to skip fetching and resume with existing reviews file.
---

# GitHub Review Processing

Process PR review threads efficiently by storing them locally and addressing them one by one.

## Working Directory Context

**CRITICAL: All commands MUST be run from the user's project root directory, NOT from the skill directory.**

- The user will be in THEIR project directory when invoking this skill
- All script paths use `$SKILL_DIR` to reference skill scripts with absolute paths
- Scripts operate on the project directory (current working directory) by default
- **DO NOT `cd` into the skill directory** - scripts handle path resolution internally

`SKILL_DIR` = directory containing this SKILL.md (automatically resolved by Claude)

## CRITICAL Rules

1. **STAY IN PROJECT ROOT** - Never `cd` into the skill directory. Call scripts using `$SKILL_DIR/scripts/<name>.sh` from the project root.
2. **ONE COMMIT PER FIX** - Each review thread fix MUST be committed separately. Never batch multiple fixes into one commit.
3. **START IN PLANNING MODE** - Always enter planning mode first (unless context explicitly says otherwise like "skip planning" or "no planning").

## Workflow

### Phase 1: Setup

Fetch reviews for current PR and list unresolved threads:

```bash
REVIEWS_FILE=$("$SKILL_DIR/scripts/fetch_reviews.sh" "$(! gh pr view --json number -q .number)")
"$SKILL_DIR/scripts/list_unresolved.sh" "$REVIEWS_FILE"
```

#### Continue mode (`/gh-process-review continue`)

Skip fetching, use existing reviews file:

```bash
REVIEWS_FILE=".scratch/reviews/$(! gh repo view --json owner,name -q '"\(.owner.login)-\(.name)"')-pr-$(! gh pr view --json number -q .number).json"
"$SKILL_DIR/scripts/list_unresolved.sh" "$REVIEWS_FILE"
```

### Phase 2: Planning (default)

After fetching, **enter planning mode** using `EnterPlanMode` tool. In the plan:

1. List all unresolved threads with file:line and brief summary
2. For each thread, outline the proposed fix approach
3. Identify any dependencies between fixes
4. Present the plan for user approval before implementing

Skip planning only if user explicitly requests it (e.g., "skip planning", "no planning", "just fix it").

### Phase 3: Implementation

For each unresolved thread (one at a time):

1. Get thread details: `"$SKILL_DIR/scripts/get_thread.sh" "$REVIEWS_FILE" PRRT_...`
2. Read the file and understand the feedback
3. Implement the fix
4. **COMMIT THIS FIX IMMEDIATELY** - Do not continue to next thread without committing:
   ```bash
   git add <changed-files>
   git commit -m "$(cat <<'EOF'
   AI-XXXX Address review: <brief description>

   Addresses comment by @<reviewer> on <file>:<line>

   Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
   EOF
   )"
   ```
5. Push the commit
6. Reply with commit: `"$SKILL_DIR/scripts/reply_with_commit.sh" "$REVIEWS_FILE" PRRT_...`
7. Mark resolved: `"$SKILL_DIR/scripts/mark_resolved.sh" "$REVIEWS_FILE" PRRT_...`
8. **Only then** proceed to next thread

## Scripts

All in `$SKILL_DIR/scripts/`. Call with full path from the **project directory**.

Scripts detect their own location internally using `BASH_SOURCE`, so they can reference sibling files if needed. They validate that they're running in a valid git repository.

### fetch_reviews.sh
```bash
"$SKILL_DIR/scripts/fetch_reviews.sh" "$(! gh pr view --json number -q .number)"  # Current PR
"$SKILL_DIR/scripts/fetch_reviews.sh" 123
"$SKILL_DIR/scripts/fetch_reviews.sh" https://github.com/owner/repo/pull/123
```

### list_unresolved.sh
```bash
"$SKILL_DIR/scripts/list_unresolved.sh" "$REVIEWS_FILE"           # summary
"$SKILL_DIR/scripts/list_unresolved.sh" "$REVIEWS_FILE" full      # full details
"$SKILL_DIR/scripts/list_unresolved.sh" "$REVIEWS_FILE" ids       # just IDs
```

### get_thread.sh
```bash
"$SKILL_DIR/scripts/get_thread.sh" "$REVIEWS_FILE" PRRT_kwDOAbcd1234
```
Returns: Thread JSON with `path`, `line`, `comments[]`, `isResolved`, `isOutdated`.

### reply_with_commit.sh
```bash
"$SKILL_DIR/scripts/reply_with_commit.sh" "$REVIEWS_FILE" PRRT_kwDOAbcd1234
"$SKILL_DIR/scripts/reply_with_commit.sh" "$REVIEWS_FILE" PRRT_kwDOAbcd1234 abc1234
```

### mark_resolved.sh
```bash
"$SKILL_DIR/scripts/mark_resolved.sh" "$REVIEWS_FILE" PRRT_kwDOAbcd1234
"$SKILL_DIR/scripts/mark_resolved.sh" "$REVIEWS_FILE" PRRT_kwDOAbcd1234 "Fixed in commit abc123"
```

## JSON Structure

- `pr`: PR metadata (number, title, branch names, url)
- `threads[]`: `id`, `path`, `line`, `isResolved`, `isOutdated`, `local_resolved`, `local_notes`, `comments[]`
- `reviews`: Review summaries

## Key Thread Fields

- `id`: GraphQL ID (starts with `PRRT_`)
- `path`: File path
- `line`: Line number
- `comments[0].body`: Main feedback
- `comments[0].author`: Reviewer
