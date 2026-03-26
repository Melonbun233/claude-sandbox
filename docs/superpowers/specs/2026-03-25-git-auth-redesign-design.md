# Git Auth & Cloning Redesign

**Date:** 2026-03-25
**Status:** Approved
**Scope:** Git authentication and repo cloning only. Jira, config cascade, session lifecycle, Anthropic config unchanged.

## Problem

The current git auth setup has two concrete failures:

1. **`gh` auth ≠ `git` auth.** `setup-github.sh` authenticates the `gh` CLI and runs `gh auth setup-git` as a credential helper. Raw `git push/pull/fetch` inside the container doesn't reliably pick up credentials, especially for enterprise servers where `gh`'s credential helper behaves differently.

2. **HTTPS-only with token injection.** `clone-repos.sh` injects PATs directly into clone URLs (`https://x-access-token:TOKEN@host/...`). This breaks for private Git servers that only support SSH or require different auth mechanisms. The injected-URL pattern also means credentials are visible in `.git/config` remote URLs.

**Root cause:** The design assumes all servers use HTTPS with PATs and routes everything through `gh`. It provides no SSH path and no native git credential support.

## Requirements

- Per-server auth method choice (`ssh` or `https`) in workspace.yaml
- SSH support: opt-in mount of host `~/.ssh/` (read-only), with optional per-server `ssh_key:` override
- HTTPS fix: write PATs to `git-credential-store` so native git commands work; chain `gh` as secondary credential helper
- Git config: opt-in mount of host `~/.gitconfig` (read-only), per-server identity overrides win
- All configuration in workspace.yaml (new `git_config:` top-level section)
- Fully backward compatible — existing workspace.yaml files work without changes

## Approach: CLI-Driven Mounts (Approach B)

The host CLI (`claude-dev`) reads workspace.yaml and generates a `docker-compose.override.yaml` at runtime with conditional volume mounts. Container scripts handle credential setup.

## Design

### 1. workspace.yaml Schema Changes

New top-level `git_config:` section, plus per-server `auth_method` and `ssh_key`:

```yaml
# ── Git Configuration ─────────────────────────────────────────
git_config:
  mount_ssh: true           # opt-in: mount host ~/.ssh/ read-only
  mount_gitconfig: true     # opt-in: mount host ~/.gitconfig read-only

# ── GitHub Servers ────────────────────────────────────────────
github_servers:
  - host: github.com
    auth_method: https       # ssh | https (default: https)
    token_env: GH_TOKEN      # required for auth_method: https
    # user_name: Jane Doe
    # user_email: jane@personal.com

  - host: github.enterprise.corp.com
    auth_method: ssh          # use SSH keys for this server
    ssh_key: id_ed25519_work  # optional: filename in ~/.ssh/ for this server
    # ssh_port: 22            # optional: non-standard SSH port (default: 22)
    user_name: Jane Doe
    user_email: jane.doe@corp.com
    ssl_verify: false
```

**Rules:**
- `git_config:` section is optional. If absent, no SSH/gitconfig mounts.
- `auth_method` defaults to `https` (backward compatible).
- `token_env` required when `auth_method: https`. Optional when `auth_method: ssh` — if provided, used for `gh` CLI auth only (so `gh pr`, `gh issue` work).
- `ssh_key` is a filename relative to the host's `~/.ssh/` directory (e.g., `id_ed25519_work`). The CLI validates the file exists at `~/.ssh/<ssh_key>` before starting the container.
- `mount_ssh: true` is required for any server using `auth_method: ssh` (validated at startup).

### 2. CLI Changes (`claude-dev`)

Before calling `docker compose up`, the CLI parses `git_config:` from `config/workspace.yaml` and generates a `docker-compose.override.yaml` with conditional volume mounts:

```yaml
# Generated at runtime by claude-dev, gitignored
services:
  claude-dev:
    volumes:
      - ${HOME}/.ssh:/home/claude/.ssh:ro
      - ${HOME}/.gitconfig:/home/claude/.gitconfig.host:ro
```

- If `mount_ssh: true`: include the `~/.ssh` mount
- If `mount_gitconfig: true`: include the `~/.gitconfig` mount (staged as `.host`, copied by `setup-git.sh` so per-server overrides can be layered)
- The override file is written to the project directory and picked up automatically by `docker compose` (which merges `docker-compose.yaml` + `docker-compose.override.yaml`)
- The override file is added to `.gitignore`

**Validation (before generating override / starting container):**
- If any server has `auth_method: ssh` but `mount_ssh` is not `true`: warn and abort
- If `mount_ssh: true` but `~/.ssh/` does not exist on host: warn and abort
- If a server specifies `ssh_key: <name>` but `~/.ssh/<name>` does not exist: warn and abort
- If `mount_gitconfig: true` but `~/.gitconfig` does not exist on host: warn (continue — not fatal)

All existing CLI commands unchanged. Session naming, volume management, compose project naming unchanged.

### 3. Container Script: `setup-git.sh` (replaces `setup-github.sh`)

**Execution order:** `setup-git.sh` runs before `clone-repos.sh` in `entrypoint.sh` (same slot as the current `setup-github.sh`). All credential and SSH configuration must complete before any cloning begins.

#### Host gitconfig (runs first):
- If `~/.gitconfig.host` exists (mounted): copy to `~/.gitconfig`
- Per-server identity overrides are applied per-repo by `clone-repos.sh` after cloning (same as today)
- If not mounted: no global gitconfig, per-server identity still works
- **Limitation:** host `~/.gitconfig` `[include]` directives pointing to files outside `~/.gitconfig` itself will not resolve inside the container.

