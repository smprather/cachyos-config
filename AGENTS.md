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
- `deepseek-harness.md` for the DeepSeek Harness (`dsh`) agent harness, its
  provider routes, profiles, and the missing TUI.
- `text-rendering-quality-tools.md` for measuring rendered-text quality. Key
  constraint: the check must work from a **screen grab**, so the terminal's own
  rendering is inside it — font-file and FreeType-direct tools are diagnosis
  only, never the acceptance test.
- `alacritty-terminal.md` for the alacritty ("atty") daily-driver setup: config mapping
  from wezterm, the palette switcher, the pinned `#000000` background, the live-reload
  rules, and the IPC-socket trap. **Resume point: palette tuning.** Never `pkill
  alacritty` — it kills the instance being worked in and live reload makes it pointless.
- `tmux.md` for the tmux setup: a LAYERED config (dispatcher, then
  tmux-settings-global.conf, tmux-settings-user.conf, tmux-global.conf, tmux-user.conf,
  then TPM), theme selection via `@theme`, pinned hex rather than ANSI slot names (slot
  names resolve against the terminal palette, which is how the active window ended up at
  1.19:1), lineless pane dividers marked by fill, the word-separator generator, the
  persist-autosave systemd timer, and the EL8 portability verdict. Every `source-file` is
  deliberately WITHOUT `-q`, so a missing file fails loudly — a misnamed theme file once
  meant no theme loaded at all and a reboot reverted the bar. Reload with
  `tmux source-file`, never a server restart.
