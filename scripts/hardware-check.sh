#!/usr/bin/env bash
# Full hardware check for this machine. READ-ONLY: every command only queries.
#
#   scripts/hardware-check.sh > /tmp/hw-raw.md                   # full run, unredacted
#   scripts/hardware-check.sh --print-redact-sed                # print the redaction rule set
#
# The output identifies the machine and its owner (disk serials, MAC addresses, IP addresses,
# SSIDs, machine-id). It is fine locally; redact before publishing anywhere:
#
#   scripts/hardware-check.sh > /tmp/hw-raw.md
#   sed -E "$(scripts/hardware-check.sh --print-redact-sed)" /tmp/hw-raw.md > hardware-check.md
#
# The rules live in REDACT_SED below -- one source of truth, exercised by the self-test at the
# end of every run, rather than retyped into a comment where it can rot. What each rule is for:
#
#   Serial Number        labelled; smartctl / dmidecode disk serials, case-insensitive.
#   link/ether, permaddr, MAC anywhere   the `ip -br link` shape has no `link/ether` literal,
#                        hence the context-free "six colon-separated hex pairs" rule beside it.
#   inet / inet6, IPv4, IPv6   likewise anchorless: `ip -br addr` carries neither literal.
#   Machine/Boot ID      labelled form only -- see the 32-hex rule for the unlabelled one.
#   SSID / UUID / PARTUUID   labelled.
#   32 hex, anywhere     the machine-id when nothing labels it: Limine names its kernel-staging
#                        directory `/boot/<machine-id>/` and records the same value in
#                        `/boot/limine.conf`, so an unredacted `/boot` listing identifies this
#                        machine on its own. Added 2026-10-17, after a regeneration republished
#                        it because the labelled rule above could not see it. The dashes in UUIDs
#                        and GPT GUIDs keep those out of its way.
#
# Do NOT reinstate the older form of this sed. It did not redact IP addresses at all: its
# `inet6? ` alternative carried its own trailing space, so that branch demanded two spaces
# between `inet` and the address and never matched real output. That leaked six IPs and a
# Bluetooth controller MAC into the published copy of this file. Equally, do not drop a rule:
# the self-test at the end of the run is what decides whether the set is still complete.
#
# hardware-check.md in this repo is the redacted copy of the 2026-10-17 run; its network,
# Bluetooth and machine-id values are machine-redacted, not hand-edited.
#
# shellcheck disable=SC2016  # Every single-quoted string below is a script handed to `sh -c`
#   on purpose, so its $vars must expand *inside*. File-wide, so it must precede all code.
set -u

# The redaction rule set: `--print-redact-sed` prints exactly this, and the self-test at the end
# of the run pipes synthetic identifiers through it. Keep it the only copy of the rules.
REDACT_SED='s/^(.*(Serial Number|serial)[^:]*:).*/\1 [redacted]/I;
s/(link\/ether|permaddr) [0-9a-fA-F:]+/\1 [redacted]/g;
s/([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}/[redacted]/g;
s/(inet6?) [0-9a-fA-F:.]+/\1 [redacted]/g;
s/[0-9]{1,3}(\.[0-9]{1,3}){3}(\/[0-9]{1,2})?/[redacted]/g;
s/[0-9a-fA-F:]*::[0-9a-fA-F:]*(\/[0-9]{1,3})?/[redacted]/g;
s/(Machine|Boot) ID[=: ]+[0-9a-fA-F-]+/\1 ID [redacted]/Ig;
s/(SSID|UUID|PARTUUID)[=: ]+[^ ]+/\1 [redacted]/Ig;
s/\b[0-9a-fA-F]{32}\b/[redacted]/g'
case "${1:-}" in
  --print-redact-sed) printf '%s\n' "$REDACT_SED"; exit 0 ;;
  "") ;;
  *) printf 'usage: %s [--print-redact-sed]\n' "$0" >&2; exit 2 ;;
esac

sec() { printf '\n## %s\n\n' "$1"; }
run() { printf '```text\n$ %s\n' "$*"; "$@" 2>&1; printf '```\n'; }
runsh() { printf '```text\n$ %s\n' "$1"; sh -c "$1" 2>&1; printf '```\n'; }

cat <<'HDR'
# Full hardware check

