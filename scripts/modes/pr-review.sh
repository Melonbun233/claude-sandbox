#!/usr/bin/env bash
set -euo pipefail

# ── PR Review mode ───────────────────────────────────────────────────────────
# Reviews a pull request and outputs comments (dry-run) or posts to GitHub.

PR_NUMBER="${PR_NUMBER:-}"
PR_REPO="${PR_REPO:-}"
DRY_RUN="${DRY_RUN:-true}"
SESSION_DIR="/workspace/.claude-session"

if [ -z "$PR_NUMBER" ]; then
  echo "ERROR: PR_NUMBER is required for pr-review mode."
  echo "  Set PR_NUMBER=123 or PR_NUMBER=org/repo#123"
  exit 1
fi

# Parse org/repo#123 format
if [[ "$PR_NUMBER" == *"#"* ]]; then
  PR_REPO="${PR_NUMBER%%#*}"
  PR_NUMBER="${PR_NUMBER##*#}"
fi

# If PR_REPO is set, find the matching workspace dir or use --repo flag
REPO_FLAG=""
if [ -n "$PR_REPO" ]; then
  REPO_FLAG="--repo $PR_REPO"
fi

echo ":: Reviewing PR #$PR_NUMBER ${PR_REPO:+(repo: $PR_REPO)}"
echo ""

# Fetch PR metadata
echo ":: Fetching PR details..."
PR_INFO=$(gh pr view "$PR_NUMBER" $REPO_FLAG --json number,title,body,baseRefName,headRefName,additions,deletions,changedFiles 2>&1) || {
  echo "ERROR: Failed to fetch PR #$PR_NUMBER"
  echo "$PR_INFO"
  exit 1
}

PR_TITLE=$(echo "$PR_INFO" | jq -r '.title')
PR_BODY=$(echo "$PR_INFO" | jq -r '.body // ""')
PR_BASE=$(echo "$PR_INFO" | jq -r '.baseRefName')
PR_HEAD=$(echo "$PR_INFO" | jq -r '.headRefName')
PR_ADDITIONS=$(echo "$PR_INFO" | jq -r '.additions')
PR_DELETIONS=$(echo "$PR_INFO" | jq -r '.deletions')

echo "  Title: $PR_TITLE"
echo "  $PR_BASE ← $PR_HEAD (+$PR_ADDITIONS/-$PR_DELETIONS)"
echo ""

# Fetch the diff
echo ":: Fetching diff..."
PR_DIFF=$(gh pr diff "$PR_NUMBER" $REPO_FLAG 2>&1) || {
  echo "ERROR: Failed to fetch diff for PR #$PR_NUMBER"
  exit 1
}

# Build the review prompt
REVIEW_PROMPT="Review this pull request. Provide a thorough code review covering:
1. Code correctness and potential bugs
2. Security concerns
3. Performance implications
4. Code style and maintainability
5. Test coverage gaps

PR Title: $PR_TITLE
PR Description: $PR_BODY
Base: $PR_BASE ← Head: $PR_HEAD

Format your review as markdown with sections for Summary, Issues Found, Suggestions, and Overall Assessment.
Rate the PR: APPROVE, REQUEST_CHANGES, or COMMENT.

Here is the diff:

$PR_DIFF"

# Run Claude
echo ":: Running Claude Code review..."
REVIEW_OUTPUT=$(echo "$REVIEW_PROMPT" | claude -p --dangerously-skip-permissions 2>&1) || {
  echo "ERROR: Claude review failed"
  exit 1
}

# Save review to file
mkdir -p "$SESSION_DIR"
echo "$REVIEW_OUTPUT" > "$SESSION_DIR/review.md"
echo "  Review saved to $SESSION_DIR/review.md"

if [ "$DRY_RUN" = "true" ] || [ "$DRY_RUN" = "1" ]; then
  echo ""
  echo "╔══════════════════════════════════════════════════╗"
  echo "║  DRY RUN — Review not posted to GitHub          ║"
  echo "╠══════════════════════════════════════════════════╣"
  echo "║                                                  ║"
  echo "║  Review saved to:                                ║"
  echo "║    /workspace/.claude-session/review.md          ║"
  echo "║                                                  ║"
  echo "║  To inspect and edit:                            ║"
  echo "║    docker exec -it claude-dev \\                  ║"
  echo "║      cat /workspace/.claude-session/review.md    ║"
  echo "║                                                  ║"
  echo "║  To post to GitHub:                              ║"
  echo "║    ./claude-dev pr-submit                        ║"
  echo "║                                                  ║"
  echo "╚══════════════════════════════════════════════════╝"
  echo ""
  echo "── Review Preview ──────────────────────────────────"
  echo ""
  echo "$REVIEW_OUTPUT"
else
  echo ":: Posting review to GitHub..."
  gh pr review "$PR_NUMBER" $REPO_FLAG --comment --body "$REVIEW_OUTPUT" 2>&1 || {
    echo "ERROR: Failed to post review. Review saved to $SESSION_DIR/review.md"
    exit 1
  }
  echo "  Review posted to PR #$PR_NUMBER"
fi

# Update session status
jq --arg review "completed" '.pr_review_status = $review' "$SESSION_DIR/status.json" \
  > "$SESSION_DIR/status.json.tmp" \
  && mv "$SESSION_DIR/status.json.tmp" "$SESSION_DIR/status.json"