- `build-caches.md` for compile-time caching: ccache through makepkg's `BUILDENV`
  (PATH-based, so it covers cmake/meson/autotools inside a build for free), sccache as
  cargo's `rustc-wrapper`, and Go's built-in `GOCACHE`. Includes the cache-size budget
  on `/` and the false negatives that look like "the cache is broken" ("called for
  link", and sccache's config being TOML rather than JSON). Also the linker: mold is
  wired for cargo and is the only LTO-safe fast linker here (lld fails on GCC LTO
  objects), and ninja is installed but measured as a tie with make.

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
  command line. Prefer exact process names or explicit PIDs. A bracket pattern
  such as `pgrep -f '[f]onttest.sh'` is the reliable way to search without
  matching yourself; I SIGTERM'd my own shell with a plain `pgrep -f` loop
  before writing this rule the second time.
- Never invoke bare `wezterm-gui` from a shell. A Dec 2019 loadout wrapper in
  `~/.local/bin` shadows the real binary and SIGSEGVs in
  `libnvidia-egl-wayland2`. Use `wezterm start` or `/usr/bin/wezterm-gui`.
- Editing `~/.config/wezterm/wezterm.lua` and touching the file **does apply
  live** to already-open windows -- but only when the config loads cleanly.
  Repeated hard errors leave a window frozen on its old config until a restart.
  That distinction is the whole trap: a stale window looks exactly like a broken
  config. Check the log first
  (`/run/user/1000/wezterm/wezterm-gui-log-<gui-pid>.txt`), then judge by
  measurement (`wezterm cli list` cols/rows, or px/cols from `xwininfo`), not by
  eye. `wezterm cli spawn --new-window` and `wezterm cli kill-pane --pane-id N`
  are the tools for driving windows from a shell; KWin scripting via
  `qdbus6 org.kde.KWin /Scripting ...loadScript` can resize them.
- Change wezterm font knobs (size / leading / family) only via
  `~/.local/bin/wezterm-tune`, which rewrites `~/.config/wezterm/tuning.lua` and
  touches `wezterm.lua` to reload. Do **not** use
  `window:set_config_overrides({font_size = N})`: mixed with wezterm's built-in
  `Increase/DecreaseFontSize` it renders a size that matches neither the request
  nor the config (asking for 20pt after one built-in increase produced ~22.5pt),
  and it was not reproducible between runs. The knob key bindings deliberately
  shadow the built-ins so only one mechanism is ever in play.
  `~/.cache/wezterm-tune.log` is what proves a keybinding actually reached the
  tuner.
- `return config` must stay the last statement in `wezterm.lua`. Both `>>` and
  `sed -i "${N}r file"` insert *after* the addressed line, so inserting before
  `return config` needs `sed -i "$((N-1))r file"`. The failure is loud in the
  GUI log (`<eof> expected near ...`) and silent in the UI (wezterm falls back to
  builtin defaults), so always read the insertion point back with `grep -n`
  before touching the config.
- Any long unattended or screen-grab-based work must inhibit idle first. A
  DPMS-blanked display returns black captures, which silently invalidates every
  screen-grab check. PowerDevil is the only idle manager here
  (`custom-idle.service` and `hypridle` are disabled), so use
  `systemd-inhibit --what=idle:sleep --mode=block ... sleep N` plus a
  FreeDesktop `ScreenSaver.Inhibit` cookie. `SetActive(false)` is *not* an
  inhibition mechanism.
- Preserve unrelated local changes. This repo commonly has many unstaged
  documentation files.

## Record Net State, Not the Install/Remove History

A `.desktop` note or a package row should read as **"this is what is true now"**,
not as a diary. When something was installed and then later removed for ordinary
reasons, delete the install record entirely — do not leave a section that
documents installing a thing that is not there. A reader reconstructing this
machine should never have to replay a removal to learn that the thing is absent.

The one exception is a **noteworthy bug or blocker that caused the removal**. Keep
that, because it prevents the mistake from being repeated, but record it as a
prohibition rather than as chronology. `asusctl` is the pattern: it is not
installed, the section is titled "Do not install asusctl or rog-control-center",
and it explains the hardware mismatch and the `shelly install` command that would
reintroduce them. It does not narrate the install.

The same applies to the *shape* of a note:

- Prefer "X is the active Y; do not install Z, because …" over
  "installed Z; then removed Z".
- Where a later change supersedes an earlier one, mark the stale reference
  inline rather than leaving two contradictory instructions in the file.
  Superseded filenames get an explicit "this no longer exists" pointer.

### Distinguish a documented undo from an applied removal

This is the single easiest way to misread this repo. Every install is required to
record its **undo command** as a replayable pair, so `sudo pacman -Rns <pkg>`
appears constantly. That line is usually **the documented rollback, not a record
of a removal that happened.**

`pacman -Q <pkg>` decides it. `okular`, `pinta`, `klayout`, `graphviz`, `zed`,
`gwenview`, `earlyoom` and many others appear in this repo as both `-Syu` and
`-Rns`, yet all are installed right now — the `-Rns` is their undo line. Before
concluding that anything was removed, check the live system; a user-local or
cargo install will not show up under `pacman -Q` at all (`tmux`, `btm`,
`nvglances`, `yq` are all `~/.local/bin` or `~/.cargo/bin` binaries).

Verify against the machine before writing any of this down. Also beware the two
shell traps that produced the most false findings during the 2026-10-04 review:
`test -e '~/.config/x'` does **not** expand the tilde inside single quotes, and
`pacman -Qq` on a cargo-installed tool reports "absent" for a tool that is
present and on `PATH`.

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
- Every install and every uninstall must be recorded as a **replayable command
  pair** — the exact command(s) to redo it and the exact command(s) to undo it,
  in order. The goal is rebuilding this machine from scratch by reading the log
  top to bottom, never from memory. A change that cannot be undone on paper is
  not finished.
  - Pacman installs: record the full `sudo pacman -Syu --noconfirm <pkgs>` line
    plus `sudo pacman -Rns <pkgs>`, and the pre/post snapper numbers.
  - User-scope installs (flatpak, cargo, npm, pipx, from-source, tarballs) get
    extra care precisely because there is **no snapper fallback**: name the
    uninstall explicitly, and for flatpak also cover the remote and any now
    unused runtimes. Note the disk footprint if it is large.
  - If a package was removed again later, log the removal as its own entry
    rather than editing the original one. `customizations.md` is append-only.
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
