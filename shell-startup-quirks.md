# Shell Startup Quirks

Two bash-startup problems specific to this box, both from opencode sessions
`ses_fab71abe...` / `ses_fabc8fb2...` (2026-08-30). Both are interactions
between the engineering-loadout bashrc's clean-slate policy and
systemd/CachyOS hooks.

## 1. uwsm session crash — bashrc killing foreign helper functions

Covered fully in [suspend-clock-uwsm-fixes.md](suspend-clock-uwsm-fixes.md).
Summary: the loadout bashrc does `unset -f $(declare -F ...)` to wipe
inherited functions; uwsm's `/usr/lib/uwsm/prepare-env.sh` defines helpers,
sources `~/.profile` (→ bashrc), and loses its own functions → Hyprland
(uwsm-managed) session dies at login. Fixed with the `case $- in *i*)`
non-interactive guard at the top of `~/.config/bash/bashrc`.

## 2. `__systemd_osc_context_ps0: command not found` after every command

Symptom: every prompt line printed

```text
❯ ls
-bash: __systemd_osc_context_ps0: command not found
```

Root cause: `/etc/profile.d/80-systemd-osc-context.sh` (systemd's OSC-3008
terminal-integration hook, dropped into profile.d by tmpfiles on Arch) sets

```bash
PS0='$(__systemd_osc_context_ps0)'
```

and defines that function. The loadout bashrc's clean-slate
`unset -f $(declare -F)` then deletes the function, but `PS0` survives —
bash expands the dangling `$(...)` before every command. Same failure class
as the uwsm bug: inherited-state references outliving the state.

Fix (whitelist approach — keep the systemd hook functional): the
clean-slate block harvests function names still referenced by the inherited
`PS0` and adds them to the keep-list alongside the existing
`LOADOUT_CFG_PRESERVE_FUNCTIONS`. `PROMPT_COMMAND` / `precmd_functions` were
already reset by the prompt block, so `PS0` was the only dangling vector.
Verified in a real PTY (`tmux` login shell): `ls` clean, hook function
preserved, starship prompt intact. The fix works under `exec bash` too since
PS0 re-checks `declare -F` on each source.

Testing notes that mattered:

- Real PTY required (`tmux` / `env -i` login-shell), not `bash -c` — PS0
  only expands in interactive prompts.
- `bash -lc` without `-l` skips `/etc/profile`, so the hook never fires and
  the test silently passes for the wrong reason.
- On this box `~/.config/bash/bashrc` is a real file (not a symlink into the
  loadout repo) — fixes must land in both places or the box keeps the bug
  until `./loadout install env-bash`.

## 3. pkill self-match hang (operational, not bashrc)

Observed twice: `pkill -f '/home/mylesp/.local/lib/firefox'` hung the shell
until tool timeout. Cause: the command text itself contains the pattern, and
the shell tool wraps commands in `bash -c '...'` — so `pkill -f` matched the
calling shell's own command line and killed it. `pgrep -c` similarly counts
the wrapper.

Rules (codified in `~/.config/opencode/skills/pkill-safety/SKILL.md`):

- Never `pkill -f <pattern>` when the pattern appears in the invoking
  command text.
- Kill by exact process name: `pkill -9 -x firefox-bin`.
- Or collect PIDs first from `pgrep` output filtered by `/proc/<pid>/exe`,
  then `kill` them individually.
- Don't trust `pgrep -c` counts that may include the wrapper.

## General pattern

The recurring trap on this system: **two mechanisms that wipe shell state
(`unset -f`) interacting with two mechanisms that reference shell state
(uwsm preloader functions, systemd's PS0 hook)**. When adding any profile.d
hook or clean-slate wipe, check both directions:

- Does the wipe orphan a reference? (PS0, PROMPT_COMMAND)
- Does a sourced file run in a foreign context where it shouldn't mutate
  state at all? (uwsm, ssh, cron → interactivity guard)