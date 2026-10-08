# System Inventory

Facts about this machine gathered while diagnosing problems. Everything here was
observed directly, not assumed. Dates note when each fact was verified, since
package state drifts.

## Hardware

Verified 2026-08-31:

- Chassis: desktop
- Vendor: Gigabyte Technology Co., Ltd.
- Model: B550 AORUS ELITE AX V2
- No LUKS or encrypted volumes; `/etc/crypttab` is empty

Verified 2026-09-01, while debugging Chrome Canary:

- GPU: NVIDIA RTX 3060, driver library `libnvidia-glcore.so.610.57.04`
- The NVIDIA driver, Vulkan, and OpenGL stack all verified working
  independently. See [chrome-fixes.md](chrome-fixes.md).

Verified 2026-10-06 by [hardware-check.md](hardware-check.md) — regenerate with
`scripts/hardware-check.sh` (read-only, 13 sections, ~3 s):

- CPU: AMD Ryzen 9 5900X, 12 cores / 24 threads, AM4, microcode current.
- Memory: 2 × 16 GiB DDR4-3600, part **`CMK32GX4M2D3600C18`** (Corsair Vengeance LPX 2×16 kit),
  in `DIMM 1` of both `P0 CHANNEL A` and `B` — dual-channel, XMP applied (running at
  3600 MT/s). Four slots, 128 GiB ceiling, two free.
- BIOS: AMI `FId`, dated 2026-08-18.
- Secure Boot: **disabled** (`SecureBoot` efivar = 0; `mokutil` is not installed, so this is
  read from the efivar directly).
- Display: a single 3440×1440 @ 59.97 Hz panel on HDMI at scale 1 — this is the "this
  display" referred to in [text-rendering-quality-tools.md](text-rendering-quality-tools.md).
- Storage: root is `nvme1n1`, an **INTEL SSDPEKKW256G7** (238.5 GB) with 33.5 TB written,
  38,280 power-on hours and 13% rated wear; `/boot` is `nvme1n1p1` (vfat) and everything else
  lives on `nvme1n1p2` (btrfs, `noatime,compress=zstd:1,discard=async`) in the subvolumes
  `@ @root @home @srv @cache @log @tmp`. `nvme0n1` is a **Samsung 980 PRO 1 TB** (1,981 h, 3%
  wear) holding a Windows install (487 GB NTFS plus its EFI/recovery partitions) and an
  **unmounted** 443 GB btrfs partition. SATA disks: `sda` 12 TB IronWolf (5.5 TB NTFS +
  5.5 TB btrfs), and `sdb` 3 TB Hitachi carrying a **degraded RAID-1** — `/dev/md127`,
  `[2/1] [U_]`, one member missing, active auto-read-only and not mounted, so no live data
  depends on it.
- Network: Realtek RTL8125 2.5 GbE and an RTL8852CE 802.11ax adapter. Audio: AMD
  Starship/Matisse HD Audio plus the RTX 3060's HDMI audio.
- Sensors expose **no fan RPMs** on any chip; CPU `Tctl` reads ~73 °C at idle.

## Session

- Distribution: CachyOS, originally installed from the Hyprland edition
- Hostname: `cachyos-x8664`
- Kernel family: Linux 7.2.x
- Session type: Wayland; `/usr/share/xsessions/` is empty
- Display manager: greetd with the noctalia greeter
- Desktops installed side by side: Plasma 6.7.4, GNOME, Hyprland, plus a COSMIC
  portal backend

## Accounts and privileges

Verified 2026-08-31:

```text
groups: mylesp sys network docker nopasswdlogin rfkill users video storage lp audio wheel
```

sudoers:

```text
%wheel ALL=(ALL) ALL
mylesp ALL=(ALL) NOPASSWD: ALL
```

`/etc/polkit-1/rules.d/` was empty until the passwordless polkit rule was added.
See [passwordless-login.md](passwordless-login.md).

## Package repositories

Sync databases present in `/var/lib/pacman/sync/`:

```text
cachyos-core-v3.db
cachyos.db
cachyos-extra-v3.db
cachyos-v3.db
chaotic-aur.db
core.db
extra.db
multilib.db
```

The `-v3` databases mean this install uses the x86-64-v3 optimized CachyOS
package set. `chaotic-aur` is configured, so many AUR packages are available as
binaries.

