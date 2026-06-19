#!/bin/bash
# Tests slug sanitization for --ingest mode (SKILL.md ingest step)
# Oracle: slug must match [a-z0-9-]+ only, ≤60 chars, no leading dot, no / or .. or %
# Run: bash test_slug_sanitize.sh

PASS=0
FAIL=0

sanitize() {
    local raw="$1"
    # Lowercase → replace non-[a-z0-9-] with - → collapse repeats → strip leading - → cap 60
    echo "$raw" \
        | tr '[:upper:]' '[:lower:]' \
        | sed 's/[^a-z0-9-]/-/g' \
        | sed 's/-\{2,\}/-/g' \
        | sed 's/^-//' \
        | cut -c1-60
}

check() {
    local label="$1"
    local input="$2"
    local expected="$3"
    local result
    result=$(sanitize "$input")
    if [[ "$result" == "$expected" ]]; then
        echo "PASS [$label]: '$input' → '$result'"
        ((PASS++)) || true
    else
        echo "FAIL [$label]: '$input' → expected='$expected' got='$result'"
        ((FAIL++)) || true
    fi
}

# Verify no disallowed chars remain
check_safe() {
    local label="$1"
    local input="$2"
    local result
    result=$(sanitize "$input")
    if echo "$result" | grep -qE '[^a-z0-9-]|^\-|\.\.|\%|/'; then
        echo "FAIL [$label]: slug contains disallowed chars: '$result'"
        ((FAIL++)) || true
    else
        echo "PASS [$label]: '$input' → '$result' (no disallowed chars)"
        ((PASS++)) || true
    fi
}

# Normal cases
check "simple article title"   "My Amazing Article"                    "my-amazing-article"
check "already lowercase"      "rag-chunking"                          "rag-chunking"
check "uppercase acronym"      "HDB Loan Rules SG"                     "hdb-loan-rules-sg"
check "numbers preserved"      "gpt-4o benchmarks 2024"               "gpt-4o-benchmarks-2024"

# Sanitization of dangerous inputs
check_safe "dotdot in slug"       "../evil"
check_safe "absolute path slug"   "/etc/passwd"
check_safe "url with scheme"      "https://example.com/path?q=1&r=2"
check_safe "percent encoded"      "%2e%2e%2fpasswd"
check_safe "backslash"            "..\\evil\\path"
check_safe "null byte"            "$(printf 'evil\x00safe')"
check_safe "spaces around dash"   "  leading and trailing  "

# Length cap
long_input=$(python3 -c "print('a' * 80)")
result=$(sanitize "$long_input")
if [[ ${#result} -le 60 ]]; then
    echo "PASS [length cap]: ${#result} chars ≤ 60"
    ((PASS++)) || true
else
    echo "FAIL [length cap]: ${#result} chars > 60"
    ((FAIL++)) || true
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
