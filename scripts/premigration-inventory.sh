#!/usr/bin/env bash
#
# premigration-inventory.sh — a dated, plain-text, diffable inventory of this machine.
#
# WHY THIS EXISTS
# ---------------
# The NVMe migration (storage-migration.md) may take the "fresh install on the new disk, then
# rebuild from this repo" route. That route is only as safe as this repo is complete, and
# nothing has ever tested that claim. This dump is the baseline that tests it:
#
#   scripts/premigration-inventory.sh                       # on the OLD system, first
#   ...same script on the NEW system...
#   diff <(zcat .../premigration-inventory-OLD.txt.gz) <(zcat .../premigration-inventory-NEW.txt.gz)
#
# Anything present-then-absent is an undocumented gap — found while the old disk is still
# attached and bootable. The DIFF is the deliverable; the dump is only its input.
#
# Read-only. Section order is fixed and content is sorted wherever order is not meaningful, so
# two runs diff cleanly.
#
# PRIVACY
# -------
# This dump deliberately never COLLECTS disk serials, MAC addresses, IP addresses or SSIDs:
# there is no smartctl section, no `lsblk SERIAL` column and no `ip`/SSID query. They are absent
# by construction, which is a stronger guarantee than redacting them afterwards. What it does
# collect is UUIDs and PARTUUIDs, which come free with `blkid` and `/etc/fstab`.
#
# The repo is PUBLISHED, so it writes two files:
#
#   premigration-inventory-<date>.txt.gz            full; stays on the machine (~/Documents)
#   premigration-inventory-<date>.redacted.txt.gz   repo copy; the documented sed applied
#
# The sed is the one documented at the top of hardware-check.sh, WITH ITS TWO IDENTIFIER BUGS FIXED.
# As documented there it does not redact IP addresses at all: the `inet6? ` alternative carries
# its own trailing space, so that branch demands `inet␣␣ADDR` (two spaces) and no real
# `ip addr` output has it -- while the MAC alternatives share one space and work. The bare-address
# rules below cover `ip -br addr` output, which has no `inet` literal at all.
#
# That bug is live in the repo, not theoretical: hardware-check.md (PUBLIC) still carries eno1's
# real MAC and `192.168.0.15/24`, from exactly such a section. Found by this script's own
# self-test on 2026-10-11; see customizations.md.
#
# Disk identity for the boot-path steps in storage-migration.md is deliberately NOT taken from
# this file -- it lives in that document, which carries the PARTUUIDs for that purpose.
#
# The verification at the end tests the RULES against synthetic input, and separately reports
# which identifier classes this dump contains. It does NOT assert "no identifiers found": that
# check passes vacuously for identifiers never collected. An earlier version of this script made
# precisely that mistake, and its positive control is what exposed both bugs.
#
# Usage:
#   scripts/premigration-inventory.sh [DEST_DIR]     # default ~/Documents
#   scripts/premigration-inventory.sh --stdout       # full dump to stdout, no files written

# shellcheck disable=SC2016  # Every single-quoted string below is a script handed to `bash -c`
#   on purpose, so its $vars must expand *inside*. File-wide, so it has to precede all code.
set -uo pipefail
export LC_ALL=C

OUT_DIR="$HOME/Documents"
STDOUT_ONLY=0
if [[ "${1:-}" == "--stdout" ]]; then
    STDOUT_ONLY=1
elif [[ -n "${1:-}" ]]; then
    OUT_DIR="$1"
fi

STAMP="$(date +%F)"
BASE="premigration-inventory-$STAMP"

sec() { printf '\n\n===== %s =====\n\n' "$1"; }
run() { printf '\n$ %s\n' "$*"; "$@" 2>&1 || printf '(exit %s)\n' "$?"; }
runsh() { printf '\n$ %s\n' "$1"; bash -c "$1" 2>&1 || printf '(exit %s)\n' "$?"; }
note() { printf '\n-- %s\n' "$1"; }

