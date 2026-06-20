# save-to-vault

Claude Code skill that exports conversation findings into the user's Obsidian
vault as a personal 2nd brain.

## What it does

- Scans the current conversation for concepts, diagrams, decisions, patterns,
  project info, and LeetCode problems.
- Writes them as atomic Markdown notes into a PARAZETTEL + MOC vault structure.
- Cross-links every note (minimum 2 `[[wiki-links]]`) so nothing is orphaned.
- Builds Maps of Content (MOCs) as curated learning curricula, not link dumps.
- Enters an endless refinement loop after saving — ask, refine, repeat — to
  improve notes over time.

## How to invoke

In any Claude Code conversation:

```
/save-to-vault          # interactive — picks findings, confirms with you
/save-to-vault --inbox  # process PreCompact dumps in 0_Inbox/ without prompting
```

Or just say: "save this to vault", "save findings", "add to second brain".

## Where notes land

```
/path/to/your/obsidian/vault/
├── 0_Inbox/        # raw captures (PreCompact dumps, quick notes)
├── 1_Projects/     # active project work
├── 2_Areas/        # ongoing responsibilities
├── 3_Resources/    # LeetCode, Books, Cheatsheets
├── 4_Archive/      # inactive
├── 5_Notes/        # atomic Zettelkasten notes (FLAT)
├── 6_MOCs/         # Maps of Content (curricula)
└── _meta/          # templates, attachments
```

## Safety

- A PreToolUse hook (`~/.claude/hooks/protect-mind-palace.sh`) blocks any
  Write/Edit/NotebookEdit/Bash tool call whose target *path* (or write/modify
  Bash command) references the protected vault. Defense-in-depth so the skill
  prompt can never accidentally cross vaults.

## Companion hook: PreCompact dump

`~/.claude/hooks/dump-before-compact.sh` fires before context compaction
(manual `/compact` or auto). It snapshots the full transcript into
`0_Inbox/precompact_<timestamp>.md` and prompts you to run `/save-to-vault`
afterwards. Nothing is lost when compaction shrinks the context window.

## Method

PARAZETTEL hybrid + Maps of Content:

- **PARA** (Tiago Forte) — execution engine: Projects / Areas / Resources / Archive.
- **Zettelkasten** (Luhmann) — insight engine: atomic, densely linked notes.
- **MOCs** (Nick Milo, LYT) — flexible curriculum hubs that replace rigid folders.
- **Karpathy LLM-wiki pattern** — Claude maintains the wiki: writes summaries,
  adds backlinks, categorizes new notes, detects existing notes to update vs create.
