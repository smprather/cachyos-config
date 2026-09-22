#!/usr/bin/env bash
# Negative tests for tests/check-keyring-state.sh.
#
# A checker that cannot fail is worthless, so this proves the check script
# DETECTS each failure mode: a re-keyed keyring, a re-added PAM line, a stray
# *.keyring file, bad permissions -- and does NOT false-positive on the
# explanatory comment left in /etc/pam.d/greetd.
#
# The checker supports KEYRING_FILE, PAM_DIR and SYSTEMCTL overrides so these
# fixtures stay hermetic; production files are never touched.
#
# Run: bash tests/test-check-keyring-state.sh
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO/tests/check-keyring-state.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

fails=0
ok() { printf 'PASS  %s\n' "$1"; }
no() { printf 'FAIL  %s\n' "$1"; fails=1; }

# Build a fixture tree: <name>/pam.d/*  +  <name>/login.keyring (plaintext).
seed() {
    local base="$T/$1"
    mkdir -p "$base/pam.d"
    for s in system-auth system-local-login login su sudo passwd chpasswd greetd; do
        printf '#%%PAM-1.0\n\nauth include system-auth\nsession include system-auth\n' > "$base/pam.d/$s"
    done
    cat > "$base/login.keyring" <<'EOF'
[keyring]
display-name=login
ctime=1787200000
mtime=0
lock-on-idle=false
lock-after=false
EOF
    chmod 600 "$base/login.keyring"
    echo "$base"
}

# run <name> -> exit code. SYSTEMCTL=false keeps systemd out of the fixtures;
# greetd is expected to be enabled, so we emulate it via a stub that succeeds
# only for greetd.
run() {
    local base="$T/$1"
    cat > "$base/systemctl" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == "is-enabled" && "$2" == "greetd" ]] && exit 0
exit 1
EOF
    chmod +x "$base/systemctl"
    KEYRING_FILE="$base/login.keyring" \
    PAM_DIR="$base/pam.d" \
    SYSTEMCTL="$base/systemctl" \
    bash "$SRC" --static >"$base/out.txt" 2>&1
    echo $?
}

echo "== baseline: healthy fixtures must PASS =="
seed good >/dev/null
rc="$(run good)"
if [[ "$rc" == "0" ]]; then ok "healthy fixtures -> exit 0"; else no "healthy fixtures -> exit $rc (expected 0)"; sed 's/^/      /' "$T/good/out.txt"; fi

echo
echo "== detection 1: re-keyed (AES/binary) keyring must FAIL =="
seed rekeyed >/dev/null
printf 'GnomeKeyring\n\r\0\n\0\0\0\0' > "$T/rekeyed/login.keyring"
chmod 600 "$T/rekeyed/login.keyring"
rc="$(run rekeyed)"
if [[ "$rc" != "0" ]]; then ok "binary keyring detected -> exit $rc"; else no "binary keyring NOT detected"; sed 's/^/      /' "$T/rekeyed/out.txt"; fi

echo
echo "== detection 2: pam_gnome_keyring re-added to greetd must FAIL =="
seed pamline >/dev/null
printf 'auth       optional     pam_gnome_keyring.so\n' >> "$T/pamline/pam.d/greetd"
rc="$(run pamline)"
if [[ "$rc" != "0" ]]; then ok "PAM keyring line detected -> exit $rc"; else no "PAM keyring line NOT detected"; sed 's/^/      /' "$T/pamline/out.txt"; fi

echo
echo "== detection 3: stray *.keyring file must FAIL =="
seed stray >/dev/null
cp "$T/stray/login.keyring" "$T/stray/login.keyring.bak-restored.keyring"
rc="$(run stray)"
if [[ "$rc" != "0" ]]; then ok "stray keyring file detected -> exit $rc"; else no "stray keyring file NOT detected"; sed 's/^/      /' "$T/stray/out.txt"; fi

echo
echo "== detection 4: wrong permissions must FAIL =="
seed perms >/dev/null
chmod 644 "$T/perms/login.keyring"
rc="$(run perms)"
if [[ "$rc" != "0" ]]; then ok "bad permissions detected -> exit $rc"; else no "bad permissions NOT detected"; sed 's/^/      /' "$T/perms/out.txt"; fi

echo
echo "== detection 5: a commented-out mention must NOT FAIL =="
seed commented >/dev/null
{
  echo "# NOTE: pam_gnome_keyring.so was removed deliberately; do not re-add."
  echo "# Backup: /etc/pam.d/greetd.bak-20260921-keyring-guard"
} >> "$T/commented/pam.d/greetd"
rc="$(run commented)"
if [[ "$rc" == "0" ]]; then ok "comment-only mentions ignored -> exit 0"; else no "false positive on comments -> exit $rc"; sed 's/^/      /' "$T/commented/out.txt"; fi

echo
if [[ "$fails" == "0" ]]; then
    echo "RESULT: all negative tests passed"
else
    echo "RESULT: failures detected"
fi
exit "$fails"
