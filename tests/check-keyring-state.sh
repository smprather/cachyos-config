#!/usr/bin/env bash
# Verify the passwordless login keyring is healthy and nothing can silently
# re-key it.
#
# Run after any PAM, keyring, or password change, and after a reboot:
#     bash tests/check-keyring-state.sh
#
# Also run automatically by the pacman hook
# /etc/pacman.d/hooks/95-keyring-pam-guard.hook, in --static mode (a pacman
# transaction has no user session bus, so the live round-trip is skipped):
#     bash tests/check-keyring-state.sh --static
#
# Exit 0 = all checks pass. Exit 1 = at least one check failed.
#
# Background: the login keyring is deliberately passwordless. Its file must
# stay in gnome-keyring's PLAINTEXT format ("[keyring]" header). Any password
# handed to the daemon becomes the keyring master, and the next save silently
# rewrites the file as AES/binary ("GnomeKeyring" header) -- after which
# autologin can never unlock it and gcr prompts on every boot.
# See passwordless-login.md (Change 8).

set -u

STATIC=0
QUIET=0
for arg in "$@"; do
    case "$arg" in
        --static) STATIC=1 ;;
        --quiet)  QUIET=1 ;;
        -h|--help)
            sed -n '2,18p' "$0"; exit 0 ;;
        *) echo "unknown argument: $arg" >&2; exit 2 ;;
    esac
done

# Quiet mode is for the pacman hook: stay silent on success, but replay the
# whole report on failure (via stderr, which pacman surfaces).
QUIET_BUF=""
if [[ "$QUIET" == "1" ]]; then
    QUIET_BUF="$(mktemp)"
    trap 'rm -f "$QUIET_BUF"' EXIT
    exec 3>&1 1>"$QUIET_BUF"
fi

# Whose keyring to inspect. Inside a pacman hook we run as root with
# HOME=/root, so fall back to the desktop user explicitly.
KR_USER="${KEYRING_USER:-$(id -un)}"
[[ "$KR_USER" == "root" ]] && KR_USER="mylesp"
KR_HOME="$(getent passwd "$KR_USER" | cut -d: -f6)"
if [[ -z "$KR_HOME" ]]; then
    echo "FAIL  cannot resolve home directory for user '$KR_USER'"
    exit 1
fi

KR="${KEYRING_FILE:-$KR_HOME/.local/share/keyrings/login.keyring}"
KR_DIR="$(dirname "$KR")"

# Directory holding the PAM service files. Overridable so the negative tests in
# tests/test-check-keyring-state.sh can exercise fixtures instead of /etc.
PAM_DIR="${PAM_DIR:-/etc/pam.d}"
fail=0

pass() { printf 'PASS  %s\n' "$1"; }
bad()  { printf 'FAIL  %s\n' "$1"; fail=1; }
info() { printf 'INFO  %s\n' "$1"; }

# Count live pam_gnome_keyring directives in a stack. Comment lines and inline
# comments are stripped first, so the explanatory comment we leave in
# /etc/pam.d/greetd does not count as a directive.
live_keyring_directives() {
    local f="$1"
    [[ -r "$f" ]] || { echo 0; return; }
    local n
    n=$(sed -e 's/[[:space:]]*#.*$//' "$f" \
        | grep -c 'pam_gnome_keyring' 2>/dev/null) || n=0
    echo "${n:-0}"
}

echo "== login keyring state =="

if [[ ! -f "$KR" ]]; then
    bad "keyring file missing: $KR"
else
    pass "keyring file present: $KR"

    # 1. Format must be plaintext. Binary starts with "GnomeKeyring";
    #    plaintext starts with a "[keyring]" section header.
    if head -c 12 "$KR" | grep -q '^GnomeKeyring'; then
        bad "keyring is AES-encrypted (GnomeKeyring header) -- it will prompt on every boot."
        echo "      fix: replace it with a blank keyring (see passwordless-login.md Change 8)"
    elif grep -q '^\[keyring\]' "$KR"; then
        pass "keyring format is plaintext (passwordless)"
    else
        bad "keyring header unrecognized: $(head -c 32 "$KR" | tr -d '\n')"
    fi

    # 2. Permissions
    perms="$(stat -c '%a' "$KR")"
    if [[ "$perms" == "600" ]]; then
        pass "keyring permissions 600"
    else
        bad "keyring permissions are $perms (want 600)"
    fi

    # 3. The daemon loads EVERY *.keyring in the directory, so a restored
    #    backup left under a .keyring name would be loaded alongside the real
    #    one. Anything else ending in .keyring is worth flagging.
    extra="$(find "$KR_DIR" -maxdepth 1 -name '*.keyring' \
             ! -name 'login.keyring' 2>/dev/null | tr '\n' ' ')"
    if [[ -n "${extra// /}" ]]; then
        bad "additional *.keyring files present (the daemon loads these too): $extra"
    else
        pass "no competing *.keyring files in the keyrings directory"
    fi
fi

echo
echo "== PAM password paths (must NOT hand a password to gnome-keyring) =="