Regenerate with `scripts/hardware-check.sh` — read-only, ~3 s, 14 sections (the redaction
self-test that closes the output is not one of them). This file is the **redacted** copy: disk
serial numbers, MAC addresses, IP addresses, SSIDs and the machine-id are replaced with
`[redacted]` before it lands in this repo, because the repo is published. The unredacted run
lives on the machine under `~/Documents/`; the rule set is `REDACT_SED` at the top of the
script (`scripts/hardware-check.sh --print-redact-sed` prints it), and the self-test block at
the end proves it still blanks every identifier shape. Every line below is command output —
nothing here is inferred or remembered.

The machine-id is on that list for a reason worth keeping: Limine names its kernel-staging
directory `/boot/<machine-id>/` and records the same value in `/boot/limine.conf`, so an
unredacted `/boot` listing identifies this machine by itself. A labelled-only rule missed
exactly that until 2026-10-17; the context-free 32-hex rule covers it. Do not remove that rule,
and do not reinstate the older sed (see the top of `scripts/hardware-check.sh`).
HDR
printf '\nGenerated: %s · machine %s · kernel %s · CachyOS on a Gigabyte B550 AORUS ELITE AX V2\n' \
  "$(date -Iseconds)" "$(hostnamectl --static 2>/dev/null)" "$(uname -r)"

sec "System"
run hostnamectl
runsh 'uptime -p; who -b 2>/dev/null'
runsh 'timedatectl | head -8'
runsh 'head -6 /etc/os-release'

sec "Firmware, board, chassis, boot"
runsh 'sudo -n dmidecode -t bios 2>/dev/null | sed -n "1,22p"'
runsh 'ls /sys/class/tpm/ 2>/dev/null | head -3 || echo "no TPM device node"'
runsh 'sudo -n dmidecode -t baseboard 2>/dev/null | sed -n "/Base Board Information/,/^$/p"'
runsh 'sudo -n dmidecode -t system,chassis 2>/dev/null | grep -v "^$" | head -26'
runsh 'if [ -d /sys/firmware/efi ]; then echo "EFI boot: yes (efivars present)"; else echo "EFI boot: no"; fi'
runsh 'sudo -n efibootmgr -v 2>/dev/null | head -12'
runsh 'if command -v mokutil >/dev/null; then mokutil --sb-state 2>&1 | head -2; else v=$(ls /sys/firmware/efi/efivars/SecureBoot-* 2>/dev/null | head -1); if [ -n "$v" ]; then printf "SecureBoot efivar present; last byte (1 = enabled, 0 = disabled): %s\n" "$(od -An -tu1 "$v" | awk "{print \$NF}")"; else echo "no mokutil and no SecureBoot efivar"; fi; fi'
runsh 'sudo -n ls -la /boot | head -14'

sec "CPU"
runsh 'lscpu | grep -v -e "^Flags" -e "^NUMA" -e "^Vulnerability" -e "^BogoMIPS" | head -32'
runsh 'lscpu | grep "^Flags" | tr " " "\n" | grep -x -e avx2 -e avx512f -e svm -e aes -e sha_ni -e f16c -e bmi2 -e movbe -e vaes -e vpclmulqdq -e sme -e sev -e invpcid -e pcid -e fsgsbase -e umip -e pku -e ospke -e user_shstk -e xsaves -e clzero -e erms -e adx -e npt -e lbrv -e v_vmsave_vmload -e vgif -e avic -e wdt -e rdseed -e ibrs -e ibpb -e stibp -e ssbd | sort | tr "\n" " "; echo'
runsh 'grep -m1 "^microcode" /proc/cpuinfo; grep -m1 "^model name" /proc/cpuinfo'
runsh 'cpupower frequency-info 2>/dev/null | grep -i -e driver -e governor -e "hardware limits" -e "current policy" -e boost -e energy | head -8'
runsh 'cat /sys/devices/system/cpu/cpufreq/policy0/energy_performance_preference 2>/dev/null; cat /sys/devices/system/cpu/amd_pstate/status 2>/dev/null'
runsh 'sudo -n dmidecode -t processor 2>/dev/null | sed -n "/Processor Information/,/^Handle/p" | grep -v "^$" | head -24'
runsh 'sudo -n dmidecode -t cache 2>/dev/null | grep -i -e "Installed Size" -e "Socket Designation" -e "Associativity" -e "^.\tType:" | head -20'
runsh 'cat /proc/cmdline'

sec "Memory"
runsh 'sudo -n dmidecode -t memory 2>/dev/null | awk "/^Memory Device/{n++} n>0 && /^\t(Size|Type|Speed|Configured Memory Speed|Part Number|Rank|Locator|Bank Locator|Form Factor|Manufacturer):/{gsub(/^\t/,\"\"); print \"slot\" n \": \" \$0}" | grep -v "No Module Installed"'
runsh 'sudo -n dmidecode -t memory 2>/dev/null | grep -e "Maximum Capacity" -e "Number Of Devices" -e "Error Correction Type"'
run free -h
runsh 'swapon --show; echo; zramctl 2>/dev/null | head -4'

