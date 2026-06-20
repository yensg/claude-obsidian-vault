# vault — Test Suite

## Coverage (5 failure modes from crossfire CF-1A)

| ID | Failure mode | Test type | Script / Fixture | Priority |
|---|---|---|---|---|
| V-1 | Slug collision → edits wrong note | LLM-judge | `fixtures/slug_collision_scenario.md` | H |
| V-2 | Path escape (`../` or symlink) writes outside vault | bash unit | `test_path_safety.sh` | H |
| V-3 | Note created but MOC not updated | LLM-judge | `fixtures/moc_update_check.md` | H |
| V-4 | Missing required frontmatter fields | static-check | (inline below) | H |
| V-5 | Wrong PARA routing (RESOURCE vs PROJECT vs Notes) | LLM-judge | `fixtures/para_routing_cases.md` | M |

---

## How to run

### V-2 (bash — auto-runnable)
```bash
bash ~/.claude/skills/vault/tests/test_path_safety.sh
```
Expected: all PASS, exit 0.

### V-4 (static-check — auto-runnable)
```bash
bash ~/.claude/skills/vault/tests/test_path_safety.sh   # included below
```
Run the static check inline (macOS: Python used instead of `realpath -m`):
```bash
SKILL=~/.claude/skills/vault/SKILL.md

echo "=== V-4: Required frontmatter fields present in SKILL.md ==="
FIELDS=("title" "type" "tags" "domain" "created" "source" "teacher" "related_projects" "related_notes" "moc")
for f in "${FIELDS[@]}"; do
    grep -q "$f" "$SKILL" && echo "PASS: '$f' documented" || echo "FAIL: '$f' missing from SKILL.md"
done
```
Expected: all 10 fields found.

### V-1, V-3, V-5 (LLM-judge — manual)
Present each fixture to the skill via `/vault` in a real conversation. Evaluate output against the rubric in each fixture file.

Minimum pass threshold: 3/3 on each rubric. Any 0 on the most critical check = FAIL.

---

## V-4: Required frontmatter fields (static oracle)

Every note written by vault MUST include these frontmatter keys:
```
title, type, tags, domain, created, source, teacher, related_projects, related_notes, moc
```

**Automatic check:** grep SKILL.md for each field name → all must appear in the frontmatter section. This ensures no field was removed from the spec.

---

## Bug found by V-2 test (requires SKILL.md fix — user must approve)

**BUG:** SKILL.md Step 4 gate says: "Verify the canonical path starts with the exact `<VAULT>` string"
But bare string prefix `canonical.startswith(VAULT)` incorrectly allows `VAULT-evil/note.md` —
because `VAULT` is a string prefix of `VAULT-evil`.

**Correct check:** `canonical.startswith(VAULT + "/")` (trailing slash enforces directory boundary).

**Impact:** attacker-controlled path `<VAULT>-backdoor/malicious.md` bypasses the gate and writes outside vault.
Not exploitable in practice (skill runs in Claude Code, not untrusted input) but spec is wrong.

**Status:** DOCUMENTED — awaiting user approval before editing SKILL.md.

---

## Baseline (B3 — run before any changes)

```bash
# Verify SKILL.md unchanged from backup
diff ~/.claude/skills/vault/SKILL.md \
     ~/.claude/skills/vault.backup-20260619-180559/SKILL.md \
  && echo "PASS: SKILL.md unchanged" || echo "FAIL: SKILL.md modified"
```

---

## Intent preservation oracle

This skill does: **Save conversation findings into your Obsidian vault. Build a 2nd brain with PARAZETTEL+MOC structure.**

Any test change that causes the skill to:
- Write outside VAULT → FAIL (violates hard safety rule)
- Skip MOC updates → FAIL (defeats connected graph intent)
- Silently overwrite existing notes → FAIL (defeats dedup intent)
- Write notes with missing sections → FAIL (violates Voice & Style enforcement)

...would degrade the skill. Revert via B4 if detected.
