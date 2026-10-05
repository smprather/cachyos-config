# Engineering Loadout relocation and PATH shadowing

Verified 2026-10-05 with Engineering Loadout 1.0.3-R2198.1 (installed by **muse**)
on Plasma 6.7.5, shell bash.

## Symptom

Everyday tools behaved as if they were subtly wrong: `cat` reported coreutils
9.7 instead of 9.12, `bash` 5.3.15 instead of 5.3.20, `node` v26.7.0 instead of
v26.10.0. Roughly 176 loadout binaries shadowed their distribution
counterparts, including 22 coreutils/shell entries (`bash`, `cat`, `cp`, `rm`,
`ls`, `chmod`, `dd`, `df`, …) and `python3`.

`~/.local/bin` sat at **PATH index 3**, ahead of `/usr/bin`, so the loadout won
every lookup. This also explained a hazard already recorded in
[chrome-fixes.md](chrome-fixes.md): `wezterm-gui` resolved to the Dec 2019
loadout wrapper that SIGSEGVs in `libnvidia-egl-wayland2`, which is why that
file says to call `/usr/bin/wezterm-gui` instead.

## Root cause

The loadout was installed into `$HOME`, so EL wrote its tree to `~/.local`
(`~/.local/bin` + `~/.local/lib`). That put its older coreutils, bash, node and
python ahead of Arch's on PATH. Nothing about the machine was unusual — this is
simply what happens when a from-source toolchain installs into a
system-precedence directory.

## Fix

### 1. Relocate the loadout to its own root

EL's CLI already has the knob:

```bash
cd ~/engineering-loadout
./loadout install @engineering-loadout --dest-dir ~/.loadout -y
```

The tree lands at `~/.loadout/local/{bin,lib,lib64,libexec,include,share,state}`
(167 packages, 7.3 G). `--dest-dir` relocates the **whole** tree including
`lib/`, so RPATH-relative libraries keep working — verified by running binaries
from the new location.

Then bake the runtime environment for per-user shells against the new root:

```bash
LOADOUT_CFG_SHARED_PREFIX="$HOME/.loadout/local" ./loadout install @envs -y
```

This writes `export LOADOUT_CFG_SHARED_PREFIX=/home/mylesp/.loadout/local` into
`~/.config/bash/global/config.sh`.

**EL's bash env PREPENDS that `bin` directory to PATH**, so relocation alone
does not stop the shadowing — it just moves it. The PATH policy below is a
separate, required step.

### 2. PATH policy: distribution first

Appended to `~/.bashrc` and `~/.zshrc`. EL's layer files are sourced earlier in
`~/.bashrc`, so this block runs last and moves the loadout directory to the end:

```bash
_loadout_bin="${LOADOUT_CFG_SHARED_PREFIX:-$HOME/.loadout/local}/bin"
if [ -d "$_loadout_bin" ]; then
    case ":$PATH:" in
        *":$_loadout_bin:"*)
            PATH="$(printf '%s' "$PATH" | tr ':' '\n' | grep -vxF "$_loadout_bin" | paste -sd: -)"
            PATH="$PATH:$_loadout_bin"
            export PATH
            ;;
    esac
fi
unset _loadout_bin
```

### 3. Prune the stale copies from `~/.local/bin`

