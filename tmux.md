# tmux

Operational state for the tmux setup. Read this before touching anything under
`~/.config/tmux/`. The dated reasoning is in `customizations.md`.

Version here: tmux 3.7b. Prefix is `C-\`.

## Files — it is a LAYERED config, not one file

`~/.config/tmux/tmux.conf` is a 12-line **dispatcher** that sources four layers
and then TPM. `~/.tmux.conf` and `~/.tmux` are both symlinks into this directory
(`~/.tmux` → `.config/tmux`, so `~/.tmux/plugins` IS `~/.config/tmux/plugins`).

    tmux.conf                  dispatcher: sources the four layers below, then TPM
    tmux-settings-global.conf  settings layer 1 — MANAGED baseline (@theme loadout1)
    tmux-settings-user.conf    settings layer 2 — user choice, WINS (@theme loadout2)
    tmux-global.conf           the bulk: bindings, plugin declarations, theme hook
    tmux-user.conf             user overrides (currently only comments)
    themes/tmux-theme-*.conf   the colour/style definitions themselves
    word-separators.conf       GENERATED — do not edit by hand
    scripts/                   helpers + the separator generator

Sourcing order matters: settings layers first (so `@theme` exists before
`tmux-global.conf` needs it), then the global layer, then the user layer, then
TPM. `tmux-global.conf` deliberately does **not** source any settings file —
doing so re-applied the user layer from inside the managed layer and made the
ordering meaningless.

## Theme selection

`@theme` names a file: the value is interpolated into
`themes/tmux-theme-<value>.conf`. Two exist:

    loadout1   the original pre-2026-10-01 theme. ANSI slot names, so it resolves
               against the TERMINAL palette; under catppuccin mocha the active
               window renders at 1.19:1 — effectively invisible.
    loadout2   current. Pinned literal hex.

Change it in **`tmux-settings-user.conf`** (not the global one, which is the
baseline and is overridden). `@theme` is re-declared every time the settings
layer loads, so `set -g @theme` at runtime never sticks.

Check what resolved with `tmux display-message -p '#{@theme}'` —
`tmux show-options -g @theme` errors with "invalid option".

## Live state (verified via `show-options`, not assumed)

    status bar        fg #cdd6f4  bg #10173a         12.04:1   dark blue
    session chip      fg #11111b  bg #89b4fa bold    8.91:1    blue block
    active window     fg #11111b  bg #89b4fa bold    8.91:1    blue block
    inactive window   fg #a6adc8  bg #10173a         7.82:1
    activity flag     fg #fab387  bg #10173a         9.84:1    peach
    bell flag         fg #f38ba8  bg #10173a bold    7.52:1    red
    pane borders      fg #090909  bg #090909                   NO visible line
    active pane fill  window-active-style bg #090909 1.055:1
    pane-border-lines heavy   (no visual effect while fg == bg)
    pane-border-indicators off
    word-separators   14206 bytes (generated)
    TMUX_PLUGIN_MANAGER_PATH  ~/.tmux/plugins/

Window formats carry `#I:#W` only — no `#F`. See "Flag clutter" below.

## Why literal hex, not ANSI slot names