body() {
    cat <<HDR
premigration-inventory — ${STAMP}
machine: $(hostnamectl --static 2>/dev/null || echo unknown)
generated: $(date -Iseconds)
kernel: $(uname -r)

A dated, read-only dump of what this machine IS, in plain text, built to be diffed against the
same script's output on a rebuild. Regenerate with scripts/premigration-inventory.sh; the
unredacted copy stays on the machine, the redacted copy is the one committed to the repo.
Section order is fixed and content is sorted, so a clean diff between two runs means the
rebuild matched. Every line below is command output — nothing here is inferred or remembered.
HDR

    sec "1. Identity"
    run hostnamectl
    runsh 'head -8 /etc/os-release'
    runsh 'uptime -p; who -b 2>/dev/null; echo "boot id: $(cat /proc/sys/kernel/random/boot_id)"'

    sec "2. Packages"
    note "counts"
    runsh 'printf "total: %s\nexplicit: %s\nforeign: %s\n" \
        "$(pacman -Qq | wc -l)" "$(pacman -Qqe | wc -l)" "$(pacman -Qqm | wc -l)"'
    note "explicitly installed (pacman -Qqe) — what someone actually asked for"
    runsh 'pacman -Qqe | sort'
    note "foreign / not in any sync repo (pacman -Qqm) — these CANNOT be reinstalled from repos"
    runsh 'pacman -Qqm | sort'
    note "everything, name+version (pacman -Q) — the diffable baseline"
    runsh 'pacman -Q | sort'
    note "non-pacman installs that a rebuild would otherwise silently miss"
    runsh 'for c in cargo npm pipx flatpak go; do printf "%-9s %s\n" "$c" "$(command -v "$c" 2>/dev/null || echo "(absent)")"; done'
    runsh 'command -v cargo >/dev/null && cargo install --list 2>/dev/null | grep -E "^[a-z0-9_-]+ " | sort'
    runsh 'command -v npm >/dev/null && npm -g --depth=0 ls 2>/dev/null | tail -n +2 | sort'
    runsh 'command -v pipx >/dev/null && pipx list --short 2>/dev/null | sort'
    runsh 'command -v flatpak >/dev/null && flatpak list --app --columns=application,origin 2>/dev/null | sort -u'

    sec "3. Files in /etc that NO package owns"
    note "the reconstruction killer: hand-made config that nothing will reinstall"
    runsh 'comm -23 <(find /etc -type f 2>/dev/null | sort) <(pacman -Qlq 2>/dev/null | grep "^/etc/" | sort)'
    note "directories under /etc that no package owns"
    runsh 'comm -23 <(find /etc -type d 2>/dev/null | sort) <(pacman -Qlq 2>/dev/null | grep "^/etc/" | sed "s:/[^/]*$::" | sort -u)'

    sec "4. Files outside /etc that no package owns"
    note "/usr/local (shims documented in system-inventory.md)"
    runsh 'find /usr/local -type f 2>/dev/null | sort'
    runsh 'comm -23 <(find /usr/local -type f 2>/dev/null | sort) <(pacman -Qlq 2>/dev/null | grep "^/usr/local/" | sort)'
    note "/opt"
    runsh 'find /opt -maxdepth 3 2>/dev/null | sort | head -40'
    note "hand-installed binaries in ~/.local/bin and ~/.cargo/bin"
    runsh 'find "$HOME/.local/bin" "$HOME/.cargo/bin" -maxdepth 1 -type f -o -maxdepth 1 -type l 2>/dev/null | sort'

    sec "5. systemd state"
    note "enabled system units"
    runsh 'systemctl list-unit-files --state=enabled --no-pager 2>/dev/null | sort'
    note "enabled user units"
    runsh 'systemctl --user list-unit-files --state=enabled --no-pager 2>/dev/null | sort'
    note "system timers"
    runsh 'systemctl list-timers --all --no-pager 2>/dev/null'
    note "user timers"
    runsh 'systemctl --user list-timers --all --no-pager 2>/dev/null'
    note "failed units (both scopes) at dump time"
    runsh 'systemctl --failed --no-pager 2>/dev/null; systemctl --user --failed --no-pager 2>/dev/null'
    note "non-package-owned unit files in /etc/systemd"
    runsh 'find /etc/systemd -type f 2>/dev/null | sort'

    sec "6. Boot chain"
    note "/etc/fstab (UUIDs kept on purpose — see the header)"
    runsh 'grep -vE "^\s*#|^\s*$" /etc/fstab'
    note "kernel command line"
    runsh 'cat /proc/cmdline'
    note "UEFI boot entries"
    runsh 'sudo -n efibootmgr -v 2>/dev/null || echo "(needs sudo -n)"'
    note "limine"
    runsh 'pacman -Qq 2>/dev/null | grep -i limine | sort'
    runsh 'printf "limine.conf entries: %s\n" "$(sudo -n grep -c "" /boot/limine.conf 2>/dev/null)"; sudo -n ls -la /boot/limine.conf* 2>/dev/null'
    note "ESP layout (kernel staging dir is Limine's, see storage-migration.md)"
    runsh 'sudo -n find /boot -maxdepth 2 2>/dev/null | sort | head -40'
    note "pacman hooks and mkinitcpio presets"
    runsh 'ls -la /etc/pacman.d/hooks/ 2>/dev/null; echo; cat /etc/mkinitcpio.conf 2>/dev/null | grep -vE "^\s*#|^\s*$"'
    runsh 'ls /etc/mkinitcpio.d/ 2>/dev/null; echo; grep -h "^ALL_kver\|^PRESETS\|^default_image" /etc/mkinitcpio.d/*.preset 2>/dev/null | sort -u'

    sec "7. Storage"
    note "lsblk (serials omitted on purpose; they are not needed to identify disks here)"
    runsh 'lsblk -o NAME,SIZE,TYPE,MODEL,FSTYPE,MOUNTPOINTS | sort -k1'
    note "blkid (labelled form, so redaction is reliable)"
    runsh 'sudo -n blkid -o export 2>/dev/null | grep -E "^(DEVNAME|UUID|PARTUUID|TYPE|LABEL|PARTLABEL)=" | sort'
    note "btrfs filesystems and subvolume layout — must match on the new disk or fstab/snapper break"
    runsh 'sudo -n btrfs filesystem show 2>/dev/null'
    runsh 'sudo -n btrfs subvolume list / 2>/dev/null | grep -v "\.snapshots/" | sort -k2'
    note "mounts and free space"
    runsh 'findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS --real | sort'
    runsh 'df -hT -x tmpfs -x devtmpfs 2>/dev/null | sort -k7'
    note "swap and mdraid"
    runsh 'cat /proc/swaps; echo; lsblk -o NAME,SIZE,TYPE | grep -i swap'
    runsh 'cat /proc/mdstat'

    sec "8. Snapshots"
    runsh 'sudo -n snapper list-configs 2>/dev/null'
    runsh 'sudo -n snapper -c root list 2>/dev/null | head -20; echo "...(truncated)"; printf "total snapshots: %s\n" "$(sudo -n snapper -c root list 2>/dev/null | grep -c "|")"'
    runsh 'sudo -n cat /etc/snapper/configs/root 2>/dev/null | grep -vE "^\s*#|^\s*$"'

    sec "9. Session, display manager, input"
    runsh 'systemctl is-enabled greetd sddm gdm 2>/dev/null'
    runsh 'find /usr/share/wayland-sessions /usr/share/xsessions -maxdepth 1 -type f 2>/dev/null | sort'
    runsh 'sudo -n ls -la /etc/greetd/ 2>/dev/null; echo; sudo -n grep -vE "^\s*#|^\s*$" /etc/greetd/*.toml /etc/greetd/config 2>/dev/null'
    runsh 'systemctl is-enabled keyd 2>/dev/null; sudo -n ls -la /etc/keyd/ 2>/dev/null; sudo -n grep -vE "^\s*#|^\s*$" /etc/keyd/*.conf 2>/dev/null'

    sec "10. Privilege and authentication config (paths only, except fstab above)"
    runsh 'sudo -n ls /etc/sudoers.d/ 2>/dev/null; ls /etc/polkit-1/rules.d/ 2>/dev/null; ls /etc/pam.d/ 2>/dev/null | sort'
    runsh 'comm -23 <(sudo -n find /etc/pam.d /etc/security /etc/polkit-1 -type f 2>/dev/null | sort) <(pacman -Qlq 2>/dev/null | grep -E "^/etc/(pam.d|security|polkit-1)/" | sort)'

    sec "11. User environment"
    runsh 'id; echo "shell: $SHELL"; getent passwd "$USER" | cut -d: -f 6,7'
    note "top-level ~/.config entries (the copy checklist for a rebuild)"
    runsh 'find "$HOME/.config" -maxdepth 1 -mindepth 1 2>/dev/null | sort'
    note "user units and autostart"
    runsh 'find "$HOME/.config/systemd" -type f 2>/dev/null | sort; echo; find "$HOME/.config/autostart" -type f 2>/dev/null | sort'
    note "cron"
    runsh 'crontab -l 2>/dev/null || echo "(no user crontab)"; echo; ls -la /etc/cron.d/ 2>/dev/null; sudo -n ls -la /var/spool/cron/ 2>/dev/null'
    note "shell startup files present"
    runsh 'ls -la "$HOME"/.bashrc "$HOME"/.bash_profile "$HOME"/.profile "$HOME"/.bash_logout /etc/bash.bashrc /etc/profile 2>/dev/null'
    note "home size and largest directories (what actually needs copying)"
    runsh 'du -sh "$HOME" 2>/dev/null; echo; du -sh "$HOME"/* 2>/dev/null | sort -h | tail -12'

    sec "12. Repositories"
    runsh 'grep -vE "^\s*#|^\s*$" /etc/pacman.conf'
    runsh 'grep -c "^Server" /etc/pacman.d/mirrorlist 2>/dev/null; head -3 /etc/pacman.d/mirrorlist 2>/dev/null'
    runsh 'ls -la /etc/pacman.d/ 2>/dev/null'

    sec "13. How to use this file"
    cat <<'FOOT'

This dump exists to be diffed. On the rebuilt system:

  scripts/premigration-inventory.sh /tmp/new
  diff <(zcat ~/Documents/premigration-inventory-<old>.txt.gz) \
       <(zcat /tmp/new/premigration-inventory-<new>.txt.gz)

Read the diff as a checklist, not as noise. Expected and ignorable:
  - package VERSIONS (a rebuild installs newer ones) — compare names, not versions
  - boot/random IDs, timestamps, uptimes, sizes, snapshot counts
  - device node names (nvme0/nvme1 swap freely — identify disks by PARTUUID)

NOT ignorable — each is a real gap the repo failed to record:
  - a line in section 3/4 (unowned config) present in old, absent in new
  - an explicit or foreign package in section 2 with no counterpart
  - an enabled unit or timer in section 5 that is not enabled after the rebuild
  - a btrfs subvolume in section 7 that the new layout lacks
  - a hook, preset or pam/security/polkit file in section 6 or 10 that is missing
FOOT
}

