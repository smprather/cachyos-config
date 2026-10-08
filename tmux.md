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

## Cursor: pinned to a steady block

    set -s cursor-style block        # tmux-user.conf

`cursor-style` is a **server** option (`set -s`, read back with `show-options -s`). It is
the only layer here that can *enforce* a cursor shape: alacritty's `[cursor] style.shape`
is a default an application may override with `DECSCUSR`, and alacritty never re-reads the
shape on a config reload — an already-running window keeps whatever shape it was created
with (measurements in alacritty-terminal.md).

With the option left at `default`, tmux sends nothing for a pane whose app requested no
style, so a stale underline in the terminal is never corrected. Verified both ways: at
`default` the active pane's cursor renders as an 8x1 line; after
`tmux source-file ~/.config/tmux/tmux.conf` the option reads `block` and the same cell
renders an 8x19 filled blob (area 152 = w*h) in the live window.

Rollback: `tmux set -s cursor-style default`, and delete the line.

Requires tmux >= 3.3 (`cursor-style` was added in 3.3 — tmux's CHANGES, entry under
"CHANGES FROM 3.2a TO 3.3"). An older tmux reports the line as an unknown option rather
than ignoring it, which is the same fail-loudly rule the `source-file` lines follow.
`prompt-cursor-style` / `prompt-cursor-colour` are newer still (3.6) and are left at
`default`, so the tmux command prompt is unaffected by this pin.

## Focus follows the mouse (TRIAL, 2026-10-06)

    set -g focus-follows-mouse on     # tmux-user.conf

A **session flag**, not a free-form option: upstream's `options-table.c` (`OPTIONS_TABLE_FLAG`,
scope `SESSION`, default off) says *"Whether moving the mouse into a pane selects it"*, and a
flag takes on/off only — `tmux set -g focus-follows-mouse last` is rejected with
`bad value: last`. Checked against tmux's own source because this box has **no tmux man
page** (`man tmux` -> "No manual entry for tmux").

Prerequisites, both already true here — the option does nothing without them:

- `mouse on` (`tmux-global.conf`): with no mouse events tmux never sees the pointer.
- The window under the pointer already gets focused by KWin
  (`FocusPolicy=FocusFollowsMouse`, `DelayFocusInterval=300` in kwinrc), so the pointer
  entering a tmux pane is both within the focused window and a pane boundary crossing.

What actually changes, and why this is a trial rather than a default:

- Keystrokes go to the pane under the **pointer**, not the last pane clicked. A mouse
  parked over a different pane silently takes your typing — the main risk.
- The drawn cursor is the *active* pane's, so the pinned block hops between panes.
- `tmux-better-mouse-mode`'s `@scroll-in-moused-over-pane on` finally agrees with focus:
  the pane you scroll is now the pane you type into.

Revert: `tmux set -g focus-follows-mouse off` and delete the line.

Verification is necessarily human. **This box has no pointer injection** (no
xdotool/ydotool; KWin scripts cannot synthesise input), so no automated check can move the
mouse. Watch the active pane while moving the pointer:

    while :; do tmux display-message -p '#{pane_id} #{pane_current_command}'; sleep 0.5; done

## Copy-mode: auto-exit at the bottom, and the mouse plugin we removed

Behaviour (2026-10-06): every way of returning to the live bottom leaves copy-mode.
The mechanism is tmux's own `scroll_exit`, and it needed two separate fixes.

