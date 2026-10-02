# alacritty ("atty") as the daily terminal

Operational state for the alacritty setup. Read this before touching it, and before
re-deriving anything — the reasoning is in `customizations.md` under the 2026-09-30 entries.

**RESUME POINT: palette tuning.** Everything else below is done and verified.

## Why alacritty

wezterm shaves the top of round glyphs at scattered point sizes (13pt clean, 14pt not; good
and bad sizes are not monotonic). Measured across terminals on identical text, pure black
backgrounds: wezterm shaves, **alacritty does not at any size tested**, kitty shaves the
bottom of `g`, ghostty was fine by eye. Hence the switch. Do not re-litigate wezterm's font
config — hinting on/off, load targets, dpi and size sweeps were all tried and the defect
survives them.

## Files

- `~/.config/alacritty/alacritty.toml` — the config. Contains the wezterm mapping, the
  black-background pin, and the mouse bindings.
- `~/.config/alacritty/themes/*.toml` — 7 palettes (6 downloaded + the original noctalia).
- `~/.local/bin/alacritty-theme` — the palette switcher.

## Live state (verified via `get-config`, not assumed)

    background     #000000      (pinned by override, overrides the theme)
    foreground     #cdd6f4      (from the imported theme, NOT overridden)
    normal.black   #45475a      (visible on pure black)
    font           Hack Nerd Font Mono 13.0, offset y=2
    window         padding 2/2, dynamic_padding false, opacity 1.0
    import         themes/catppuccin_mocha.toml

## Verify a change actually applied

Live reload is on, so no restart is ever needed — **never `pkill alacritty`**; that kills the
instance being worked in and is unnecessary. To read back what the running instance resolved:

    S=$(ls -t /run/user/1000/Alacritty-*.sock | head -1)
    alacritty msg -s "$S" get-config

Notes that will otherwise waste time:

- Plain `alacritty msg` fails with *"no socket found"* from a shell that is not a child of the
  instance, because it depends on `ALACRITTY_SOCKET`, which alacritty only exports to its own
  children. The socket must be globbed/passed explicitly: `Alacritty-wayland-0-<pid>.sock` on
  Wayland, `Alacritty-:0-<pid>.sock` on X11.
- `get-config` **omits `bindings`** — `"keyboard":{}` and a `mouse` section with only
  `hide_when_typing` are normal serialization, not a config failure.
- An invalid config is rejected by alacritty's own validation and the running instance keeps
  its previous config, so a bad edit cannot wedge a live terminal. A *fresh* instance is what
  reports config errors, so validate by launching `alacritty -e sleep 10` and reading stderr.

## Palettes

Switch live with `~/.local/bin/alacritty-theme <name> | next | prev | --verify`. It rewrites
the single `import` line atomically and never restarts anything.

Installed, with the values that matter for a pure-black background (`colors.normal.black`):

    catppuccin_mocha  bg #1E1E2E  fg #CDD6F4  black #45475A  ok
    tokyo_night       bg #1a1b26  fg #a9b1d6  black #32344a  ok
    noctalia          bg #131318  fg #e4e1e9  black #46464f  ok
    one_dark          bg #282c34  fg #abb2bf  black #1e2127  RISK
    gruvbox_dark      bg #282828  fg #ebdbb2  black #282828  RISK
    kanagawa_wave     bg #1f1f28  fg #dcd7ba  black #090618  RISK
    dracula           bg #282a36  fg #f8f8f2  black #000000  INVISIBLE (= the background)

RISK means ANSI "black" text becomes hard to see, or invisible, against the pinned
`#000000`. Fix for those, if one is adopted:

    [colors.normal]
    black = "0x4a4a4a"

**Why the background is an override rather than a theme choice:** a theme's own background
only applies while it is imported, and every dark theme here is `#131318`–`#282c34`. Pinning
`[colors.primary] background` in `alacritty.toml` means trying a new palette changes only the
ANSI colours. `foreground` is deliberately left unset so the theme supplies it. A swatch sheet
of all 7 is at `~/Pictures/alacritty-palettes.png` (generated; regenerate if themes change).

## Mouse bindings (already correct — do not "fix" them again)

    bindings = [
      { mouse = "Middle", mods = "None",  action = "PasteSelection" },
      { mouse = "Right",  mods = "Shift", action = "Paste" },
    ]

Required behaviour: bare right-click goes to the application (tmux), Shift+right-click is the
terminal pasting. Alacritty's `process_mouse_bindings` already does this: **in mouse mode a
binding fires only while Shift is held**, so a bare right-click matches nothing and is
forwarded. Binding `mods = "None"` here would be WRONG — it would fire on the bare click and
steal it from tmux. Outside mouse mode a bare right-click still does the built-in
`Right -> ExpandSelection`.

## Not verified, and why

Behaviour of the mouse bindings. `get-config` omits bindings and there is no pointer injection
on this box (no xdotool/ydotool; KWin scripts cannot synthesise input). Syntax is validated;
the click needs a human.

## Rollback

- `~/.config/alacritty/alacritty.toml.pre-wezterm-map.20260930-1405` — pre-mapping state
  (Nord palette, 0.8 opacity, `monospace` font).
- To unpin the background: comment out `background` under `[colors.primary]`.
- To drop a palette: point `import` back at `themes/noctalia.toml`, or run
  `alacritty-theme noctalia`.

## Adjacent state (different work, still in place)

- KWin focus-follows-mouse delay: `[Windows] DelayFocusInterval = 300` in kwinrc. Fixes the
  Plasma launcher closing on a 1px pointer overshoot. There is no per-app/per-type alternative
  — see `customizations.md` for the source-level reason.
- wezterm is still installed and configured (`~/.local/bin/wezterm-tune`, currently 8pt) but is
  no longer the intended daily driver.