if (( STDOUT_ONLY )); then
    body
    exit 0
fi

TMP="$(mktemp)" || exit 1
trap 'rm -f "$TMP"' EXIT
body > "$TMP"

mkdir -p "$OUT_DIR" || exit 1
FULL="$OUT_DIR/$BASE.txt.gz"
REDACTED="$OUT_DIR/$BASE.redacted.txt.gz"

REDACT_SED='s/^(.*(Serial Number|serial)[^:]*:).*/\1 [redacted]/I; s/(link\/ether|permaddr) [0-9a-fA-F:]+/\1 [redacted]/g; s/([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}/[redacted]/g; s/(inet6?) [0-9a-fA-F:.]+/\1 [redacted]/g; s/[0-9]{1,3}(\.[0-9]{1,3}){3}(\/[0-9]{1,2})?/[redacted]/g; s/[0-9a-fA-F:]*::[0-9a-fA-F:]*(\/[0-9]{1,3})?/[redacted]/g; s/(SSID|UUID|PARTUUID)[=: ]+[^ ]+/\1 [redacted]/Ig'

gzip -9 -c "$TMP" > "$FULL"
sed -E "$REDACT_SED" "$TMP" | gzip -9 -c > "$REDACTED"

printf 'wrote:\n  %s\n  %s\n\n' "$FULL" "$REDACTED"
printf 'raw bytes: %s, gz bytes: %s\n' "$(wc -c < "$TMP")" "$(wc -c < "$FULL")"

