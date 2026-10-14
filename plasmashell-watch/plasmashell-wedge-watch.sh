#!/usr/bin/env bash
# plasmashell-wedge-watch.sh
#
# Capture post-mortem evidence from a WEDGED plasmashell, before systemd destroys it.
#
# Why this exists
# ---------------
# On 2026-10-10 plasmashell wedged in userspace: the panel froze, and because
# plasmashell's SIGTERM handling runs through the Qt event loop (KSignalHandler),
# it never died. systemd waited its full TimeoutSec=40sec and then SIGKILLed it,
# which destroyed every trace (no core, no backtrace, nothing). The trigger was
# therefore unrecoverable, permanently.
#
# This script is the only way to get a backtrace out of that failure mode, because a
# SIGKILLed process has no corpse. See ../plasmashell-wedge.md.
#
# It is PASSIVE. It probes liveness and, after several consecutive failures, writes
# a capture. It does NOT signal plasmashell unless AUTO_KILL below is switched on.
#
# Root is required, and not by preference: /proc/sys/kernel/yama/ptrace_scope is 1 on
# this machine, so a same-user, non-descendant ptrace is refused. Only root can
# attach gdb. (Validated 2026-10-10: root attach to a non-child works.)
#
# Test seams (documented in plasmashell-watch/README.md, used by its test recipe):
#   PWW_PID            pid to watch instead of looking up plasmashell
#   PWW_PROBE          shell command used as the liveness probe (default: D-Bus ping)
#   PWW_STRIKES        consecutive probe failures required before capturing (default 3)
#   PWW_STATE_DIR      capture directory (default /var/log/plasmashell-wedge)
#   PWW_NO_GDB=1       skip the gdb attach (capture /proc data only)
#   PWW_CORE_RETAIN    number of newest cores to keep (default 2)
#   PWW_MIN_UPTIME     skip instances younger than this many seconds (default 90)
#   PWW_SPIN_THRESHOLD core fraction considered a spin (default 0.5)
#   PWW_SPIN_STRIKES   consecutive spin samples required before capturing (default 3)
#   PWW_CLK_TCK        jiffies per second, for tests (default: getconf CLK_TCK)

set -uo pipefail

STATE_DIR="${PWW_STATE_DIR:-/var/log/plasmashell-wedge}"
STRIKES_REQUIRED="${PWW_STRIKES:-3}"
STRIKE_FILE="$STATE_DIR/.strikes"
CORE_RETAIN="${PWW_CORE_RETAIN:-2}"
MIN_UPTIME="${PWW_MIN_UPTIME:-90}"
PROBE_TIMEOUT="${PWW_PROBE_TIMEOUT:-5}"
GDB_TIMEOUT="${PWW_GDB_TIMEOUT:-90}"

# Opt-in only. Touch this file to make the watchdog SIGKILL a wedged plasmashell
# after capturing, so the unit's Restart=on-failure respawns the panel and logout
# stops costing 40 seconds. Left off by default on purpose: a false positive would
# kill a working panel, and that has to be earned by evidence, not assumed.
AUTO_KILL_FLAG="${PWW_AUTO_KILL_FLAG:-/etc/plasmashell-wedge-watch.autokill}"

log() { logger -t plasmashell-wedge-watch -- "$*"; echo "$*"; }

mkdir -p "$STATE_DIR" || exit 0
chmod 0700 "$STATE_DIR" 2>/dev/null

# ---------------------------------------------------------------- find the target
pid="${PWW_PID:-}"
if [[ -z "$pid" ]]; then
    pid="$(pgrep -x plasmashell 2>/dev/null | head -1)"
fi
if [[ -z "$pid" || ! -d "/proc/$pid" ]]; then
    rm -f "$STRIKE_FILE"          # nothing to watch: no session, or a clean exit
    exit 0
fi

etimes="$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')"
if [[ -n "$etimes" && "$etimes" -lt "$MIN_UPTIME" ]]; then
    # A just-started instance is loading QML and may legitimately not answer yet.
    exit 0
fi

# The probe has to run as the session owner, not as root. A user session bus
# rejects a cross-UID connection outright: as root, the same busctl call that
# succeeds as the owner fails with "Failed to connect to system scope bus via
# local transport: Broken pipe", because dbus-daemon's EXTERNAL auth requires the
# peer UID to match the bus owner. Root is only needed for the capture below.
#
# setpriv rather than runuser: runuser opens a PAM session on every run, which logs
# two lines each time -- ~17k journal lines a day at a 10s interval, which is noise in
# exactly the log this watchdog depends on.
owner_uid="$(ps -o uid= -p "$pid" 2>/dev/null | tr -d ' ')"
owner_gid="$(ps -o gid= -p "$pid" 2>/dev/null | tr -d ' ')"

