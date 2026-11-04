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

find "$ROOT" -type f -name '*.ko' -exec basename {} \; | tr -d '\r' | sort -u > "$TMP/found"
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

if [ -n "$MISSING" ] || [ -n "$EXTRA" ]; then
    echo "RESULT: FAIL"
    exit 1
fi

echo "RESULT: PASS ($(wc -l < "$TMP/found" | tr -d ' ') modules)"
