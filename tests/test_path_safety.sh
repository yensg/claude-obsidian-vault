#!/bin/bash
# Tests vault path safety gate logic (SKILL.md Step 4)
# Oracle: any path with .. OR resolved canonical outside VAULT must be rejected
# Run: bash test_path_safety.sh
set -euo pipefail

VAULT="/path/to/your/obsidian/vault"

PASS=0
FAIL=0

check() {
    local label="$1"
    local target="$2"
    local expect="$3"  # "safe" or "unsafe"

    # Gate 1: reject any path containing ..
    if echo "$target" | grep -qF '..'; then
        result="unsafe"
    else
        # Gate 2: resolve canonical path (use Python — macOS realpath lacks -m)
        canonical=$(python3 -c "import os.path, sys; print(os.path.realpath(sys.argv[1]))" "$target" 2>/dev/null || echo "UNRESOLVABLE")
        # Gate 3: must start with exact VAULT string + trailing slash
        # (bare VAULT prefix check passes VAULT-evil paths — see bug note in TESTS.md)
        if [[ "$canonical" == "${VAULT}/"* ]]; then
            result="safe"
        else
            result="unsafe"
        fi
    fi

    if [[ "$result" == "$expect" ]]; then
        echo "PASS [$label]: $target → $result"
        ((PASS++)) || true
    else
        echo "FAIL [$label]: $target → expected=$expect got=$result"
        ((FAIL++)) || true
    fi
}

# --- Safe paths (must pass gate) ---
check "note in 5_Notes"       "$VAULT/5_Notes/test-note.md"                           "safe"
check "note in 3_Resources"   "$VAULT/3_Resources/LeetCode/two-pointers.md"           "safe"
check "note in 1_Projects"    "$VAULT/1_Projects/MyProject/notes/arch.md"             "safe"
check "note in 6_MOCs"        "$VAULT/6_MOCs/Claude_Code_MOC.md"                      "safe"
check "deep resource subfolder" "$VAULT/3_Resources/Singapore Property/hdb-rules.md"  "safe"

# --- Unsafe paths (must be rejected) ---
check "dotdot traversal"      "$VAULT/../evil.md"                                      "unsafe"
check "deep dotdot"           "$VAULT/5_Notes/../../etc/passwd"                        "unsafe"
check "absolute outside vault" "/tmp/evil.md"                                          "unsafe"
check "home dir escape"       "/Users/otheruser/.claude/skills/vault/evil.md"         "unsafe"
check "dotdot in subfolder"   "$VAULT/5_Notes/../../../.ssh/authorized_keys"           "unsafe"
check "dotdot percent encoded" "$VAULT/5_Notes/..%2F..%2Fevil.md"                     "unsafe"
check "vault-evil suffix"     "${VAULT}-evil/note.md"                                  "unsafe"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
