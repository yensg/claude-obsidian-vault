#!/usr/bin/env bash
# PreToolUse hook: security scan before any git-based skill upgrade.
#
# Intercepts Bash commands containing "git reset --hard origin" (the apply step
# of every skill upgrade). Runs git fetch itself (idempotent), inspects the
# incoming diff for shell execution, credential exfiltration, and persistence
# patterns, then allows, warns, or blocks.
#
# Contract (same as protect-mind-palace.sh):
#   Block: emit {"decision":"block","reason":"..."} on stdout + exit 0
#   Warn:  write message to stderr + exit 1 (user sees it, upgrade proceeds)
#   Allow: exit 0, no output
#
# Log: ~/.claude/upgrade-security.log

set -euo pipefail

# Hard dependency check
if ! command -v jq >/dev/null 2>&1; then
  printf 'Upgrade security warning: jq not found — scanner cannot parse input, allowing upgrade\n' >&2
  exit 1
fi

INPUT="$(cat)"
TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')"
[ "$TOOL_NAME" = "Bash" ] || exit 0

CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')"

# Intercept git upgrade commands in skill directories.
# Expanded pattern covers: reset --hard, pull, fetch+checkout, fetch+merge.
printf '%s' "$CMD" | grep -qE \
  'git[[:space:]]+(reset[[:space:]]+--hard[[:space:]]+origin|pull[[:space:]]|fetch[[:space:]].*&&.*(checkout|merge|reset))' \
  || exit 0

# --- Determine the skill directory ---
# Try to extract from a quoted cd statement: cd "/path/.claude/skills/foo"
SKILL_DIR=$(printf '%s' "$CMD" | \
  sed -n 's/.*cd[[:space:]]*"\([^"]*\.claude\/skills\/[^"]*\)".*/\1/p' | head -1)

# Fallback: unquoted cd or inline path reference
if [ -z "$SKILL_DIR" ]; then
  SKILL_DIR=$(printf '%s' "$CMD" | \
    grep -oE '[^[:space:]";&]+\.claude/skills/[a-zA-Z0-9_-]+' | head -1)
  SKILL_DIR="${SKILL_DIR/#\~/$HOME}"
fi

SKILL_NAME=$(basename "${SKILL_DIR:-unknown}")
LOG="$HOME/.claude/upgrade-security.log"

# If we still can't find a git repo, log and allow (don't block what we can't inspect)
if [ -z "$SKILL_DIR" ] || [ ! -d "$SKILL_DIR/.git" ]; then
  printf '[%s] WARN: could not locate skill git dir — allowing upgrade\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$LOG"
  exit 0
fi

# Fetch incoming changes (idempotent — the upgrade command will re-fetch)
git -C "$SKILL_DIR" fetch origin --quiet 2>/dev/null || {
  printf '[%s] WARN: git fetch failed for %s — allowing upgrade\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SKILL_NAME" >> "$LOG"
  exit 0
}

CURRENT_SHA=$(git -C "$SKILL_DIR" rev-parse HEAD 2>/dev/null || echo "unknown")
INCOMING_SHA=$(git -C "$SKILL_DIR" rev-parse origin/main 2>/dev/null || echo "unknown")
COMMIT_COUNT=$(git -C "$SKILL_DIR" rev-list HEAD..origin/main --count 2>/dev/null || echo "0")

printf '[%s] Checking %s: %s -> %s (%s new commits)\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SKILL_NAME" \
  "${CURRENT_SHA:0:8}" "${INCOMING_SHA:0:8}" "$COMMIT_COUNT" >> "$LOG"

# No incoming commits — nothing to inspect, allow
[ "$COMMIT_COUNT" = "0" ] && exit 0

# Get the full diff
DIFF=$(git -C "$SKILL_DIR" diff HEAD..origin/main 2>/dev/null || echo "")

