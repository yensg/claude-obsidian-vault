#!/usr/bin/env bash
# PreCompact hook: snapshot current session transcript to your vault's inbox
# before context compaction (manual /compact or auto) destroys detail. Also
# injects a system reminder telling the LLM to prompt the user to run /vault.
#
# WARNING: the dump includes the full transcript — API keys, tokens, file paths,
# and any other sensitive content visible in the session. The dump lands in your
# Obsidian vault. Be aware of what is in your session before triggering /compact.
#
# Setup: set VAULT_INBOX to your vault's 0_Inbox folder path, or export it in
# your shell profile.
#
# Contract: receives JSON on stdin with keys { transcript_path, trigger, ... }.
# `trigger` is "manual" or "auto".
# To inject context for the LLM, respond with JSON on stdout:
#   {"hookSpecificOutput": {"hookEventName": "PreCompact", "additionalContext": "..."}}

set -euo pipefail

# Hard dependency check — fail loudly rather than silently allowing on parse failure.
if ! command -v jq >/dev/null 2>&1; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreCompact","additionalContext":"dump-before-compact.sh: jq not found — cannot parse hook input. Install jq to enable vault dumps."}}\n'
  exit 0
fi

# Configure: absolute path to your vault's 0_Inbox folder.
# Example: /Users/yourname/path/to/vault/0_Inbox
VAULT_INBOX="${VAULT_INBOX:-/path/to/your/obsidian/vault/0_Inbox}"

if [ "$VAULT_INBOX" = "/path/to/your/obsidian/vault/0_Inbox" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreCompact","additionalContext":"dump-before-compact.sh: VAULT_INBOX not configured. Edit the hook or export VAULT_INBOX=your/vault/0_Inbox in your shell profile."}}\n'
  exit 0
fi

mkdir -p "$VAULT_INBOX"

INPUT="$(cat)"
TRANSCRIPT_PATH="$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty')"
TRIGGER="$(printf '%s' "$INPUT" | jq -r '.trigger // "unknown"')"
# Sanitize trigger to safe YAML chars before embedding in frontmatter.
TRIGGER_SAFE="$(printf '%s' "$TRIGGER" | tr -dc 'a-zA-Z0-9_-' | head -c 64)"

TS="$(date +%Y%m%d_%H%M%S)"
# Use mktemp to avoid same-second collision overwrites.
TARGET="$(mktemp "$VAULT_INBOX/precompact_${TS}_XXXXXX.md")"

{
  echo "---"
  echo "title: PreCompact dump $TS"
  echo "type: raw-capture"
  echo "tags: [inbox, precompact, needs-refinement]"
  echo "created: $(date +%Y-%m-%d)"
  echo "trigger: $TRIGGER_SAFE"
  echo "---"
  echo
  echo "# Raw transcript before compaction"
  echo
  echo "> Run \`/vault\` to organize this into atomic notes + MOC entries."
  echo
  if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
    echo "_Source: \`$TRANSCRIPT_PATH\`_"
    echo
    echo '````jsonl'
    cat "$TRANSCRIPT_PATH"
    echo '````'
  else
    echo "_(Transcript path not provided by harness — refer to ~/.claude/sessions/ manually.)_"
  fi
} > "$TARGET"

# Inject reminder for the LLM
jq -n --arg target "$TARGET" --arg trigger "$TRIGGER" \
  '{hookSpecificOutput: {hookEventName: "PreCompact", additionalContext: ("Context compaction (\($trigger)) just dumped the full transcript to \($target). After compaction completes, the user should run /vault to organize findings into atomic notes before continuing.")}}'

exit 0
