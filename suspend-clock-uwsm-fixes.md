# Suspend, Clock, and Session Fixes

Three fixes from opencode session `ses_fabc8fb22ff...` (2026-08-30): the dual
login entries that rejected the password, the dual-boot clock skew against
Windows, and the instant-wake suspend bug. The wake fix is detailed in
[power-idle-suspend.md](power-idle-suspend.md); this file covers the session
and clock stories.

## 1. Two Hyprland entries at the login screen

The noctalia greeter offered `Hyprland` and `Hyprland (uwsm-managed)`. Both
take the same password — the uwsm one crashed at startup and dumped back to
the login screen, which looks exactly like a wrong password. A session that
crashes ≠ a rejected password; check the logs before touching passwords.

### What uwsm is

uWSM (Universal Wayland Session Manager) runs the Wayland session as
systemd-managed units — cleaner environment handling, proper app service
scope. CachyOS/Hyprland treats it as the recommended mode. The plain
`hyprland.desktop` session ran fine without it.

### Root cause: bashrc killed uwsm's helper functions

uwsm's env preloader `/usr/lib/uwsm/prepare-env.sh` (a `/bin/sh` script):

1. Defines helper functions (`lowercase`, `load_wm_env`, ...)
2. Sources `~/.profile` — which on this box symlinks to `~/.config/bash/bashrc`
3. That bashrc runs `unset -f $(declare -F ...)` — **erases every shell
   function, including uwsm's own helpers**
4. Next line calls `lowercase` → command not found → preloader aborts →
   session dies → back at greeter

Log signature (`journalctl -b -u` + uwsm unit logs):

```text
/usr/lib/uwsm/prepare-env.sh: line 177: lowercase: command not found
/usr/lib/uwsm/prepare-env.sh: line 195: load_wm_env: command not found
Env output mark ... not found in shell output!
```

### Fix: non-interactive guard at top of bashrc

Inserted at the very top of `~/.config/bash/bashrc`, before any state
mutation:

```bash
# Non-interactive shells (uwsm prepare-env, scripts sourcing ~/.profile,
# scp/sftp remotes, build systems that run `bash -l`) must bail out before any
# state mutation. This file defines/erases aliases and functions; sourcing it
# from ~/.profile (as uwsm does) would unset -f the parent script's helpers
# and abort session startup.
case $- in
    *i*) ;;
    *) return 0 2>/dev/null || exit 0 ;;
esac
```

Mechanics: `$-` holds shell option flags and contains `i` only in interactive
shells. Interactive passes through unchanged; non-interactive (uwsm preloader,
`ssh host command`, cron, scp) returns immediately — with an `exit` fallback
for the case where the file is executed rather than sourced. Side benefit:
non-interactive startup skips the whole file.

After this, both greeter entries boot; uwsm works.

## 2. Windows dual-boot clock skew

Linux defaults the RTC (hardware clock) to UTC; Windows assumes local time.
Booting Linux then Windows leaves Windows 5–6 hours off. The same class of
problem hits every dual-boot pair where one side is Windows.

Fix (Linux side only, no registry edit):

```bash
sudo timedatectl set-local-rtc 1
timedatectl   # verify "RTC in local TZ: yes"
```

Both OSes now read and write the hardware clock identically.

Caveats:

- systemd prints a warning about DST transitions: if the box boots only
  Windows during a DST switch week, Windows may not update the RTC. Sync time
  once in Windows, or boot Linux once. Normal operation unaffected.
- If Windows time still drifts, the remaining suspect is Windows Fast
  Startup (hibernation-like shutdown skips clock resync) — disable via
  Control Panel → Power Options.

## 3. Instant wake from suspend

Summary; full detail in [power-idle-suspend.md](power-idle-suspend.md):

- Woke after ~8 s, every S3 attempt. USB keyboard wake and ACPI gpe04 were
  red herrings — masking either changed nothing.
- Real culprit: PCIe PME (power management events) from PCI devices.
- Fix: `/etc/systemd/system-sleep/nowakeup.sh` disarms all PCI/USB wake at
  pre-sleep, then re-enables the USB keyboard (`3-4.2`) and its controller
  (`0000:09:00.3`) only. Power button always works (ACPI path).
- BIOS: ErP enabled on the Gigabyte B550. Note ErP hides/grays out the other
  wake options in firmware setup — OS-side disarm is the complete fix on
  this board.

## Diagnostic commands worth keeping

```bash
# Did suspend happen, how long did it hold?
journalctl -b -u systemd-suspend

# Which ACPI wake sources are armed / fired?
cat /proc/acpi/wakeup

# Per-device wake toggles
cat /sys/bus/usb/devices/*/power/wakeup
cat /sys/bus/pci/devices/*/power/wakeup

# RTC state
timedatectl
timedatectl show -p NTP -p NTPSynchronized

# What session am I actually in?
loginctl          # Service= line: greetd vs uwsm units, Desktop=, Type=wayland
pgrep -a uwsm
```

## General lessons

- A login screen that "rejects" a password on one entry is usually a session
  crash, not an auth failure. Read `journalctl` before resetting passwords.
- Anything sourced from `~/.profile` runs in foreign contexts (uwsm's sh
  preloader, ssh, cron). Interactive-only state mutation in bashrc needs an
  interactivity guard.
- Dual-boot with Windows → set RTC to local time once, accept the DST caveat.
- Runtime `/sys` wake disables don't survive reboot or BIOS flashes; a
  systemd sleep hook under `/etc/systemd/system-sleep/` is the persistent
  mechanism.