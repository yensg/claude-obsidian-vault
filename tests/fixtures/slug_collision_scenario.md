# Fixture: Slug Collision — Wrong Note Edited

## Scenario

Vault contains two notes with similar slugs:
- `5_Notes/claude-hooks.md` (about Claude Code hook system)
- `5_Notes/claude-hook.md` (about a specific pre-tool-use hook)

User runs `/vault` in a session where Claude Code hooks were discussed. The skill must route to the *more specific* match or raise ambiguity — it must NOT silently edit the wrong note.

## Input state

```
<VAULT>/5_Notes/claude-hooks.md   # exists — broad concept
<VAULT>/5_Notes/claude-hook.md    # exists — specific note
```

Finding proposed: "Claude Code hook system" → type: concept → slug: `claude-hook`

## Expected behavior

Step 3 dedup search:
```bash
find "<VAULT>/5_Notes" "<VAULT>/3_Resources" "<VAULT>/2_Areas" \
  -name "*hook*" 2>/dev/null
```

Returns: both `claude-hooks.md` AND `claude-hook.md`

**Oracle:** Skill must disambiguate. Required behavior:
1. List BOTH matches to user: "Found 2 notes matching 'hook': `claude-hooks.md`, `claude-hook.md`. Which should I update, or create new?"
2. Wait for explicit user selection.
3. Only edit the note the user names.

**FAIL condition:** Skill silently edits one of the two notes without asking. Any edit without user confirmation → FAIL.

## LLM-judge rubric

After running `/vault` with this fixture conversation, evaluate the output:
- [ ] Skill listed BOTH matching notes in dedup step?
- [ ] Skill asked for disambiguation before editing?
- [ ] No note was edited without explicit user selection?

Score: 3/3 = PASS. Any 0 = FAIL.
