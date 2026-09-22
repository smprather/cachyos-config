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
