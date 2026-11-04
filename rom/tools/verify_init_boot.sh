#!/bin/sh
# Verify that an init_boot image carries the VABC userspace-snapshot daemon.
#
# Usage:
#   rom/tools/verify_init_boot.sh <init_boot.img> [unpack_bootimg]
#
# Example (build host, after `mka bacon`):
#   rom/tools/verify_init_boot.sh out/target/product/marvel/init_boot.img
#
# Exit status: 0 if all three entries are present, 1 otherwise.

set -eu

IMG="${1:-}"
UNPACK="${2:-unpack_bootimg}"
LZ4_BIN="${LZ4:-lz4}"

if [ -z "$IMG" ] || [ ! -f "$IMG" ]; then
    echo "usage: $0 <init_boot.img> [unpack_bootimg]" >&2
    exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

"$UNPACK" --boot_img "$IMG" --out "$TMP" >/dev/null

RAM="$(find "$TMP" -maxdepth 1 -type f -name 'ramdisk*' | head -n 1)"
if [ -z "$RAM" ]; then
    echo "ERROR: no ramdisk written by unpack_bootimg" >&2
    exit 1
fi

# The ramdisk is usually LZ4 (legacy) on this device; try the common formats.
if "$LZ4_BIN" -d -c "$RAM" > "$TMP/ramdisk.cpio" 2>/dev/null; then
    :
elif gzip -dc "$RAM" > "$TMP/ramdisk.cpio" 2>/dev/null; then
    :
else
    cp "$RAM" "$TMP/ramdisk.cpio"
fi

LIST_OK=0
if cpio -it < "$TMP/ramdisk.cpio" > "$TMP/list.txt" 2>/dev/null; then
    LIST_OK=1
fi

rc=0
for entry in \
    system/bin/snapuserd \
    system/bin/snapuserd_ramdisk \
    system/etc/init/snapuserd.rc
do
    found=0
    if [ "$LIST_OK" = 1 ]; then
        if grep -qx "$entry" "$TMP/list.txt" || grep -qx "./$entry" "$TMP/list.txt"; then
            found=1
        fi
    elif grep -aq "$entry" "$TMP/ramdisk.cpio"; then
        found=1
    fi

    if [ "$found" = 1 ]; then
        echo "OK   $entry"
    else
        echo "MISS $entry"
        rc=1
    fi
done

exit "$rc"
