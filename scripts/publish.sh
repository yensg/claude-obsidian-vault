#!/usr/bin/env bash
# publish.sh — sync local personal SKILL.md → public repo with personal references stripped.
#
# Usage:
#   cd ~/Documents/GitHub/claude-obsidian-vault
#   ./scripts/publish.sh
#
# Personal config lives in scripts/.publish-env (gitignored — never committed).
# Copy scripts/.publish-env.example to scripts/.publish-env and fill in your values.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SRC="$HOME/.claude/skills/vault/SKILL.md"
DST="$REPO_ROOT/SKILL.md"
CONFIG="$SCRIPT_DIR/.publish-env"

[[ -f "$SRC" ]] || { echo "ERROR: $SRC not found"; exit 1; }
[[ -f "$CONFIG" ]] || { echo "ERROR: $CONFIG not found. Copy .publish-env.example and fill in your values."; exit 1; }

# shellcheck disable=SC1090
source "$CONFIG"

: "${VAULT_PERSONAL_PATH:?VAULT_PERSONAL_PATH not set in .publish-env}"
: "${VAULT_PERSONAL_NAME:?VAULT_PERSONAL_NAME not set in .publish-env}"
: "${VAULT_PROTECTED_NAME:?VAULT_PROTECTED_NAME not set in .publish-env}"
: "${VAULT_OWNER_PROJECTS:?VAULT_OWNER_PROJECTS not set in .publish-env}"
: "${VAULT_OWNER_NAME:?VAULT_OWNER_NAME not set in .publish-env}"

echo "Copying $SRC → $DST"
cp "$SRC" "$DST"

python3 - "$DST" \
  "$VAULT_PERSONAL_PATH" \
  "$VAULT_PERSONAL_NAME" \
  "$VAULT_PROTECTED_NAME" \
  "$VAULT_OWNER_PROJECTS" \
  "$VAULT_OWNER_NAME" <<'PYEOF'
import sys, re

path, personal_path, vault_name, protected_name, owner_projects, owner_name = sys.argv[1:7]
# Short form of protected name without owner prefix (e.g. "Main Vault" from "My Main Vault")
protected_short = protected_name.split("'s ", 1)[-1] if "'s " in protected_name else protected_name
# Slug for wiki-links: strip all non-alphanumeric/underscore chars (not just spaces).
owner_slug = re.sub(r"[^a-zA-Z0-9_]", "", owner_name)

with open(path) as f:
    text = f.read()

