# When everything is frozen

The ladder, in order, and what is **verified to work on this machine**. Written
2026-10-14, after a morning that ended in a power-button hold and dirty filesystems that
did not need to happen (see `plasmashell-wedge.md` for that incident).

Read the rung that matches the symptom. Rungs 1–3 are about getting the session back;
rung 4 is about getting the *machine* back.

## 1. Only the panel is dead

Symptom: the taskbar/panel stops drawing or stops responding; windows, terminals and the
journal are fine. This is the known failure and it is **not** a system freeze.

    Meta+Shift+F            # kwin global shortcut -> fixpanel-shortcut KWin script
    fixpanel                # ~/.local/bin/fixpanel -> cachyos-config/bin/fixpanel
    # or click "Fix Panel" in the app launcher
    # or just wait ~30 s: plasmashell-wedge-watch captures a core, SIGKILLs the shell,
    #    and Restart=on-failure respawns it

**Do not power-cycle for this.** While the panel is dead the journal, systemd, D-Bus and
every terminal keep working — verified on 2026-10-14, when the shell sat at 100 % of a core
for 16 minutes and `Peer.Ping` still answered in 2 ms. The power-button hold is what dirtied
`/boot` and forced a BTRFS tree-log replay, not the freeze.

## 2. Desktop unusable, kernel alive

- **`Ctrl+Alt+F3` → a shell, with no password.** `getty@tty3` is enabled with
  `--autologin mylesp` (drop-in `/etc/systemd/system/getty@tty3.service.d/autologin.conf`),
  matching this machine's deliberate passwordless posture. Verified: a `-bash` runs as
  `mylesp` on tty3, logind session 3, `pam_unix(login:session): session opened`.
  From there: `fixpanel`, or `sudo systemctl reboot` for a *clean* reboot.
  `Ctrl+Alt+F1` returns to the graphical session.
- **`Ctrl+Alt+Delete` → the KDE logout greeter**, drawn by kwin and ksmserver, both separate
  from plasmashell. Evidence it survives a dead shell: on 2026-10-14 plasmashell segfaulted
  at 08:12:53 and this greeter still started at 08:26:30.
- `loginctl` and `systemctl --user` both work from the VT or from any surviving terminal.
- **Remote rescue from the work laptop: available, deliberately not enabled.** Nothing needs
  memorising — this box advertises mDNS (`avahi-daemon` active), so its name is
  **`cachyos-x8664.local`**: no IP, and it survives DHCP changes. `sshd` is off. If the
  remote rung is ever wanted (and it needs the laptop off its VPN):

  ```bash
  sudo systemctl enable --now sshd
  sudo ufw allow from 192.168.0.0/24 to any port 22 proto tcp
  # from the laptop:  ssh mylesp@cachyos-x8664.local
  # undo:  sudo systemctl disable --now sshd
  #        sudo ufw delete allow from 192.168.0.0/24 to any port 22 proto tcp
  ```

  Two caveats worth knowing before relying on it: a locked-down laptop may not resolve
  `.local` (that needs an mDNS client — `nss-mdns` or Windows 10+), and password auth is the
  fallback (`passwd` decides what that password is). Off by default because a network login
  service is new attack surface on a machine with passwordless sudo.

## 3. Nothing responds at all — kernel or GPU hang

Verified facts, so no time is wasted:

- **REISUB is unavailable, and the mapping that blocks it is deliberate — leave it alone.**
  `/proc/sys/kernel/sysrq` is `16` (sync only, not `1`), *and* keyd remaps `print = f13` in
  `/etc/keyd/default.conf`, so the SysRq key never reaches the kernel at all. That remap is
  what makes the physical PrintScreen key trigger the region capture instead of colliding
  with Spectacle's shipped `Print` default — see `screen-capture.md`, "Key routing (keyd F13
  bridge)". Do **not** remove it to get SysRq back.
