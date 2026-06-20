#!/usr/bin/env bash
# PreToolUse hook: multi-layer defense for vault writes.
# Layer 1 — blocks path traversal (../) in Write/Edit/NotebookEdit file_path.
# Layer 2 — denylist: blocks writes whose canonical path references the protected vault.
#            Uses realpath canonicalization to defeat symlink escapes and
#            string-prefix bypasses (e.g. <VAULT>-evil/, <VAULT>/link-out/).
# Layer 3 — Bash: blocks commands that write/mutate the protected vault, with an
#            expanded write-op pattern set covering redirects, interpreters, rsync, etc.
#
# Limitation: this is a denylist, not a full allowlist. The skill's own path safety
# gate (Step 4) is the primary confinement layer for vault writes.
#
# Setup: set VAULT_PROTECTED_NAME to the name of the vault you want to protect
# (the one Claude should NEVER write to). Use the exact folder name as it appears
# in the file path. Export it in your shell profile or edit this file directly.
#
# Contract: receives JSON on stdin with keys { tool_name, tool_input, ... }.
# To block: emit JSON {"decision":"block","reason":"..."} on stdout, exit 0.

set -euo pipefail

# Hard dependency check — fail loudly rather than silently allowing on parse failure.
if ! command -v jq >/dev/null 2>&1; then
  printf '{"decision":"block","reason":"BLOCKED: jq not found — hook cannot safely parse input. Install jq."}\n'
  exit 0
fi

INPUT="$(cat)"
TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')"

# Protected vault: the folder name Claude must never write to.
# Set VAULT_PROTECTED_NAME in your environment or replace the default below.
# Uses literal string match (grep -F) — apostrophes and special chars are safe.
PROTECTED_LITERAL="${VAULT_PROTECTED_NAME:-My Protected Vault}"

# Canonicalize a path (resolve symlinks, normalize ..). Falls back to original
# path if realpath is unavailable or fails (macOS built-in lacks -m flag).
_canon() {
  local p="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$p" 2>/dev/null || printf '%s' "$p"
  else
    printf '%s' "$p"
  fi
}

# Bash write-operation patterns — only evaluated when PROTECTED_LITERAL is already
# present in the command, so false-positive risk is low.
_BASH_UTIL_RE='\b(rm|mv|cp|tee|touch|mkdir|chmod|chown|dd|rsync|install|truncate)\b'
_BASH_INPLACE_RE='sed[[:space:]]+-i|awk[[:space:]]+-i|perl[[:space:]]+-[pi]'
_BASH_INTERP_RE='\b(python[23]?|node|ruby|php|perl)[[:space:]]+'
_BASH_REDIR_RE='>[[:space:]]*["/'"'"'/~]'
_BASH_GIT_RE='git[[:space:]]+(apply|checkout|restore|reset[[:space:]]+--hard)'

_bash_writes_protected() {
  local cmd="$1"
  printf '%s' "$cmd" | grep -qF "$PROTECTED_LITERAL" || return 1
  printf '%s' "$cmd" | grep -qE "$_BASH_UTIL_RE"    && return 0
  printf '%s' "$cmd" | grep -qE "$_BASH_INPLACE_RE" && return 0
  printf '%s' "$cmd" | grep -qE "$_BASH_INTERP_RE"  && return 0
  printf '%s' "$cmd" | grep -qE "$_BASH_REDIR_RE"   && return 0
  printf '%s' "$cmd" | grep -qE "$_BASH_GIT_RE"     && return 0
  return 1
}

case "$TOOL_NAME" in
  Write|Edit|NotebookEdit|MultiEdit)
    # NotebookEdit uses notebook_path; all others use file_path.
    FP="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')"

    # Layer 1: block path traversal (../ or /..)
    if [[ -n "$FP" ]] && printf '%s' "$FP" | grep -qE '(^|/)\.\.(/|$)'; then
      jq -n --arg fp "$FP" \
        '{decision:"block", reason:("BLOCKED: path traversal (..) detected. path=" + $fp)}'
      exit 0
    fi

    # Layer 2: canonicalize then check for protected vault
    if [[ -n "$FP" ]]; then
      CANON="$(_canon "$FP")"
      if printf '%s' "$CANON" | grep -qF "$PROTECTED_LITERAL"; then
        jq -n --arg fp "$FP" --arg canon "$CANON" \
          '{decision:"block", reason:("BLOCKED: canonical path references the protected vault. path=" + $fp + " canonical=" + $canon)}'
        exit 0
      fi
    fi
    ;;

  Bash)
    CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')"

    # Block traversal targeting the protected vault via Bash
    if printf '%s' "$CMD" | grep -qF "$PROTECTED_LITERAL" && \
       printf '%s' "$CMD" | grep -qE '(^|/)\.\.(/|$)'; then
      jq -n --arg cmd "$CMD" \
        '{decision:"block", reason:("BLOCKED: Bash command references protected vault with path traversal.")}'
      exit 0
    fi

    # Block write-like Bash operations targeting the protected vault
    if _bash_writes_protected "$CMD"; then
      jq -n --arg cmd "$CMD" \
        '{decision:"block", reason:("BLOCKED: Bash command appears to write/modify the protected vault.")}'
      exit 0
    fi
    ;;
esac

exit 0
