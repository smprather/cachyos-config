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
# History: Hermes was the fourth CLI covered here. It was removed from this machine
# on 2026-10-14 — its agent code and venv were already gone, so the
# `~/.hermes/SOUL.md` instruction file, `hermes approvals.deny`, and the two runtime
# batteries that shelled out to the Hermes binary all retired with it. See
# `customizations.md`. Claude Code, Codex CLI and OpenCode are checked below.
#
# Usage: tests/check-tmux-guard.sh [--quiet] [--static]
#   --quiet   print only failures and the summary line
#   --static  accepted and ignored: there are no runtime probes left to skip, but
#             pre-2026-10-14 invocations pass it and must not start failing

set -u

QUIET=0
for arg in "$@"; do
    case "$arg" in
        --static) : ;;
        --quiet) QUIET=1 ;;
        *) echo "unknown argument: $arg" >&2; exit 2 ;;
    esac
done

pass=0
fail=0
say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
ok()  { pass=$((pass+1)); say "  ok    $1"; }
bad() { fail=$((fail+1)); printf '  FAIL  %s\n' "$1"; }

PHRASE="never kill the shared server"

say "=== 1. instruction rule in every global instruction file ==="
for f in "$HOME/.claude/CLAUDE.md" \
         "$HOME/.codex/AGENTS.md" "$HOME/.config/opencode/AGENTS.md"; do
    if [ -f "$f" ] && grep -aq "$PHRASE" "$f"; then
        ok "$f"
    else
        bad "$f (missing: $PHRASE)"
    fi
done

say ""
say "=== 2. mechanical deny rules ==="

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
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
if [ "$fail" -eq 0 ]; then exit 0; else exit 1; fi
