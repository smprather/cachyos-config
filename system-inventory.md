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
`scripts/hardware-check.sh` (read-only, 14 sections, ~3 s):

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

Peripherals the machine cannot name (verified 2026-10-17; **supplied by hand** — no
`lsusb` or `lspci` entry identifies them):

- **KVM dock: AV Access iDock P10** — a 2-PC, dual-monitor USB-C KVM docking station (GbE,
  EDID emulation, 65 W PD, 5× USB-A, SD card, remote switch, 4K@60 Hz over HDMI and
  DisplayPort). This machine sees only its silicon: three Genesys Logic hubs (`05e3:0610`,
  `05e3:0626`) and two QinHeng serial bridges (`1a86:e229` "WCH UART TO KB-MS_V1.8" and
  `1a86:7523` CH340) that carry the one keyboard and mouse across the two PCs. Two
  consequences, both observed rather than inferred from the dock's spec sheet:
  - The display now negotiates **3440×1440 @ 59.97 Hz** with `Vrr: incapable` and
    `Brightness control: unsupported`, where a direct connection reported 3440×1440 @ 120 Hz
    with both supported. The KVM's emulated EDID caps the link.
  - Switching KVM inputs tears the NVIDIA HDMI audio device down and re-adds it. That is the
    recurring `spa.alsa: … poll fd error/hangup (card removed?)` in the journal, and the reason
    KDE's volume applet holds a dead node (`No object for name "…hdmi-stereo" returning
    nullptr`). The "Audio/PipeWire path" candidate in
    [plasmashell-wedge.md](plasmashell-wedge.md) is this, not a plasmashell defect.
- Monitor: **Dell S3425DW** (3440×1440, 2 × 5 W speakers). Its speakers are this machine's only
  connected audio output — every analog jack on the ALC897 reports nothing plugged in, so the
  onboard card idles on its S/PDIF profile and WirePlumber defaults to the monitor over HDMI.
- Keyboard (`28e9:30ad`), mouse (`2516:0141`) and webcam (`046d:085e`) enumerate behind Genesys
  hubs in the same tree, consistent with the dock; nothing distinguishes its hubs from the
  monitor's by name.

Storage drift since the 2026-10-06 survey (from the 2026-10-17 run; `nvmeXnY` labels are a
per-boot snapshot, so match by model, not name):

- The 443 GB btrfs partition on the Samsung 980 PRO has **no filesystem now** — `blkid` returns
  only a PARTUUID. Its contents were rescued to `~/Documents/rescued-nvme1n1p5-2026-10-11/`.
- `sda3` (12 TB IronWolf, btrfs) is mounted **read-only** at `/mnt/12TB_2`, and **not via
  `/etc/fstab`**, so the mount does not survive a reboot.
- Root (`nvme1n1p2`) is at **89 %** — 28 GiB free — against the cache budget in
  [build-caches.md](build-caches.md).


### RAM upgrade — decided 2026-09-28, waiting for a price, not ordered

**Decided 2026-09-28:** when RAM becomes affordable, add a **second identical kit** —
another Corsair Vengeance LPX `CMK32GX4M2D3600C18` (2×16 GB). Recorded at the time as
"*you have to work with RAM constraints until RAM becomes more affordable. when that
happens, i'll add another 32GB to my system*" (session `01a0d759`), and worked through
the same day in session `01a0e4b9`. Both `DIMM 0` slots are empty and the ceiling is
128 GiB (`dmidecode -t 16`), so this lands at 4 × 16 GiB = 64 GiB and retires nothing.

| path | after | slots left | speed outlook | when to prefer it |
| --- | --- | --- | --- | --- |
| **second `CMK32GX4M2D3600C18`** (2×16) — *the plan* | 4 × 16 GiB = 64 GiB | 0 | 3600 likely, may need a BIOS nudge | default: the same part number is the best predictor that four DIMMs train together |
| one 2×32 GiB kit | 2 × 32 GiB = 64 GiB | 2 | 3600 easily | only if four sticks refuse 3600 *and* bandwidth matters more than price |

**Speed caveat, stated in both directions.** Both current modules are **dual-rank**,
the harder case for the Zen 3 memory controller. AMD's *guaranteed* table for four
dual-rank DIMMs is **2667** (3200 for two), so 3600 across four sticks is not
contractual — Zen 3 usually trains 4×16 GB at 3600, with SoC/latency tuning if not,
and a 3200/2933 fallback is normal. Treat 3600 as likely rather than certain, and
treat 3200 as an acceptable outcome rather than a failure.

**SMBIOS reports SPD nominal voltage, not the applied VDIMM.** The 2026-09-28 session
read the reported `1.2 V` as "JEDEC, not the XMP profile"; that inference is wrong.
The kit is in fact running 3600 MT/s with XMP applied (this line said so), and
dmidecode cannot see what the BIOS actually set. Do not use the voltage field to
judge whether XMP is active.

**Buy criteria:** exact part number `CMK32GX4M2D3600C18` (Vengeance LPX 2×16 GB,
DDR4-3600 CL18). A later production batch can differ in IC revision even at the
same PN, so budget for tuning SOC/VDDIO and `procODT` rather than assuming XMP
holds across four sticks. Do not trust SMBIOS for the XMP voltage — it reports
1.2 V here where these kits profile at 1.35 V.

**Verify after fitting:** `sudo dmidecode -t 17 | grep -E 'Size|Configured Memory Speed|Part Number'`
and `free -h`. Regenerate the whole survey with `scripts/hardware-check.sh`.
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

Five files live in `/usr/local/bin`, and **no package owns any of them**. The first three
shadow or wrap system commands, since this directory precedes `/usr/bin` in PATH; the
rest are unique to this machine, and the last is **temporary** (it exists only for the
pre-rebuild boot loop and must be removed after it). Nothing tracked them before the 2026-10-06 review. They are listed here because an unowned shim has no
lifecycle: pacman will not update it, will not notice when it becomes obsolete, and will
not mention it if its behaviour quietly changes.

```text
/usr/local/bin/mkinitcpio                   Limine boot-safety guard (keep)
/usr/local/bin/remove-nvidia                legacy name; clears VM guest packages (no-op today)
/usr/local/bin/MarkdownBlaze                wrapper for the MarkdownBlaze package (expires)
/usr/local/bin/plasmashell-wedge-watch.sh   panel-wedge watchdog (keep; source in plasmashell-watch/)
/usr/local/bin/boot-capture.sh              reboot-loop capture (TEMPORARY; source in scripts/, undo in
                                            customizations.md — remove when the loop is over)
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
- **`plasmashell-wedge-watch.sh`** — the panel-wedge watchdog. Probes `plasmashell`
  liveness over D-Bus and, once the probe fails repeatedly, captures a gdb backtrace and
  core **before** systemd's `TimeoutSec=40sec` SIGKILL can destroy the evidence (see the
  2026-10-10 entry in `customizations.md` for why that matters). Driven by the system-scope
  `plasmashell-wedge-watch.timer`, every 10 s. Source, design constraints and the test
  recipe that exercises its failure path: [plasmashell-watch/](plasmashell-watch/).
  Rationale: [plasmashell-wedge.md](plasmashell-wedge.md).

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
- The journal is capped at **`SystemMaxUse=2G`** by
  `/etc/systemd/journald.conf.d/50-retention.conf`. `cachyos-settings` ships
  `SystemMaxUse=50M` in `/usr/lib/systemd/journald.conf.d/00-journal-size.conf`, which
  retained barely one boot and made the 2026-10-10 panel freeze partly undiagnosable. The
  `/usr/lib` file is package-owned: **override in `/etc`, never edit it.** Verify with
  `systemd-analyze cat-config systemd/journald.conf | grep SystemMaxUse` and
  `journalctl --list-boots`. See [plasmashell-wedge.md](plasmashell-wedge.md).
