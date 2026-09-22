#!/usr/bin/env bash
# Verify approvals.deny verdicts via `hermes approvals test` (dry-run, no execution).
# Usage: tmux-deny-check.sh <tests-file>
# Lines starting with '#' are section headers; every other non-empty line is a command.
set -u
H="$HOME/.local/bin/hermes"
f="${1:?tests file}"
deny_fail=0
allow_fail=0
section=""
while IFS= read -r line; do
    case "$line" in
        "# MUST DENY"*) section="deny"; echo "=== MUST DENY (expect exit 3) ==="; continue ;;
        "# MUST NOT DENY"*) section="allow"; echo "=== MUST NOT DENY (expect 0 or 2, never 3) ==="; continue ;;
        "#"*|"") continue ;;
    esac
    "$H" approvals test -- "$line" >/dev/null 2>&1
    rc=$?
    printf '  %-46s exit=%s' "$line" "$rc"
    if [ "$section" = deny ]; then
        if [ "$rc" -eq 3 ]; then echo "  ok"; else echo "  FAIL (expected 3)"; deny_fail=$((deny_fail+1)); fi
    else
        if [ "$rc" -eq 3 ]; then echo "  FAIL (denied)"; allow_fail=$((allow_fail+1)); else echo "  ok"; fi
    fi
done < "$f"
echo
echo "deny-section failures:  $deny_fail"
echo "allow-section failures: $allow_fail"
[ "$deny_fail" -eq 0 ] && [ "$allow_fail" -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
