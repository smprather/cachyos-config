#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
archive_dir="$repo_root/power-management/custom-idle"

expected_hashes=$(cat <<'EOF'
d5a524507b6df22376120ae28bc2db774a0ae3f356af41d9d7698eacf49c88c9  custom-idle.sh
2744b00c9c1dbae9c224fa89346bc7e835c6f2269927955685efc05eb1c9944b  custom-idle.service
a004cfbfd9bfa4201ae406b5cc590ea9ceacc8e08c19d712c1693e12ab956b2e  suspend_if_low_cpu.sh
46e887e413257d3d1f1ccdd20250dd0e8eb4623be29df3904f3a624660b54c79  hypridle.conf
EOF
)

(
    cd "$archive_dir"
    sha256sum --check --strict <<<"$expected_hashes"
)

if [[ ${CHECK_LIVE_POWER_POLICY:-0} != 1 ]]; then
    exit 0
fi

assert_equal() {
    local description=$1
    local expected=$2
    local actual=$3

    if [[ $actual != "$expected" ]]; then
        printf 'FAIL: %s\n  expected: %s\n  actual:   %s\n' \
            "$description" "$expected" "$actual" >&2
        return 1
    fi
}

assert_equal \
    'GNOME monitor idle timeout' \
    'uint32 300' \
    "$(gsettings get org.gnome.desktop.session idle-delay)"
assert_equal \
    'GNOME automatic suspend on AC' \
    "'nothing'" \
    "$(gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type)"
assert_equal \
    'GNOME automatic suspend on battery' \
    "'nothing'" \
    "$(gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type)"
assert_equal \
    'GNOME manual suspend shortcut' \
    "['<Super><Shift>z']" \
    "$(gsettings get org.gnome.settings-daemon.plugins.media-keys suspend)"
assert_equal \
    'custom idle service enablement' \
    'disabled' \
    "$(systemctl --user is-enabled custom-idle.service 2>&1 || true)"
assert_equal \
    'custom idle service state' \
    'inactive' \
    "$(systemctl --user is-active custom-idle.service 2>&1 || true)"
assert_equal \
    'Hypridle service enablement' \
    'disabled' \
    "$(systemctl --user is-enabled hypridle.service 2>&1 || true)"
assert_equal \
    'Hypridle service state' \
    'inactive' \
    "$(systemctl --user is-active hypridle.service 2>&1 || true)"