# ---------------------------------------------------------------- liveness probe
# A healthy plasmashell answers Peer.Ping in ~2ms. QtDBus dispatches on the main
# event loop, so a wedged main thread cannot answer at all -- that is what makes
# this a real liveness test and not a CPU-usage guess.
#
# Counterexample, found 2026-10-14: plasmashell's main thread was pinned at ~100% of
# one core inside Qt's EGL fallback-surface path while the event loop kept dispatching,
# so this probe answered in ~2ms and scored zero strikes while the panel was unusable
# (every applet runs in-process, so they all froze together). A responsive bus is
# therefore NOT proof of a healthy panel. The CPU-spin source below is the one that
# would have caught it.
probe() {
    if [[ -n "${PWW_PROBE:-}" ]]; then
        bash -c "$PWW_PROBE" >/dev/null 2>&1
        return $?
    fi
    local bus
    bus="$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null \
            | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p' | head -1)"
    [[ -n "$bus" && -n "$owner_uid" ]] || return 1
    timeout "$PROBE_TIMEOUT" setpriv --reuid="$owner_uid" --regid="$owner_gid" \
        --init-groups -- busctl --address="$bus" call \
        org.kde.plasmashell / org.freedesktop.DBus.Peer Ping >/dev/null 2>&1
}

# ------------------------------------------------------------ CPU-spin source
# Second, independent signal. The probe above only sees a blocked event loop; a panel
# whose event loop is alive but pinned never fails it. Sample utime+stime each tick and
# strike when the process burns more than $SPIN_THRESHOLD of one core for several
# consecutive samples. A healthy panel measures ~0-0.05 of a core, and the consecutive
# sample requirement is what keeps a burst of ordinary animation from tripping it.
SPIN_THRESHOLD="${PWW_SPIN_THRESHOLD:-0.5}"
SPIN_STRIKES="${PWW_SPIN_STRIKES:-3}"
SPIN_FILE="$STATE_DIR/.spin"
SPIN_STRIKE_FILE="$STATE_DIR/.spinstrikes"
CLK_TCK="${PWW_CLK_TCK:-$(getconf CLK_TCK 2>/dev/null || echo 100)}"

# utime+stime in jiffies. Field 2 (comm) can contain spaces and parentheses, so strip
# everything through the LAST ") " before field-splitting; the remainder's fields 12 and
# 13 are then the original fields 14 and 15.
cpu_jiffies() {
    local s
    s="$(cat "/proc/$pid/stat" 2>/dev/null)" || return 1
    awk '{print $12 + $13}' <<< "${s##*\) }"
}

spin_frac=""          # empty means: no usable sample, so no spin judgement this tick
spin_count=0
spin_hot=0
if j="$(cpu_jiffies)" && now="$(cut -d' ' -f1 /proc/uptime)"; then
    prev_pid=""; prev_j=""; prev_now=""
    if [[ -r "$SPIN_FILE" ]]; then
        read -r prev_pid prev_j prev_now < "$SPIN_FILE" 2>/dev/null || true
    fi
    printf '%s %s %s\n' "$pid" "$j" "$now" > "$SPIN_FILE"
    if [[ "$prev_pid" == "$pid" && -n "$prev_j" && -n "$prev_now" ]]; then
        spin_frac="$(awk -v dj="$(( j - prev_j ))" \
                         -v a="$now" -v b="$prev_now" -v hz="$CLK_TCK" \
                         'BEGIN{ dt = a - b; if (dt <= 0) exit 1; printf "%.2f", (dj/hz)/dt }')" || spin_frac=""
    fi
fi
if [[ -n "$spin_frac" ]] && awk -v f="$spin_frac" -v t="$SPIN_THRESHOLD" 'BEGIN{exit !(f>=t)}'; then
    spin_hot=1
    prev_pid=""; prev_spin=0
    if [[ -r "$SPIN_STRIKE_FILE" ]]; then
        read -r prev_pid prev_spin < "$SPIN_STRIKE_FILE" 2>/dev/null || true
    fi
    [[ "$prev_pid" == "$pid" && "$prev_spin" =~ ^[0-9]+$ ]] || prev_spin=0
    spin_count=$(( prev_spin + 1 ))
    printf '%s %s\n' "$pid" "$spin_count" > "$SPIN_STRIKE_FILE"
    log "plasmashell pid $pid burning ${spin_frac} of one core (spin strike $spin_count/$SPIN_STRIKES)"
else
    rm -f "$SPIN_STRIKE_FILE"
fi

# ---------------------------------------------------------------- decide
probe_ok=0
probe && probe_ok=1
if (( probe_ok )); then
    rm -f "$STRIKE_FILE"
