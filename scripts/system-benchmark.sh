#!/usr/bin/env bash
# System benchmark for this machine -- the "before / after" pair for rebuilding it.
#
#   scripts/system-benchmark.sh before     # on the current install, before the rebuild
#   scripts/system-benchmark.sh after      # on the fresh install, same suite
#   scripts/system-benchmark.sh before     # again -- each run gets its own file, nothing overwrites
#   scripts/system-benchmark.sh --average benchmarks/2026-10-17-before*.txt
#   scripts/system-benchmark.sh --diff benchmarks/2026-10-17-before-avg.txt benchmarks/2026-11-01-after-avg.txt
#
# Writes benchmarks/<date>-<label>.txt (a second run that day becomes -run2, then -run3) and
# prints the same to stdout. Runtime ~3 min: time_based fio jobs plus 15 s/10 s sysbench jobs,
# so a slow disk does not stretch it. Take three runs and average them: the CPU, crypto and
# memory metrics repeat to ~1%, but the disk metrics swing (on the old root, 4K random write
# measured 23.7 / 82.4 / 35.0 MiB/s within an hour, and raw sequential read 620-867 MiB/s),
# so a single run is not a baseline. --average prints mean, median, min, max and spread.
#
# Read-only on the hardware: the only file it writes is a scratch file in $HOME/.cache, removed
# at the end. The one command that needs privileges is fio reading the root *partition* (device
# -level numbers, read-only); if sudo refuses, that section is skipped and says so.
#
# Nothing identifying is printed -- no serials, MACs, IPs, SSIDs, machine-id or product UUID.
# hostnamectl's Machine ID / Boot ID / Product UUID lines are filtered out for exactly that
# reason, and the run ends by checking the result file for the machine-id and failing loudly if
# it finds it. Results are safe to commit to this published repo.
#
# Why these metrics:
#   boot time      systemd-analyze; the number a rebuild most obviously moves
#   sysbench cpu   single-thread and 24-thread integer throughput
#   sysbench mem   single-thread and 24-thread memory bandwidth
#   openssl speed  SHA-256 + AES-256-GCM: independent CPU instruction-mix check
#   fio (file)     4K QD1 random read is the "78.7 MB/s" figure quoted in storage-migration.md;
#                  plus 4K QD32 and 1M sequential, through the filesystem
#   fio (device)   4K QD32 + 1M sequential read straight off the root partition, so two installs
#                  can be compared without filesystem differences (btrfs COW, zstd, layout)
#   vkmark         Vulkan throughput. Session-dependent (compositor, browser, monitor refresh);
#                  compare only like with like, and treat it as a sanity check, not a score.
#
# fio reads the filesystem under test through O_DIRECT when the kernel allows it (btrfs does);
# the file jobs use incompressible data so zstd:1 cannot flatter the numbers. All fio jobs pin
# --ioengine=libaio: with the psync default, iodepth is meaningless and QD32 would silently
# measure QD1.

# shellcheck disable=SC2016  # Every single-quoted string below is a script handed to `bash -c`
#   on purpose, so its $vars expand *inside* -- same as scripts/hardware-check.sh. File-wide,
#   so it must precede all code.
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTDIR="$REPO/benchmarks"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/system-benchmark"
FIOFILE="$CACHE/fio.dat"
FIO_SIZE=2G
NPROC="$(nproc)"

# METRIC|name|value|unit -- one machine-readable line per number, for --diff.
metric() { printf 'METRIC|%s|%s|%s\n' "$1" "$2" "$3"; }
sec()    { printf '\n## %s\n\n' "$1"; }
show()   { printf '```text\n$ %s\n' "$*"; "$@" 2>&1; printf '```\n'; }
showsh() { printf '```text\n$ %s\n' "$1"; bash -c "$1" 2>&1; printf '```\n'; }