# --- Verification -----------------------------------------------------------------------------
# Test the RULES, not an absence. Asserting "no identifiers in the redacted file" would pass
# vacuously here, because the dump collects no serials/MACs/IPs/SSIDs to begin with.
rc=0
selftest_in='Serial Number: TESTSERIAL123
UUID=deadbeef-0000-1111-2222-333333333333
link/ether aa:bb:cc:dd:ee:ff
inet 192.0.2.55/24
SSID: TestNet
198.51.100.7/24 fe80::5cb:5188:ec9f:a776/64
Controller BC:C7:46:9A:E8:89 (public)
lo UNKNOWN 00:1b:44:11:3a:b7 <UP>'
selftest_out="$(printf '%s\n' "$selftest_in" | sed -E "$REDACT_SED")"

printf '\nredaction rule self-test (synthetic input; every line must read "redacted"):\n'
for tok in TESTSERIAL123 deadbeef-0000-1111-2222-333333333333 aa:bb:cc:dd:ee:ff 192.0.2.55 TestNet 198.51.100.7 fe80::5cb:5188:ec9f:a776 BC:C7:46:9A:E8:89 00:1b:44:11:3a:b7; do
    if printf '%s' "$selftest_out" | grep -qF -- "$tok"; then
        printf '  FAIL      %s survived the sed\n' "$tok"
        rc=1
    else
        printf '  redacted  %s\n' "$tok"
    fi