No AUR helper is installed: neither `yay` nor `paru` was found on 2026-08-29.
`docker` is installed and the user is in the `docker` group.

`checkupdates` from `pacman-contrib` is available.

## Snapshots

Snapper is configured and takes automatic pre- and post-transaction snapshots on
pacman operations. The `plasma-meta` install on 2026-08-31 produced snapshot
`root: 60`. Snapper snapshots are the rollback path for package-level changes.

## Local files outside package management

Three files live in `/usr/local/bin` — which precedes `/usr/bin` in PATH, so all three
shadow or wrap system commands — and **no package owns any of them**. Nothing tracked them
before the 2026-10-06 review. They are listed here because an unowned shim has no
lifecycle: pacman will not update it, will not notice when it becomes obsolete, and will
not mention it if its behaviour quietly changes.

```text
/usr/local/bin/mkinitcpio        Limine boot-safety guard (keep)
/usr/local/bin/remove-nvidia     legacy name; clears VM guest packages (no-op today)
/usr/local/bin/MarkdownBlaze     wrapper for the MarkdownBlaze package (expires)
```

- **`mkinitcpio`** — runs the real `/usr/bin/mkinitcpio "$@"`, then for `-P`, `-p`,
  `--allpresets` or `--preset` warns that this does **not** update Limine boot entries and
  offers to run `limine-mkinitcpio` instead. Load-bearing on this machine: it boots with
  Limine and its initramfs hook is the local override
  `/etc/pacman.d/hooks/90-mkinitcpio-install.hook -> limine-mkinitcpio-install`, so a bare
  `mkinitcpio -P` regenerates images but can leave a new kernel unbootable. The pacman
  hooks call `/usr/share/libalpm/scripts/...` by absolute path and never pass through this
  shim, so it only ever catches a human. With no tty the prompt reads EOF, which matches
  the empty-answer case and therefore runs `limine-mkinitcpio` automatically.
- **`remove-nvidia`** — the name is a legacy misnomer: the file clears **VM guest**
  packages (virtualbox-guest-utils{,-nox}, open-vm-tools, qemu-guest-agent, plus the vmware
  autostart file) when the machine is not itself a VM. It touches no NVIDIA package. It is
  a **no-op today** (`systemd-detect-virt` = none; none of those packages installed), no
  other copy exists on disk, and nothing references it by name. Left in place rather than
  renamed or deleted because the intent behind the name is recorded nowhere — settle that,
  then rename or drop it.
- **`MarkdownBlaze`** — see [standard-tools.md](standard-tools.md). It sets
  `WEBKIT_DISABLE_DMABUF_RENDERER=1`, without which the app never renders on this NVIDIA
  Wayland box (Gdk Error 71, 0 `mdSetDocumentTitle` lines in its log). **This one expires:**
  re-test after a `webkit2gtk-4.1` upgrade by running `/usr/bin/MarkdownBlaze <file.md>`
  directly — if a document renders, delete the wrapper.

Snapper does **not** guard this directory automatically: `/usr/local` is part of `/` (not
its own subvolume) but nothing snapshots a hand edit. Take one before changing these files:

```bash
sudo snapper -c root create -d "pre: <what you are about to do>"
```

## Operational notes

- Pacman is the preferred package manager. Use it directly for system and
  repository packages; do not introduce an AUR helper or GUI package manager
  for ordinary installs unless there is a documented need.
- Always use `pacman -Syu` rather than a bare `pacman -S`. Arch and CachyOS do
  not support partial upgrades, and installing against a stale database risks
  breaking the system.
- If `pacman` reports `unable to lock database`, check for a running package
  manager with `pgrep -a -f 'pacman|pamac|paru|yay|octopi|discover|packagekit'`
  before touching `/var/lib/pacman/db.lck`. Removing the lock while another
  transaction is live corrupts state.
- Do not restart `greetd` to test a configuration change; it kills the active
  graphical session. Reboot instead.
- Do not enable `sddm` or `gdm`. Both are installed but deliberately disabled.
- Beware `pkill -f <pattern>`: the invoking `bash -c` wrapper's own command
  line can match the pattern and kill the calling shell. Kill by exact name
  (`pkill -9 -x <comm>`) or by PID. See
  [shell-startup-quirks.md](shell-startup-quirks.md).
