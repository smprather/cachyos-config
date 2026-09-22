# Passwordless Login

The stated goal for this machine is to never type a password. This file records
the full chain of changes that achieves that, the security tradeoffs that were
accepted knowingly, and how to reverse each piece.

All changes were made on 2026-08-31, except Change 8 (2026-09-21), which repairs
drift discovered that day: the blank keyring had silently become encrypted again
and was prompting on every boot.

## Threat model

The reasoning that makes these tradeoffs acceptable on this specific machine:

- It is a **desktop**, not a laptop: Gigabyte B550 AORUS ELITE AX V2. It stays
  in one place.
- The disk is **not encrypted**. `lsblk` found no LUKS or crypt devices and
  `/etc/crypttab` is empty.
- Because the disk is unencrypted, anyone with physical access can already read
  everything by booting from a USB stick. Autologin does not open a door that
  was closed.
- Passwordless `sudo` was already configured before any of this work:
  `mylesp ALL=(ALL) NOPASSWD: ALL`.
- The user account was already in the `nopasswdlogin` group.

Credentials live in Bitwarden, not in a browser password manager or an OS
keyring, so keyring degradation does not put real secrets at risk.

## Change 1: autologin via greetd

`/etc/greetd/config.toml` gained an `initial_session` block:

```toml
[terminal]
vt = 1

[default_session]
command = "/usr/bin/noctalia-greeter-session"
user = "greeter"

[initial_session]
command = "/usr/lib/plasma-dbus-run-session-if-needed /usr/bin/startplasma-wayland"
user = "mylesp"
```

`initial_session` fires only on boot. Logging out still drops to the noctalia
greeter, where GNOME and Hyprland remain selectable, so autologin does not
prevent switching desktops.

Verified before reboot: the TOML parses, and both
`/usr/lib/plasma-dbus-run-session-if-needed` and `/usr/bin/startplasma-wayland`
exist and are executable.

**Backup:** `/etc/greetd/config.toml.bak-20260831-224205`

**Recovery if autologin fails and the machine lands at a TTY:**

```bash
sudo cp /etc/greetd/config.toml.bak-20260831-224205 /etc/greetd/config.toml
sudo systemctl restart greetd
```

## Change 2: blank login keyring

Autologin and an encrypted keyring are mutually exclusive. gnome-keyring's
auto-unlock derives its key from the password typed at login; with no password
typed there is no key, and GNOME prompts to unlock the keyring instead.

A blank-password keyring was created deliberately:

```bash
mkdir -p ~/.local/share/keyrings
cat > ~/.local/share/keyrings/login.keyring <<EOF
[keyring]
display-name=login
ctime=$(date +%s)
mtime=0
lock-on-idle=false
lock-after=false
EOF
printf 'login' > ~/.local/share/keyrings/default
chmod 700 ~/.local/share/keyrings
chmod 600 ~/.local/share/keyrings/login.keyring ~/.local/share/keyrings/default
```

The `[keyring]` plaintext form is load-bearing, not cosmetic: with no master
password the daemon writes this format, and with a master it writes AES/binary.
If the file ever gains a `GnomeKeyring` header, it has acquired a master
password and autologin can no longer unlock it. See Change 8.

**Tradeoff, stated plainly:** the contents of this keyring are stored
unencrypted on disk. That is consistent with the disk itself being unencrypted,
but it is a real exposure to any other local user or to an offline disk read.

## Change 3: kwallet disabled

`~/.config/kwalletrc`:

```ini
[Wallet]
Enabled=false
First Use=false
```

`~/.config/autostart/pam_kwallet_init.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=pam_kwallet_init
Hidden=true
```

Takes effect at next login. The running `kwalletd6` exits at logout.

**Revert:** `rm ~/.config/kwalletrc ~/.config/autostart/pam_kwallet_init.desktop`

## Change 4: KDE secret portal repointed at gnome-keyring

With kwallet off, Plasma's secret portal pointed at a dead backend. An override
was created at `/etc/xdg-desktop-portal/kde-portals.conf`:

```ini
[preferred]
default=kde
org.freedesktop.impl.portal.Settings=kde;gtk;
org.freedesktop.impl.portal.Secret=gnome-keyring
org.freedesktop.impl.portal.Notification=plasmanotify
```

Only the `Secret` line differs from the shipped
`/usr/share/xdg-desktop-portal/kde-portals.conf`, which uses `kwallet`.
`gnome-keyring.portal` is present in `/usr/share/xdg-desktop-portal/portals/`,
so the backend resolves.

**Revert:** `sudo rm /etc/xdg-desktop-portal/kde-portals.conf`

