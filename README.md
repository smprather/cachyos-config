# cachyos-config

Notes for tracking this CachyOS installation: problems, diagnosis, solutions, and customizations.

The primary purpose of this repository is fast reconstruction. Starting from a
fresh CachyOS installation, an AI agent should be able to use these notes to
restore the intended desktop, tools, services, and behavior without repeating
the original investigation. Records should therefore capture the desired end
state, exact commands and files, verification, rollback, and any non-obvious
reasoning needed to avoid known integration failures.

## Notes

- [Customization log](customizations.md) — dated, append-only record of every change made
- [System inventory](system-inventory.md) — hardware, session, privileges, repositories, operational rules
- [Desktop environments](desktop-environments.md) — Plasma, GNOME, Hyprland and COSMIC side by side behind greetd
- [Passwordless login](passwordless-login.md) — the full no-password chain, its tradeoffs, and every rollback
- [Chrome browser notes](chrome-fixes.md) — Stable Chrome state, legacy Canary fixes, and NVIDIA GPU playback notes
- [Keyboard remapping](keyboard-remapping.md) — global keyd Caps Lock tap=Escape, hold=Control; DE-specific mappings removed
- [Screen capture](screen-capture.md) — silent PrintScreen region capture to a PNG and the Wayland clipboard
- [Foreign binary compatibility](foreign-binary-compat.md) — running EL8-built binaries on Arch/CachyOS
- [Power and idle](power-idle-suspend.md) — five-minute monitor powerdown, manual-only suspend, preserved custom idle source, and the instant-wake sleep-hook fix
- [Suspend, clock, uwsm](suspend-clock-uwsm-fixes.md) — uwsm login crash (bashrc guard), dual-boot RTC local time, wake diagnostics
- [Shell startup quirks](shell-startup-quirks.md) — PS0/systemd OSC hook, uwsm interaction, pkill self-match hazard
- [Hyprland: lua wrapper and HyDE](hyprland-cachyos-lua-hyde.md) — CachyOS lua config system, HyDE overlay lessons
- [EL8 GUI apps](el8-gui-apps.md) — Firefox ESR and wezterm: bundled sonames, lib64 shadowing, NSS trust proxy
- [GNOME configuration](gnome-configuration.md) — keyboard repeat, FancyZones-style drag tiling, an ungrouped current-workspace taskbar, GNOME Tweaks runtime isolation, and Python-tool installation policy
- [DeepSeek Harness](deepseek-harness.md) — the `dsh` agent harness: npm install, provider routes to Ollama Cloud/OpenRouter, profile modes, and the no-TUI finding
- [tmux](tmux.md) — the layered config and `@theme` selection, pinned-hex status bar, lineless pane dividers marked by fill, the word-separator generator, the persist-autosave systemd timer, and the EL8 portability verdict
- [Engineering Loadout relocation](engineering-loadout-path.md) — why loadout tools shadowed coreutils/bash/node, relocating EL to `~/.loadout` with `--dest-dir`, the distribution-first PATH policy, and the persistent `dest_dir` config

## Provenance

`desktop-environments.md`, `passwordless-login.md`, `system-inventory.md`,
`foreign-binary-compat.md`, and the 2026-08-31 section of `customizations.md`
were extracted on 2026-09-02 from Claude Code session transcripts under
`~/.claude/projects/`:

- Session `4b3b874f` (2026-08-31, `~`) — Plasma completion, desktop coexistence,
  passwordless login chain.
- Session `c6cff390` (2026-08-29, `~/dev/engineering-loadout`) — EL8 binary
  compatibility findings on CachyOS.

The session that produced `chrome-fixes.md` and the 2026-09-01 entries in
`customizations.md` is no longer on disk; only `~/.claude/session-env/` stubs
remain for it. Those two files were its sole surviving record before later
updates documented the Chrome Stable migration and Plasma playback findings.

`power-idle-suspend.md`, `suspend-clock-uwsm-fixes.md`,
`shell-startup-quirks.md`, `hyprland-cachyos-lua-hyde.md`, `el8-gui-apps.md`,
and the 2026-08-30 section of `customizations.md` were extracted on
2026-09-02 from the opencode session database
(`~/.local/share/opencode/opencode.db`), searching all sessions across all
directories:

- Session `ses_fab678caf` (2026-08-30, `~`) — Hyprland monitor powerdown,
  hypridle → custom idle daemon, HyDE install and keybind/focus fixes.
- Session `ses_fabc8fb2` (2026-08-30, `~`) — uwsm session crash, dual-boot
  RTC clock, suspend instant-wake fix.
- Session `ses_fab71abe` (2026-08-30, `~/dev/engineering-loadout`) — PS0
  systemd OSC hook fix, Firefox ESR universal-host fixes, pkill hazard.
- Session `ses_fa26697` (2026-09-01, `~/dev/engineering-loadout`) — EL8
  build-box mandate, cross-compile findings (context for
  `el8-gui-apps.md`).
