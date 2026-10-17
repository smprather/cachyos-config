#!/usr/bin/env bash
# Per-boot capture for the reboot-loop benchmark.
#
#   boot-capture.sh                 # capture this boot (this is what the timer runs)
#   boot-capture.sh --report        # summarise every captured boot and flag anomalies
#   boot-capture.sh --dir DIR ...   # use another data directory (default /var/lib/boot-loop)
#
# Driven by /etc/systemd/system/boot-capture.{service,timer}, which fires 90 s after each boot, so
# a capture lands whether or not the desktop came up — a boot that dies earlier shows up in the
# report as a journal boot with no capture. One detail file per boot, plus one deduplicated TSV row.
#
# Why a loop: boot time is the one number a fresh install can plausibly move, and a single boot
# says nothing (this machine's disk metrics already swing 250 % between identical runs). The loop
# is also uniquely good at exposing the failures this machine has a history with:
#
#   * units that failed, and a system state other than `running`
#   * a previous boot whose journal has no clean-shutdown marker — the freeze/panic class of
#     `frozen-system-recovery.md` (which is why `nmi_watchdog=1`, `hardlockup_panic=1`, `panic=15`
#     are captured here too: they are the policy that is supposed to survive a reboot)
#   * pstore records, i.e. a panic the kernel managed to persist
#   * NVMe enumeration flips between boots — the trap `storage-migration.md` is built around
#   * PCIe link renegotiation (a drive that comes up at a lower speed than it trained at)
#   * whether the plasmashell EGL containment of `plasmashell-wedge.md` still holds
#     (`grep -c libnvidia-eglcore /proc/<plasmashell>/maps` must be 0), and whether the panel
#     watchdog is loaded
#
# Nothing identifying is written: no MACs, IPs, SSIDs or machine-id; UUID values are masked. The
# files are safe to commit to this published repo.
#
# Installed by copy to /usr/local/bin (the `plasmashell-watch/` precedent) so root never executes a
# file out of a git working tree; install and undo commands are in the 2026-10-17 boot-loop entry
# of customizations.md, and the copy must be repeated whenever this file changes.

# shellcheck disable=SC2016  # Every single-quoted string below is a shell script handed to
#   `bash -c` on purpose, so its $vars expand *inside* -- same as scripts/hardware-check.sh and
#   scripts/system-benchmark.sh. File-wide, so it must precede all code.
set -u

DIR=/var/lib/boot-loop
while :; do
    case "${1:-}" in
        --dir) DIR="$2"; shift 2 ;;
        *) break ;;
    esac
done
MODE="${1:-capture}"
TSV="$DIR/boots.tsv"
SESSION_USER=mylesp                       # whose user manager supplies the session facts
RUNTIME_DIR="/run/user/$(id -u "$SESSION_USER" 2>/dev/null || echo 1000)"

