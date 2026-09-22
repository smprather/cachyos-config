# Hyprland on CachyOS — Lua Wrapper and HyDE Lessons

The CachyOS Hyprland edition's configuration system, and what happened when
a pre-packaged config (HyDE) was layered on top. From opencode session
`ses_fab678caf...` (2026-08-30). The box has since settled on Plasma/GNOME
sessions ([desktop-environments.md](desktop-environments.md)); this file
preserves the Hyprland knowledge for whenever Hyprland is used again.

## The CachyOS lua wrapper

CachyOS's Hyprland edition does not use stock `hyprland.conf`. Instead:

- Entry: `~/.config/hypr/hyprland.lua` — loads modules from
  `~/.config/hypr/config/*.lua` (`binds.lua`, `inputs.lua`, `misc.lua`,
  `environment.lua`, ...)
- Configs auto-reload on save; no `hyprctl reload` needed (hypridle and
  other daemons still need restarts).
- Dispatcher syntax differs from upstream docs:
  `hyprctl eval 'hl.dispatch(hl.dsp.dpms({action="off"}))'` rather than
  `hyprctl dispatch dpms off`.
- Cachy binds worth knowing (they override HyDE's):
  - `Super + T` = text EDITOR (`gnome-text-editor`) — NOT terminal
  - `Super + Return` = terminal (kitty)
  - `Alt + Tab` = `hl.dsp.window.cycle_next()` (via `binds.lua:22`)
  - `Super + Tab` = noctalia window-switcher OSD
- Input tweaks lived in `config/inputs.lua`: `repeat_rate = 30`,
  `repeat_delay = 200`, `accel_profile = "flat"`, `follow_mouse = 1`. The
  older `kb_options = "ctrl:nocaps"` Caps Lock mapping was removed on
  2026-09-07; Caps Lock is now handled globally by keyd.
- No `systemsettings` GUI exists for Hyprland — config is text by design.
  Community GUIs (`hyprgui`, `nwg-displays`) cover only fractions.

Implication: 99% of community dotfiles and wiki pages assume
`hyprland.conf` syntax and don't drop in cleanly.

## HyDE experiment (installed 2026-08-30, later de-hybrided)

HyDE (`HyDE-Project/HyDE`) is the most polished pre-packaged Hyprland config
— includes a keybind cheatsheet overlay, waybar, rofi, pyprland. Installed
here via `~/HyDE/Scripts/install.sh`, integrated through a patched
`hyprland.lua` loading `~/.local/share/hypr/hyde.lua`.

### Why it hurt here but not for its community

HyDE targets clean Arch minimal (archinstall + installer on an empty
system): SDDM, no lua wrapper, no noctalia, pipewire-jack, no existing
hypridle. This box layered it over CachyOS's existing Hyprland (lua
wrapper, greetd + noctalia, custom idle scripts) — an integration project,
not an install. Known papercuts from the pairing:

- `pipewire-jack` vs `jack2` conflict — fixed with
  `yes | pacman -S pipewire-jack`, removing `jack2`.
- Python SSL: portable python expected
  `/opt/cpython3144-portablelib/ssl/cert.pem`; fixed by symlinking to
  `/etc/ssl/certs/ca-certificates.crt`.
- `Super + .` = glyph picker and `Super + T` = editor (Cachy binds win over
  HyDE's), `Super + A` = rofi app finder (not `Super + R` as docs suggest).
  Keybind cheat overlay is generated and incomplete — `hyprctl binds` and
  `~/HyDE/KEYBINDINGS.md` are the reliable source.
- HyDE's `altab` shows a screenshot-preview notification bubble per
  Alt+Tab. Disabled via `hl.env("ALTAB_NOTIFY", "0")` in
  `~/.config/hypr/config/environment.lua` (also `ALTAB_CAPTURE=0` if the
  capture overlay annoys).
- `follow_mouse = 1` + HyDE altab = focus bounces back to the window under
  the cursor after Alt+Tab. `follow_mouse = 0` makes Alt+Tab stick but kills
  mouse-follow. Patched HyDE's `~/.local/lib/hyde/altab/hyprland.lua`
  (`hypr.focus_addr`) to warp the cursor to the target window's center —
  the warp bounced back to the ORIGINAL window's center; a real upstream bug
  (issue drafted, not confirmed filed). Workaround: choose — follow_mouse
  or sticky alt-tab, not both.
- Going "all-in HyDE" (dropping the Cachy `config/` dir from
  `hyprland.lua`) silently loses Cachy input/session tweaks such as repeat
  rate, DPMS wake, `follow_mouse`, and `ALTAB_NOTIFY`. Any switch like this
  needs a diff-against-backup pass to restore personalizations. Caps Lock is no
  longer a Hyprland-specific tweak; see
  [keyboard-remapping.md](keyboard-remapping.md).
- HyDE `waybar` doesn't auto-start reliably after config flips
  (`waybar.py --update` / `hs.bar` on session start only).
- Updating HyDE (`install.sh -r` / `hyde-shell update`) re-overwrites
  `hyprland.conf`, `hypridle.conf`, and the like — every custom patch needs
  re-applying. Backups land in `~/.config/cfg_backups` and
  `~/.local/share/deez/backup`.

### Session at login

CachyOS uses **greetd + noctalia**, not SDDM. HyDE's docs assume SDDM, but
it works fine under greetd — the session is `hyprland.desktop`
(`Exec=/usr/bin/start-hyprland`) and HyDE hooks in via the lua loader. A
`Hyprland (uwsm-managed)` entry also exists — see
[suspend-clock-uwsm-fixes.md](suspend-clock-uwsm-fixes.md) for the uwsm
crash fix.

### Backups from that day

- `~/.config/hypr.bak.20260830_1809` — pre-HyDE Cachy Hyprland config
- `~/.config/hypr/config.cachy.bak`, `~/.config/hypr/hyprland.lua.cachy.bak`
  — from the all-in flip
- `~/HyDE/` — the cloned HyDE repo + `KEYBINDINGS.md`

## Useful Hyprland commands

```bash
hyprctl reload                     # manual reload (lua wrapper: usually unneeded)
hyprctl binds                     # list active binds — the reliable source
hyprctl getoption input:follow_mouse
hyprctl getoption misc:mouse_move_enables_dpms
hyprctl dispatch dpms off          # plain dispatcher
hyprctl eval 'hl.dispatch(hl.dsp.dpms({action="off"}))'  # lua-wrapper form
hyprctl monitors                   # includes dpmsStatus
hyprctl cursorpos
```

## Verdict recorded at the time

HyDE-on-Cachy works but stays a moving target (127 open issues, weekly
ships, lua API churn). The box's picky suspend policy already lives outside
the DE (see [power-idle-suspend.md](power-idle-suspend.md)), which is the
right call for agent-heavy usage. If Hyprland returns: either stay pure
Cachy lua wrapper, or go clean-Arch + vanilla `hyprland.conf` — hybrid
layering is where all the friction lived.