**`scroll_exit` is per-copy-mode state, set by `-e` at entry** (`window_copy_init`:
`data->scroll_exit = args_has(args, 'e')`) and honoured by only three paths in
`window-copy.c`: `scroll1`, `pagedown1` and `cmd_scroll_down`. So the entry keys decide
whether page-down works at all:

    bind -T prefix [     copy-mode -e          # and -eu / -de for PPage / NPage

With that, wheel-down, `C-e`, `J`, `PageDown` and `C-d` all exit on reaching the bottom.
Measured in a sandbox: entering *without* `-e` and pressing PageDown left the pane at
`oy=0` with `mode=1` indefinitely — the "I still have to press Enter" symptom. With `-e`:
20 -> 10 -> exit.

**`cursor-down` is deliberately NOT one of those paths**, so `j` and `Down` needed explicit
bindings, guarded on `scroll_position` *before* the move:

    bind -T copy-mode-vi j if -F '#{==:#{scroll_position},0}' \
      'send-keys -X cursor-down' \
      'send-keys -X cursor-down ; if -F "#{==:#{scroll_position},0}" "send-keys -X cancel"'

The pre-move guard is the whole point: without it a first `j` at the bottom — the state
`prefix+[` starts in — cancels immediately and the cursor becomes unusable on the visible
screen. Verified both ways: scrolled, `oy` 15 -> 10 -> 5 -> exit on the press that reaches
0; entered at the bottom, five presses leave `mode=1, oy=0, cy=11`. `G` (`history-bottom`)
gets the same treatment since it is outside the scroll_exit paths too.

### The plugin this replaced

`nhdaly/tmux-better-mouse-mode` owned the wheel; it is gone from `tmux-global.conf` and the
bindings are ours in `tmux-user.conf`. Two reasons:

- **Its first wheel-up did not scroll.** It entered copy-mode and then relied on
  `send-keys -M` re-injecting the wheel event to do the scrolling, and that re-injection does
  not scroll the event that *enters* the mode. The replacement scrolls explicitly in the same
  event: `copy-mode -e -t= ; send-keys -t= -X -N 3 scroll-up`.
- **Ordering.** `tmux-user.conf` is sourced before TPM loads plugins, so a plugin binding
  silently overrode anything set there. With no plugin, nothing fights the user layer.

Reimplemented from it: the alternate-screen arrow-key emulation (`#{alternate_on}` -> three
`up`/`down` keys), `-t=` targets so wheeling does not change the active pane, and the
3-lines-per-notch speed (stock tmux uses 5). Its root `pane_in_mode` branch is kept verbatim:
it may be unreachable when tmux routes mouse events to the mode table first, but a wheel
event cannot be synthesised on this box, so it was left as it was rather than changed on a
guess. The checkout at `~/.tmux/plugins/tmux-better-mouse-mode` is inert.

Undo: re-add `set -g @plugin 'nhdaly/tmux-better-mouse-mode'` to `tmux-global.conf` with its
three `@options`, run `prefix+I`, and delete the replacement bindings.

### Testing copy-mode without a mouse

A wheel event cannot be injected here, but everything else can be driven. Use a second
server so the live session is untouched:

    tmux -L probe new-session -d -s p -x 100 -y 12 'seq 1 400; sleep 600'
    P=$(tmux -L probe list-panes -t p -F '#{pane_id}')
    tmux -L probe set -gw mode-keys vi
    tmux -L probe copy-mode -e -t $P ; tmux -L probe send-keys -t $P -X -N 20 scroll-up
    tmux -L probe send-keys -t $P j        # then read #{pane_in_mode} / #{scroll_position}
    tmux -L probe kill-server

Keystrokes sent to a pane *in copy-mode* pass through the copy-mode key table, so bindings
in that table are testable this way. Prefix bindings are not (send-keys never reaches
tmux's own key tables), so those are checked with `list-keys` plus running the same command.
`#{e|-:#{pane_height},1}` gives the last row index and works; `#{selection_present}` read 0
even with a selection just started, so nothing here depends on it.

**Trap:** sourcing the config with no client attached prints
`tmux-user.conf:24: no current window` twice (from `set -s cursor-style block`). Harmless —
a reload with a client is clean — but a detached `source-file` therefore looks like a
failure when it is not.

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

**`show-options -g @plugin` is NOT how you check the plugin list.** tmux keeps only the
last value of that string option, so it always looks as if one plugin were declared — while
TPM ignores the option entirely: `plugin_functions.sh` awk-parses the config files for lines
matching `set(-option)? +-g +@plugin` and takes the fourth field. So one plugin per line,
spelled exactly `set -g @plugin 'name'`, is the contract — and `set -ag @plugin ...` silently
drops the line from TPM's list. To see what TPM will actually load:

    bash -c '. ~/.tmux/plugins/tpm/scripts/helpers/plugin_functions.sh; tpm_plugins_list_helper'

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
