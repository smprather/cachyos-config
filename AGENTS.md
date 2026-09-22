# Agent Cold Start

This repository documents the intended state of this CachyOS machine and the
reasoning behind prior fixes. Treat it as an operational notebook for restoring
or changing the system without repeating old diagnostics.

## Current State

- The user has switched back to Plasma as the active/preferred desktop.
- The machine started as the CachyOS Hyprland edition, then Plasma, GNOME, and
  other desktop components were layered onto it.
- Plasma was originally incomplete; `plasma-meta` was installed later to finish
  the desktop. Do not assume package state matches a clean stock install.
- Sessions are Wayland-only. `/usr/share/xsessions/` is expected to be empty.
- The display manager is `greetd` with the noctalia greeter. `sddm` and `gdm`
  may be installed, but they are deliberately disabled.

## Read These First

Start here before changing the machine:

1. `README.md` for the repo map and provenance.
2. `system-inventory.md` for hardware, repositories, privileges, snapshots, and
   standing operational rules.
3. `desktop-environments.md` for Plasma/GNOME/Hyprland coexistence, display
   manager constraints, portals, and PlasmaZones session scoping.
4. `customizations.md` for the append-only timeline of actual system changes.

Then read the topic file for the area you are touching:

- `passwordless-login.md` for autologin, keyring, PAM, polkit, and lock-screen
  behavior.
- `chrome-fixes.md` for the current Chrome Stable state, legacy Canary fixes,
  and NVIDIA GPU playback notes.
- `keyboard-remapping.md` for the global keyd Caps Lock tap=Escape,
  hold=Control mapping. Do not add DE-specific Caps Lock mappings.
- `power-idle-suspend.md` and `suspend-clock-uwsm-fixes.md` for idle, suspend,
  wake, RTC, and uwsm login issues.
- `shell-startup-quirks.md` for bash startup hazards and `pkill` safety.
- `hyprland-cachyos-lua-hyde.md` for Hyprland/HyDE/CachyOS Lua wrapper history.
- `el8-gui-apps.md` and `foreign-binary-compat.md` for EL8 binary compatibility.
- `gnome-configuration.md` for GNOME-specific settings and extension notes.

## Hard Rules

- Use `pacman -Syu`, not bare `pacman -S`; Arch/CachyOS partial upgrades are
  unsupported.
- If pacman reports a lock, check for a live package manager first:
  `pgrep -a -f 'pacman|pamac|paru|yay|octopi|discover|packagekit'`.
  Do not remove `/var/lib/pacman/db.lck` while a package transaction is running.
- Do not restart `greetd` to test changes. It kills the active graphical
  session. Reboot instead when display-manager behavior must be tested.
- Do not enable `sddm` or `gdm` unless the user explicitly asks to replace
  greetd.
- Treat the passwordless-login setup as deliberate, including passwordless sudo,
  passwordless polkit for `wheel`, autologin, disabled screen lock, and an
  unencrypted login keyring on an unencrypted disk.
- Do not use `pkill -f <pattern>` casually. The invoking shell can match its own
  command line. Prefer exact process names or explicit PIDs.
- Preserve unrelated local changes. This repo commonly has many unstaged
  documentation files.

## Plasma-Specific Notes

- Plasma should be available through `/usr/share/wayland-sessions/plasma.desktop`.
- `plasmazones.service` is intended to run only in Plasma. It should have a
  per-user systemd guard:

  ```ini
  [Unit]
  ConditionEnvironment=XDG_CURRENT_DESKTOP=KDE
  ```

- If PlasmaZones does not start in Plasma, first inspect what the user systemd
  manager imported:

  ```bash
  systemctl --user show-environment | rg XDG_CURRENT_DESKTOP
  systemctl --user status plasmazones.service
  ```

- If mouse input breaks in a non-Plasma session and a full-screen
  `PlasmaZones` XWayland window is present, stop it with:

  ```bash
  systemctl --user stop plasmazones.service
  ```

## Change Discipline

- Record meaningful system changes in `customizations.md` with date, command,
  affected files, verification, and rollback.
- Prefer exact observed facts over assumptions. Include verification commands
  when a fact may drift with package updates or desktop changes.
- Before package-level changes, note the existing state and the expected snapper
  rollback path. Pacman transactions should create pre/post snapshots.
- For config edits outside this repository, document the target path and the
  rollback command in the relevant topic file.
- Keep new notes concise and operational: desired end state, exact commands or
  files, verification, rollback, and non-obvious reasoning.

## Quick Orientation Commands

Use read-only checks first:

```bash
hostnamectl
echo "$XDG_CURRENT_DESKTOP $XDG_SESSION_TYPE $DESKTOP_SESSION"
systemctl is-enabled greetd sddm gdm
find /usr/share/wayland-sessions /usr/share/xsessions -maxdepth 1 -type f -printf '%p\n' 2>/dev/null | sort
pacman -Q plasma-meta plasma-desktop systemsettings powerdevil xdg-desktop-portal-kde
systemctl --user show-environment | rg 'XDG_CURRENT_DESKTOP|WAYLAND_DISPLAY|DISPLAY'
```

Use escalation only when the task genuinely requires changing system state.