Ownership was determined **by name**, not by content hash: anything present in
both `~/.local/bin` and `~/.loadout/local/bin` is a redundant old loadout copy.
Hash matching alone undercounts, because EL rebuilds several packages with
different options than the previous build (`bash`, `broot`, `btm`, `fd`, `fzf`,
`klayout`, `lazygit` all differed by hash while still being EL's).

`~/.local/bin` went from 351 entries to 27. What remains is deliberately
non-EL and must not be pruned: `pi`, `claude`, `codex`, `cua-driver`,
`cave`, `caveman`, `dsh`, `hermes*`, `muse`, `region-screenshot`,
`wezterm-tune`, `custom-idle.sh`, `persist-autosave.sh`, `gnome-tweaks`,
`repowise*`, `agent-deck`, `alacritty-theme`, `hyde-shell`, `hydectl`,
`surfer`, `xdg-terminal-exec`.

**Prune with an absolute `/usr/bin/rm`.** A loop that deletes `rm` while `rm`
resolves through `~/.local/bin` fails on every subsequent iteration — that
silently removed 187 of 319 entries on the first attempt.

### Verified after the change

| tool | resolves to | version |
| --- | --- | --- |
| `bash` | `/usr/bin/bash` | 5.3.**20** (was 5.3.15) |
| `cat` | `/usr/bin/cat` | 9.**12** (was 9.7) |
| `node` | `/usr/bin/node` | v26.**10.0** (was v26.7.0) |
| `rg`, `fd`, `fzf`, `eza`, `bat`, `nvim`, `python3`, `git` | `/usr/bin/…` | distribution |
| `wezterm-gui` | `/usr/bin/wezterm-gui` | **fixes the SIGSEGV wrapper hazard** |
| `tmux`, `yq`, `st`, `zellij` | `~/.loadout/local/bin/…` | EL only, no distro copy |

Reclaimed roughly 1.7 G from `~/.local/bin`.

Backup: `~/loadout_backups/localbin-prefix-prune-20261005-150008.tar.zst`

## Persistent `dest_dir` (EL feature, added 2026-10-05)

`--dest-dir` was CLI-only, so the flag had to be repeated on every install. EL
now reads `~/.config/engineering-loadout/config.toml`:

```toml
dest_dir = "~/.loadout"
```

Precedence is **explicit flag > config file > `$HOME`**. The key mirrors the
flag name on purpose. A missing file is not an error, and a malformed or
wrong-typed one degrades to "no default" rather than aborting an install.
Implemented in `loadout_main.py` (`_loadout_config`, `_config_dest_dir`,
`_resolve_home`, `_dest_dir_option`), using stdlib `tomllib`; the flag's default
is computed at import so `--help` shows `[default: …/loadout]`. Covered by
`tests/config-toml-dest-dir` (10 cases, all passing).

## Known gaps

- **The GUI session does not see the loadout.** `systemd --user
  show-environment` has no `~/.loadout/local/bin`, so applications launched from
  the panel cannot call `tmux`/`st`/`yq` by bare name. Nothing is broken today —
  no `.desktop` `Exec` invokes an EL-only tool by name — but a GUI entry point
  added later would fail. Closing it needs a session-level PATH change
  (`/etc/environment` via `pam_env`, which is system-wide and needs root).
  A `~/.config/systemd/user.conf.d/` `DefaultEnvironment` drop-in does **not**
  work for this: the user manager inherits PATH from the login session and
  `DefaultEnvironment` cannot override an already-populated environment block,
  verified by `systemctl --user daemon-reexec` leaving `show-environment`
  unchanged.
- **An already-open terminal keeps the old PATH.** Open a new one.
- **A future `./loadout install @envs` re-bakes `config.sh`**, but not
  `~/.bashrc`, so the PATH policy survives reinstalls.

## Verification

```bash
# system tools must win, EL-only tools must resolve
bash -lc 'for t in bash cat python3 node nvim rg fzf tmux yq st wezterm-gui; do
  printf "%-12s %s\n" "$t" "$(command -v $t)"; done'

# no duplicates left between the two trees
comm -12 <(ls ~/.local/bin | sort) <(ls ~/.loadout/local/bin | sort)   # expect empty
```

## Rollback

```bash
# 1. restore the old ~/.local/bin
tar --zstd -xf ~/loadout_backups/localbin-prefix-prune-20261005-150008.tar.zst \
  -C ~/.local

# 2. drop the PATH policy from ~/.bashrc and ~/.zshrc
#    (the block is delimited by the two dashed comment lines)

# 3. reinstall in place
cd ~/engineering-loadout && ./loadout install @engineering-loadout -y
```