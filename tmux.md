# tmux

Operational state for the tmux setup. Read this before touching
`~/.config/tmux/tmux.conf`. The reasoning behind the current values is in
`customizations.md` under the 2026-10-01 entries.

Version: tmux 3.7b. Prefix is `C-\`.

## Files

- `~/.config/tmux/tmux.conf` — the config. `~/.tmux.conf` is a **symlink** to it, so
  editing `~/.tmux.conf` and editing the real file are the same thing.
- `~/.config/tmux/tmux.conf.bak-<timestamp>-<tag>` — dated backups. The one that
  precedes the 2026-10-01 status-bar work is `…-20261001-224614-prebar`.
- `~/.config/tmux/` also holds helper scripts: `shell-state-export.sh`,
  `tmux-3col-layout.sh`, `tmux-popin.sh`, `tmux-popout.sh`, `tmux-word-separators`.
- Plugins live in `~/.tmux/plugins/`: `tpm`, `tmux-resurrect`, `tmux-continuum`,
  `tmux-yank`, `tmux-better-mouse-mode`.

## Live state (verified via `tmux show-options -g`, not assumed)

    status bar        fg #a6adc8  bg #1a1d2b         7.52:1    slate blue
    session chip      fg #11111b  bg #89b4fa        8.91:1    blue block
    active window     fg #11111b  bg #89b4fa bold   8.91:1    blue block
    inactive window   fg #7f849c  bg #1a1d2b         4.53:1
    activity flag     fg #fab387  bg #1a1d2b         9.46:1    peach
    bell flag         fg #f38ba8  bg #1a1d2b bold    7.23:1    red
    pane borders      fg #43704d                     3.66:1    dark green, single
    active pane border fg #43704d bg #090909
    active pane fill  window-active-style bg #090909 1.055:1

Window formats carry `#I:#W` only — deliberately no `#F`. See "Flag clutter" below.

## Why the colours are literal hex, not ANSI slot names

The bar used to be `status-style bg=green` (tmux's own default, never chosen) with
`window-status-current-style "fg=white bg=blue"`. Those are ANSI slot names, and tmux
resolves them against the **terminal's palette**. Under catppuccin mocha that made
`white` `#bac2de` and `blue` `#89b4fa` — both light — so the active window rendered at
**1.19:1**. Effectively invisible.

Literal hex means the bar and the grid look identical on every machine this config is
carried to, whatever that terminal's palette happens to be. That is the point: this
config is shared across systems.

The one value that is *not* portable is the active-pane fill. `#090909` is only "slightly
above the background" where the terminal background is actually `#000000` (alacritty pins
it there). On a terminal whose background is `#282c34` the fill is *darker* than the
background and the active pane reads as a sunken hole rather than a raised block. tmux has
no "background + 8" operator, so this needs a per-system value or omitting `window-active-style`
entirely.

## Active pane: two cues, and each has a hole

The active pane is marked by a **raised fill** (`window-active-style`) and by its border
carrying the fill colour behind the line. Neither is sufficient alone:

- **The fill is masked by any program that paints its own background.** It only exists on
  cells the program leaves at the terminal default. An `nvim` pane — or any full-screen
  TUI with its own bg — shows *none* of it. On this machine that is easy to miss, because
  the fill and the border cover for each other; a pane running a colourised editor has
  only the border.
- **The border is a 1px line.** It is legible here but it is thin by design.

If the cue ever needs to be unambiguous regardless of colour perception, the lever not yet
tried is `pane-border-status top` plus a `pane-border-format` that inverts the active
pane's title. It costs a row of height per pane, so the layout shifts.

## The border line is drawn whenever `fg` != `bg`

Setting `pane-active-border-style "fg=#090909 bg=#090909"` does **not** remove the line —
tmux still draws the box-drawing glyph, it is simply painted the same colour as the cell
behind it. `fg` controls the line; `bg` fills the cell. This was mistaken for "the line
cannot be kept" once, during a round of colour experiments; it can.