# Which display manager is live. Only one should be enabled.
# The tests inject SYSTEMCTL=false to keep fixtures hermetic.
SYSCTL="${SYSTEMCTL:-systemctl}"
enabled_dm=""
for dm in greetd sddm gdm; do
    if "$SYSCTL" is-enabled "$dm" >/dev/null 2>&1; then
        enabled_dm="$dm"
        break
    fi
done
[[ -n "$enabled_dm" ]] && info "enabled display manager: $enabled_dm"

# Stacks that can carry a login or password-change password. The active DM is
# checked, plus the shared paths used by passwd/su/sudo/login.
stacks=(system-auth system-local-login login su sudo passwd chpasswd)
[[ -n "$enabled_dm" ]] && stacks+=("$enabled_dm")

# sddm and gdm ship pam_gnome_keyring lines in their own stacks. They are
# inert while disabled -- but enabling one would immediately restore the
# re-key vector, so say so loudly.
for dm in sddm gdm; do
    if [[ "$dm" != "$enabled_dm" ]] && "$SYSCTL" is-enabled "$dm" >/dev/null 2>&1; then
        bad "$dm is enabled -- its PAM stack ships pam_gnome_keyring lines that can re-key the keyring"
        echo "      see passwordless-login.md Change 8 before logging in through it"
        stacks+=("$dm")
    fi
done

for s in "${stacks[@]}"; do
    f="$PAM_DIR/$s"
    [[ -e "$f" ]] || continue
    n="$(live_keyring_directives "$f")"
    if [[ "$n" == "0" ]]; then
        pass "$f has no live pam_gnome_keyring directives"
    else
        bad "$f has $n live pam_gnome_keyring directive(s) -- a password login can re-key the keyring"
        [[ "$s" == "greetd" ]] && echo "      fix: remove them (backup: /etc/pam.d/greetd.bak-20260921-keyring-guard)"
    fi
done

# A package update that changes a shipped PAM file leaves a .pacnew for manual
# merge. That is how a re-introduced pam_gnome_keyring line would arrive, and
# it will not be live until someone merges it -- so surface it here.
pacnew_hits="$(find "$(dirname "$PAM_DIR")" -maxdepth 1 -name 'pam.d.pacnew' 2>/dev/null | tr '\n' ' ')"
pacnews="$(find "$PAM_DIR" -maxdepth 1 -name '*.pacnew' 2>/dev/null | tr '\n' ' ')"
if [[ -n "${pacnews// /}" || -n "${pacnew_hits// /}" ]]; then
    for f in $pacnews; do
        if grep -q 'pam_gnome_keyring' "$f" 2>/dev/null; then
            bad "$f proposes pam_gnome_keyring lines -- do NOT merge them into the live stack"
        else
            info "unmerged pacman PAM artifact present: $f (no keyring lines)"
        fi
    done
else
    pass "no unmerged .pacnew artifacts in the PAM directory"
fi

if [[ "$STATIC" == "0" ]]; then
    echo
    echo "== secret service round-trip (must work with no prompt) =="

    if ! command -v secret-tool >/dev/null; then
        bad "secret-tool not installed (libsecret) -- cannot test round-trip"
    else
        prompters_before="$(pgrep -x gcr-prompter | wc -l)"
        if printf 'keyring-check-value' | timeout 15 secret-tool store \
               --label 'keyring state check' hermes-check state >/dev/null 2>&1; then
            got="$(timeout 15 secret-tool lookup hermes-check state 2>/dev/null || true)"
            if [[ "$got" == "keyring-check-value" ]]; then
                pass "secret-tool store/lookup round-trip OK"
            else
                bad "secret-tool lookup returned '$got' (expected 'keyring-check-value')"
            fi
            timeout 15 secret-tool clear hermes-check state >/dev/null 2>&1 || true
        else
            bad "secret-tool store failed (daemon down, or keyring locked)"
        fi
        prompters_after="$(pgrep -x gcr-prompter | wc -l)"
        if [[ "$prompters_before" == "0" && "$prompters_after" == "0" ]]; then
            pass "no gcr-prompter ran (no unlock dialog)"
        else
            bad "gcr-prompter is active -- an unlock dialog is up (or was spawned)"
        fi
    fi

    echo
    echo "== daemon =="
    if systemctl --user is-active --quiet gnome-keyring-daemon.service; then
        pass "gnome-keyring-daemon.service active"
    else
        # Not fatal: the socket unit activates the daemon on first use.
        if systemctl --user is-active --quiet gnome-keyring-daemon.socket; then
            pass "gnome-keyring-daemon.service not running yet; socket active (activates on demand)"
        else
            bad "neither gnome-keyring-daemon.service nor .socket is active"
        fi
    fi
fi

echo
if [[ "$fail" == "0" ]]; then
    echo "RESULT: all checks passed"
else
    echo "RESULT: failures detected (see above)"
fi

# In quiet mode everything above went to a buffer: discard it on success so a
# routine package update stays silent, replay it on stderr when something fails.
if [[ -n "$QUIET_BUF" ]]; then
    if [[ "$fail" != "0" ]]; then
        {
            echo
            echo "!!! keyring guard: the passwordless login keyring is not in its expected state !!!"
            cat "$QUIET_BUF"
            echo
            echo "See passwordless-login.md (Change 8) for the fix and the rollback."
        } >&2
    fi
fi

exit "$fail"