else
    # --------------------------------------------- count consecutive failures
    prev_pid=""; count=0
    if [[ -r "$STRIKE_FILE" ]]; then
        read -r prev_pid count < "$STRIKE_FILE" 2>/dev/null || true
    fi
    [[ "$prev_pid" == "$pid" && "$count" =~ ^[0-9]+$ ]] || count=0
    count=$(( count + 1 ))
    printf '%s %s\n' "$pid" "$count" > "$STRIKE_FILE"
    log "plasmashell pid $pid failed liveness probe (strike $count/$STRIKES_REQUIRED)"
fi

capture=0; reason=""
if (( ! probe_ok )) && (( count >= STRIKES_REQUIRED )); then
    capture=1; reason="liveness probe failed $count consecutive times"
fi
if (( spin_hot )) && (( spin_count >= SPIN_STRIKES )); then
    capture=1
    reason="${reason:+$reason; }CPU burn ${spin_frac} of one core for $spin_count consecutive samples"
fi
(( capture )) || exit 0

# ---------------------------------------------------------------- capture
stamp="$(date +%Y%m%d-%H%M%S)"
base="$STATE_DIR/wedge-$stamp"

{
    echo "plasmashell wedge capture"
    echo "when:            $(date -Is)"
    echo "pid:             $pid"
    echo "uptime_seconds:  ${etimes:-unknown}"
    echo "comm:            $(cat /proc/"$pid"/comm 2>/dev/null)"
    echo "cmdline:         $(tr '\0' ' ' < /proc/"$pid"/cmdline 2>/dev/null)"
    echo "reason:          $reason"
    echo "probe_strikes:   ${count:-0} of $STRIKES_REQUIRED"
    echo "spin_strikes:    ${spin_count:-0} of $SPIN_STRIKES (last sample ${spin_frac:-n/a} of one core)"
    echo
    echo "=== /proc/$pid/status ==="
    cat "/proc/$pid/status" 2>/dev/null
    echo
    echo "=== per-thread state (state/wchan/syscall) ==="
    for t in /proc/"$pid"/task/*; do
        [[ -d "$t" ]] || continue
        tid="${t##*/}"
        printf '\n-- thread %s "%s" state=%s\n' \
            "$tid" "$(cat "$t/comm" 2>/dev/null)" \
            "$(awk '{print $3}' "$t/stat" 2>/dev/null)"
        printf '   wchan:   %s\n' "$(cat "$t/wchan" 2>/dev/null)"
        printf '   syscall: %s\n' "$(cat "$t/syscall" 2>/dev/null)"
    done
    echo
    echo "=== kernel stacks (root; needs CONFIG_STACKTRACE) ==="
    for t in /proc/"$pid"/task/*; do
        [[ -d "$t" ]] || continue
        printf '\n-- %s\n' "${t##*/}"
        cat "$t/stack" 2>/dev/null
    done
} > "$base.txt" 2>&1

# ------------------------------------------------- gdb: backtrace + core
if [[ "${PWW_NO_GDB:-0}" != "1" ]] && command -v gdb >/dev/null 2>&1; then
    timeout "$GDB_TIMEOUT" gdb -p "$pid" -batch \
        -ex 'set pagination off' \
        -ex 'set print thread-events off' \
        -ex 'info threads' \
        -ex 'thread apply all bt' \
        -ex "generate-core-file $base.core" \
        -ex 'detach' > "$base.gdb.txt" 2>&1
    echo "gdb_rc: $?" >> "$base.txt"
    # If gdb is killed mid-attach the target is left SIGSTOPped, which would freeze
    # the panel permanently. Always resume it.
    kill -CONT "$pid" 2>/dev/null
fi

# ------------------------------------------------- compress the core
if [[ -s "$base.core" ]]; then
    if command -v zstd >/dev/null 2>&1; then
        zstd -q -T0 --rm -o "$base.core.zst" "$base.core" 2>/dev/null \
            || rm -f "$base.core"
    else
        gzip -f "$base.core" 2>/dev/null || rm -f "$base.core"
    fi
fi

# ------------------------------------------------- core retention
mapfile -t cores < <(ls -1t "$STATE_DIR"/wedge-*.core.zst "$STATE_DIR"/wedge-*.core.gz \
                     "$STATE_DIR"/wedge-*.core 2>/dev/null)
if (( ${#cores[@]} > CORE_RETAIN )); then
    for f in "${cores[@]:CORE_RETAIN}"; do rm -f "$f"; done
fi

log "CAPTURED plasmashell wedge ($reason) -> $base.txt (+ $base.gdb.txt, core if gdb succeeded)"

# ------------------------------------------------- optional auto-kill (opt-in)
if [[ -f "$AUTO_KILL_FLAG" ]]; then
    log "auto-kill flag present: SIGKILL $pid so Restart=on-failure can respawn the panel"
    kill -KILL "$pid" 2>/dev/null
fi

exit 0
