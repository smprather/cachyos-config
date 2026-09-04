# Persistent tmux Across Desktop Logouts

## Goal

Keep the user's default tmux server, its sessions, and all pane processes alive
across GNOME logout/login cycles. A real reboot may terminate every live process;
the existing tmux-resurrect and tmux-continuum configuration remains the
best-effort layout and command restoration layer for that case.

## Current state

The running tmux 3.7b server uses the ordinary per-user socket:
`/tmp/tmux-1000/default`. It was started by WezTerm and currently belongs to:

```text
user@1000.service/app.slice/app-gnome-org.wezfurlong.wezterm-34855.scope
```

That scope has `PartOf=graphical-session.target` and
`KillMode=control-group`. GNOME logout therefore kills the server and its whole
process tree even when every tmux client has detached. User lingering is also
currently disabled.

The current tmux configuration derives `default-terminal` from the server's
`TERM`. The live server has `TERM=xterm-256color` and
`EXTENDED_KEYS_SUPPORTED=0`; a service-started server must preserve those
values rather than inheriting the user manager's current `TERM=linux`.

## Design

### Persistent server

Add a systemd user unit named `tmux.service`. It runs `/usr/bin/tmux -D` as a
foreground process under the default user target, outside
`graphical-session.target`. tmux's `-D` mode stays in the foreground, disables
`exit-empty`, and lets systemd track the real server process without a PID file
or shell wrapper.

The unit explicitly sets `TERM=xterm-256color` and
`EXTENDED_KEYS_SUPPORTED=0`, matching the existing server. It uses the normal
tmux socket name, so commands such as `tmux`, `tmux attach`, plugins, and scripts
continue to work without aliases or wrapper commands. `Restart=on-failure`
recovers an unexpected server failure but permits an intentional
`tmux kill-server` to remain stopped.

Enable the unit under `default.target` and enable systemd user lingering for
the account. The user manager and tmux service can then remain alive while no
login session exists. On a later reboot, the lingering user manager starts a
new, empty tmux server; any reconstruction performed by tmux-continuum is
best-effort and is not process checkpointing.

### Installation

Store the canonical unit in the repository and add an idempotent installer
script. The installer will:

1. Verify that `/usr/bin/tmux`, `systemctl`, and `loginctl` exist.
2. Install the unit into `~/.config/systemd/user/tmux.service`.
3. Reload the user manager and enable the unit without replacing a running
   tmux server.
4. Enable lingering for the current user, using `sudo loginctl` only when the
   unprivileged operation is not authorized.
5. Start and verify the service immediately when no default tmux server exists.
6. If a server already exists, leave it untouched and print the exact live
   migration command or perform migration only through an explicit installer
   option.

The script must fail clearly on partial setup and remain safe to rerun.

### One-time migration of the current server

The current server cannot be restarted without losing live processes. Move the
server and every descendant process from WezTerm's graphical scope into a new
transient user scope in `background.slice`, created through systemd's
`StartTransientUnit` API. Repeat descendant discovery and attachment until no
tmux descendant remains in the graphical scope, which closes the race with
short-lived forks.

The migration must verify all of the following before reporting success:

- The tmux server PID is unchanged.
- `tmux list-sessions` reports the same sessions as before migration.
- The server and every descendant are outside any unit that is part of
  `graphical-session.target`.
- The transient scope is active and the account reports `Linger=yes`.
- The persistent `tmux.service` is installed and enabled, but is not started
  against the occupied default socket. It will take over after the next reboot
  or after the current server is intentionally stopped.

If systemd refuses any process attachment, abort without logging out and report
the remaining graphical-scope PIDs. Do not kill or restart the tmux server as a
fallback.

## Repository layout

- `systemd/user/tmux.service`: canonical persistent server unit.
- `bin/install-persistent-tmux`: idempotent installer and verifier.
- `tmux-persistence.md`: operational explanation, diagnostics, recovery, and
  fresh-install procedure.
- `README.md`: link to the tmux persistence guide.
- `customizations.md`: record of the local preference and applied state.

## Verification

Automated/static checks cover shell syntax, unit-file validity, idempotent
installation into a temporary home directory, and the foreground tmux command
using an isolated socket. Live verification checks the enabled unit, lingering,
socket compatibility, PID stability during migration, session preservation,
and final cgroup ownership.

The definitive logout test is manual: detach all clients, log out of GNOME,
log back in, attach to the normal tmux socket, and confirm the original server
PID and sessions remain. This test is performed only after all non-destructive
pre-logout checks pass.

## Reboot and process checkpointing

Full process checkpoint/restore is out of scope. CRIU and DMTCP can checkpoint
some process trees, but arbitrary interactive shells, agents, sockets, network
connections, terminal state, and graphical resources make general workstation
restoration fragile. System hibernation is the reliable whole-machine analogue,
but it resumes the same boot rather than restoring processes after a true
reboot.