done

# What this dump actually carries, so the self-test's coverage is explicit rather than implied.
# Each count is independent (and \bUUID keeps PARTUUID out of the UUID count).
printf '\nidentifier labels in the redacted copy (counts of redacted values):\n'
printf '  %-14s %s\n' 'Serial Number' "$(zcat "$REDACTED" | grep -ci -E 'Serial Number.*\[redacted\]')"
printf '  %-14s %s\n' 'link/ether'    "$(zcat "$REDACTED" | grep -c  -E 'link/ether .*\[redacted\]')"
printf '  %-14s %s\n' 'SSID'          "$(zcat "$REDACTED" | grep -ci -E 'SSID.*\[redacted\]')"
printf '  %-14s %s\n' 'PARTUUID'      "$(zcat "$REDACTED" | grep -c  -E 'PARTUUID \[redacted\]')"
printf '  %-14s %s\n' 'UUID'          "$(zcat "$REDACTED" | grep -c  -E '\bUUID \[redacted\]')"
printf '  %-14s %s\n' 'bare MAC/uuid' "$(zcat "$REDACTED" | grep -coE '([0-9a-f]{2}:){5}[0-9a-f]{2}|HD\([0-9]+,GPT,[0-9a-f-]+\)')"

printf '\nfull copy stays on the machine; commit only the .redacted.txt.gz\n'
exit "$rc"
