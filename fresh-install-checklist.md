# Fresh install on the new NVMe — ordered checklist

Written 2026-10-14, when the drive arrived and the owner chose a **fresh CachyOS install** over
the `btrfs send`/`receive` clone in `storage-migration.md`. That document still owns the
hardware facts, the slot choreography and the rule that matters most on the day — *identify
every disk by model, serial or PARTUUID, never by `/dev/nvmeXnY`*. This one is the order of
operations plus the list of things no package can restore.

**The one safety net that does not carry over: the boot menu.** `limine.conf`'s snapshot
entries name subvolumes of the *current* btrfs (`rootflags=subvol=/@/.snapshots/NN/snapshot`),
so a new filesystem has none of them. Keep the old disk installed *and bootable* until the new
install has booted a few times — that, plus the `sda3` copy, is the fallback
(`storage-migration.md`, correction 3).

## 0. Before touching anything

```bash
scripts/premigration-inventory.sh      # read-only, ~33 s; writes the "before" copy
scripts/system-benchmark.sh before     # ~2.5 min; run it three times (each run gets its own file),
                                       # then --average them — see benchmarks/README.md
```

That script exists to be **diffed**, and the diff is what makes a rebuild safe rather than
hopeful: run it again on the new system and treat every difference as a gap found on purpose,
while the old disk is still attached. Keep the unredacted copy in `~/Documents/` and only the
redacted one in `inventories/` — this repo is published (`README.md`, "Provenance").

The benchmark is the same idea for performance, and it has the same one-shot property: take the
before-baseline **now**, while the old install is still the one booting, or the comparison is gone
for good (`benchmarks/README.md`, `storage-migration.md`).

## 0a. The live medium

**The stick is the PNY "USB 3.0 FD", serial `070B66D983812136`, 29.6 GB**, written 2026-10-17 from
`cachyos-desktop-linux-260809.iso`

| Property | Value |
|---|---|
| ISO sha256 | `959f6577f45e25ee9fd8c220fd221b08e4ea79412c7315c0f922dd6d86d5e33c` (3041 MiB, published hash, matched) |
| written with | `sudo dd if=<iso> of=/dev/sdc bs=4M oflag=sync conv=fsync` |
| verified by | reading the first 3041 MiB back off the stick and comparing sha256 — **identical** |
| layout | `sdc1` iso9660 `COS_202608` 2.9 G · `sdc2` vfat `ARCHISO_EFI` 23 M with `BOOTx64.EFI` + `BOOTIA32.EFI` |

Before it was overwritten the stick was the board's **BIOS-flash stick**: one file
`B550AORUSELITEAXV212.FId` (16 MiB, the current `FId` firmware) on FAT32 labelled `BIOSFLASH`, no
`EFI/` directory and no ISO — which is exactly why the firmware answered "insert boot media and press a
key" when it was tried as a live medium. That image was preserved first, so a BIOS stick can be remade
at any time:

```text
~/Documents/board-firmware/B550AORUSELITEAXV212.FId
sha256 334dc14d462efa5ccb33afaec0f030584cbda07356789af2e7cc7d8f7f80b267
```

Boot it from the firmware's boot menu (Gigabyte: `F12`) and pick the **UEFI** entry for the stick.
Secure Boot is off, so nothing needs signing. The stick sits on a **direct** xHCI port (bus 4, port 1),
not behind the dock's hub — if the firmware still refuses it, try a rear USB 2.0 port rather than the
front-panel or dock ports, because the dock's hub chain is a known source of enumeration oddity here.

**The target drive is already fitted and empty:** the 9100 PRO is in the **CPU slot**
(`0000:01:00.0`, `LnkCap 32GT/s`, `LnkSta 16GT/s ×4` — i.e. Gen5 trained down to Gen4, which is the
acceptance test `storage-migration.md` asks for), with no partitions. The Intel 600p (this install) is
in the chipset slot at 8GT/s and stays bootable as the fallback.

## 1. Install

