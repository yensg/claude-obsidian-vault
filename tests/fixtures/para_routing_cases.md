# Fixture: PARA Routing — 5 Cases

## Purpose

Verify skill routes note types to correct PARA folders (SKILL.md "Type → folder routing" table).
Run via LLM-judge: present each case to the skill, verify output path matches expected.

## Cases

| # | Finding | Proposed type | Expected path | Common wrong path |
|---|---|---|---|---|
| 1 | "RAG chunking splits docs into 512-token windows" | `concept` | `5_Notes/rag-chunking.md` | `3_Resources/...` |
| 2 | "Singapore HDB loan tenure: max 25yr for HDB flat" | `reference` | `3_Resources/Singapore Property/hdb-loan-tenure.md` | `5_Notes/hdb-loan-tenure.md` |
| 3 | "MyProject: decided to use FastAPI + async SQLAlchemy" | `decision` | `1_Projects/MyProject/notes/fastapi-async-decision.md` | `5_Notes/...` |
| 4 | "Two-pointer pattern for sorted array problems" | `leetcode` | `3_Resources/LeetCode/two-pointers.md` | `5_Notes/...` |
| 5 | "Tool-calling: how LLMs invoke external functions via JSON schema" | `concept` | `5_Notes/tool-calling.md` | `3_Resources/...` |

## Oracle

For each case, skill output must:
1. Propose the exact expected path (or equivalent).
2. NOT propose the "Common wrong path" column.

## LLM-judge rubric (per case)

- [ ] Correct PARA folder selected?
- [ ] Slug is lowercase, hyphen-separated, no dates?
- [ ] Confirmed with user before writing?

Score per case: 3/3 = PASS. 0 on folder = case FAIL (most critical).

## Notes on edge cases

- Case 2: `hdb-loan-tenure` is domain-specific knowledge → `3_Resources`, NOT `5_Notes`. Common failure: treating all factual notes as concepts.
- Case 5: "tool-calling" is cross-domain principle (applies to Claude, OpenAI, Anthropic, all LLMs) → `5_Notes`. Common failure: routing to `3_Resources/AI/` treating it as domain-bound.
- Case 3: has project name "MyProject" → must go into `1_Projects/MyProject/notes/`, not generic `5_Notes/decision.md`.