SUBS = [
    # Frontmatter description
    (
        f'the user\'s Obsidian "{vault_name}"',
        "the user's Obsidian"
    ),
    # Intro line
    (
        f"Save conversation findings into {vault_name} vault.",
        "Save conversation findings into your Obsidian vault."
    ),
    # Hardcoded vault path
    (
        personal_path,
        "/path/to/your/obsidian/vault"
    ),
    # Safety rule (uses short protected name)
    (
        f"**Never write, edit, or delete inside the user's other Obsidian vault** (the {protected_short} one). That vault is read-only to this skill. Only `{vault_name}` is writable. Before every Write/Edit, self-check the target path. If path falls outside `<VAULT>`, refuse. A PreToolUse hook also enforces this independently.",
        "**Never write, edit, or delete inside any other Obsidian vault** (only your designated `<VAULT>` is writable). Before every Write/Edit, self-check the target path. If the path falls outside `<VAULT>`, refuse. A PreToolUse hook can also enforce this independently (see `hooks/protect-mind-palace.sh`)."
    ),
    # Concrete example — "tied to the owner's projects"
    (
        f"— nested inline story tied to {owner_name}'s projects",
        "— nested inline story tied to your own projects"
    ),
    # Frontmatter YAML example (wrong — uses personal project name as wikilink)
    (
        f"related_projects: [[{owner_slug}s_Claude_Palace]]",
        "related_projects: [[Your_Project_Name]]"
    ),
    # Frontmatter YAML example (correct quoted form)
    (
        f'  - "[[{owner_slug}s_Claude_Palace]]"',
        '  - "[[Your_Project_Name]]"'
    ),
    # Tag vocabulary intro (ends with short protected name)
    (
        f"Domain tags mirror {protected_name} Johnny Decimal top-level folders. Searching `#programming` in {vault_name} returns the same conceptual set as browsing `100 - Programming/` in {protected_short}.",
        "Domain tags reflect your vault's top-level knowledge areas. Customize these to match your own domains — the list below is a starting point."
    ),
    # Domain tag label (uses short protected name)
    (
        f"- **Domain (matches {protected_short}):**",
        "- **Domain:**"
    ),
    # Voice guide header (uses full protected name)
    (
        f"Match it precisely — never default to generic Claude prose. Validated against an audit of {protected_name}.",
        "Match it precisely — never default to generic Claude prose."
    ),
    # Section self-contained note (uses short protected name as concept)
    (
        f"- Each section is **self-contained** — readable in isolation. {protected_short} pattern.",
        "- Each section is **self-contained** — readable in isolation."
    ),
    # Examples priority list
    (
        f"- Priority: personal/lived ({owner_projects}) → borrowed (course/teacher) → invented hypothetical.",
        "- Priority: personal/lived (your own projects, work, hobbies) → borrowed (course/teacher/book) → invented hypothetical."
    ),
    # Voice tics section header
    (
        f"### {owner_name}'s verbal tics (use sparingly, deliberately)",
        "### Voice patterns (use sparingly, deliberately)"
    ),
    # Voice & style guide section header
    (
        f"## Voice & style guide (write like {owner_name})",
        "## Voice & style guide"
    ),
    # Callout admonition anti-pattern
    (
        f"- Never use callout admonitions (`> [!note]`) — {owner_name} doesn't use them.",
        "- Never use callout admonitions (`> [!note]`) — avoid them."
    ),
    # Anti-pattern (uses short protected name)
    (
        f"- Don't reference {protected_short} paths in note bodies or frontmatter. {protected_short} stays out of file relationships entirely.",
        "- Don't reference paths from other vaults in note bodies or frontmatter. Your protected vault stays out of file relationships entirely."
    ),
]

failed = []
for old, new in SUBS:
    if old in text:
        text = text.replace(old, new)
        print(f"  ✓ {old[:70].strip()}")
    else:
        print(f"  ⚠ NOT FOUND: {old[:70].strip()}")
        failed.append(old)

# Insert setup instruction after vault path placeholder if missing
PLACEHOLDER_BLOCK = "/path/to/your/obsidian/vault\n```\n\nRefer to this below"
SETUP_BLOCK = "/path/to/your/obsidian/vault\n```\n\n**One-time setup:** Replace `/path/to/your/obsidian/vault` above with the absolute path to your Obsidian vault folder. This path is used throughout the skill as `<VAULT>`.\n\nRefer to this below"
if PLACEHOLDER_BLOCK in text and SETUP_BLOCK not in text:
    text = text.replace(PLACEHOLDER_BLOCK, SETUP_BLOCK)
    print("  ✓ inserted setup instruction")

with open(path, 'w') as f:
    f.write(text)

if failed:
    print(f"\n  {len(failed)} substitution(s) not found — strings may have drifted. Review and update publish.sh.")
    sys.exit(1)
PYEOF
if [ $? -ne 0 ]; then
  echo "ERROR: substitution drift detected above. Fix publish.sh before pushing."
  exit 1
fi

echo ""
echo "Checking for remaining personal references..."
# Use grep -F (fixed-string) per pattern to avoid metacharacter expansion in vault names.
LEAKS=$(
  grep -inF "$VAULT_PERSONAL_NAME" "$DST" 2>/dev/null || true
  grep -inF "$VAULT_PROTECTED_NAME" "$DST" 2>/dev/null || true
  grep -inF "$VAULT_OWNER_NAME" "$DST" 2>/dev/null || true
  grep -inF "$VAULT_PERSONAL_PATH" "$DST" 2>/dev/null || true
)
if [[ -n "$LEAKS" ]]; then
    echo "⚠ PERSONAL REFERENCES STILL PRESENT — review before pushing:"
    echo "$LEAKS"
    exit 1
else
    echo "✓ No personal references found."
    echo ""
    echo "Next: review diff, then commit:"
    echo "  git diff SKILL.md"
    echo "  git add SKILL.md scripts/publish.sh scripts/.publish-env.example .gitignore && git commit -m 'chore: sync skill from local'"
fi
