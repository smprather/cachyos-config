#!/bin/bash
# Pre-migration backup (2026-10-06): read-only snapshots of the live root subvolumes, sent
# with `btrfs send` to the empty 5.5 TB btrfs on /dev/sda3.
#
#   sudo scripts/premigration-backup.sh        # logs to /var/tmp/premigration-backup.log
#
# The disposable caches (@cache, @tmp, @log) are deliberately excluded — volatile, and they
# would only add time and churn. `/home` **is** included: @home is its own subvolume.
# This is a live backup, so files changing while it runs may be captured mid-flight; it is a
# safety net for the migration, not a point-in-time archive.
#
# Restore: each subvolume is received under its own name, and must be sent back to its
# matching mount point — copying `@` alone would silently leave /home and /root empty, since
# those are separate subvolumes mounted over empty directories inside `@`.
set -uo pipefail
LOG=${LOG:-/var/tmp/premigration-backup.log}
DEST=${DEST:-/mnt/premigration}
TARGET_NAME=${TARGET_NAME:-root-$(date +%Y-%m-%d)}
SNAP=${SNAP:-/premigration-snap}
TARGET="$DEST/$TARGET_NAME"
SUBVOLS="@ @root @home @srv"

exec >>"$LOG" 2>&1
ts() { date -Iseconds; }
echo "=== pre-migration backup started $(ts)  target=$TARGET"

mkdir -p "$SNAP"
for sv in $SUBVOLS; do
  case "$sv" in
    "@")     src="/" ;;
    "@root") src="/root" ;;
    "@home") src="/home" ;;
    "@srv")  src="/srv" ;;
  esac
  echo "--- read-only snapshot $src -> $SNAP/$sv  $(ts)"
  btrfs subvolume snapshot -r "$src" "$SNAP/$sv" || { echo "!! snapshot failed: $sv"; exit 2; }
done

mkdir -p "$DEST"
mount /dev/sda3 "$DEST" || { echo "!! cannot mount /dev/sda3"; exit 3; }
mkdir -p "$TARGET"
for sv in $SUBVOLS; do
  echo "--- send $sv  $(ts)"
  btrfs send "$SNAP/$sv" | btrfs receive "$TARGET/" || echo "!! send/receive FAILED: $sv"
  echo "    target used: $(btrfs filesystem usage -b "$DEST" 2>/dev/null | awk '/Used:/{print $2, $3}')"
done

cat > "$TARGET/README-restore.md" <<EOF
# Restore notes — pre-migration backup of the CachyOS root filesystem

Taken $(ts) from \`nvme1n1p2\` before migrating this OS to a new NVMe. Contains read-only
copies of the subvolumes \`@\`, \`@root\`, \`@home\`, \`@srv\` — **not** the disposable
caches (\`@cache\`, \`@tmp\`, \`@log\`).

Each subvolume was received under its own name:

    @       -> the old /          (its /home and /root are empty mount points)
    @root   -> the old /root
    @home   -> the old /home      <- user data lives HERE, not under @/home
    @srv    -> the old /srv

To restore, send each subvolume back to its matching mount point, for example:

    mount -o subvolid=5 /dev/<device> /mnt/old
    mount -o subvolid=5 /dev/<device> /mnt/new
    btrfs send /mnt/old/@home | btrfs receive /mnt/new/

Copying \`@\` alone would silently drop \`/home\` and \`/root\`: they are separate
subvolumes mounted on top of empty directories inside \`@\`. This applies equally to the
migration itself — see storage-migration.md.
EOF

echo "--- received subvolumes:"
btrfs subvolume list "$TARGET" 2>&1 | head -20
echo "--- removing the temporary read-only staging snapshots (the sda3 copy is the backup)"
for sv in $SUBVOLS; do btrfs subvolume delete "$SNAP/$sv"; done
rmdir "$SNAP" 2>/dev/null
umount "$DEST" && echo "--- unmounted $DEST"
echo "=== pre-migration backup finished $(ts)"
