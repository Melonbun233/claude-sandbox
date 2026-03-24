# Modes

## Develop

**Type**: Interactive
**When**: Feature development, bug fixes, refactoring, exploration

Start the container and attach to use Claude Code with full terminal formatting:

```bash
./claude-dev start --mode=develop
./claude-dev attach
```

Claude has access to:
- All cloned workspace repos in `/workspace/`
- `gh` CLI authenticated to all configured GitHub servers
- `jira-*` read-only query scripts
- All skills (pr-review, test-gen) and agents (developer, reviewer)

### With --dangerously-skip-permissions

```bash
SKIP_PERMISSIONS=true ./claude-dev start --mode=develop
./claude-dev attach --skip-permissions
```

This skips all permission prompts. Use only when you trust the task and want Claude to work autonomously.

---

## PR Review

**Type**: Non-interactive (one-shot)
**When**: Code review of pull requests

### Dry-run (default)

Reviews the PR and saves output to `/workspace/.claude-session/review.md`:

```bash
./claude-dev run --mode=pr-review --pr=123
```

Inspect the review, then post it:

```bash
./claude-dev pr-submit
```

### Direct post

Skip dry-run and post the review directly to GitHub:

```bash
./claude-dev run --mode=pr-review --pr=org/repo#456 --no-dry-run
```

### Cross-server PRs

For PRs on enterprise GitHub servers, ensure the server is in `workspace.yaml`'s `github_servers` list with a valid token.
