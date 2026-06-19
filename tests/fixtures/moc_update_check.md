# Fixture: MOC Update — Atomicity Check

## Scenario

User runs `/vault` and skill creates a new `concept` note: `5_Notes/rag-chunking.md`.

## Expected behavior

After writing the note, skill must:
1. Find or create `6_MOCs/<Topic>_MOC.md` (e.g., `AI_MOC.md` or `Claude_Code_MOC.md`)
2. Add `[[rag-chunking]]` to the correct MOC section with 1-line annotation
3. Re-sequence the MOC (not just append)
4. If a new MOC is created, update `6_MOCs/Home.md`

## Oracle

Step 7 summary table must include:
- A row with `Action: Created` or `Updated` pointing to an MOC file
- The note `rag-chunking` must appear in at least one MOC's link list after the run

**FAIL condition:** Summary table shows note created but NO MOC row → MOC update silently skipped.

## LLM-judge rubric

After running `/vault`, check output:

- [ ] Summary table has at least one `Updated` or `Created` row for an MOC file?
- [ ] The MOC entry for the new note has a 1-line annotation (not just `[[note]]`)?
- [ ] If MOC was newly created, Home.md also updated?

Score: 3/3 = PASS. Missing MOC row = FAIL (most critical).

## Why this matters

A note with no MOC entry is harder to discover. Over time, unlinked notes become orphans that `--lint` flags. The skill's purpose is building a *connected* knowledge graph — silently skipping MOC updates defeats the 2nd brain goal.