hdr()  { printf '```text\n$ %s\n' "$*"; "$@" 2>&1; printf '```\n'; }
hdrs() { printf '```text\n$ %s\n' "$1"; bash -c "$1" 2>&1; printf '```\n'; }
# Session-layer reads go through the user bus, as root can (verified 2026-10-17):
userctl() { sudo -u "$SESSION_USER" XDG_RUNTIME_DIR="$RUNTIME_DIR" systemctl --user "$@"; }
mask()    { sed -E 's/([Aa]UID=|[Uu]uid=)[0-9a-fA-F-]+/\1[masked]/g;
                     s/([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}/[redacted]/g;
                     s/\b[0-9]{1,3}(\.[0-9]{1,3}){3}(\/[0-9]{1,2})?\b/[redacted]/g'; }

# ------------------------------------------------------------------ capture
capture() {
    mkdir -p "$DIR" && chmod 0755 "$DIR"
    local boot_id ts uptime_s detail
    boot_id=$(cat /proc/sys/kernel/random/boot_id)
    ts=$(date -Iseconds)
    uptime_s=$(cut -d. -f1 /proc/uptime)
    detail="$DIR/boot-${boot_id:0:8}.txt"

    # -- boot timing ------------------------------------------------------
    local analyze total firmware loader kernel_ph initrd userspace
    analyze=$(systemd-analyze 2>&1)
    phase() { printf '%s' "$analyze" | grep -o -E "[0-9.]+s \($1\)" | grep -o -E '^[0-9.]+' | head -1; }
    # systemd-analyze ends this line with a trailing space ("... = 30.053s "), so an `s$` anchor
    # matches nothing at all. That is the same trailing-space mistake this repo already has form
    # for in the hardware-check redaction sed, hence [[:space:]]*$ and not $.
    total=$(printf '%s' "$analyze" | sed -n 's/.*= \([0-9.]*\)s[[:space:]]*$/\1/p' | head -1)
    firmware=$(phase firmware); loader=$(phase loader); kernel_ph=$(phase kernel)
    initrd=$(phase initrd); userspace=$(phase userspace)

    # -- system health ----------------------------------------------------
    local sys_state failed_s
    sys_state=$(systemctl is-system-running 2>&1)
    failed_s=$(systemctl --failed --no-legend 2>/dev/null | wc -l)

    # -- session health ---------------------------------------------------
    local plasma_state failed_u watchdog desktop_s pid egl
    plasma_state=$(userctl is-active plasma-plasmashell.service 2>/dev/null || echo unknown)
    failed_u=$(userctl --failed --no-legend 2>/dev/null | wc -l)
    watchdog=$(systemctl is-active plasmashell-wedge-watch.timer 2>/dev/null || echo unknown)
    desktop_s=$(userctl show plasma-plasmashell.service -p ActiveEnterTimestampMonotonic 2>/dev/null \
                | sed -n 's/.*=\([0-9]*\)$/\1/p' | awk '{printf "%.2f", $1/1000000}')
    pid=$(pgrep -x plasmashell 2>/dev/null | head -1)
    if [ -n "${pid:-}" ] && [ -r "/proc/$pid/maps" ]; then
        egl=$(grep -c libnvidia-eglcore "/proc/$pid/maps" 2>/dev/null || true)
    else
        egl=n/a
    fi

    # -- storage ----------------------------------------------------------
    local md127 nvme_map=""
    md127=$(grep -m1 '^md127' /proc/mdstat 2>/dev/null | tr -s ' ' '_')
    local c node model pci lnk
    for c in /sys/class/nvme/nvme*; do
        [ -e "$c" ] || continue
        node=$(basename "$c")
        model=$(tr ' ' '_' < "$c/model" 2>/dev/null)
        pci=$(basename "$(readlink -f "$c/device")")
        lnk=$(lspci -vv -s "$pci" 2>/dev/null | grep -m1 -o 'LnkSta:.*' \
              | grep -o -E 'Speed [0-9.]+GT/s[^,)]*' | tr ' ' '_')
        nvme_map+="${node}=${model}@${pci}:${lnk};"
    done

    # -- fault signals ----------------------------------------------------
    local errs hard pstore prev_window prev_last prev_shutdown prev_failed_unmounts
    errs=$(journalctl -b -p err --no-pager 2>/dev/null | wc -l)
    # 'thermal' is deliberately not matched: it fired on benign boot-time registration lines
    # ("thermal_sys: Registered thermal governor", "ACPI: thermal: Thermal Zone ...") and turned
    # zero real signals into nine.
    hard=$(journalctl -b -k --no-pager 2>/dev/null \
           | grep -c -i -E 'call trace|hung task|soft lockup|hard lockup|kernel panic|hardware error|machine check|Oops|BUG:' || true)
    pstore=$(find /sys/fs/pstore -maxdepth 1 -type f 2>/dev/null | wc -l)   # find, not ls (SC2012)

    # How the previous boot ended. Completion markers ("systemd-shutdown", "Reached target
    # Power-Off") never appear in this machine's journal: calibrated 2026-10-17 against boots -1,
    # -2 and -3, all of which ended in ordinary reboots and all of which contain zero of them,
    # because journald stops before they are written. So the discriminator is whether a shutdown
    # phase appears at all -- `orderly` = stopping/unmounting lines present, `abrupt` = the journal
    # simply stops mid-activity, which is what a hang or a power cut looks like.
    prev_window=$(journalctl -b -1 -n 100 --no-pager 2>/dev/null)
    prev_last=$(printf '%s' "$prev_window" | tail -12)
    prev_failed_unmounts=$(printf '%s' "$prev_window" | grep -c -i 'Failed unmounting' || true)
    if [ -z "$prev_last" ]; then
        prev_shutdown=n/a
    elif printf '%s' "$prev_window" | grep -q -i -E 'Stopping |Stopped |Unmounted |Deactivated |Failed unmounting'; then
        prev_shutdown=orderly
    else
        prev_shutdown=abrupt
    fi

    # -- detail file: every line traceable to its command -----------------
    {
        printf '# boot capture — %s\n\n' "$ts"
        printf 'boot_id %s · uptime at capture %ss · kernel %s\n' "$boot_id" "$uptime_s" "$(uname -r)"
        printf 'cmdline %s\n\n' "$(mask < /proc/cmdline)"

        printf '## Boot timing\n\n'; hdrs 'systemd-analyze'
        hdrs 'systemd-analyze blame | head -8'

        printf '\n## System health\n\n'; hdrs 'systemctl is-system-running'
        hdrs 'systemctl --failed --no-legend; systemctl is-active graphical.target'

        printf '\n## Session health\n\n'
        hdrs "sudo -u $SESSION_USER XDG_RUNTIME_DIR=$RUNTIME_DIR systemctl --user is-active plasma-plasmashell.service"
        hdrs "sudo -u $SESSION_USER XDG_RUNTIME_DIR=$RUNTIME_DIR systemctl --user show plasma-plasmashell.service -p ActiveState,ActiveEnterTimestampMonotonic"
        hdrs "sudo -u $SESSION_USER XDG_RUNTIME_DIR=$RUNTIME_DIR systemctl --user --failed --no-legend"
        hdrs "grep -c libnvidia-eglcore /proc/\$(pgrep -x plasmashell | head -1)/maps   # must be 0"
        hdrs 'systemctl is-active plasmashell-wedge-watch.timer; journalctl -b --no-pager -u plasmashell-wedge-watch | tail -3'

        printf '\n## Storage and boot path\n\n'
        hdrs 'head -4 /proc/mdstat'
        hdrs 'findmnt -no SOURCE,TARGET,FSTYPE,OPTIONS / /boot; df -h --output=avail / | tail -1'
        hdrs 'for c in /sys/class/nvme/nvme*; do p=$(basename $(readlink -f $c/device)); printf "%s %s link=%s\n" "$(basename $c)" "$(cat $c/model)" "$(lspci -vv -s $p | grep -m1 -o "LnkSta:.*")"; done'
        hdrs 'limine-list | head -6'

        printf '\n## Fault signals\n\n'
        hdrs 'journalctl -b -k --no-pager | grep -i -E "call trace|hung task|soft lockup|hard lockup|kernel panic|hardware error|machine check" | tail -10'
        hdrs 'journalctl -b -p err --no-pager | tail -15'
        hdrs 'ls -l /sys/fs/pstore | tail -5'
        printf '```text\n$ previous boot: last 12 lines (classification: %s, failed unmounts: %s)\n%s\n```\n' \
            "$prev_shutdown" "$prev_failed_unmounts" "$(printf '%s' "$prev_last" | mask)"

        printf '\n## Recovery policy (must survive a reboot)\n\n'
        hdrs 'sysctl kernel.nmi_watchdog kernel.hardlockup_panic kernel.panic'
        printf '\n## Boot list (cross-check: a journal boot with no capture never booted far enough)\n\n'
        hdrs 'journalctl --list-boots --no-pager | tail -6'
    } > "$detail" 2>&1
    chmod 0644 "$detail"

    # -- TSV row, deduplicated by boot id ---------------------------------
    # No field may ever be empty: a tab is IFS *whitespace*, so bash's `read -a` collapses runs of
    # them and silently drops empty fields, shifting every later column (found 2026-10-17: an empty
    # total_s cost the row its last field, and the anomaly loop then read F[21] out of 21).
    #
    # Schema v2 (2026-10-17): prev_clean split into prev_shutdown + prev_failed_unmounts. If the file
    # on disk carries a different header, archive it instead of appending rows that would not mean
    # the same thing.
    local want_header='boot_id\tts\tkernel\ttotal_s\tfirmware_s\tloader_s\tkernel_s\tinitrd_s\tuserspace_s\tdesktop_s\tsys_state\tfailed_system\tfailed_user\tplasma_state\tegl_maps\twatchdog\tmd127\tnvme_map\terrors\thard_signals\tpstore\tprev_shutdown\tprev_failed_unmounts'
    if [ -f "$TSV" ] && [ "$(head -1 "$TSV")" != "$(printf '%b' "$want_header")" ]; then
        local archived
        archived="$TSV.schema-$(date +%Y%m%d%H%M%S)"   # declared, then assigned: SC2155 would
        mv "$TSV" "$archived"                          # otherwise mask the command's exit status
        printf 'note: capture schema changed; previous file archived as %s\n' "$archived" >&2
    fi
    [ -f "$TSV" ] || printf '%b\n' "$want_header" > "$TSV"
    greppat="^$(printf '%s' "$boot_id" | sed 's/[.[\*^$]/\\&/g')	"
    grep -v "$greppat" "$TSV" > "$TSV.tmp" 2>/dev/null; mv "$TSV.tmp" "$TSV"
    local row=( "${boot_id:-n/a}" "${ts:-n/a}" "$(uname -r)" "${total:-n/a}" "${firmware:-n/a}"
                "${loader:-n/a}" "${kernel_ph:-n/a}" "${initrd:-n/a}" "${userspace:-n/a}"
                "${desktop_s:-n/a}" "${sys_state:-n/a}" "${failed_s:-n/a}" "${failed_u:-n/a}"
                "${plasma_state:-n/a}" "${egl:-n/a}" "${watchdog:-n/a}" "${md127:-none}"
                "${nvme_map:-none}" "${errs:-n/a}" "${hard:-n/a}" "${pstore:-n/a}"
                "${prev_shutdown:-n/a}" "${prev_failed_unmounts:-0}" )
    # Joined with printf rather than by setting IFS. This script runs as root, where an IFS
    # assignment is both a semgrep ifs-tampering smell and a foot-gun -- and the earlier bug in this
    # very file was IFS-whitespace field collapsing, so it is the last mechanism to reach for.
    { printf '%s' "${row[0]}"; printf '\t%s' "${row[@]:1}"; printf '\n'; } >> "$TSV"
    chmod 0644 "$TSV"

    printf 'captured %s (%s) -> %s\n' "$boot_id" "$ts" "$detail"
}

# ------------------------------------------------------------------ report
report() {
    [ -f "$TSV" ] || { printf 'no captures in %s — is the timer enabled?\n' "$TSV" >&2; exit 1; }
    local n
    n=$(($(wc -l < "$TSV") - 1))
    printf '# Reboot-loop report — %s\n\n' "$(date -Iseconds)"
    printf '%s captures in %s\n\n' "$n" "$TSV"

    printf '## Per boot\n\n'
    printf '%-9s %-25s %7s %6s %6s %6s %6s %7s %7s %-9s %5s %5s %5s %-7s\n' \
        boot ts total fw load kern initr usr desk state failS errs hard prev
    tail -n +2 "$TSV" | awk -F'\t' '{ printf "%-9s %-25s %7s %6s %6s %6s %6s %7s %7s %-9s %5s %5s %5s %-7s\n", substr($1,1,8), $2, $4, $5, $6, $7, $8, $9, $10, $11, $12, $19, $20, $22 }'

    printf '\n## Statistics (median is the one to quote; this loop exists because single runs lie)\n\n'
    tail -n +2 "$TSV" | awk -F'\t' '
        # Sorts in place, so the caller can read min/max straight off the array. The first version
        # sorted a copy and then printed a[1]/a[n] from the *unsorted* array, which reported the
        # insertion order as min and max (and a negative spread).
        function sortmed(a, n,    i, j, t, med) { for (i=1;i<=n;i++) for (j=i+1;j<=n;j++) if (a[i]>a[j]) { t=a[i]; a[i]=a[j]; a[j]=t }
            med = (n%2) ? a[(n+1)/2] : (a[n/2]+a[n/2+1])/2; return med }
        # Only numeric values count: with placeholders in the TSV, "n/a" would sort as 0 and drag
        # the statistics toward a boot that never reported.
        $4 ~ /^[0-9.]+$/ { t[++nt]=$4; st+=$4 } $9 ~ /^[0-9.]+$/ { u[++nu]=$9; su+=$9 } $10 ~ /^[0-9.]+$/ { d[++nd]=$10; sd+=$10 }
        END {
            printf "%-22s %5s %9s %9s %9s %9s %9s\n", "metric", "runs", "min", "median", "mean", "max", "spread"
            if (nt) printf "%-22s %5d %9.2f %9.2f %9.2f %9.2f %8.1f%%\n", "boot total (s)", nt, t[1], sortmed(t,nt), st/nt, t[nt], (t[nt]-t[1])*100/t[1]
            if (nu) printf "%-22s %5d %9.2f %9.2f %9.2f %9.2f %8.1f%%\n", "userspace (s)", nu, u[1], sortmed(u,nu), su/nu, u[nu], (u[nu]-u[1])*100/u[1]
            if (nd) printf "%-22s %5d %9.2f %9.2f %9.2f %9.2f %8.1f%%\n", "desktop ready (s)", nd, d[1], sortmed(d,nd), sd/nd, d[nd], (d[nd]-d[1])*100/d[1]
            printf "\nMETRIC|bootloop_runs|%d|runs\n", NR
            if (nt) printf "METRIC|bootloop_total_median|%.2f|s\nMETRIC|bootloop_total_spread|%.1f|%%\n", sortmed(t,nt), (t[nt]-t[1])*100/t[1]
            if (nd) printf "METRIC|bootloop_desktop_median|%.2f|s\n", sortmed(d,nd)
        }'

    printf '\n## Anomalies\n\n'
    local anomalies=0
    # Read each row into an array and name only the columns this check needs. Spelling out all 23
    # fields of the read leaves most of them unused (a shellcheck warning each) and gives the column
    # order two places to drift apart.
    while IFS=$'\t' read -r -a F; do
        id=${F[0]} ts=${F[1]} desk=${F[9]} sstate=${F[10]} fs=${F[11]} fu=${F[12]}
        egl=${F[14]} wd=${F[15]} hard=${F[19]} pst=${F[20]} prev=${F[21]} pfu=${F[22]}
        [ "$id" = boot_id ] && continue
        local notes=""
        [ "$sstate" != running ] && notes+="system state $sstate; "
        [ "$fs" -gt 0 ] 2>/dev/null && notes+="failed system units: $fs; "
        [ "$fu" -gt 0 ] 2>/dev/null && notes+="failed user units: $fu; "
        [ "$hard" -gt 0 ] 2>/dev/null && notes+="kernel fault signals: $hard; "
        [ "$pst" -gt 0 ] 2>/dev/null && notes+="pstore records: $pst; "
        [ "$prev" = abrupt ] && notes+="previous boot stopped abruptly (no shutdown phase -- hang or power cut?); "
        [ "${pfu:-0}" -gt 0 ] 2>/dev/null && notes+="previous boot had $pfu failed unmount(s); "
        [ "$egl" != 0 ] && [ "$egl" != n/a ] && notes+="plasmashell has libnvidia-eglcore mapped ($egl) — containment broken; "
        [ "$wd" != active ] && notes+="panel watchdog not active ($wd); "
        [ "$desk" = n/a ] && notes+="no shell start timestamp (desktop never started?); "
        if [ -n "$notes" ]; then
            printf '%s (%s): %s\n' "${id:0:8}" "$ts" "${notes%; }"
            anomalies=$((anomalies+1))
        fi
    done < "$TSV"
    [ "$anomalies" -eq 0 ] && printf 'none — every captured boot was clean\n'

    printf '\n## Enumeration stability (the storage-migration trap)\n\n'
    tail -n +2 "$TSV" | awk -F'\t' '{ print $18 }' | sort | uniq -c | sort -rn | head -5
    printf '\n## Boots the journal knows about but no capture exists for\n\n'
    local missing=0 current cur_age
    current=$(tr -d '-' < /proc/sys/kernel/random/boot_id)
    cur_age=$(cut -d. -f1 /proc/uptime)
    while read -r idx id rest; do
        case "$idx" in IDX|-*) continue ;; esac
        # journalctl prints the boot id without dashes; this file stores it with them. Comparing
        # the two forms directly matched nothing, so every boot looked uncaptured — including the
        # current one. Strip the dashes before matching.
        if ! cut -f1 "$TSV" | tr -d '-' | grep -q "^${id}$"; then
            if [ "$id" = "$current" ]; then
                # Not a fault: the timer fires at 90 s, so a report run on a just-booted machine is
                # always ahead of the capture. Calling that "never captured" made a healthy boot
                # look broken.
                printf '  %s — this boot, capture not due yet (timer at 90 s, uptime %ss)\n' "$id" "$cur_age"
            else
                printf '  %s — booted but never captured (died before 90 s, or the timer did not run)\n' "$id"
                missing=$((missing+1))
            fi
        fi
    done < <(journalctl --list-boots --no-pager 2>/dev/null | tail -8)
    [ "$missing" -eq 0 ] && printf '  no past boot in the last 8 was missed\n'

    printf '\n## Verdict\n\n'
    if [ "$missing" -gt 0 ] || [ "${anomalies:-0}" -gt 0 ]; then
        printf '%s anomaly boot(s), %s missed capture(s)\n' "${anomalies:-0}" "$missing"
        exit 1
    fi
    printf 'clean: no anomaly boots, no missed captures\n'
    exit 0
}

case "$MODE" in
    capture) capture ;;
    --report) report ;;
    *) printf 'usage: %s [capture|--report] [--dir DIR]\n' "$0" >&2; exit 2 ;;
esac
