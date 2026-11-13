#!/bin/sh
# Verify the stock GKI module set in an unpacked/built system_dlkm tree.
#
# Usage:
#   rom/tools/check_system_dlkm.sh <system_dlkm-root>
#
# Example:
#   rom/tools/check_system_dlkm.sh out/target/product/marvel/system_dlkm
#
# Exit status: 0 if the stock module set is present, 1 otherwise.

set -eu

ROOT="${1:-}"
if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then
    echo "usage: $0 <system_dlkm-root>" >&2
    exit 2
fi

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
MANIFEST="$HERE/system_dlkm.modules"
if [ ! -f "$MANIFEST" ]; then
    echo "ERROR: missing manifest: $MANIFEST" >&2
    exit 2
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

find -L "$ROOT" -type f -name '*.ko' -exec basename {} \; | tr -d '\r' | sort -u > "$TMP/found"
tr -d '\r' < "$MANIFEST" | sort -u > "$TMP/expected"

MISSING=$(comm -23 "$TMP/expected" "$TMP/found")
EXTRA=$(comm -13 "$TMP/expected" "$TMP/found")

if [ -n "$MISSING" ]; then
    echo "MISSING:"
    echo "$MISSING"
fi
if [ -n "$EXTRA" ]; then
    echo "EXTRA:"
    echo "$EXTRA"
fi

# AOSP treats BOARD_SYSTEM_KERNEL_MODULES_LOAD as a module list and writes the
# basenames into modules.load. The build output is flat
# /system_dlkm/lib/modules/modules.load; the device-tree
# system_dlkm_modprobe.sh handles both flat and versioned layouts. Verify the
# built image has the stock 60-entry load list.
LOAD_FILES=$(find -L "$ROOT" -type f -name modules.load)
LOAD_FILE_COUNT=$(printf '%s\n' "$LOAD_FILES" | grep -c . || true)
if [ "${LOAD_FILE_COUNT:-0}" -ne 1 ]; then
    echo "EXPECTED exactly one modules.load, found ${LOAD_FILE_COUNT:-0}"
    echo "$LOAD_FILES"
    echo "RESULT: FAIL"
    exit 1
fi
LOAD_FILE=$LOAD_FILES
LOAD_COUNT=$(grep -c . "$LOAD_FILE" 2>/dev/null || true)
if [ "${LOAD_COUNT:-0}" -lt 60 ]; then
    echo "SHORT: ${LOAD_FILE} has fewer than 60 entries"
    echo "RESULT: FAIL"
    exit 1
fi

# Compare the load-list module names with the stock manifest as a set.
sed 's#.*/##' "$LOAD_FILE" | tr -d '\r' | sort -u > "$TMP/load"
LOAD_MISSING=$(comm -23 "$TMP/expected" "$TMP/load")
LOAD_EXTRA=$(comm -13 "$TMP/expected" "$TMP/load")
if [ -n "$LOAD_MISSING" ] || [ -n "$LOAD_EXTRA" ]; then
    echo "MISMATCH: modules.load names differ from the stock manifest"
    [ -n "$LOAD_MISSING" ] && echo "missing: $LOAD_MISSING"
    [ -n "$LOAD_EXTRA" ] && echo "extra: $LOAD_EXTRA"
    echo "RESULT: FAIL"
    exit 1
fi

if [ -n "$MISSING" ] || [ -n "$EXTRA" ]; then
    echo "RESULT: FAIL"
    exit 1
fi

echo "RESULT: PASS ($(wc -l < "$TMP/found" | tr -d ' ') modules; modules.load ${LOAD_COUNT:-0} entries)"