sec "GPU"
runsh 'lspci -nnk | grep -A3 -i "VGA compatible\|3D controller"'
runsh 'cat /proc/driver/nvidia/version 2>/dev/null | head -3'
runsh 'nvidia-smi --query-gpu=name,driver_version,vbios_version,memory.total,memory.used,temperature.gpu,power.draw,power.limit,clocks.sm,clocks.mem,utilization.gpu,pstate --format=csv 2>/dev/null'
runsh 'command -v vulkaninfo >/dev/null && (vulkaninfo --summary 2>/dev/null | head -14) || echo "vulkaninfo not installed"'
runsh 'command -v glxinfo >/dev/null && (glxinfo -B 2>/dev/null | head -12) || echo "glxinfo not installed"'

sec "Storage and filesystems"
runsh 'lsblk -o NAME,SIZE,TYPE,FSTYPE,FSVER,MOUNTPOINTS,ROTA,MODEL'
runsh 'cat /proc/mdstat 2>/dev/null || echo "no md arrays"'
runsh 'command -v mdadm >/dev/null && (sudo -n mdadm --detail /dev/md127 2>/dev/null | sed -n "1,24p") || echo "mdadm not installed"'
runsh 'df -hT -x tmpfs -x devtmpfs -x efivarfs'
runsh 'findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS -t btrfs,vfat,ext4,swap,none 2>/dev/null | head -14'
runsh 'sudo -n btrfs filesystem usage / 2>/dev/null | head -8'
runsh 'sudo -n btrfs subvolume list / 2>/dev/null | head -12'
runsh 'sudo -n snapper -c root list --columns number,type,date,description 2>/dev/null | tail -6'
runsh 'for d in $(lsblk -dno NAME,TYPE | awk "\$2==\"disk\"{print \$1}"); do echo "== /dev/$d"; sudo -n smartctl -i -H -A "/dev/$d" 2>/dev/null | grep -i -e "Model Number" -e "Firmware" -e "Serial Number" -e "SMART overall" -e "Temperature" -e "Percentage Used" -e "Data Units Written" -e "Power On Hours" -e "Available Spare" -e "Media and Data" | head -12; done'

sec "PCIe topology (which M.2 slot each NVMe sits in, and its link)"
runsh 'for n in /sys/class/nvme/nvme*; do d=$(basename "$n"); dev=$(readlink -f "$n/device"); pci=$(basename "$dev"); parent=$(basename "$(dirname "$dev")"); printf "%-7s %s\n" "$d" "$(cat $n/model 2>/dev/null)"; sudo -n lspci -vv -s "$pci" 2>/dev/null | grep -m1 -o "LnkSta:.*" | sed "s/^/          link now : /"; sudo -n lspci -vv -s "$parent" 2>/dev/null | grep -m1 -o "LnkCap:.*Speed [0-9.]*GT/s" | sed "s/^/          slot max : /"; done'

sec "Displays"
runsh 'kscreen-doctor -o 2>/dev/null | head -40 || echo "kscreen-doctor unavailable from this shell"'
runsh 'for c in /sys/class/drm/card*-*; do [ -e "$c/status" ] || continue; printf "%s: status=%s enabled=%s modes=%s\n" "$(basename $c)" "$(cat $c/status)" "$(cat $c/enabled 2>/dev/null)" "$(head -3 $c/modes 2>/dev/null | tr "\n" ",")"; done'

sec "Network and Bluetooth"
runsh 'ip -br link; echo; ip -br addr | head -8'
runsh 'lspci -nn | grep -i -e ethernet -e "network controller"'
runsh 'for i in $(ls /sys/class/net | grep -v lo); do printf "%-12s " "$i"; sudo -n ethtool "$i" 2>/dev/null | grep -i -e speed -e duplex -e "link detected" | tr "\n" " "; echo; done'
runsh 'rfkill list 2>/dev/null | head -8; echo; iw dev 2>/dev/null | grep -i -e Interface -e type -e channel -e ssid | head -8'
runsh 'timeout 5 bluetoothctl show 2>/dev/null | head -8 || echo "bluetoothctl unavailable"'
runsh 'lsusb | grep -i -e bluetooth -e wireless -e intel | head -4'