- Crash core dumps are **already working** — `systemd-coredump.socket` is active and
  `core_pattern` pipes to it. `coredumpctl list` being empty means nothing has genuinely
  crashed, not that capture is broken. A `SIGKILL`, however, never produces a core, which
  is why a wedged-then-killed process leaves no post-mortem. Do not "enable" coredumps.
- **`pacman.conf`'s commented `#LogFile` is correct as shipped.** `pacman-conf LogFile`
  returns `/var/log/pacman.log`, so pacman does log. **`shelly upgrade all` does not write
  that log**: its transactions leave no `pacman.log` entry at all (2026-10-09 00:17–00:28
  upgraded `qt6-base` to 6.12.0 and KDE to 6.7.5-3.1, invisibly). Reconstruct what changed
  from `snapper -c root list` plus `pacman -Qi <pkg> | grep 'Install Date'`.
- A **user session bus rejects a cross-UID connection.** As root, a `busctl` call to a
  user's bus fails with `Failed to connect to system scope bus via local transport: Broken
  pipe`, because dbus-daemon's EXTERNAL auth requires the peer UID to match the bus owner.
  Any diagnostic that must talk to a user bus and also needs root must split the two:
  probe via `setpriv --reuid=<uid> --regid=<gid> --init-groups --` (not `runuser`, which
  opens a PAM session and logs two lines per run), capture as root.