#### HTTPS servers (`auth_method: https`):
1. Write PAT to `~/.git-credentials`: `https://x-access-token:{TOKEN}@{HOST}`
2. Configure `git config --global credential.helper store` (queries `~/.git-credentials` first)
3. Chain `gh` as secondary: `git config --global --add credential.helper '!gh auth git-credential'` (appended, so `store` has priority; `gh` is fallback)
4. Authenticate `gh` CLI per server (for `gh pr`, `gh issue`, etc.)

Note: tokens are written fresh to `~/.git-credentials` on every container start, so stale credentials are not a concern.

#### SSH servers (`auth_method: ssh`):
1. If `ssh_key` specified: append `~/.ssh/config` entry (`Host`, `HostName`, `IdentityFile /home/claude/.ssh/<key>`, `IdentitiesOnly yes`). The mounted `~/.ssh/` is read-only, so we write to a copy or append to the config.
2. If no `ssh_key`: rely on default key selection from mounted `~/.ssh/config` or ssh-agent
3. Add host to `~/.ssh/known_hosts` via `ssh-keyscan -H {HOST}`. Error handling: if `ssh-keyscan` fails (timeout, unreachable), log a warning and continue — the clone will fail later with a clear SSH error. For non-standard SSH ports, add optional `ssh_port` field to workspace.yaml server config.
4. If the server also has a `token_env`: authenticate `gh` CLI for that host (so `gh pr` works even over SSH)

**Out of scope for this iteration:** SSH agent forwarding (`SSH_AUTH_SOCK`). Users relying on ssh-agent or hardware keys (YubiKey) must use key files for now.

#### SSL config:
Unchanged — `ssl_verify: false` sets `git http.<host>.sslVerify false` (applies to HTTPS git operations and `gh` CLI API calls only; silently irrelevant for SSH git operations). `ca_cert` handled by `setup-certs.sh`.

### 4. Clone Script Changes (`clone-repos.sh`)

URL construction switches based on `auth_method`:

| `auth_method` | Clone URL |
|---------------|-----------|
| `https` | `https://github.com/org/repo.git` (no token in URL) |
| `ssh` | `git@github.com:org/repo.git` |

**Key changes from today:**
- No more token injection into URLs. HTTPS clones rely on `git-credential-store`. Git asks the credential helper, gets the PAT, authenticates.
- SSH URL conversion: repo URL in workspace.yaml is always `https://host/org/repo`. Clone script converts to `git@host:org/repo.git` when `auth_method: ssh`.
- Subsequent `git pull/push/fetch` works natively — credentials are configured globally.

**Unchanged:** per-repo branch scoping, per-repo git identity, error handling, `safe.directory` marking, already-cloned repos get `git pull --ff-only`.

**Existing cloned repos with token-injected URLs:** On restart, if a repo already exists and its remote URL contains embedded credentials (`x-access-token:...@`), `setup-git.sh` or `clone-repos.sh` rewrites the remote URL to the clean form (plain HTTPS or SSH) so the credential store / SSH keys are used instead. This handles migration of sessions created before this change.

### 5. Backward Compatibility

Fully backward compatible. No breaking changes.

- `git_config:` section optional. If absent, same behavior as today.
- `auth_method` defaults to `https`. Existing workspace.yaml files work unchanged.
- Only behavioral difference for existing HTTPS users: credential-store instead of token-injected URLs. Same result, better plumbing.

**Migration for SSH users:**
1. Add `git_config: mount_ssh: true`
2. Set `auth_method: ssh` on desired servers
3. Optionally add `ssh_key:` per server
4. Restart session (no rebuild needed)

## Files Changed

| File | Change |
|------|--------|
| `config/workspace.yaml.example` | Add `git_config:` section, `auth_method`/`ssh_key`/`ssh_port` examples |
| `claude-dev` | Parse `git_config`, generate `docker-compose.override.yaml`, validation |
| `docker-compose.override.yaml` | Generated at runtime (gitignored), conditional SSH/gitconfig mounts |
| `.gitignore` | Add `docker-compose.override.yaml` |
| `scripts/setup-github.sh` → `scripts/setup-git.sh` | Rename, add SSH setup + git-credential-store + gitconfig copy |
| `scripts/clone-repos.sh` | URL construction based on `auth_method`, rewrite stale remote URLs |
| `scripts/entrypoint.sh` | Call `setup-git.sh` instead of `setup-github.sh` |
| `docker-compose.yaml` | No changes (override file handles conditional mounts) |
| `.env.example` | Add comment: tokens only needed for HTTPS servers |

**No Dockerfile change needed:** `openssh-client` is already installed (provides `ssh`, `ssh-keyscan`, `ssh-agent`).

## Verification Plan

Manual tests to confirm the feature works (no automated test suite):

1. **HTTPS clone + push:** Configure a server with `auth_method: https`, clone a private repo, run `git push` inside the container — verify credential store is used (no token in remote URL)
2. **SSH clone + push:** Configure a server with `auth_method: ssh`, `mount_ssh: true`, clone a private repo via SSH, run `git push` — verify SSH key is used
3. **Per-server SSH key:** Configure `ssh_key: id_ed25519_work` for one server, verify the correct key is selected
4. **`gh` CLI on SSH server:** Configure an SSH server with `token_env`, verify `gh pr list` works
5. **Backward compatibility:** Use an existing workspace.yaml with no `git_config:` section, verify everything works as before
6. **Session restart migration:** Start a session with old token-injected URLs, restart with new config, verify remote URLs are rewritten
7. **Validation errors:** Test `auth_method: ssh` without `mount_ssh: true`, verify CLI aborts with clear error
