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
| Intel 600p (current root, `00:01.1`, CPU slot) | 8 GT/s (3.0) | **16 GT/s (4.0)** |
| Samsung 980 PRO (`03:04.0`, chipset slot) | 16 GT/s (4.0) | **8 GT/s (3.0)** |

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

- **New NVMe → CPU M.2 slot** (`00:01.1`, 16 GT/s): Linux.
- **980 PRO stays in the chipset slot** (8 GT/s): Windows. **Windows is not moved.**
  Its install and its own ESP (`nvme0n1p3`, `Boot0000`) stay exactly where they are, so the
  two systems remain on separate disks with separate ESPs — the arrangement this machine
  insists on, after Windows and rEFInd once shared an ESP (their fossils are still in
  `nvme0n1p3`).
- **Intel 600p → retire** (38,280 h, 33.5 TB written, 13 % wear). Leave it installed and
  bootable until the new disk has booted at least once; afterwards it can serve as an
  internal `btrfs send` backup target. **Note: `/boot` currently *is* the 600p's ESP**
  (`nvme1n1p1`, `Boot0002` → `HD(1, GPT, 35e30959…)`), so retiring it without first giving
  the new disk its own ESP removes the machine's boot path.

**Cloning Windows is not part of this plan.** If it ever becomes necessary: clone
`nvme0n1` p1/p2/p3 (and p4) offline, target needs ≥ 389 GB free, and let Windows rebuild its
own boot entry with `bcdboot <target>\Windows /s <target ESP> /f UEFI` — the ESP is mandatory,
because Windows' BCD lives inside it. Note the only currently free space is on the two
spinning disks, which are a poor home for an OS.

## Physical choreography (verified 2026-10-06)

Both M.2 slots are occupied, so one has to be freed before the new drive can go in. This order
is safe because **nothing on the Windows disk is in use** and **the whole boot chain is
UUID-based** — both checked on the machine rather than assumed:

- `nvme0n1` has no mounted partition, and the only swap is `/dev/zram0`, so that drive can be
  absent without affecting the running system.
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

## Steps

0. **Backup first.** `sda3` is an empty 5.5 TB btrfs — a ready-made target for `btrfs send`
   snapshots of the current root. Also take a manual snapper snapshot
   (`sudo snapper -c root create -d "pre: OS migration"`).
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
  `FSCK0000.REC`–`FSCK0005.REC` and epoch/1979 timestamps — lost-and-found fragments from a past
  `fsck` on this filesystem — plus an unexplained `c918fefaab2e4235b68284d69c2545b1` directory
  beside `amd-ucode.img`, `EFI/limine/` and `limine.conf{,.old}`. Since the migration builds a
  fresh ESP anyway, do the `fsck.vfat` and work out what that directory is *before* depending
  on the old one as the fallback. Re-run `scripts/hardware-check.sh` at migration time rather
  than trusting today's numbers — disk UUIDs, device order and wear figures will all have moved.