# Extract added lines from all files — INCLUDING .md and .tmpl.
# Previously .md/.tmpl were excluded, but SKILL.md/templates are the primary
# vector for prompt-injection attacks via malicious skill upgrades.
ADDED=$(printf '%s' "$DIFF" | awk '
  /^\+\+\+ / {
    skip = ($0 ~ /\.(txt|rst)([ \t]|$)/)
    next
  }
  /^--- / { next }
  /^\+[^+]/ && !skip { print substr($0, 2) }
')

# Strip comment-only lines (shell #, JS/TS //, block comment *)
CODE=$(printf '%s' "$ADDED" | \
  grep -v '^[[:space:]]*#' | \
  grep -v '^[[:space:]]*//' | \
  grep -v '^[[:space:]]*\*' || true)

BLOCK_REASON=""
WARN_MSG=""

_block() {
  local label="$1" pattern="$2"
  [ -n "$BLOCK_REASON" ] && return 0
  if printf '%s' "$CODE" | grep -qE "$pattern" 2>/dev/null; then
    BLOCK_REASON="$label"
    printf '[%s] MATCH(block): %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$label" >> "$LOG"
  fi
  return 0
}

# --- Tier 1: always block ---

# Piping a download directly to a shell interpreter
_block "remote-code-execution" \
  '(curl|wget)[[:space:]]+[^[:space:]]+[[:space:]]*\|[[:space:]]*(bash|sh|zsh|python|node|perl|ruby)'

# Base64-decode piped into a shell interpreter (not jq/cat/etc.)
_block "base64-execute" \
  'base64[[:space:]]+(-d|--decode).*\|[[:space:]]*(bash|sh|zsh|python[23]?|node|eval)'

# eval of dynamic content (variable, subshell, backtick, or string)
_block "eval-dynamic" \
  'eval[[:space:]]+[$`"]'

# Reverse shell via /dev/tcp or netcat
_block "reverse-shell" \
  '(/dev/tcp/|nc[[:space:]]+-[elnv])'

# Direct access to SSH private keys
_block "ssh-key-access" \
  '~/\.ssh/(id_rsa|id_ed25519|id_ecdsa|authorized_keys)'

# Cloud credential files or env vars
_block "cloud-creds-access" \
  '~/\.aws/(credentials|config)|AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY'

# Claude-specific OAuth tokens (Gmail, etc.)
_block "claude-token-access" \
  '~/\.claude/(gmail_token|gmail_client_secret|oauth)'

# macOS Keychain credential extraction
_block "keychain-dump" \
  'security[[:space:]]+(find-generic-password|find-internet-password)'

# Writing to shell startup files (persistence via profile injection)
_block "shell-profile-write" \
  '\.(bashrc|zshrc|bash_profile|zprofile)[[:space:]]*[>|]'

# Installing a launch agent or cron job (persistence)
_block "persistence-install" \
  '(LaunchAgents|launchctl[[:space:]]+load|crontab[[:space:]]+-[le])'

# --- Tier 2: warn but allow ---

# Outbound network calls to domains outside the expected set
if [ -z "$BLOCK_REASON" ] && [ -z "$WARN_MSG" ]; then
  UNEXPECTED=$(printf '%s' "$ADDED" | \
    grep -oE '(curl|wget)[[:space:]]+https?://[a-zA-Z0-9._-]+' | \
    grep -vE '(github\.com|api\.github\.com|raw\.githubusercontent\.com|npmjs\.org|yarnpkg\.com|bun\.sh|anthropic\.com)' \
    || true)
  if [ -n "$UNEXPECTED" ]; then
    WARN_MSG="outbound call to unrecognized domain"
    printf '[%s] MATCH(warn): unexpected-outbound\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$LOG"
  fi
fi

# More than 30 commits at once is unusual for a tool update — flag for awareness
if [ -z "$BLOCK_REASON" ] && [ -z "$WARN_MSG" ] && [ "$COMMIT_COUNT" -gt 30 ]; then
  WARN_MSG="large update: $COMMIT_COUNT new commits (inspect if unexpected)"
  printf '[%s] MATCH(warn): large-commit-count (%s)\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$COMMIT_COUNT" >> "$LOG"
fi

# Optional: gitleaks credential scan (if installed)
if [ -z "$BLOCK_REASON" ] && command -v gitleaks >/dev/null 2>&1; then
  if ! printf '%s' "$DIFF" | gitleaks detect --no-git --pipe --quiet 2>/dev/null; then
    BLOCK_REASON="gitleaks found credential patterns in diff"
    printf '[%s] MATCH(block): gitleaks\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$LOG"
  fi
fi

# --- Decision ---

if [ -n "$BLOCK_REASON" ]; then
  printf '[%s] DECISION: BLOCKED\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$LOG"
  jq -n \
    --arg skill "$SKILL_NAME" \
    --arg dir "$SKILL_DIR" \
    --arg reason "$BLOCK_REASON" \
    --arg log "$LOG" \
    '{
      decision: "block",
      reason: ("Upgrade blocked for \($skill): \($reason).\n\nTo inspect the diff manually:\n  git -C \($dir) diff HEAD..origin/main\n\nSecurity log: \($log)")
    }'
  exit 0
fi

if [ -n "$WARN_MSG" ]; then
  printf '[%s] DECISION: allowed with warning\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$LOG"
  printf 'Upgrade security warning (%s): %s\n' "$SKILL_NAME" "$WARN_MSG" >&2
  exit 1
fi

printf '[%s] DECISION: allowed (%s commits, clean)\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$COMMIT_COUNT" >> "$LOG"
exit 0