The bar used to be `status-style bg=green` (tmux's own default, never chosen)
with `window-status-current-style "fg=white bg=blue"`. Those are ANSI slot names,
which tmux resolves against the **terminal's palette**; under catppuccin mocha
`white` and `blue` are both light, so the active window rendered at **1.19:1**.
Literal hex makes the bar and grid identical on every machine this config is
carried to, whatever the local palette is.

The one non-portable value is the active-pane fill: `#090909` is only "slightly
above the background" where the background is actually `#000000`. On a terminal
whose bg is lighter it reads as a sunken hole. tmux has no "background + 8"
operator, so that needs a per-system value or dropping `window-active-style`.

## Pane appearance: no visible line, dividers by fill

Both border styles set `fg` and `bg` to the same colour, so the box-drawing glyph
is painted in the colour of the cell behind it and vanishes. The border CELL is
still filled — with `#090909`, the active pane's own fill colour — so the divider
reads as a faint band against the `#000000` panes.

Accepted consequence: the active pane's fill is the same `#090909`, so it merges
with the divider network and has no boundary of its own. It stays identifiable
(interior `#090909` vs inactive panes' `#000000`) but nothing marks where it ends.

**The fill is masked by any program that paints its own background** — it only
exists on cells a program leaves at the terminal default, so an `nvim` pane shows
none of it, and with no line drawn there is no fallback cue in such a pane.

`pane-border-lines` has no visual effect while `fg == bg`. `heavy` is kept so
that restoring a visible line starts from the thick one (measured when a line WAS
visible: `single` = 1px strokes, `heavy` = 2px).

## Word separators

tmux takes a **literal** character list — no Unicode class, no ranges, no loops.
Anything absent counts as word material, so prompt icons and TUI rules get
swallowed by double-click selection.

So the ranges live in `scripts/tmux-word-separators` (a bash GENERATOR, run by
hand) and its expanded output is checked in as `word-separators.conf`, which
`tmux-global.conf` sources directly. Reloads therefore spawn no subprocess and
depend on no interpreter.

    ~/.config/tmux/scripts/tmux-word-separators      # regenerate after changing ranges

Result: 3,812 characters / 14,206 bytes — emoji/pictographs, plus the three
contiguous drawing blocks U+2500–U+25FF (box drawing, block elements, geometric
shapes). Regenerating on AlmaLinux 8.10 produced a **byte-identical** file
(sha `4056a921…`), which is what proves the generate path has no host coupling.

## Persist autosave (systemd --user timer)

`tmux-persist` saves on clean detach/exit, so a hard crash while attached never
fires the hook. `theredspoon/tmux-persist-autosave` closes that gap with a real
OS timer.

**It is NOT a tmux plugin** — no `*.tmux` entry point, and upstream's `install.sh`
writes a macOS LaunchAgent. Do not add it to `@plugin`; TPM would clone a repo
that can never run.

    ~/.local/bin/persist-autosave.sh                          (8672 B, sha256 9d09827c…)
    ~/.config/systemd/user/tmux-persist-autosave.service
    ~/.config/systemd/user/tmux-persist-autosave.timer        OnCalendar=*:0/10

The service deliberately does **not** set `PrivateTmp=yes`: the lock and the tmux
socket both live under `/tmp`, and a private `/tmp` would hide them — the script
would find no server and exit 0 having done nothing.

It skips cleanly when there is no tmux server, no plugin, or no `save.sh`. It
sources tmux-persist's own helpers for directory resolution and **aborts loudly**
if their internal function names change upstream, rather than resolving a wrong
path silently. It has a regression guard: a snapshot that suddenly has far fewer
panes than its predecessor is reverted, with the degenerate one kept for
forensics; bypass once with
`touch <persist-dir>/<session>_last.allow_regression`.

## Portability to EL8 (asked and answered)

The config and scripts have **no distro coupling**: zero host/user-specific
paths; only ubiquitous binaries (`tmux bash sh printf grep mktemp dirname date
awk`); all five scripts pass `bash -n` on EL8's bash 4.4; `flock` is mentioned
only in a comment; `readlink` is used without `-f`; lock ages use
`stat -f … || stat -c …` (BSD then GNU).

Requirements on a fresh box, all environmental: a current tmux (the theme uses
`pane-border-indicators` and `pane-border-lines`; authored against 3.7b), the
plugins installed (needs `git`), `nvim` for `bind-key v` only, and a UTF-8
locale (the separator list is box-drawing + emoji).

`systemctl --user` **works on EL8** — systemd 239 ships
`/usr/lib/systemd/system/user@.service` with `ExecStart=-/usr/lib/systemd/systemd
--user`. It fails only in contexts without a user bus (containers, root's shell,
root cron) and needs `loginctl enable-linger <user>` on a headless box.

## Traps

**`source-file` paths are checked, not swallowed.** Every `source-file` in the
tree is deliberately **without `-q`**, so a missing or misnamed file fails loudly.
This is not theoretical: `tmux-global.conf` once built
`themes/tmux_theme_loadout2.conf` while the files had been renamed
`tmux-theme-loadout2.conf`, and with `-q` **no theme loaded at all** — the bar
silently reverted to tmux's default green, and a reboot lost it. With `-q` gone,
a typo in `@theme` is an error instead of a silent no-op.

**A comma inside `#[...]` nested in `#{?...}` leaks literal text.** The
conditional splits its own arguments on commas and does not protect the bracket.
A prefix-indicator chip written that way printed a stray `bold]` on the status
line. Space-separate the attributes inside `#[...]`.

**The path in a `source-file -F` must be quoted.** Unquoted, the `#` in
`#{@theme}` is read as the start of a comment when a CONFIG FILE is parsed and
the line dies with `syntax error`. It works unquoted as a *shell command*, which
is why it is easy to get wrong.

**`tmux source-file`, never a server restart.** tmux has no auto-reload (the
`live_config_reload` option belongs to alacritty, not tmux). An invalid config is
rejected and the running server keeps the previous one.

**A running server can be older than the config.** Compare
`tmux display-message -p '#{pid}'` + `ps -o lstart=` against `stat` on the file.
Observed here: server 09:46:43, config 09:54:12 — live options did not match the
file until a `source-file`.

**Flag clutter.** `#F` contributed only the `*` current marker (the blue block
says that) and the `-` last-used marker. Its other two cannot fire as configured:
`monitor-activity` is off and `bell-action` is none. Zoom is covered by the ZOOM
indicator in `status-right`.

**tmux-persist's autosave needs `$TMUX` or a locale.** With neither, tmux's
format engine silently mangles literal tabs to underscores and every saved layout
comes out empty. The autosave script sets `$TMUX` itself for exactly this reason.

## Verifying a colour change

Measure from a real screen grab, not the config:

- `magick <png> txt:-` then compute WCAG contrast in a script (`magick` is
  present; PIL/numpy are not in the agent sandbox).
- `magick <png> -format '%c' histogram:info:-` for "did it apply at all".
- Locate a border by scanning a column range for exact colours. Use
  `round(cell * width / total_cells)` — integer division drifts (it produced a
  confident false "the border is not drawn").

**Capturing the terminal:** `shot.sh window` grabs whatever has FOCUS, and once
returned a sharp, plausible image of Firefox. The focus-independent path here is
`spectacle -m` (current monitor, 3440x1440):

    spectacle -m -b -n -o /tmp/mon.png

Validate the artifact anyway — `spectacle -f` exits 0 and writes no file at all.

## Rollback

Restore the pre-change config and reload:

    cp ~/.config/tmux/tmux-global.conf.bak-<timestamp>-presource ~/.config/tmux/tmux-global.conf
    tmux source-file ~/.config/tmux/tmux.conf

Theme: set `@theme` back in `tmux-settings-user.conf`. Bar background: the colour
is repeated as `bg=` in three `window-status-*-style` options — change them
together or the bar shows dark patches.

Autosave: `systemctl --user disable --now tmux-persist-autosave.timer` and remove
the three files (see `customizations.md` for the exact pair).