Verified by a 1-pixel scan across the active pane's left edge, which reads:

    [ #000000 neighbour ][ #090909 bg ][ 1px #43704d ][ #090909 bg ][ pane content ]

## Flag clutter

`#F` in a window format expands the window flags. Its contributions were:

- `*` current marker — redundant once the current window is a filled blue block
- `-` last-used marker — removed on request; it is just noise in a status line
- `#` activity — **cannot fire**: `monitor-activity` is off
- `!` bell — **cannot fire**: `bell-action` is none, even though `monitor-bell` is on

So `#F` was contributing only `*` and `-`. Both formats are now plain `#I:#W`. If activity
or bell monitoring is ever turned back on, re-add just that flag with a conditional, e.g.
`#{?window_bell_flag,!,}`. Zoom is covered by the separate `ZOOM` indicator on the right
(`status-right`), not by `#F`'s `Z`.

## Traps

**A comma inside `#[...]` nested in `#{?...}` leaks literal text.** The conditional splits
its own arguments on commas and does not protect the bracket. Writing

    #{?client_prefix,#[fg=#11111b bg=#fab387,bold],...}

puts a stray `bold]` on the status line. Space-separate the attributes inside `#[...]`
instead; tmux accepts either separator. This is documented inline in the config too.

**`status-right` is injected by tmux-continuum at runtime.** The plugin prepends its
`#(...continuum_save.sh)` call, so `set -g status-right ""` in the config does not result
in an empty `status-right`. The save script emits nothing, so it is invisible — but
`status-right-length` is budgeting for it as well as for anything you add. Expect
`tmux show-options -g status-right` to show the script even when the config does not.

**Reload with `tmux source-file`; never restart the server.** tmux has no auto-reload
(the `live_config_reload` option in `alacritty-terminal.md` is alacritty's, not tmux's), so a
running server keeps its current options until you `source-file`. Killing the server kills
the panes you are working in. An invalid config is rejected by
tmux's own validation and the running instance keeps the previous one, so a bad edit cannot
wedge a live session — but a stale running server will not show a config file edit until
you `source-file` it. Check with `tmux show-options -g <option>` rather than trusting the
file.

**A running server can be older than the config.** `tmux display-message -p '#{pid}'` plus
`ps -o lstart=` against `stat` on the file. Observed here: server started 09:46:43, config
written 09:54:12, so the live options did not match the file at all until a `source-file`.

## Verifying colour changes

Contrast is measured from a real screen grab, not from the config:

- Crop the bar or the border region and convert to text with
  `magick <png> txt:-`, then compute WCAG contrast in a script. `magick` is present;
  PIL and numpy are not available in the agent sandbox.
- Colour census over a grab catches "did it apply at all":
  `magick <png> -format '%c' histogram:info:-`.
- Locate a border precisely by scanning a column range and counting exact colours.
  Integer cell arithmetic drifts — use `round(cell * width / total_cells)`, not
  integer division, or you will sample the wrong column (this produced a confidently
  wrong "the border is not drawn" reading once).

## Capturing the terminal

**`shot.sh window` grabs whatever has focus.** It captured Firefox while the terminal was
backgrounded, and the resulting image was sharp and plausible. Always confirm from the
image that it is the window you asked for.

The focus-independent path on this machine is **`spectacle -m`** — current monitor,
no focus requirement:

    spectacle -m -b -n -o /tmp/mon.png

It writes a real file (3440x1440 here). Validate the artifact anyway: `spectacle -f`
exits 0 and writes *no file at all*.

`region`, `app` and `full` modes of `shot.sh` cannot work here — `xwininfo -root` reports
`0x0` geometry.

## Rollback

Restore the pre-change config and reload:

    cp ~/.config/tmux/tmux.conf.bak-20261001-224614-prebar ~/.config/tmux/tmux.conf
    tmux source-file ~/.config/tmux/tmux.conf

To revert only the active-pane fill, delete the `window-active-style` line. To revert only
the bar colour, set `status-style` back to `"fg=#a6adc8 bg=#11111b"` **and** the three
`window-status-*-style` backgrounds with it — they are separate hard-coded copies and will
show as dark patches if changed alone.
