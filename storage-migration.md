# Migrating this OS to a new NVMe — plan and runbook

**Status: plan only. Nothing here has been executed.** Written 2026-10-06 while choosing a
disk; a drive was ordered the same day and execution is deferred to a later date. Nothing
below has been started, and nothing needs to be until the drive arrives. The hardware facts it rests on are in [hardware-check.md](hardware-check.md) and
[system-inventory.md](system-inventory.md), both machine-verified.

## The decision

Buy the **Samsung 9100 PRO** (1 TB or 2 TB) if it is priced at or below a 990 PRO of the same
capacity — at the time of writing it was $40 *cheaper*, which settles it. On this board the
choice barely matters for speed, because **B550 + Zen 3 tops out at PCIe 4.0**:

| Disk | Card supports | Slot max (root port `LnkCap`) |
| --- | --- | --- |
| Intel 600p (current root, `01:00.0`, CPU slot) | 8 GT/s (3.0) | **16 GT/s (4.0)** |
| Samsung 980 PRO (`04:00.0`, chipset slot) | 16 GT/s (4.0) | **8 GT/s (3.0)** |

So a Gen5 drive trains down to 4.0 x4 (≈7 GB/s, against its rated 14,700 MB/s), and at 4.0 x4
a 980 PRO — itself a 4.0 x4 drive of the same class — is link-limited to roughly the same
sequential speed. What the 9100 PRO still buys: much higher high-queue-depth random IOPS,
a 5 nm controller that runs cooler, and 5.0 headroom if this machine ever moves to AM5.
Buy the **heatsink-less (3.88 mm)** SKU if the board's M.2 thermal guard will be fitted; the
with-heatsink SKU is 8.88 mm and will not fit under it.

Not a reason to buy: raw speed on its own. Measured, the current root does 78.7 MB/s at 4K
QD1 and 1.2 GB/s sequential, against 253 MB/s and 2.2 GB/s for the 980 PRO — the latter *on a
3.0 link*. The real wins of replacing the root disk are space (41 GB free on a 256 GB root at
83 %) and getting off a 38,280-hour, 33.5 TB-written drive.

## Target layout

- **New NVMe → CPU M.2 slot** (the 16 GT/s root port; identify it by capability, not by the
  address below, which changes with the device): Linux.
- **980 PRO stays in the chipset slot** (8 GT/s): Windows. **Windows is not moved.**
  Its install and its own ESP (`nvme1n1p3`, `Boot0000`) stay exactly where they are, so the
  two systems remain on separate disks with separate ESPs — the arrangement this machine
  insists on, after Windows and rEFInd once shared an ESP (their fossils are still in the
  Windows ESP, `nvme1n1p3`).

  **2026-10-11: Windows is effectively abandoned on this machine** (the owner's words: "good
  riddance"), so nothing below needs the space kept for it. The layout rules still hold — separate
  ESPs are worth having regardless — but the *reason* shifts from "Windows must keep booting" to
  "do not let one system's bootloader update clobber the other's boot path". Practical effect: the
  ~488 GiB of `p1`+`p2`+`p4` becomes reclaimable **at leisure**, and nothing has been deleted. Note
  the Windows partitions are not even readable from this Linux — `ntfsresize`/`ntfs-3g` are not
  installed and the kernel has no `ntfs3` — so anything wanted from `C:` needs either a Windows
  boot or `ntfs-3g` installed first.
- **Intel 600p → retire** (38,280 h, 33.5 TB written, 13 % wear). Leave it installed and
  bootable until the new disk has booted at least once; afterwards it can serve as an
  internal `btrfs send` backup target. **Note: `/boot` currently *is* the 600p's ESP**
  (`nvme0n1p1`, `Boot0002` → `HD(1, GPT, 35e30959…)`), so retiring it without first giving
  the new disk its own ESP removes the machine's boot path. (This node was `nvme1n1p1` when
  written — the enumeration has swapped since; see the 2026-10-10 note below and identify
  disks by model or PARTUUID, never by `/dev/nvmeXnY`.)

**Cloning Windows is not part of this plan.** If it ever becomes necessary: clone
`nvme1n1` p1/p2/p3 (and p4) offline, target needs ≥ 389 GB free, and let Windows rebuild its
own boot entry with `bcdboot <target>\Windows /s <target ESP> /f UEFI` — the ESP is mandatory,
because Windows' BCD lives inside it. Note the only currently free space is on the two
spinning disks, which are a poor home for an OS.

## Physical choreography (verified 2026-10-06)