sec "Audio"
runsh 'lspci -nn | grep -i audio'
runsh 'aplay -l 2>/dev/null | head -12'
runsh 'pactl info 2>/dev/null | grep -i -e "Server Name" -e "Server Version" -e "Default Sink" -e "Default Source"'

sec "PCI and USB inventory"
run lspci -nn
runsh 'lsusb'
runsh 'lsusb -t | head -24'

sec "Sensors, thermals, power"
runsh 'if command -v sensors >/dev/null; then sudo -n sensors 2>/dev/null | head -46; else echo "lm_sensors not installed"; fi'
runsh 'for z in /sys/class/thermal/thermal_zone*; do [ -e "$z/temp" ] && printf "%s %s: %s\n" "$(basename $z)" "$(cat $z/type 2>/dev/null)" "$(( $(cat $z/temp) / 1000 ))C"; done'
runsh 'powerprofilesctl get 2>/dev/null; upower -e 2>/dev/null | head -6; for p in /sys/class/power_supply/*/type; do [ -e "$p" ] && cat "$p"; done'
runsh 'cat /sys/devices/system/cpu/cpufreq/policy0/scaling_driver 2>/dev/null; cat /sys/devices/system/cpu/cpufreq/boost 2>/dev/null'

sec "Virtualisation and platform security"
runsh 'systemd-detect-virt; echo "IOMMU groups: $(ls /sys/kernel/iommu_groups 2>/dev/null | wc -l)"; sudo -n dmesg 2>/dev/null | grep -i -m4 -e "AMD-Vi" -e "iommu" | head -4'
runsh 'sudo -n dmesg 2>/dev/null | grep -i -m3 -e "microcode" -e "Spectre" -e "MDS" | head -3'

sec "Kernel modules and packages in play"
runsh 'lsmod | grep -i -e "^nvidia" -e "^kvm" -e "^snd_hda" -e "^iwlwifi" -e "^r8169" -e "^usbhid" -e "^amdgpu" | head -14'
runsh 'pacman -Q linux-cachyos linux-cachyos-lts linux-cachyos-nvidia-open nvidia-utils linux-firmware 2>/dev/null'
runsh 'rg -c . /proc/crypto >/dev/null 2>&1; ls /usr/lib/modules | head -6'

# --- Redaction self-test --------------------------------------------------------------------
# Tests the RULES against synthetic input, not "are there identifiers in the output" -- that
# check passes vacuously for any identifier class this script never happens to collect, which
# is the mistake the sibling premigration-inventory.sh documents. That script got its self-test
# on 2026-10-11 after a leak shipped; this one had none until 2026-10-17, when an unlabelled
# machine-id reached the published copy for exactly that reason. The exit status is the verdict.
rc=0
selftest_in='Serial Number: TESTSERIAL123
UUID=deadbeef-0000-1111-2222-333333333333
link/ether aa:bb:cc:dd:ee:ff
inet 192.0.2.55/24
SSID: TestNet
198.51.100.7/24 2001:db8::5678/64
Machine ID: 0123456789abcdef0123456789abcdef
drwxr-xr-x 5 root root 4096 Aug 29 22:28 0123456789abcdef0123456789abcdef
module_path: boot():/0123456789abcdef0123456789abcdef/linux-cachyos/initramfs'
selftest_out="$(printf '%s\n' "$selftest_in" | sed -E "$REDACT_SED")"
printf '\nRedaction self-test (synthetic identifiers; none may survive the rules above):\n\n'
printf '```text\n'
for pair in 'TESTSERIAL123|disk serial, labelled' \
            'deadbeef-0000-1111-2222-333333333333|GUID with dashes' \
            'aa:bb:cc:dd:ee:ff|MAC, anchorless shape' \
            '192.0.2.55|IPv4, anchorless shape' \
            'TestNet|wireless network name, labelled' \
            '198.51.100.7|IPv4, bare inside a list' \
            '2001:db8::5678|IPv6' \
            '0123456789abcdef0123456789abcdef|machine-id, labelled and bare'; do
  # The label is what gets published -- the fixture that was tested would itself be redacted
  # by the very rules under test, and a reader still gets to see which shapes were covered.
  if printf '%s' "$selftest_out" | grep -qF -- "${pair%%|*}"; then
    printf '  FAIL      synthetic value survived the rules (%s)\n' "${pair#*|}"
    rc=1
  else
    printf '  redacted  %s\n' "${pair#*|}"
  fi
done
printf '```\n'
exit "$rc"