# ---------------------------------------------------------------- average mode
# Mean and median per metric across N run files. The median is the one to trust where the spread
# is wide; the mean is what --diff consumes, so an averaged file is still diffable.
if [ "${1:-}" = "--average" ]; then
    shift
    [ $# -ge 1 ] || { printf 'usage: %s --average <run files...>\n' "$0" >&2; exit 2; }
    # An average is not a run. Skip files that say they are averages, so that re-running --average
    # on a glob which has since grown to include the previous result cannot average an average.
    # The marker is printed below and ignored by --diff.
    files=()
    for f in "$@"; do
        if grep -q '^# AVERAGED FROM' "$f" 2>/dev/null; then
            printf 'skipping %s: it is itself an average\n' "$f" >&2
        elif ! grep -q '^METRIC|' "$f" 2>/dev/null; then
            # Catches an empty or unrelated file too -- note that redirecting this output onto a
            # file the glob already matched truncates it before the glob is read, so "accepted but
            # empty" is a real case, not a hypothetical one. It must not be listed as a source.
            printf 'skipping %s: no METRIC lines\n' "$f" >&2
        else
            files+=("$f")
        fi
    done
    [ "${#files[@]}" -ge 1 ] || { printf 'no run files given (only averages?)\n' >&2; exit 2; }
    printf '# AVERAGED FROM %s\n\n' "${files[*]}"
    awk -F'|' '
      $1=="METRIC" && $3!="" { n[$2]++; v[$2 SUBSEP n[$2]]=$3+0; u[$2]=$4; s[$2]+=$3+0 }
      END {
        printf "%-26s %4s %12s %12s %12s %12s %8s\n","metric","runs","mean","median","min","max","spread"
        for (k in n) {
          for (i=1;i<=n[k];i++) a[i]=v[k SUBSEP i]
          for (i=1;i<=n[k];i++) for (j=i+1;j<=n[k];j++) if (a[i]>a[j]) { t=a[i]; a[i]=a[j]; a[j]=t }
          med=(n[k]%2) ? a[(n[k]+1)/2] : (a[n[k]/2]+a[n[k]/2+1])/2
          row[k]=sprintf("%-26s %4d %12.1f %12.1f %12.1f %12.1f %7.1f%%", k, n[k], s[k]/n[k], med, a[1], a[n[k]], (a[1]>0) ? (a[n[k]]-a[1])*100/a[1] : 0)
        }
        c=0; for (k in row) key[++c]=k
        for (i=1;i<=c;i++) for (j=i+1;j<=c;j++) if (key[i]>key[j]) { t=key[i]; key[i]=key[j]; key[j]=t }
        for (i=1;i<=c;i++) print row[key[i]]
      }' "${files[@]}"
    printf '\n'
    awk -F'|' '$1=="METRIC" && $3!="" { s[$2]+=$3+0; n[$2]++; u[$2]=$4 } END { for (k in s) printf "METRIC|%s|%.1f|%s\n", k, s[k]/n[k], u[k] }' "${files[@]}" | sort
    exit 0
fi

# ---------------------------------------------------------------- diff mode
if [ "${1:-}" = "--diff" ]; then
    [ $# -eq 3 ] || { printf 'usage: %s --diff <before.txt> <after.txt>\n' "$0" >&2; exit 2; }
    awk -F'|' '
      FNR==NR { if ($1=="METRIC") { b[$2]=$3; bu[$2]=$4 } next }
      $1=="METRIC" { a[$2]=$3; au[$2]=$4 }
      END {
        printf "%-26s %14s %14s %10s\n", "metric", "before", "after", "change"
        for (k in a) {
          if (!(k in b)) { printf "%-26s %14s %14s %10s\n", k, "-", a[k], "new"; continue }
          d = (b[k] == 0) ? 0 : (a[k]-b[k])*100/b[k];
          printf "%-26s %14.1f %14.1f %9.1f%%\n", k, b[k], a[k], d
        }
        for (k in b) if (!(k in a)) printf "%-26s %14.1f %14s %10s\n", k, b[k], "-", "gone"
      }' "$2" "$3"
    exit 0
fi

LABEL="${1:-run}"
mkdir -p "$OUTDIR" "$CACHE"
OUT="$OUTDIR/$(date +%F)-$LABEL.txt"
i=1
while [ -e "$OUT" ]; do i=$((i+1)); OUT="$OUTDIR/$(date +%F)-$LABEL-run$i.txt"; done
exec > >(tee "$OUT") 2>&1

printf '# System benchmark — %s\n\n' "$LABEL"
printf 'Run %s · host %s · kernel %s · CachyOS on a Gigabyte B550 AORUS ELITE AX V2\n' \
    "$(date -Iseconds)" "$(hostnamectl --static)" "$(uname -r)"
printf '\nEvery line below is command output, except `METRIC|` lines, which this script emits for\n'
printf '`--diff`. fio numbers are MiB/s unless marked IOPS. Compare like with like: the load\n'
printf 'average, the power profile and the session state all move the CPU and GPU numbers.\n'

ROOT_SRC="$(findmnt -no SOURCE /)"; ROOT_DEV="${ROOT_SRC%%[*}"
printf '\n- Root device: `%s` (%s)\n' "$ROOT_DEV" "$(lsblk -dno MODEL "$ROOT_DEV" 2>/dev/null)"
printf -- '- Free space on `/`: %s\n' "$(df -h --output=avail / | tail -1 | tr -d ' ')"
printf -- '- Load average: %s\n' "$(awk '{print $1, $2, $3}' /proc/loadavg)"

sec "System and session state"
showsh 'hostnamectl | grep -vE "(Machine|Boot) ID|Product UUID" | head -6'
show hostnamectl --static
showsh 'uname -r; uptime -p; awk "{print \"load:\", \$1, \$2, \$3}" /proc/loadavg'
showsh 'powerprofilesctl get 2>/dev/null; cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor; cat /sys/devices/system/cpu/cpufreq/policy0/energy_performance_preference; cat /sys/devices/system/cpu/amd_pstate/status 2>/dev/null'
showsh 'cat /proc/driver/nvidia/version | head -1'
showsh 'pacman -Qqen | wc -l; pacman -Q linux-cachyos linux-cachyos-nvidia-open nvidia-utils fio sysbench vkmark 2>/dev/null'
showsh 'findmnt -no SOURCE,FSTYPE,OPTIONS /'

sec "Boot time"
BOOT_OUT="$(systemd-analyze 2>&1)"
printf '```text\n$ systemd-analyze\n%s\n```\n' "$BOOT_OUT"
metric boot_total "$(printf '%s' "$BOOT_OUT" | sed -n 's/.*= \([0-9.]*\)s.*/\1/p')" s
metric boot_userspace "$(printf '%s' "$BOOT_OUT" | sed -n 's/graphical.target reached after \([0-9.]*\)s.*/\1/p')" s
showsh 'systemd-analyze blame 2>/dev/null | head -5'

sec "CPU — sysbench (integer, events/s)"
for t in 1 "$NPROC"; do
    out="$(sysbench cpu --cpu-max-prime=20000 --time=15 --threads="$t" run 2>&1)"
    printf '```text\n$ sysbench cpu --cpu-max-prime=20000 --time=15 --threads=%s run\n%s\n```\n' "$t" "$out"
    metric "cpu_events_s_${t}t" "$(printf '%s' "$out" | sed -n 's/.*events per second:[[:space:]]*\([0-9.]*\).*/\1/p' | head -1)" events/s
done

sec "CPU — openssl speed (16 KiB blocks, MB/s)"
for algo in sha256 aes-256-gcm; do
    out="$(openssl speed -evp "$algo" -bytes 16384 -seconds 3 2>&1)"
    printf '```text\n$ openssl speed -evp %s -bytes 16384 -seconds 3\n%s\n```\n' "$algo" "$out"
    # "Doing sha256 for 3s on 16384 size blocks: 123456 sha256's in 3.00s" -> MB/s
    metric "openssl_${algo//-/_}_mbs" "$(printf '%s' "$out" | sed -n 's/.*: \([0-9]*\) .* in \([0-9.]*\)s$/\1 \2/p' | awk '{printf "%.0f", $1*16384/1048576/$2}')" MiB/s
done

sec "Memory — sysbench (MiB/s)"
for t in 1 "$NPROC"; do
    out="$(sysbench memory --time=10 --memory-block-size=1M --memory-total-size=200G --threads="$t" run 2>&1)"
    printf '```text\n$ sysbench memory --time=10 --memory-block-size=1M --memory-total-size=200G --threads=%s run\n%s\n```\n' "$t" "$out"
    metric "mem_mibs_${t}t" "$(printf '%s' "$out" | sed -n 's/.*(\([0-9.]*\) MiB\/sec)/\1/p' | head -1)" MiB/s
done

# fio helper: run, print, add "  name: value unit" METRIC lines for BW and IOPS.
fio_run() {
    local name="$1"; shift
    local out
    out="$(sudo -n fio --name="$name" --output-format=normal "$@" 2>&1)" || true
    printf '```text\n$ fio --name=%s %s\n%s\n```\n' "$name" "$*" "$out"
    local bw iops
    # fio prints e.g. "BW=266MiB/s" and "IOPS=68.1k" -- note it switches to k notation above
    # 10000, so the unit must survive parsing (a value-only parse silently reports 68 for 68.1k).
    bw="$(printf '%s' "$out" | grep -o -m1 -E 'BW=[0-9.]+[KMG]iB/s' | sed 's/.*=//; s|iB/s$||')"
    iops="$(printf '%s' "$out" | grep -o -m1 -iE 'IOPS=[0-9.]+[km]?' | sed 's/.*=//')"
    if [ -n "$bw" ]; then
        metric "${name}_mibs" "$(awk -v r="$bw" 'BEGIN{u=substr(r,length(r),1); v=r+0; if(u=="K")v/=1024; else if(u=="G")v*=1024; printf "%.1f", v}')" MiB/s
    fi
    if [ -n "$iops" ]; then
        metric "${name}_iops" "$(awk -v r="$iops" 'BEGIN{u=substr(r,length(r),1); v=r+0; if(u=="k"||u=="K")v*=1000; else if(u=="m"||u=="M")v*=1000000; printf "%.0f", v}')" IOPS
    fi
}

sec "Disk — fio through the filesystem ($FIOFILE, $FIO_SIZE, O_DIRECT)"
printf 'The 4K QD1 job is the metric storage-migration.md quotes; sequential is its other one.\n'
sudo -n rm -f "$FIOFILE" 2>/dev/null || rm -f "$FIOFILE"
FIO_COMMON="--ioengine=libaio --direct=1 --size=$FIO_SIZE --filename=$FIOFILE --randrepeat=0 --buffer_compress_percentage=0 --group_reporting"
# shellcheck disable=SC2086  # FIO_COMMON and RAW are option lists that must word-split.
fio_run file_seq_write_1m --rw=write      --bs=1M --iodepth=1  --time_based --runtime=10 --ramp_time=1 $FIO_COMMON
fio_run file_seq_read_1m  --rw=read       --bs=1M --iodepth=1  --time_based --runtime=10 --ramp_time=1 $FIO_COMMON
fio_run file_rand_read_4k_qd1  --rw=randread --bs=4k --iodepth=1  --time_based --runtime=15 --ramp_time=1 $FIO_COMMON
fio_run file_rand_read_4k_qd32 --rw=randread --bs=4k --iodepth=32 --time_based --runtime=10 --ramp_time=1 $FIO_COMMON
fio_run file_rand_write_4k_qd32 --rw=randwrite --bs=4k --iodepth=32 --time_based --runtime=10 --ramp_time=1 $FIO_COMMON
rm -f "$FIOFILE"
printf -- '- Free space on `/` after the file jobs: %s\n' "$(df -h --output=avail / | tail -1 | tr -d ' ')"

sec "Disk — fio on the raw partition (read-only, bypasses the filesystem)"
if sudo -n true 2>/dev/null; then
    RAW="--ioengine=libaio --direct=1 --filename=$ROOT_DEV --offset=1G --size=4G --group_reporting"
    # shellcheck disable=SC2086  # option list, must word-split
    fio_run raw_seq_read_1m --rw=read --bs=1M --iodepth=1 --time_based --runtime=8 --ramp_time=1 $RAW
    # 4K QD1 here is the same metric as the file job above, so filesystem and device can be told apart.
    fio_run raw_rand_read_4k_qd1 --rw=randread --bs=4k --iodepth=1 --time_based --runtime=8 --ramp_time=1 $RAW
    fio_run raw_rand_read_4k_qd32 --rw=randread --bs=4k --iodepth=32 --time_based --runtime=8 --ramp_time=1 $RAW
else
    printf 'skipped: `sudo -n true` failed, so %s cannot be opened.\n' "$ROOT_DEV"
fi

sec "GPU — vkmark (Vulkan; session-dependent, compare like with like)"
if command -v vkmark >/dev/null && vkmark -L >/dev/null 2>&1; then
    if [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; then
        GPU_OUT="$(timeout 90 vkmark --winsys wayland -b vertex:duration=4 -b texture:duration=4 2>&1)" \
            || GPU_OUT="$(timeout 90 vkmark -b vertex:duration=4 -b texture:duration=4 2>&1)" || true
        printf '```text\n$ vkmark --winsys wayland -b vertex:duration=4 -b texture:duration=4\n%s\n```\n' "$GPU_OUT"
        i=0
        # vkmark prints "[vertex] duration=4: FPS: 19255 FrameTime: 0.052 ms" and a summary line
        # "vkmark Score: 20913" -- FPS *before* the colon, score prefixed by the program name. A
        # naive '[0-9.]+ fps' / '^Score:' parse matches neither and silently reports no GPU
        # metrics at all, which is how the first three runs lost them.
        for fps in $(printf '%s' "$GPU_OUT" | sed -n 's/.*FPS:[[:space:]]*\([0-9.]*\).*/\1/p'); do
            i=$((i+1))
            [ "$i" -le 2 ] && metric "gpu_fps_${i}" "$fps" fps
        done
        score="$(printf '%s' "$GPU_OUT" | sed -n 's/.*Score:[[:space:]]*\([0-9.]*\).*/\1/p' | head -1)"
        [ -n "$score" ] && metric gpu_vkmark_score "$score" score
    else
        printf 'skipped: no WAYLAND_DISPLAY or DISPLAY in this shell.\n'
    fi
else
    printf 'skipped: vkmark missing or no usable Vulkan device.\n'
fi

sec "After the run"
showsh 'uptime -p; awk "{print \"load:\", \$1, \$2, \$3}" /proc/loadavg'
showsh 'df -h --output=avail / | tail -1'
printf '\nResults written to `%s` relative to the repo root.\n' "${OUT#"$REPO"/}"

# The machine-id has reached a published file in this repo twice by accident. This script prints
# hostnamectl (which carries it), so check the artifact before anyone commits it.
if [ -s /etc/machine-id ] && grep -qF "$(head -c 64 /etc/machine-id)" "$OUT" 2>/dev/null; then
    printf '\n*** WARNING: the machine-id appears in %s — do not commit it. ***\n' "$OUT"
    exit 1
fi
