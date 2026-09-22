#!/usr/bin/env bash
# Verify the tmux shared-server guard is in place everywhere.
#
# The guard has two halves:
#   1. Instruction rule ("never kill the shared server") in every agent CLI's
#      global instruction file.
#   2. Mechanical deny rules that block `tmux kill-server` / `pkill tmux` /
#      `killall tmux` before the yolo bypass, in each CLI's own permission
#      config.
#
# Read-only; safe to run any time. Exit 0 = all present, 1 = something missing.
#
# Usage: tests/check-tmux-guard.sh [--static] [--quiet]
#   --static  skip `hermes approvals test` (no runtime probes)
#   --quiet   print only failures and the summary line

set -u

STATIC=0
QUIET=0
for arg in "$@"; do
    case "$arg" in
        --static) STATIC=1 ;;
        --quiet) QUIET=1 ;;
        *) echo "unknown argument: $arg" >&2; exit 2 ;;
    esac
done

pass=0
fail=0
say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
ok()  { pass=$((pass+1)); say "  ok    $1"; }
bad() { fail=$((fail+1)); printf '  FAIL  %s\n' "$1"; }

HERMES_BIN="${HERMES_BIN:-$HOME/.local/bin/hermes}"
PHRASE="never kill the shared server"

say "=== 1. instruction rule in every global instruction file ==="
for f in "$HOME/.hermes/SOUL.md" "$HOME/.claude/CLAUDE.md" \
         "$HOME/.codex/AGENTS.md" "$HOME/.config/opencode/AGENTS.md"; do
    if [ -f "$f" ] && grep -aq "$PHRASE" "$f"; then
        ok "$f"
    else
        bad "$f (missing: $PHRASE)"
    fi
done

say ""
say "=== 2. mechanical deny rules ==="

# Hermes: approvals.deny must carry the four globs.
deny_out="$("$HERMES_BIN" config get approvals.deny 2>/dev/null || true)"
for pat in "tmux kill-server*" "tmux *kill-server*" "pkill *tmux*" "killall *tmux*"; do
    if printf '%s' "$deny_out" | grep -qF -- "$pat"; then
        ok "hermes approvals.deny has '$pat'"
    else
        bad "hermes approvals.deny missing '$pat'"
    fi
done

# Claude Code: permissions.deny with Bash(...) rules.
if python3 - "$HOME/.claude/settings.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
rules = (d.get("permissions") or {}).get("deny") or []
need = ["Bash(tmux kill-server*)", "Bash(tmux *kill-server*)",
        "Bash(pkill *tmux*)", "Bash(killall *tmux*)"]
missing = [r for r in need if r not in rules]
sys.exit(1 if missing else 0)
PY
then ok "claude permissions.deny (4 Bash rules)"; else bad "claude permissions.deny incomplete"; fi

# OpenCode: permission.bash deny entries.
if python3 - "$HOME/.config/opencode/opencode.jsonc" <<'PY'
import json, re, sys
raw = open(sys.argv[1]).read()
raw = re.sub(r'^\s*//.*$', '', raw, flags=re.M)
d = json.loads(raw)
bash = ((d.get("permission") or {}).get("bash") or {})
need = ["tmux kill-server*", "tmux *kill-server*", "pkill *tmux*", "killall *tmux*"]
missing = [p for p in need if bash.get(p) != "deny"]
sys.exit(1 if missing else 0)
PY
then ok "opencode permission.bash (4 deny rules)"; else bad "opencode permission.bash incomplete"; fi

say ""
say "=== 3. runtime verdicts (hermes approvals test) ==="
if [ "$STATIC" -eq 1 ]; then
    say "  skipped (--static)"
elif [ -x "$HERMES_BIN" ]; then
    must_deny="tmux kill-server
tmux -L default kill-server
tmux -f /dev/null kill-server
sudo tmux kill-server
pkill -f tmux
killall -9 tmux"
    while IFS= read -r c; do
        "$HERMES_BIN" approvals test -- "$c" >/dev/null 2>&1
        if [ "$?" -eq 3 ]; then ok "denied: $c"; else bad "NOT denied: $c"; fi
    done <<< "$must_deny"
    must_allow="tmux ls
tmux kill-session -t scratch
tmux new-session -d -s scratch
pgrep -a tmux"
    while IFS= read -r c; do
        "$HERMES_BIN" approvals test -- "$c" >/dev/null 2>&1
        if [ "$?" -eq 3 ]; then bad "wrongly denied: $c"; else ok "allowed: $c"; fi
    done <<< "$must_allow"
else
    say "  skipped (hermes binary not executable at $HERMES_BIN)"
fi

say ""
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $([ "$fail" -eq 0 ] && echo 0 || echo 1)