- **CachyOS Plasma edition**, not the Hyprland edition with desktops layered on top. The
  current install is Hyprland-edition plus Plasma plus GNOME, and that layering is where
  several documented oddities come from — three notification daemons (`dunst`, `swaync`,
  Plasma's) all claiming `org.freedesktop.Notifications`, and a Plasma desktop that had to be
  finished later with `plasma-meta`. Read `desktop-environments.md` first: it records what the
  coexistence requires and what it costs.
- **Same disk layout**: btrfs with `@ @home @root @srv @cache @tmp @log`, a separate ESP,
  `limine` + `snapper` + `limine-snapper-sync`. Subvolume layout in `hardware-check.md`, boot
  chain in `storage-migration.md`.
- Cross-check the package set: `pacman -Qqen | wc -l` against the inventory copy (326 explicit
  packages, 1 flatpak on 2026-10-14).

## 1b. Home comes over verbatim (a mirror, pulled from the new system)

Decided 2026-10-17: `$HOME` moves to the new install **verbatim**, not selectively.

**Direction: pull — from the new system, at a TTY, before its first graphical login, reading the old
`@home` mounted read-only, with `rsync --delete-after` so the result is a true mirror.** Two reasons,
and a note on what changed:

1. **`--delete-after` is what makes it verbatim, and it removes the "target must be empty" constraint
   an earlier version of this section used to argue for pushing.** Without it, copying into a home the
   installer already touched is a *merge*: our files win on collisions, their leftovers stay. With it,
   the destination mirrors the source exactly — including deleting the installer's `/etc/skel` copies.
   Guard rails, because `--delete` can destroy data:
   - **Prove the destination before running it.** `rsync --delete` deletes into whatever is mounted at
     the destination, so a missing or stale mount means deleting into the *wrong filesystem*. Check
     `findmnt -no SOURCE,UUID /home` — it must be the new NVMe — and never assume a mount survived a
     reboot.
   - **`--dry-run --itemize-changes` first, and read the deletion list** (deletions are marked
     `*deleting`).
   - **`--delete-after`**, not during: deletions happen only once the transfer has completed.
   - Excluded paths are *protected* from deletion unless `--delete-excluded` is also given. Nothing is
     excluded any more (the cache comes over — see below), so this only matters if an exclusion is ever
     added back.
2. **The source is consistent for free.** Booting from the new disk means the old system is *not
   running*, so mounting its `@home` read-only is already a quiescent source — no snapshot needed.
   Pushing from a running old system (or pulling from one) would race the browser profiles and caches
   still being written, and *that* case is the one that needs `btrfs subvolume snapshot -r /home`
   first.
3. **The new system needs exactly one tool for this**: `rsync` (`sudo pacman -Syu rsync`). The old home
   stays mounted at `/mnt/old-home` for the duration, so this repo and its scripts are readable from it
   — the verification steps below can be run from either side.

Do it from a TTY, not a desktop session: the destination is the running system's own home, so a
logged-in Plasma would be writing into it during the mirror. Logging in *after* the copy is also the
nicest ordering — the new install's first KDE start then happens on top of the mirrored home, which is
the whole point of doing this verbatim.

**Order on the day — the smoke test comes first, and that is fine.** Install, boot the new system,
verify it (login, Plasma, GPU, network), run `pacman -Syu`, and *then* mirror:

```text
install -> boot new + verify -> sudo pacman -Syu -> log out of the desktop -> TTY
        -> mirror (commands above) -> verify -> log in
```

`--delete-after` is what makes the smoke test harmless: whatever the first login and the upgrade wrote
into the new home is deleted by the mirror, so the target's prior state does not matter. What *does*
matter is when the mirror runs — **with no desktop session on the new system**. KDE rewrites its own
config at login and logout (`~/.config/ksmserverrc` was rewritten at 15:01 today by a reboot), so
mirroring from inside a live session, or logging out right afterwards, overwrites parts of the
verbatim copy with session state.

Three things in this home that are easy to misjudge:

- **The browser profiles are gone as of 2026-10-17**, deliberately, before this copy: the three
  Chrome-family profiles (`~/.config/google-chrome` 6.4 G, `-canary` 6.1 G, `chromium` 394 M) and their
  caches were wiped (19 GB in total), so the copy no longer carries them — which also removes the only
  reason to consider excluding `Cache/`-style subdirectories. Firefox followed the same evening
  (`~/.config/mozilla` + `~/.mozilla` + an 8 K flatpak leftover), so **no browser profile comes over at
  all**. The undo is a btrfs snapshot of `@home`, verified to contain every deleted path, so the space
  stays allocated until that is dropped; see `customizations.md`, 2026-10-17 (late). Just over 19 GB in
  total, which is why this copy is ~19 GB smaller than the 150 GB first measured.
- **Session-restore state travels**: `~/.config/session/` (a Dolphin entry from 2026-10-15, a KWin
  entry from 2026-09-10) and `ksmserverrc`. The new system's first login may therefore try to reopen
  what was open here. Clearing `~/.config/session/` after the mirror, or setting the login mode to an
  empty session, is the way to avoid that if it is not wanted.
- **Per-user flatpaks travel with home** (`~/.local/share/flatpak` 3.4 G, `~/.var/app` 496 K): they
  are not pacman packages, so nothing needs reinstalling for them — but the new install needs the
  `flatpak` package itself. The user-scoped `ingetrazo` remote is configured **`no-gpg-verify`**, which
  is worth re-checking rather than inheriting blindly. Anything installed system-wide (the `flathub`
  system remote, `/var/lib/flatpak`) is **not** in home and must be set up again.

Sizing, measured 2026-10-17 *after* the browser-profile wipe (it was 150 GB in 1,881,609 files before
it): the copy is **131 GB**, of which `.cache` is 50 G — it was going to be 81 GB while `.cache` was
excluded. `/home` sits at 90 % (25 GB free, held there by the wipe's snapshot rather than by data). The
copy is metadata-bound, not bandwidth-bound — the old root measures ~8.5k IOPS at 4 KiB QD1 — so budget
tens of minutes. Largest directories:

```text
.cache 50G     .local 25G      build-work 12G  engineering-loadout 11G   .ciel 5G
.codex 3.1G    .volare 2.7G    Documents 2.7G  shed-design-private 2.4G   .npm 2.2G
.rustup 1.5G   .cargo 685M     loadout_backups 779M      (.config ~1.5G after the wipe; was 14G)

must carry, verify by name afterwards: .ssh 16K  .gnupg 80K  .config/systemd 76K
.local/share/kwin 8K  .local/share/applications 36K  kwinrc 4K  kwinoutputconfig.json 4K
+ the containment drop-in ~/.config/systemd/user/plasma-plasmashell.service.d/10-mesa-software-gl.conf
```

Steps, run on the old system. Identify every disk by model or PARTUUID, never by device node — the
boot-loop captures measured the NVMe enumeration flipping between boots:

```bash
# What was actually done on 2026-10-17. The direction flipped to a PUSH from the old system,
# because the new system was shut down anyway: the destination was then quiescent, and a snapshot
# covers the source-side race that the pull was originally chosen to avoid.

# 1. freeze the source. NOTE: @home's root contains the directory mylesp/ — the snapshot is of
the SUBVOLUME, not of the user's home.
sudo btrfs subvolume snapshot -r /home /.snapshots/home-premigration-$(date +%F-%H%M)

# 2. mount the NEW @home read-write and prove it is the new disk by UUID
sudo mkdir -p /mnt/new-home
sudo mount -o rw,subvol=/@home /dev/disk/by-uuid/<new-root-uuid> /mnt/new-home
findmnt -no SOURCE,UUID /mnt/new-home

# 3. dry run first — read the *deleting lines; they should be only the new install's skel and caches
sudo rsync -aHAX --numeric-ids --delete-after --itemize-changes --dry-run \
     /<snapshot>/mylesp/ /mnt/new-home/mylesp/ | head -40

# 4. mirror, as a transient unit so a long copy survives whatever shell started it
sudo systemd-run --unit=home-mirror --collect -p Type=oneshot -p TimeoutStartSec=infinity \
     /usr/bin/rsync -aHAX --numeric-ids --delete-after /<snapshot>/mylesp/ /mnt/new-home/mylesp/

# 5. verify and tidy — in this order, and the umount is not optional
sudo rsync -aHAX --numeric-ids --delete-after --dry-run /<snapshot>/mylesp/ /mnt/new-home/mylesp/ | head  # nothing
sudo ls -nd /mnt/new-home/mylesp                          # uid/gid 1000, mode 700
sudo ls -l /mnt/new-home/mylesp/.config/systemd/user/plasma-plasmashell.service.d/   # containment drop-in
sudo umount /mnt/new-home                                 # a btrfs mounted rw here cannot also be mounted
                                                          # by the new system's kernel
sudo btrfs subvolume delete /.snapshots/home-premigration-*
```

**Two traps in that sequence, one of which bit on 2026-10-17:**

1. **The source path must be `<snapshot>/mylesp/`, not `<snapshot>/`.** The `@home` subvolume's root
   holds exactly one entry, the directory `mylesp/`, so pointing rsync at the root copies *that
   directory* into the home — leaving `/home/mylesp` root-owned with the real home nested inside it
   at `/home/mylesp/mylesp`. That is what happened, and it was repaired by renaming the outer
   directory and promoting the inner one (instant, same filesystem); see `customizations.md`. rsync
   also takes the *destination* directory's ownership from the source root, which is why the home
   came out `0:0` rather than `1000:1000`.
2. **Unmount before booting the new system.** A btrfs mounted read-write from here cannot be mounted
   by another kernel; the new system would fail to mount `@home` and land on a broken/empty home.

Measured on the day: **2,047,807 entries, 131 GiB, 4 min 50 s wall clock** (~460 MiB/s average, and
4 min 36 s of CPU — the file count, not the NVMe link, is the cost). The dry run predicted **137
deletions**, all of them the new install's own skel and caches (`.cache/ksycoca*`,
`event-sound-cache.tdb.<new-machine-id>`, `fish/generated_completions/*`, and `gtk-4.0/` files that had
to go so this home's symlink could land).

Open items to decide before the copy runs:

- **`~/.cache` is copied after all** — owner's call, 2026-10-17: too much of it is downloaded material
  that would only be fetched again. `.cache/uv` 5.7 G, `.cache/pip` 902 M, `.cache/ms-playwright`
  656 M and `.cache/puppeteer` 261 M are exactly that. It is 50 G — 38 % of the copy and most of its
  file count — but it is real work avoided. Composition worth knowing: **36 G of it is the loadout's
  build cache** (`.cache/engineering-loadout` 25 G + `.cache/loadout-build` 11 G), so those two are the
  only exclusions worth considering if copy *time* ever matters more than rebuilding the loadout. The
  purely derived caches are not worth excluding (fontconfig 6.9 M, ksycoca 1.4 M, mesa_shader_cache
  5.2 M — under 15 M together, and they rebuild themselves), and HyDE's 780 M plus the dead GNOME
  caches (~190 M) belong to things this rebuild is shedding anyway.
- **HyDE/Hyprland leftovers (313 M, nearly all `~/.config/hyde`)** — inert without Hyprland installed,
  but this rebuild exists partly to shed the layered-desktop mess that `desktop-environments.md`
  documents. Verbatim carries them along.
- **The engineering loadout (`~/.local/share/loadout` 7.7 G + `~/engineering-loadout` 11 G)** — 18.7 G
  and PATH-visible (`…/loadout/prefer` is first on PATH today). The path-shadowing policy in
  `engineering-loadout-path.md` is a deliberate fix, so a verbatim copy must take the configuration
  that arranges it too, and the PATH order on the new install wants checking afterwards.
- **Regenerable toolchains** — `.npm` 2.2 G, `.rustup` 1.5 G, `.cargo` 685 M, `build-work` 12 G,
  `.ciel` 5 G, `.volare` 2.7 G.
- **`/var/lib/boot-loop/`** — the boot-loop captures are **not** in home and must be copied explicitly
  if they are wanted on the new install.

Not a concern, checked 2026-10-17: `~/.local/bin` is 373 M because it holds three self-contained
binaries (`muse-bin-1.4.3-R5018.1` 327 M, `agent-deck` 33 M, `hydectl` 13 M) — no virtualenvs, so
nothing there is tied to the old Python and it copies as-is.

## 2. Not in any package — recreate by hand

Most **user-scope** rows below arrive with the verbatim `$HOME` copy above: the containment drop-in,
user units, the `~/.local/bin` keep-list, the KWin `fixpanel-shortcut` script, `~/.ssh`, `~/.gnupg`.
What stays manual is everything under `/etc` and `/usr/local`. Every row still wants verifying by name
once the copy has landed.

Every row is a file this machine depends on that pacman cannot restore. The named doc is the
authority; this table exists so none of them is *missed*.

| Artifact | What it does | Install/undo lives in |
|---|---|---|
| `/usr/local/bin/plasmashell-wedge-watch.sh` + `/etc/systemd/system/plasmashell-wedge-watch.{service,timer}` + `/etc/plasmashell-wedge-watch.autokill` | captures a core and respawns the panel when it wedges; the flag makes it automatic | `plasmashell-watch/README.md`, `plasmashell-wedge.md` |
| `~/.config/systemd/user/plasma-plasmashell.service.d/10-mesa-software-gl.conf` | keeps the shell off the NVIDIA EGL path — the freeze mechanism | `plasmashell-wedge.md` |
| `/etc/sysctl.d/99-recovery.conf` | `panic=15`, `hardlockup_panic=1`, `nmi_watchdog=1` (CachyOS ships the last one **off**) | `frozen-system-recovery.md` |
| `nowatchdog` removed from `/etc/default/limine` + `limine-update` | lets the lockup detector run at all | `frozen-system-recovery.md` |
| `/etc/systemd/system/getty@tty3.service.d/autologin.conf` | passwordless rescue shell on `Ctrl+Alt+F3` | `frozen-system-recovery.md` |
| `bin/fixpanel` → symlink in `~/.local/bin` | one-word panel restart | `standard-tools.md`, `plasmashell-wedge.md` |
| **KWin script `fixpanel-shortcut` + `fixpanel.desktop`** | binds **Meta+Shift+F** to `fixpanel` — the only shortcut that still fires when the panel is dead | block below (recorded nowhere else) |
| `bin/nvidia-driver-watch.sh` + `~/.config/systemd/user/nvidia-driver-watch.{service,timer}` | weekly notice when the driver line changes | `standard-tools.md`, `plasmashell-wedge.md` |
| user units `custom-idle.service`, `tmux-persist-autosave.{service,timer}`, `vp-journal.*`, `vp-tick.*` | idle policy, tmux persistence, the VP pair | `power-idle-suspend.md`, `tmux.md` |
| `~/.local/bin` entries that are not loadout-managed (`fixpanel`, `region-screenshot`, `wezterm-tune`, `custom-idle.sh`, …) | the keep-list, pruned once by name | `engineering-loadout-path.md` |
| keyd `print = f13`, `capslock = overload(control, esc)` | PrintScreen → region capture; Caps Lock tap/hold | `keyboard-remapping.md`, `screen-capture.md` |
| greetd + noctalia greeter config, autologin chain | display manager | `passwordless-login.md` |
| `~/.ssh/authorized_keys`, GPG/Git identity, browser profiles | user state, not configuration | n/a — back up `~` selectively |

### The KWin shortcut — install block

The only place this is written down. Two files plus one config key:

```bash
# 1. ~/.local/share/kwin/scripts/fixpanel-shortcut/metadata.json
#      KPlugin{Id,Name,Description,Version,License,EnabledByDefault:false},
#      X-Plasma-API:"javascript", X-Plasma-MainScript:"code/main.js",
#      KPackageStructure:"KWin/Script"
# 2. ~/.local/share/kwin/scripts/fixpanel-shortcut/contents/code/main.js
#      const UNIT="plasma-plasmashell.service"; restartPanel() { callDBus("org.freedesktop.systemd1",
#      "/org/freedesktop/systemd1","org.freedesktop.systemd1.Manager","KillUnit",UNIT,"all",9);
#      callDBus(...,"StartUnit",UNIT,"replace"); }
#      registerShortcut("FixPanelRestart","Fix Panel: restart the Plasma shell","Meta+Shift+F",restartPanel);
# 3. ~/.local/share/applications/fixpanel.desktop  (Exec=<repo>/bin/fixpanel, NoDisplay=false)
kwriteconfig6 --file kwinrc --group Plugins --key fixpanel-shortcutEnabled true
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start
# verify: journalctl -b | grep fixpanel-shortcut      -> "registered (Meta+Shift+F)"
# undo:   kwriteconfig6 --file kwinrc --group Plugins --key fixpanel-shortcutEnabled false
```

Why `KillUnit … 9` and not a clean restart request: plasmashell handles SIGTERM through the Qt
event loop, so a shell stuck mid-frame makes systemd wait out its full `TimeoutSec=40sec`.

## 3. After the first boot

Both measurements below read this repo, which lives in `$HOME` — so they only run **after** §1b's mirror
has landed (the inventory's "before" copy was taken 2026-10-11 and is already in `~/Documents`). If
after-boot captures are wanted as well, re-install the boot-capture timer from the pair in
`customizations.md`: its unit and script live in `/etc` and `/usr/local`, so they do **not** travel with
home.

```bash
scripts/premigration-inventory.sh                     # the "after" copy, then diff the two
scripts/system-benchmark.sh after                    # three times, then --average, then --diff
                                                      # against the before-average
systemctl --failed --no-legend; systemctl --failed --user --no-legend   # expect mdmonitor.service
                                                                        # unless mdadm.conf has a
                                                                        # MAILADDR: customizations.md
                                                                        # 2026-10-17 (boot capture)
journalctl --user -b | grep -c 'Compositor bridge did not register'   # 0 — PlasmaZones' KWin
                                                                       # effect is version-coupled;
                                                                       # expect this until the repo's
                                                                       # plasmazones is newer than
                                                                       # 3.4.19-1 (see
                                                                       # desktop-environments.md);
                                                                       # is-active is NOT the test
sysctl kernel.nmi_watchdog kernel.hardlockup_panic kernel.panic   # 1 / 1 / 15
grep -c libnvidia-eglcore /proc/$(pgrep -x plasmashell)/maps      # 0
limine-list | head                                    # kernels + a Snapshots section
sudo snapper -c root list | tail -3                   # pre/post pairs being taken again
```

Then walk `frozen-system-recovery.md` once: `Meta+Shift+F`, `Ctrl+Alt+F3`, and the limine
snapshot menu are the three things worth having personally seen work before trusting them.

## 4. The choices that make it boring

1. **NVIDIA: `nvidia-open-dkms` + `nvidia-utils`, not the prebuilt per-kernel module.**
   `linux-cachyos-nvidia-open` hard-pins `linux-cachyos=<exact>` *and* `nvidia-utils=<exact>`,
   so holding a driver freezes the kernel with it. DKMS keeps the kernel moving and rebuilds
   the module — the difference between "pinned forever" and "tracked".
2. **Driver policy: pin nothing, test everything.** `bin/nvidia-driver-watch.sh` reports when the
   repos offer a different driver; the test order is in `plasmashell-wedge.md`. A driver
   generation change is the one thing that has actually broken this desktop.
3. **Update rhythm: `pacman -Syu` weekly**, snapshots automatic, and be wary of
   `shelly upgrade all` — it performs real transactions and writes **no** pacman log, which is
   why one of this machine's upgrades had to be reconstructed from snapper
   (`plasmashell-wedge.md`, standing rules).

Two CachyOS defaults are worth knowing before they bite again: the packaged journal cap
(`SystemMaxUse=50M` in `/usr/lib/systemd/journald.conf.d/00-journal-size.conf`, overridden to
2G in `/etc/systemd/journald.conf.d/50-retention.conf`) and `kernel.nmi_watchdog = 0` in
`/usr/lib/sysctl.d/70-cachyos-settings.conf`.