## Change 5: gnome-keyring PAM unlock in greetd

> **SUPERSEDED 2026-09-21 — this is the bug.** The three `pam_gnome_keyring.so`
> lines below were removed. They existed because an encrypted keyring needs a
> password to unlock; once the keyring is passwordless there is nothing to
> unlock, and passing a password is actively harmful: the password becomes the
> keyring master and the next save silently re-encrypts the file, after which
> autologin can never unlock it. See
> [Change 8](#change-8-pam-re-key-vector-removed-2026-09-21). Kept below as
> history.

`/etc/pam.d/greetd` was extended so the keyring unlocks with the login password
when a password is actually typed:

```text
#%PAM-1.0

auth       required     pam_securetty.so
auth       requisite    pam_nologin.so
auth       include      system-local-login
auth       optional     pam_gnome_keyring.so
account    include      system-local-login
password   include      system-local-login
password   optional     pam_gnome_keyring.so use_authtok
session    include      system-local-login
session    required     pam_systemd.so
session    optional     pam_gnome_keyring.so auto_start
```

Every added line is `optional`, so a module failure can never block
authentication. The worst case is a keyring that stays locked, not a lockout.

All modules were verified resolvable in `/usr/lib/security/`:
`pam_gnome_keyring.so`, `pam_nologin.so`, `pam_securetty.so`, `pam_systemd.so`.

This change predates the autologin decision and is now largely redundant, since
no password is typed at boot. It is harmless and was left in place.

**Backup:** `/etc/pam.d/greetd.bak-20260831-223906`

## Change 6: passwordless polkit for the wheel group

`/etc/polkit-1/rules.d/49-nopasswd-wheel.rules`:

```javascript
// Allow members of the wheel group to perform any polkit action without
// authenticating. Matches the existing passwordless sudo configuration.
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("wheel") && subject.local && subject.active) {
        return polkit.Result.YES;
    }
});
```

Verified live with `pkcheck`, which returned `polkit.result=yes` with no prompt
for `org.freedesktop.login1.reboot` and
`org.freedesktop.udisks2.filesystem-mount`.

**Tradeoff, stated plainly:** this is a blanket `YES` for the wheel group. Any
process running as this user can take any privileged action silently. This is
the same posture the existing `NOPASSWD: ALL` sudo rule already had.

Note that `/etc/polkit-1/rules.d/` is root-readable only, so reading the file
back requires `sudo cat`.

**Revert:** `sudo rm /etc/polkit-1/rules.d/49-nopasswd-wheel.rules`

## Change 7: lock screen disabled

Plasma, `~/.config/kscreenlockerrc`:

```ini
[Daemon]
Autolock=false
LockOnResume=false
LockOnDelay=0
Timeout=0
```

GNOME, via gsettings:

```bash
gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.desktop.screensaver idle-activation-enabled false
gsettings set org.gnome.desktop.session idle-delay 0
```

**Revert:** delete `~/.config/kscreenlockerrc`; reset the three GNOME keys above
with `gsettings reset`.

## Change 8: PAM re-key vector removed (2026-09-21)

### What went wrong

The blank keyring from Change 2 did not stay blank. On 2026-09-13 15:32
`~/.local/share/keyrings/login.keyring` was rewritten into gnome-keyring's
AES/binary format (`GnomeKeyring` header) with a real master password. Nothing
prompted that day, so the drift went unnoticed until the first reboot that
needed the secret service: Chrome raised a gcr dialog reading "The login
keyring did not get unlocked when you logged into your computer." Every boot
since would have done the same, because autologin has no password to offer.

### The mechanism (reproduced in a sandbox, not inferred)

`gkm_secret_collection_save` routes on the master secret: an empty master writes
the plaintext format, any non-empty master writes AES/binary. And
`pam_gnome_keyring.so` hands the login password to the daemon, where
`create_credential` adopts it as the keyring master. So the sequence is:

1. A password is typed at a login prompt (`greetd`, a TTY, `su`, and so on).
2. PAM passes it to gnome-keyring, which adopts it as the login keyring master.
3. The next save rewrites the file encrypted under that password.
4. Autologin thereafter cannot unlock it, and gcr prompts on every boot.

Reproduction: a sandbox keyring in plaintext format, unlocked via
`gnome-keyring-daemon --unlock` with a password on stdin (exactly PAM's path),
turned into the `GnomeKeyring` binary format after one secret was stored. With
an empty password the same sandbox stayed plaintext.

### Fix, part 1: restore a blank keyring

```bash
systemctl --user stop gnome-keyring-daemon.service
umask 077
cat > ~/.local/share/keyrings/login.keyring <<EOF
[keyring]
display-name=login
ctime=$(date +%s)
mtime=0
lock-on-idle=false
lock-after=false
EOF
chmod 600 ~/.local/share/keyrings/login.keyring
systemctl --user start gnome-keyring-daemon.service
```

The old encrypted file was kept as `login.keyring.bak-20260921-165642`. Its
name does not match the daemon's `*.keyring` watch pattern
(`gkm-secret-module.c`), so it sits inert.

### Fix, part 2: remove the PAM lines

The three `pam_gnome_keyring.so` lines described in Change 5 are the vector and
were removed from `/etc/pam.d/greetd`. The daemon does not need them: it starts
on demand through the enabled `gnome-keyring-daemon.socket` (WantedBy
`sockets.target`) and through D-Bus activation of `org.freedesktop.secrets`.
Verified by stopping the service and round-tripping a secret with socket
activation alone.

**Backup:** `/etc/pam.d/greetd.bak-20260921-keyring-guard`

### Verifying the PAM stack after an edit

A broken PAM stack locks you out, so validate it rather than trusting the file.
`pamtester` is not packaged on CachyOS; a ~60-line C program linking `-lpam`
works. Authenticate with a deliberately wrong password:

- `PAM_AUTH_ERR` (7) = every module line parsed and ran. Healthy.
- `PAM_SYSTEM_ERR` (4), `PAM_SERVICE_ERR` (3), `PAM_OPEN_ERR` (1),
  `PAM_MODULE_UNKNOWN` (28) = stack broken, fix before logging out.

`pam_faillock` is in `/etc/pam.d/system-auth`, so a wrong-password test adds a
failure to the tally. Reset it afterwards:

```bash
sudo faillock --user mylesp --reset
```

An earlier attempt to validate by loading the stack only (`pam_start` without
`pam_authenticate`) proved nothing: `pam_start` is lazy and returns success even
for a nonexistent service name.

### Do not do this

- Do not re-add `pam_gnome_keyring.so` to any PAM stack while the keyring is
  passwordless. It reintroduces the re-key.
- Do not "fix" a locked keyring by deleting and recreating it if you care about
  what it holds. A new keyring gets a new random master, so anything previously
  encrypted (Chrome's `os_crypt` key protects saved passwords and cookies) is
  unrecoverable.
- Do not leave the old backup named `login.keyring`. The daemon loads every
  `*.keyring` file in the directory.

### Can a package update bring the PAM lines back?

Checked 2026-09-21, because this was the obvious worry: updates and other config
changes could plausibly reanimate `pam_gnome_keyring`. Findings, all verified
against the cached packages and the pacman database:

- `/etc/pam.d/greetd` **is** a tracked backup file of the `greetd` package
  (`pacman -Qii greetd` lists it under Backup Files), and pacman 7.1 does 3-way
  merges on those. But the pristine file shipped in the package
  (`greetd-0.10.3-2.1`) contains **no** keyring lines, and neither do any
  cached versions. A merge therefore cannot reintroduce them: the only source
  was the hand-edit of 2026-08-31, which now exists only in the `.bak` file.
- `noctalia-greeter`'s post-install/post-upgrade scriptlet
  (`/usr/share/noctalia-greeter/setup_greeter_system.sh` →
  `setup_greetd_pam.sh`) rewrites `/etc/pam.d/greetd` on every update, but it
  only ever inserts a `session required pam_systemd.so` line, is idempotent
  ("already contains pam_systemd.so; nothing to do"), and never touches
  keyring lines. All three cached versions were checked.
- `pambase` and `shadow` ship no keyring lines, and none of the stacks that a
  password actually flows through (`system-auth`, `system-local-login`,
  `login`, `su`, `sudo`, `passwd`, `chpasswd`, `greetd`) contains one.
- `sddm*` and `gdm*` **do** ship `pam_gnome_keyring` lines and are currently
  disabled. Enabling one would immediately restore the re-key vector, so treat
  that as a deliberate hazard, not a convenience.
- A future package could of course change this. The check script therefore
  reports unmerged `*.pacnew` artifacts in the PAM directory and flags a
  keyring line arriving that way.
- `/etc/pam.d/greetd.bak-20260921-keyring-guard` contains all three keyring
  lines and sits in the same directory. It is inert (nothing reads `.bak*`),
  but do not restore it "to be safe" -- restoring it re-arms the re-key.

### Update guard (pacman hook)

`/etc/pacman.d/hooks/95-keyring-pam-guard.hook` (to be installed) runs
`tests/check-keyring-state.sh --static --quiet` after any transaction touching
`greetd`, `greetd-*`, `noctalia-greeter`, `gnome-keyring`, `pambase`, `sddm`, or
`gdm`. It is read-only, silent on success, and prints a full report on stderr if
the keyring has been re-encrypted or a keyring PAM line came back.

Install:

```bash
sudo install -o root -g root -m 644 \
  ~/.hermes/cache/scratch/95-keyring-pam-guard.hook \
  /etc/pacman.d/hooks/95-keyring-pam-guard.hook
```

`AbortOnFail` is deliberately unset: a detection failure must not mark an
already-completed package transaction as failed, which would confuse update
tooling and invite retry loops. The stderr report is the alarm.

Rollback: `sudo rm /etc/pacman.d/hooks/95-keyring-pam-guard.hook`

### Verifying the checker itself

`tests/check-keyring-state.sh` supports `KEYRING_FILE`, `PAM_DIR`, and
`SYSTEMCTL` overrides so it can be tested hermetically.
`tests/test-check-keyring-state.sh` proves it fails on a re-keyed keyring, a
re-added PAM line, a stray `*.keyring` file, and bad permissions -- and that it
does not false-positive on the explanatory comment left in
`/etc/pam.d/greetd`.

```bash
bash tests/test-check-keyring-state.sh
```

### What the keyring holds

Only application keys minted through the Secret portal -- Chrome's `os_crypt`
key (items keyed by `app_id` + `xdg:schema=org.freedesktop.portal.Secret`) and,
historically, a `chrome_libsecret_os_crypt_password_v2` item. Nothing else used
it: no git credential helper is configured, no SSH keys live there
(`SSH_AUTH_SOCK` points at the loadout agent and `gcr-ssh-agent` is disabled),
and kwallet is off by design (Change 3).

Replacing the keyring therefore loses Chrome's locally stored logins and
cookies. That was accepted knowingly on 2026-09-21 because credentials are
managed in Bitwarden and Chrome re-syncs from its signed-in account.

### Verification

`tests/check-keyring-state.sh` checks the plaintext header, permissions, the
absence of live `pam_gnome_keyring` directives, a `secret-tool` round-trip, and
that no prompter appears. Run it after any PAM, keyring, or password change, and
after a reboot.

```bash
bash tests/check-keyring-state.sh
```

## Summary of files touched

| Change | Location | Backup or revert |
|---|---|---|
| `plasma-meta` installed, 90 packages | system | snapper snapshot `root: 60` |
| Autologin into Plasma at boot | `/etc/greetd/config.toml` | `.bak-20260831-224205` |
| Blank login keyring | `~/.local/share/keyrings/login.keyring` | delete the directory |
| kwallet off | `~/.config/kwalletrc`, `~/.config/autostart/pam_kwallet_init.desktop` | delete both |
| Secret portal to gnome-keyring | `/etc/xdg-desktop-portal/kde-portals.conf` | delete the override |
| Polkit NOPASSWD for wheel | `/etc/polkit-1/rules.d/49-nopasswd-wheel.rules` | delete the rule |
| No lock screen, Plasma | `~/.config/kscreenlockerrc` | delete the file |
| No lock screen, GNOME | gsettings keys | `gsettings reset` |
| ~~gnome-keyring PAM unlock~~ (removed 2026-09-21, see Change 8) | `/etc/pam.d/greetd` | ~~`.bak-20260831-223906`~~ `.bak-20260921-keyring-guard` |
| Blank keyring restored after drift | `~/.local/share/keyrings/login.keyring` | `login.keyring.bak-20260921-165642` holds the drifted (encrypted) file |
| Keyring state check | `tests/check-keyring-state.sh` | delete the script |

## Testing procedure for PAM changes

When a PAM change is made, verify it without risking a lockout:

1. Keep the current session open.
2. Switch to a fresh TTY with `Ctrl+Alt+F2`.
3. Log in there with the normal password.
4. If that works, PAM is fine. `Ctrl+Alt+F1` returns to the session.

If step 3 fails, restore the backup from the still-open session.

For a check that does not require leaving the session, authenticate against the
edited stack with a deliberately wrong password from a small C tester linking
`-lpam`; `PAM_AUTH_ERR` (7) means the stack is healthy. Reset the `pam_faillock`
tally afterwards (`sudo faillock --user mylesp --reset`). See Change 8 for
details. Note that `pam_start` alone proves nothing -- it is lazy and succeeds
even for a service name that does not exist.

Do not test PAM by restarting `greetd`; it kills the active graphical session.
