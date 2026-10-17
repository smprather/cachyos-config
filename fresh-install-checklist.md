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

## 1b. Home comes over verbatim (before the new system ever boots)

Decided 2026-10-17: `$HOME` moves to the new install **verbatim**, not selectively.

**Direction: push from the old system, into the new `@home` while the new system is still booted from
nothing.** Not a pull from the new system, for three reasons:

1. **Verbatim needs an empty target.** The new home is populated by the installer and then by Plasma
   at first graphical login. Copying into a populated home is a *merge*: our files win on collisions,
   but anything the new install wrote and we lack stays. Pushing into the new `@home` before the new
   system has ever booted is the only way to get verbatim by construction.
2. **A read-only snapshot freezes the source.** `btrfs subvolume snapshot -r /home` gives a consistent
   source while the old system stays usable; copying out of a live home races the browser profiles and
   caches that are still being written. That is the pull's one genuine advantage, obtained without
   giving up the empty target.
3. **The tooling is here** — the repo, the scripts, the inventory, the verification, and sudo.

If the new install is smoke-tested *before* the copy, the target is no longer pristine: accept that
and verify with a diff instead of assuming verbatim.

Sizing, measured 2026-10-17: `$HOME` is **150 GB in 1,881,609 files** and `/home` is at 90 % (25 GB
free). The copy is metadata-bound, not bandwidth-bound — the old root measures ~8.5k IOPS at 4 KiB
QD1 — so budget tens of minutes. Largest directories, regenerable ones marked `*`:

```text
.cache 55G *   .local 25G      .config 14G     build-work 12G   engineering-loadout 11G
.ciel 5G       .codex 3.1G     .volare 2.7G    Documents 2.7G   shed-design-private 2.4G
.npm 2.2G *    .rustup 1.5G *  .cargo 685M *   loadout_backups 779M

must carry, verify by name afterwards: .ssh 16K  .gnupg 80K  .config/systemd 76K
.local/share/kwin 8K  .local/share/applications 36K  kwinrc 4K  kwinoutputconfig.json 4K
+ the containment drop-in ~/.config/systemd/user/plasma-plasmashell.service.d/10-mesa-software-gl.conf
```

Steps, run on the old system. Identify every disk by model or PARTUUID, never by device node — the
boot-loop captures measured the NVMe enumeration flipping between boots:

```bash
# 1. freeze the source (outside $HOME, so it is not part of the copy; delete when done)
sudo btrfs subvolume snapshot -r /home /.snapshots/home-premigration-$(date +%F)

# 2. mount the NEW root's @home subvolume (new NVMe, identified by UUID)
sudo mkdir -p /mnt/new-home
sudo mount -o subvol=/@home /dev/disk/by-uuid/<new-root-uuid> /mnt/new-home

# 3. copy. --numeric-ids keeps uid/gid 1000 as-is; /.cache excluded by recommendation only
sudo rsync -aHAX --numeric-ids --info=progress2 --exclude=/.cache \
     /.snapshots/home-premigration-YYYY-MM-DD/ /mnt/new-home/

# 4. verify — all four must pass BEFORE the new system boots
sudo rsync -aHAX --numeric-ids --dry-run --itemize-changes \
     /.snapshots/home-premigration-YYYY-MM-DD/ /mnt/new-home/ | head -20   # expect nothing
ls -nd /mnt/new-home/mylesp                                              # uid/gid 1000
ls -l /mnt/new-home/mylesp/.config/systemd/user/plasma-plasmashell.service.d/   # containment
find /.snapshots/home-premigration-YYYY-MM-DD -type f | wc -l            # vs the destination
```

Open items to decide on the day: whether `~/.cache` really is excluded (the one deviation from
"verbatim" — it is 37 % of the volume and most of the file churn); whether the regenerable toolchains
(`.npm`, `.rustup`, `.cargo`, `build-work`, `.ciel`, `.volare`) come along or get rebuilt; and
`/var/lib/boot-loop/` — the boot-loop captures are **not** in home and must be copied explicitly if
they are wanted on the new install.

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
