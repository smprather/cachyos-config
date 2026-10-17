# Benchmark runs — before and after the rebuild

`scripts/system-benchmark.sh <label>` writes `benchmarks/<date>-<label>.txt`; further runs that
day become `-run2`, `-run3`, and nothing is overwritten. `--average` prints mean, median, min,
max and spread across run files, `--diff` compares two runs (averaged ones included). The suite,
its exact commands and the reason for each metric live in the script's header; this file records
which run is which and what the numbers can bear.

| Artifact | What it is |
|---|---|
| `2026-10-17-before.txt`, `-run2` … `-run6` | six runs on the current install: CachyOS (Hyprland edition, Plasma and GNOME layered on top), root on the 38,280-hour Intel 600p, btrfs `compress=zstd:1`. Runs 1–3 predate the vkmark parse fix, so the GPU metrics have n=3 while everything else has n=6 |
| `2026-10-17-before-avg.txt` | those six averaged — the file to diff an "after" average against |
| `2026-10-17-disk-control.txt` | one-off control run on the 980 PRO proving the "4K QD1" figures in `storage-migration.md` are mislabeled |

## What repeats, and what does not

From the six before-runs (spread = max−min over min):

- **Repeats to ≤ 1 %:** boot time, 24-thread CPU and memory, both openssl numbers, sequential read.
- **1–5 %:** single-thread CPU, 4 KB QD1 reads, raw 4 KB QD32, filesystem 4 KB QD32. The GPU score
  is within 8.5 % (n=3), but one run came in 14 % low on the texture scene.
- **5–10 %:** single-thread memory, sequential write.
- **Do not trust a single run:** `file_rand_write_4k_qd32` (24.0–83.9 MiB/s, **250 %** spread —
  median 34.6 against a mean of 41.9) and `raw_seq_read_1m` (620–892 MiB/s, 44 %). On the near-full
  old btrfs, random 4K writes are dominated by allocation and GC state; the raw sequential read
  wanders with the drive's own background work. Quote the **median**: adding a sixth run slid the
  4K-write mean by 8 % while its median barely moved.

One comparability caveat that matters for the rebuild: **the before-runs were taken with `/home` at
89–90 % full** (208 GB used of 235 GB), and the after-runs will be on a nearly-empty new disk. The
filesystem jobs are space-sensitive — that is part of why 4K random write swings 250 % — so a
better-looking after-number for `file_*` should be treated as unproven until the `raw_*` jobs agree:
those measure the drive itself, not how full it is, and they are the ones that can show the 9100 PRO
actually being faster than the 38,280-hour 600p.

Runs 1–3 were taken before the vkmark parser was fixed (`FPS: N` and `vkmark Score: N` were not
being read), so the GPU metrics average over three samples. `--average` counts per metric, so
every other number averages over six.

The suite prints load average, power profile and governor, and whether a compositor was up — a
run taken while something else was busy is not comparable to a quiet one. These three were taken
on a live desktop (load ~2), so a clean re-run immediately before the wipe is worth having.

Add a row per run set, and keep the pairs honest: the after-runs must use the same suite version,
the same session state as far as possible, and the same three-run-then-average discipline.

## The reboot loop — boot time, and the faults a loop exposes

`scripts/boot-capture.sh` is installed as `/usr/local/bin/boot-capture.sh` and fired by
`boot-capture.timer` 90 s after every boot, so the loop needs no manual step per boot: reboot, wait
~2 min, repeat. One detail file and one deduplicated TSV row per boot land in `/var/lib/boot-loop/`,
and `sudo /usr/local/bin/boot-capture.sh --report` summarises the whole loop: a per-boot table,
min/median/mean/max with spread for total, userspace and desktop-ready time, an anomalies list,
enumeration stability, and any journal boot with no capture at all (one that never got 90 s in).

What it watches is listed in the script header. Two definitions there took calibration and are worth
knowing, because both are surprising:

- **There is no clean-shutdown marker to look for.** `systemd-shutdown` / `Reached target Power-Off`
  appear **zero** times across the last three boots — all of which were ordinary reboots — because
  journald stops before they are written. So the previous boot is classified `orderly` (a shutdown
  phase is present: stopping/unmounting lines) or `abrupt` (the journal simply stops mid-activity,
  which is what a hang or a power cut looks like), and `Failed unmounting` is counted separately.
  A completion marker is not a signal on this machine.
- **Boot total = firmware + loader + kernel + initrd + userspace**, and here the firmware/loader half
  is the *bigger* half (12.6 s of 30.1 s on 2026-10-17). A fresh install cannot change firmware, so
  compare `userspace` and `desktop ready` when asking what a rebuild actually bought.

Installed 2026-10-17 for the pre-rebuild loop; it is temporary, and its install/undo commands are in
that date's `customizations.md` entry. Do not carry it to the new install unless the loop is being
run again — a capture unit nobody reads is just another thing to keep alive.

One baseline fact to read every report with: **every boot on this machine reports `degraded`**, because
`mdmonitor.service` fails with `mdadm: No mail address or alert command - not monitoring.` —
`/etc/mdadm.conf` ships with `#MAILADDR` commented out, so `mdadm --monitor --scan` exits 1 every boot.
It is a configuration gap, not a boot defect. Close it (or mask the unit) before reading `degraded` as
a signal, because until then a genuinely degraded boot looks exactly the same.
