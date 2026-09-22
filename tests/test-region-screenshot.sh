#!/usr/bin/env bash

set -euo pipefail

script_path=${REGION_SCREENSHOT_SCRIPT:-"$HOME/.local/bin/region-screenshot"}
temp_dir=$(mktemp -d)
trap 'rm -rf -- "$temp_dir"' EXIT

fake_bin="$temp_dir/bin"
clipboard_file="$temp_dir/clipboard.png"
mkdir -p "$fake_bin" "$temp_dir/Pictures"

spectacle_log="$temp_dir/spectacle.log"

cat >"$fake_bin/spectacle" <<'EOF'
#!/bin/sh
set -eu

[ -n "${SPECTACLE_LOG:-}" ]
printf '%s\n' "$*" >>"$SPECTACLE_LOG"

output=
while [ "$#" -gt 0 ]; do
    if [ "$1" = '--output' ]; then
        output=$2
        shift 2
    else
        shift
    fi
done

if [ -n "${output:-}" ]; then
    printf 'PNG fixture\n' >"$output"
fi
EOF
chmod +x "$fake_bin/spectacle"

cat >"$fake_bin/wl-copy" <<'EOF'
#!/bin/sh
set -eu

cat >"$TEST_CLIPBOARD_FILE"
EOF
chmod +x "$fake_bin/wl-copy"

notify_log="$temp_dir/notify.log"

cat >"$fake_bin/notify-send" <<'EOF'
#!/bin/sh
set -eu

[ -n "${NOTIFY_LOG:-}" ]
printf '%s\n' "$*" >>"$NOTIFY_LOG"
echo "${REGION_TEST_NOTIFY_RESULT:-}"
EOF
chmod +x "$fake_bin/notify-send"

# Case 1: notification times out (no edit requested). No editor launch.
REGION_TEST_NOTIFY_RESULT="" \
NOTIFY_LOG="$notify_log" \
SPECTACLE_LOG="$spectacle_log" \
PATH="$fake_bin:$PATH" \
TEST_CLIPBOARD_FILE="$clipboard_file" \
XDG_PICTURES_DIR="$temp_dir/Pictures" \
"$script_path"

mapfile -t captures < <(find "$temp_dir/Pictures/Screenshots" -maxdepth 1 -type f -name '*.png' -print | sort)
if [ "${#captures[@]}" -ne 1 ]; then
    printf 'FAIL: expected exactly one PNG in the Screenshots folder, found %s\n' "${#captures[@]}" >&2
    exit 1
fi

cmp -- "${captures[0]}" "$clipboard_file"

if rg -q -- '--edit-existing' "$spectacle_log"; then
    printf 'FAIL: editor launched although edit action was not chosen\n' >&2
    exit 1
fi

rm -f "$spectacle_log" "$notify_log"
rm -f "${captures[0]}"
rm -f "$clipboard_file"

# Case 2: edit action chosen. Editor opens on the saved capture.
REGION_TEST_NOTIFY_RESULT="edit" \
NOTIFY_LOG="$notify_log" \
SPECTACLE_LOG="$spectacle_log" \
PATH="$fake_bin:$PATH" \
TEST_CLIPBOARD_FILE="$clipboard_file" \
XDG_PICTURES_DIR="$temp_dir/Pictures" \
"$script_path"

if ! rg -q -- '--edit-existing' "$spectacle_log"; then
    printf 'FAIL: editor was not launched after the edit action\n' >&2
    exit 1
fi

rg -- '--edit-existing' "$spectacle_log" | rg -q 'Screenshot_[0-9]{8}_[0-9]{6}_[0-9]+\.png' \
    || { printf 'FAIL: editor opened a file that is not the saved capture\n' >&2; exit 1; }

printf 'OK\n'