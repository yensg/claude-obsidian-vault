# claude-obsidian-vault

A Claude Code skill that turns your conversations into a structured Obsidian second brain — automatically.

Every time you finish a deep session (debugging a hard problem, learning something new, making an architecture decision), run `/vault` and Claude organises the findings into atomic notes, cross-links them, and adds them to curated Maps of Content. Nothing gets lost between sessions.

---

## What it does

- **Extracts** concepts, decisions, code patterns, diagrams, and project notes from the current conversation
- **Deduplicates** against your existing vault — edits existing notes when the topic already exists, creates new ones when it doesn't
- **Writes** atomic Markdown notes following a consistent voice and structure (numbered emoji headers, direct claims, personal examples, anti-patterns, open questions)
- **Cross-links** everything — minimum 2 `[[wiki-links]]` per note so nothing is orphaned
- **Builds Maps of Content** as curated learning curricula, not flat link dumps
- **Runs a refinement loop** after saving — ask Claude to fix wording, add context, or merge notes until you're satisfied

---

## Modes

| Command | What it does |
|---------|-------------|
| `/vault` | Capture mode — extracts findings from the current conversation, confirms with you, writes notes |
| `/vault --inbox` | Batch-process PreCompact dumps in `0_Inbox/` without prompting |
| `/vault --query "…"` | Read-only — answer a question from your vault contents |
| `/vault --lint` | Audit for orphaned notes, broken links, missing sections, and candidate contradictions |
| `/vault --stats` | Health metrics — most-linked notes, isolated notes, totals per folder |
| `/vault --ingest <url\|file>` | Pull an external source (article, PDF, local file) into the vault |
| `/vault --help` | Print the flag reference and exit |

---

## Prerequisites

- [Claude Code](https://claude.ai/code) installed and working
- [Obsidian](https://obsidian.md) with a vault already set up
- The vault folder structure below (create it once — Claude writes into it)

---

## Installation

**1. Copy the skill into your Claude skills folder:**

```bash
mkdir -p ~/.claude/skills/vault
cp SKILL.md ~/.claude/skills/vault/SKILL.md
```

**2. Set your vault path:**

Open `~/.claude/skills/vault/SKILL.md` and replace the placeholder near the top:

```
/path/to/your/obsidian/vault
```

with the absolute path to your Obsidian vault folder. For example:

```
/Users/yourname/Documents/MyVault
```

That's it. The skill is ready.

**3. (Optional) Create the vault folder structure:**

The skill expects this layout inside your vault. Create it once:

```bash
mkdir -p ~/path/to/vault/{0_Inbox/raw,1_Projects,2_Areas,3_Resources,4_Archive,5_Notes,6_MOCs,_meta/templates}
```

---

## Vault folder structure

```
your-vault/
├── 0_Inbox/        # Incoming dumps; raw/ holds immutable source files
├── 1_Projects/     # Active project work (README + notes/ + decisions/)
├── 2_Areas/        # Ongoing responsibilities (flat, one file per area)
├── 3_Resources/    # Reference material: LeetCode/, Books/, Cheatsheets/
├── 4_Archive/      # Inactive items
├── 5_Notes/        # FLAT atomic Zettelkasten notes — no subfolders
├── 6_MOCs/         # Maps of Content + Home.md
└── _meta/          # Templates: concept.md, project.md, leetcode.md, moc.md
```

Note naming in `5_Notes/`: lowercase, hyphen-separated, no dates in filename. Date goes in frontmatter `created:` field.
Example: `rag-chunking.md`, `tool-calling.md`, `prompt-caching.md`

---

## The PARAZETTEL method

This skill uses a hybrid of three knowledge systems:

**PARA** (Tiago Forte) — the execution engine. Four folders: Projects (active), Areas (ongoing), Resources (reference), Archive (inactive). Everything has a home.

**Zettelkasten** (Niklas Luhmann) — the insight engine. Every idea gets its own atomic note, written to be self-contained and densely linked. Notes reference each other by concept, not by folder hierarchy.

**Maps of Content** (Nick Milo / LYT) — flexible curriculum hubs. Instead of rigid folder nesting, MOCs are notes that sequence links into a learning path. Updating a MOC *is* the learning act — you re-sequence what you know every time you add something new.

**LLM-wiki pattern** (Andrej Karpathy) — Claude maintains the wiki. It writes summaries, adds backlinks, detects existing notes to update vs. create, and keeps the graph connected. You provide the raw conversation; Claude provides the synthesis.

---

## Note structure

Every concept note follows the same template — eight numbered sections with emoji headers, a direct one-line claim as the opening blockquote, and personal examples before hypothetical ones:

```markdown
# Note title

> One-line direct claim about this concept.

## 1️⃣ What is this really?
## 2️⃣ Concrete example (from my work)
## 3️⃣ How it works (top-down)
## 4️⃣ Compare / contrast
## 5️⃣ Anti-patterns (what NOT to do)
## 6️⃣ Why I'm learning this
## 7️⃣ Questions to deepen this
## Related
## Refinements
## Source
```

**Confidence tagging** — claims are tagged inline where the distinction matters:
- `(extracted)` — the source stated this directly
- `(inferred)` — you introduced an analogy or extension not in the source
- `(ambiguous)` — the field has no consensus or sources conflict

---

## Rename propagation

When you tell the skill something was renamed, it:
1. Greps the vault for the old name (word-boundary match, skips raw captures, templates, archive, and historical decision notes)
2. Shows you the full file list and match counts before touching anything
3. Applies replacements only after your explicit confirmation

---

## Safety

**Path safety gate** — built into the skill itself. Every Write/Edit checks that the target path starts with your `<VAULT>` path and contains no `..` traversal. Refuses and tells you if either check fails.

**Optional PreToolUse hook** — for extra defense-in-depth, you can add a hook to `~/.claude/hooks/` that blocks any Write/Edit/Bash tool call whose path or command references a vault you want to protect. Useful if you have multiple Obsidian vaults and want a hard guarantee that the skill can never touch the wrong one.

See the [Claude Code hooks documentation](https://docs.anthropic.com/en/docs/claude-code/hooks) for how to set up hooks.

---

## Companion: PreCompact dump hook

Claude Code can compact long conversations automatically. If you add a `dump-before-compact.sh` hook (fired on the `PreCompact` event), it snapshots the full conversation into `0_Inbox/precompact_<timestamp>.md` before compaction runs — so nothing is lost.

After a compaction, run `/vault --inbox` to process any pending dumps in one batch.

---

## License

MIT