Both M.2 slots are occupied, so one has to be freed before the new drive can go in. This order
is safe because **nothing on the Windows disk is in use** and **the whole boot chain is
UUID-based** — both checked on the machine rather than assumed:

- The **980 PRO** (the Samsung 1 TB whose `p3` is PARTUUID `222670bc-…`) has no mounted
  partition, and the only swap is
  `/dev/zram0`, so that drive can be absent without affecting the running system. As of
  2026-10-10 that drive is `nvme1n1` — but it was `nvme0n1` when this was written, and today
  `nvme0n1` is the *live root*, so the node here was not merely stale, it was inverted.
  **Do not pull a drive on the strength of a device node in this document.** Verify first:
  the drive to pull is the one whose `p3` has PARTUUID `222670bc-076c-4994-9ec0-90ed9c7354fb`
  (Windows' ESP = `Boot0000`); the drive to keep is the one whose `p1` is
  `35e30959-a6e8-4319-8e32-1e98a48d4de0` (`/boot`, `Boot0002`) and whose `p2` holds
  `UUID=6ed46d55-71f2-47a0-9ee9-b8bf035d8c88` (`/`).
- The kernel command line reads `root=UUID=6ed46d55-…` with `rootflags=subvol=/@`,
  `/etc/fstab` is entirely by UUID (including `/boot` = `UUID=B26C-249B`), and the generated
  `limine.conf` cmdlines are by UUID too. Device renaming — which is exactly what pulling a
  drive or moving cards between slots causes — cannot break any of them.

1. **Power off.** Pull the **980 PRO** (Windows), fit the **new NVMe into the freed chipset
   slot**, and boot Linux from the 600p as usual. The new drive will run at 3.0 x4 during the
   copy, which does not matter: the source disk is the bottleneck. A stale `Boot0000` pointing
   at the absent Windows ESP is harmless — `BootOrder` tries `0002` (Limine) first.
2. Migrate onto the new drive (steps below); verify it boots and runs.
3. **Power off.** Move the **new NVMe to the CPU/4.0 slot**, refit the **980 PRO in the chipset
   slot**, remove the **600p**, boot, and confirm `LnkSta: 16GT/s`.
4. Only then retire the 600p fully: it *is* the machine's original boot path, so keep it in a
   drawer (or as a `btrfs send` target) until step 3 has booted a few times.

Pulling the Windows drive also removes the "do not write to a hibernated Windows volume"
hazard from the whole operation, which is worth having on its own.

### Rollback is a boot-menu entry, not a restore

`/boot/limine.conf` already carries generated *snapshot* entries — for example
`rootflags=subvol=/@/.snapshots/165/snapshot` for the snapshot taken during the shim
housekeeping earlier the same day. `limine-snapper-sync` regenerates them, so **take a manual
snapshot immediately before migrating and the pre-migration state becomes a bootable entry in
the Limine menu**:

```bash
sudo snapper -c root create -d "pre: OS migration to new NVMe"
```

That is a stronger safety net than any file-level restore, and it costs nothing.

## Re-verified 2026-10-10 — the enumeration has swapped, and three corrections

Everything above was written 2026-10-06. On 2026-10-10 it was re-checked against the live
machine, and **the device nodes and PCI addresses have since swapped.** The *instructions*
above were written by model name and are still correct; the *nodes* were not, which is exactly
the failure mode this document warns about one paragraph earlier.

| Drive | Identify it by | Node now | Node on 2026-10-06 | PCI now | Role |
| --- | --- | --- | --- | --- | --- |
| Intel 600p (`SSDPEKKW256G7`, 238.5 GiB) | `p1` = PARTUUID `35e30959-a6e8-4319-8e32-1e98a48d4de0` (`Boot0002`, `/boot`) | `nvme0n1` | `nvme1n1` | `01:00.0` | **live root** + `/boot` |
| Samsung 980 PRO (1 TB) | `p3` = PARTUUID `222670bc-076c-4994-9ec0-90ed9c7354fb` (`Boot0000`, Windows ESP) | `nvme1n1` | `nvme0n1` | `04:00.0` | Windows (not moved) |

Slot assignment is unchanged from the table above and was re-confirmed: the 600p sits on a
4.0-capable port (a 3.0 drive, so no downgrade shows), and the 980 PRO reports
`LnkSta: 8GT/s (downgraded)` against a 4.0-capable card — i.e. still behind the 3.0 chipset
port. So **the choreography order still holds**: pulling the Windows drive frees the chipset
slot, and the new disk lives there during the copy before moving to the CPU slot at the end.

**Rule for migration day: identify every drive by model, serial or PARTUUID. Never by
`/dev/nvmeXnY`, and never by PCI address.** Device order follows slot probing and moves when
drives move; PARTUUIDs do not.

### Three corrections

1. **`FSCK0000`–`FSCK0383` is 384 fragments, not six**, and the "unexplained" directory is
   Limine's kernel staging area (see the resolved trap above). Neither is a reason to distrust
   the old ESP as a fallback; the directory is load-bearing.
2. **There is a third btrfs filesystem, on the Windows disk.** `nvme1n1p5` (443 GiB, PARTUUID
   `53194683-33b7-4512-b89c-94501ec22746`, UUID `90c6cfd1-8c68-447c-8597-552f126d16ae`, 97 GiB
   used) is btrfs and is **not referenced by `/etc/fstab`, by any mount unit, or by any snapper
   config** — it is unmounted, and it is *not* in the `sda3` premigration backup, which captured
   only the 600p's `@ @root @home @srv`. Pulling the 980 PRO takes it offline for the whole
   migration, so anything wanted on it has to be copied first.

   Identified 2026-10-11 by mounting it **read-only** (subvolid=5 exposes the top level, so the
   subvolume layout is visible):

   ```bash
   sudo mkdir -p /mnt/nvme1n1p5-inspect
   sudo mount -o ro,subvolid=5 /dev/nvme1n1p5 /mnt/nvme1n1p5-inspect
   # ... inspect ...
   sudo umount /mnt/nvme1n1p5-inspect
   ```

   It is an **abandoned CachyOS install**: the same `@ @home @root @srv @cache @tmp @log` layout
   as this machine, `@/etc/os-release` = CachyOS, filesystem created 2024-09-30, last written
   around 2025-04-28, and holding **a different machine-id** — so it is not this machine's
   current install. 75 GiB is the OS, 25 GiB is one user's home, 6 GiB is cache, 45 MiB logs. Of
   that home, 16.3 GiB of the 17 GiB `Downloads` is two Linux ISOs plus duplicate-finder
   tooling, i.e. disposable.

   **But the same directory holds a small number of personal documents belonging to a named
   individual** (employment and identity paperwork). So: **do not reformat, resize or repurpose
   this partition until those have been reviewed and deliberately dealt with.** Nothing on it is
   needed to run this machine; once it has been triaged, p5 is 443 GiB of reclaimable space on
   the Windows disk.

   **Why it was abandoned** (the machine's owner, 2026-10-11): Windows made the install
   unreachable and retrieving it was not worth the effort. Note precisely what that does and does
   not mean — the partition and all 97 GiB are **intact**, mounting cleanly read-only with no
   errors, so what was lost was the *boot path*, not the data. This is the same hazard the Traps
   section warns about, seen from the other side: a Windows-side change is exactly what makes a
   Linux install vanish from the menu, and it is the concrete reason the two systems keep
   separate ESPs on this machine. It also means reviving it would be a boot-entry exercise rather
   than a data-recovery one.

   **Destroyed 2026-10-11**, after a verified rescue of the personal documents — a copy now exists
   on `/` at `~/Documents/rescued-nvme1n1p5-2026-10-11/` (23 111 files, 2.7 GiB, every file
   checksum-verified against the source *before* anything was written). The filesystem signature
   was removed with `wipefs -a` and the whole 443 GiB discarded with `blkdiscard`, so the btrfs
   magic is gone and the blocks are unmapped at the drive. `p5` is now a **RAW, empty, 443 GiB
   partition** — no filesystem, no signature — and the partition table was deliberately not
   touched, so the Windows partitions were never at risk.

   What to put on it is an open decision: NTFS for a Windows data volume, or btrfs for Linux
   scratch. Note it is **not adjacent to the Windows C: partition** — p1 through p5 are separated
   by the recovery, ESP and MSR partitions — so the space cannot simply be folded back into C:
   without moving those three, and p3 is the Windows ESP.
3. **The "rollback is a boot-menu entry" safety net does not survive a fresh install.** It
   rests on `limine-snapper-sync` generating one entry per snapper snapshot (hence the 94 KiB
   `limine.conf`), and those entries name subvolumes of the *current* btrfs
   (`rootflags=subvol=/@/.snapshots/NN/snapshot`). On a new filesystem those subvolumes do not
   exist. The net is real for the clone route above; for the fresh-install alternative the
   fallback is the old disk remaining bootable, plus the `sda3` copy — not the boot menu.

## Pre-migration inventory — the acceptance test for a fresh install

`scripts/premigration-inventory.sh` (read-only, ~33 s) dumps what this machine *is*: explicit and
foreign packages, non-pacman installs, every file under `/etc` that **no package owns**, unowned
`/usr/local` and `~/.local/bin` files, enabled units and timers in both scopes, fstab and kernel
cmdline, the UEFI and Limine boot chain, blkid and the btrfs subvolume layout, snapper config, pam
and polkit files, the `~/.config` checklist, and the repositories.

It exists to be **diffed**, and that diff is what makes the fresh-install route safe rather than
hopeful: run it here first, run it again on the rebuilt system, and read the difference as a
checklist. Anything present here and absent there is an undocumented gap — found while the old disk
is still attached and bootable. The script prints the exact diff command, and lists which
differences are expected noise (package versions, device nodes, timestamps) versus which are real
gaps. It is worth running regardless of which route is chosen.

| copy | where | why |
| --- | --- | --- |
| full | `~/Documents/premigration-inventory-<date>.txt.gz` | stays on the machine; the reference |
| redacted | `inventories/premigration-inventory-<date>.redacted.txt.gz` | this repo is published |

The redaction rule set is the one documented in `scripts/hardware-check.sh`, and the script
self-tests it against synthetic input on every run, exiting non-zero if a rule fails. That
self-test is not decoration — it is what found the redaction leak recorded in the 2026-10-11 entry
of `customizations.md`.

## `/scratch` on the 980 PRO — what the 443 GiB becomes (decided 2026-10-11)

`nvme1n1p5` (443 GiB, emptied earlier the same day) is **not** going back to Windows. The decision:
Windows is effectively abandoned here, so the space becomes **Linux scratch for job runs**
(OpenROAD-class flows were the motivating case). **No partition was moved and none needs to be** —
this is `mkfs` plus one fstab line, which is the entire reason it beat growing `C:`.

Why not grow `C:`, recorded so it is not re-opened: `p1` is followed *immediately* by `p2`
(recovery), with only 2 048 sectors free between `p2` and `p3`, and the 443 GiB sits at the **tail**
of the disk behind `p2`/`p3`/`p4`. Extend Volume therefore needs three partitions moved **offline**,
and the risky one is the **ESP** — `Boot0000` resolves Windows as `HD(3,GPT,222670bc-…)`. This Linux
could not have done it anyway: no `ntfsresize`, no `ntfs-3g`, no kernel `ntfs3`.

### Why scratch is worth having here specifically

- **`/tmp` is tmpfs** on this machine, so a large flow writing intermediates there is spending
  **RAM**. That is the concrete problem this fixes.
- **Snapper's root config is `SUBVOLUME="/"`**, so job output under `/` lands in snapshot scope. A
  separate volume is invisible to snapper *and* to the `@ @root @home @srv` backup — which is
  correct for disposable data.
- **A separate partition bounds a runaway job** at 443 GiB, rather than filling the pool the OS
  lives in.
- `sda3` is 5.5 TB of btrfs and 97 % empty, but it is a **spinning** disk: good for capacity, poor
  for this I/O. Scratch wants NVMe. (The 980 PRO is the *slower* of the two NVMe options — chipset
  slot, 3.0 x4, `LnkSta: 8GT/s (downgraded)` — which is the right way round: fast slot for the OS.)

### Format and mount — migration day, not before

Deliberately **not** the recipe the rest of `/etc/fstab` uses. `compress=zstd:1` is wrong for
write-churn scratch: compression and CoW on constantly-rewritten temp files cost CPU and fragment
for no benefit.

```bash
# either — xfs is the simpler fit for pure churn; btrfs keeps one filesystem family
mkfs.xfs -L scratch /dev/nvme1n1p5
# mkfs.btrfs -L scratch /dev/nvme1n1p5      # then, after mounting: chattr +C /scratch
```

```fstab
# UUID from `blkid /dev/nvme1n1p5`; nofail is NOT optional (see below)
UUID=<p5-uuid> /scratch xfs defaults,noatime,nofail,x-systemd.device-timeout=5 0 0
```

**`nofail` is mandatory**, not tidiness: the choreography above **removes the 980 PRO from the
machine**, and every existing fstab entry on this system is mandatory. A mandatory entry for an
absent disk is how you get an emergency shell instead of a boot. Either add this line *after* the
hardware is settled, or write it with `nofail` from the start.

Permissions, or the jobs cannot write: `chmod 1777 /scratch` (as `/tmp`), or a setgid group. Then
point runs at it — `TMPDIR=/scratch/$USER/…` plus the flow's own output/scratch setting. If a flow
insists on writing beside the design, **bind-mount** rather than symlink into the build tree.
Anything containerised needs the path bind-mounted in *and* permissions matching the container
UID — the usual "job cannot write to scratch" failure.

**Standing rule: nothing irreplaceable in `/scratch`.** It sits on the disk that already ate one
Linux install, so it is expendable by design. Decline if Windows ever offers to format it.

## Steps

0. **Backup first.** `sda3` is an empty 5.5 TB btrfs — a ready-made target for `btrfs send`
   snapshots of the current root. Also take a manual snapper snapshot
   (`sudo snapper -c root create -d "pre: OS migration"`).
   **Done 2026-10-07:** snapper **166**, and `scripts/premigration-backup.sh` →
   `/mnt/premigration/root-2026-10-07/` on `sda3` (135.73 GiB; `@ @root @home @srv`, caches
   excluded). Re-run it on migration day if much has changed — it is a full stream, not
   incremental, so it sends another complete copy rather than a delta.
1. **Prepare the new disk:** GPT with `p1` = 1 GiB vfat (ESP, mounted `/boot`) and `p2` = the
   remainder, btrfs.
2. **Create the filesystem and subvolume layout** to match the current root:
   `@ @root @home @srv @cache @log @tmp`.
3. **Copy the filesystem:** `btrfs send` each subvolume read-only and `btrfs receive` it on
   the new disk. This preserves everything — the repo, configs, caches — without a reinstall.
4. **Bootloader:** install Limine into the **new ESP** and add a UEFI entry for it; update the
   local override `/etc/pacman.d/hooks/90-mkinitcpio-install.hook` if it references the old
   ESP. Remember the boot-safety guard at `/usr/local/bin/mkinitcpio`: regenerate with
   `limine-mkinitcpio` or `limine-update`, never a bare `mkinitcpio -P`.
5. **`/etc/fstab`:** point at the new root UUID. Use UUIDs, not device names — moving cards
   between M.2 slots renames `nvme0`/`nvme1`.
6. **snapper:** repoint the `root` config at the new filesystem/subvolume (and its
   `.snapshots`), then confirm a pre/post pair is still created on a test pacman transaction.
7. **First boot from the new disk**, leaving the old entry in `BootOrder` as the fallback.

*Alternative, if migration feels like too much:* install CachyOS fresh on the new disk and
rebuild from this repo. That is precisely why the repo exists — but the migration is less
work than it sounds, and nothing here is destructive until step 5.

## Acceptance tests

- `sudo lspci -vv -s <new device> | grep LnkSta` → **16 GT/s**. 8 GT/s means the drive is in
  the chipset slot, not the CPU slot.
- `findmnt -no SOURCE /` shows the new partition, with the same mount options.
- `scripts/hardware-check.sh` re-run lists the new disk and the new topology.
- A heavy build and a `systemd-analyze` comparison; zram/swap unchanged.
- Rollback: boot the old 600p entry (still present in `BootOrder`), then revert `fstab` and
  the hook.

## Traps

- `/boot` is the old ESP — see above. This is the step that bricks a machine if skipped.
- `md127` (`sdb3`, 3 TB Hitachi) is a **degraded RAID-1** carrying legacy DiskStation
  metadata, unmounted and unrelated to this migration — but do not let a `btrfs send` target
  land on it by accident.
- Windows and Linux must not end up sharing an ESP. Their current separation is deliberate.
- The ESP being replaced is **not healthy**: `/boot` (4 GiB vfat, mode 700) carries
  **384** `FSCK0000.REC`–`FSCK0383.REC` fragments with epoch/1979 timestamps — lost-and-found
  remains from a past `fsck` (trivial in size, 1.5 MiB total) — beside `amd-ucode.img`,
  `EFI/limine/` and `limine.conf{,.old}`. The directory that was flagged here as unexplained
  is now identified: `/boot/c918fefaab2e4235b68284d69c2545b1/` is **Limine's own kernel staging
  area**, holding per-kernel `vmlinuz` + `initramfs` plus `limine_history/snapshots.json`. It is
  1.9 GiB — essentially all of the ESP's usage — and is written by `limine-mkinitcpio-hook`
  (`limine-mkinitcpio-install`). It is **load-bearing, not debris**: do not "clean" it, and
  expect a fresh ESP to be rebuilt with the same shape rather than copied. Re-run
  `scripts/hardware-check.sh` at migration time rather than trusting today's numbers — disk
  UUIDs, device order and wear figures will all have moved.