- **SysRq is not needed here anyway.** From the VT3 shell,
  `sudo sh -c 'echo s > /proc/sysrq-trigger; echo b > /proc/sysrq-trigger'` is the
  sync+reboot half of REISUB with no keyboard ritual (verified: `/proc/sysrq-trigger` is
  `--w------- root`, and sudo is passwordless). And for a *true* kernel lockup SysRq would
  not be dependable on this desk regardless — the KVM's emulated keyboard is another layer
  between the key and the kernel. That case stays the power-button hold.
- **A hard hang now reboots itself** (from 2026-10-14). `nowatchdog` was removed from
  `/etc/default/limine` and `limine.conf` was regenerated, so the lockup detector runs;
  with `/etc/sysctl.d/99-recovery.conf` (`kernel.panic=15`, `kernel.hardlockup_panic=1`) a
  locked-up CPU panics and reboots in ~15 s instead of hanging forever. Verify after a
  reboot: `/proc/cmdline` reads `quiet splash …`, `/proc/sys/kernel/nmi_watchdog` is 1,
  `hardlockup_panic` 1, `panic` 15. (Before this, `nmi_watchdog` was 0 and could not be
  re-enabled at runtime — verified by writing 1 and reading 0 back.)
- Therefore: **hold the power button ~10 s.** Safe here, and each claim is measured rather
  than assumed:
  - root, `/home`, `/root`, `/srv`, `/var/cache`, `/var/tmp` are btrfs subvolumes with
    `compress=zstd:1` → crash-consistent; the 2026-10-14 hard cut produced exactly
    `BTRFS info (device nvme0n1p2): start tree-log replay`, then a normal boot.
  - `/boot` is vfat → the 2026-10-14 hard cut produced `Dirty bit is set. Fs was not
    properly unmounted…`, which `systemd-fsck` clears automatically at boot.
  - `btrfs device stats /` is all zeros, so no hard cut has ever corrupted data.
  - The login keyring is unencrypted and autologin is on, so nothing needs unlocking.
  - Loss is limited to unsaved work in open applications.

## 4. It comes up broken (bad update, broken config, unbootable)

**Boot an older snapshot from the limine menu.** This is the guarantee that a hard reboot is
always recoverable:

- `/boot/limine.conf` holds **53 bootable snapper snapshots** (106 entries carrying
  `rootflags=subvol=/@/.snapshots/<N>/snapshot`), listed under `//Snapshots`.
- `limine-snapper-sync` is enabled and takes pre/post pairs around every package
  transaction (`snapper -c root list`) — so pick the `pre` snapshot of whatever broke it.
- `/boot/limine.conf.old` is kept alongside the live config.
- No second machine and no network are needed for this rung.

## 5. Disk failure or a lost bootloader

Outside what a hard reboot can fix: needs a USB stick with the CachyOS ISO. The disk plan and
the migration/backup situation are in `storage-migration.md`. Nothing on this machine
substitutes for that stick — keep one.

## Verified 2026-10-14, so it can be relied on

| Thing | State | Undo |
|---|---|---|
| `getty@tty3` autologin rescue shell | active + enabled, shell verified on tty3 | `sudo rm -rf /etc/systemd/system/getty@tty3.service.d && sudo systemctl daemon-reload && sudo systemctl disable --now getty@tty3` |
| `/etc/sysctl.d/99-recovery.conf` (`panic=15`, `hardlockup_panic=1`) + `nowatchdog` removed from the cmdline | applied 2026-10-14; takes effect on the next boot — check `nmi_watchdog`=1 afterwards | `sudo rm /etc/sysctl.d/99-recovery.conf && sudo sysctl --system`, and restore `/etc/default/limine.bak-20261014` + re-run `limine-update` |
| REISUB | unavailable: `sysrq=16` plus keyd's `print = f13`, which **is** the PrintScreen→capture bridge — do not remove it | use `echo s`, `echo b > /proc/sysrq-trigger` from the VT3 shell instead |
| `sshd` | disabled, nothing listening on 22 | — |
| limine snapshot entries | 53 bootable, `limine-snapper-sync` enabled | — |
| panel freeze recovery | `Meta+Shift+F` / `fixpanel` / watchdog autokill | see `plasmashell-wedge.md` |
