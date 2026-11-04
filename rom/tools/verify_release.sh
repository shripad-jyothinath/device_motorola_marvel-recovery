#!/bin/sh
# Read-only release preflight. Never flashes anything.
#
# Usage:
#   rom/tools/verify_release.sh [modules-repo] [init_boot.img] [system_dlkm-dir] [stock-images-dir]
#
# Defaults are the build outputs under out/target/product/marvel and the
# stock-images directory. Set UNPACK_BOOTIMG if unpack_bootimg is not on PATH.

set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
MODULES_REPO=${1:-}
INIT_BOOT=${2:-$ROOT/out/target/product/marvel/init_boot.img}
SYSTEM_DLKM=${3:-$ROOT/out/target/product/marvel/system_dlkm}
STOCK_IMAGES=${4:-${MARVEL_STOCK_IMAGE_DIR:-$ROOT/stock-images}}
LOCK="$ROOT/rom/tools/vendor-modules.lock"
UNPACK_BOOTIMG=${UNPACK_BOOTIMG:-unpack_bootimg}
NODE=${NODE:-node}
if [ ! -x "$NODE" ] && ! command -v "$NODE" >/dev/null 2>&1; then
    if [ -x "/c/Program Files/nodejs/node.exe" ]; then
        NODE="/c/Program Files/nodejs/node.exe"
    fi
fi
winpath() {
    if command -v cygpath >/dev/null 2>&1; then
        cygpath -w -- "$1"
    else
        printf '%s' "$1"
    fi
}

FAILS=0
WARNS=0
ok()   { printf 'OK   %s\n' "$1"; }
warn() { WARNS=$((WARNS + 1)); printf 'WARN %s\n' "$1"; }
fail() { FAILS=$((FAILS + 1)); printf 'FAIL %s\n' "$1"; }

[ -f "$LOCK" ] || { fail "missing $LOCK"; exit 1; }

if [ -x "$NODE" ] || command -v "$NODE" >/dev/null 2>&1; then
    HASHES=$("$NODE" - "$(winpath "$LOCK")" <<'EOF'
const fs = require('fs');
const l = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
for (const e of Object.values(l.hashes || {})) console.log(`repo\t${e.path}\t${e.sha256}`);
for (const e of Object.values(l.stock_images || {})) console.log(`stock\t${e.file}\t${e.sha256}`);
EOF
)
    while IFS='	' read -r kind path hash; do
        [ -n "$kind" ] || continue
        if [ "$kind" = "repo" ]; then
            file="$ROOT/$path"
        else
            file="$STOCK_IMAGES/$path"
        fi
        if [ ! -f "$file" ]; then
            fail "missing $file"
            continue
        fi
        actual=$(sha256sum "$file" | awk '{print $1}')
        if [ "$actual" != "$hash" ]; then
            fail "$file hash $actual != $hash"
        else
            ok "$file"
        fi
    done <<EOF
$HASHES
EOF
else
    fail "node not found; cannot verify hashes"
fi

if sed -n '/^AB_OTA_PARTITIONS/,/^$/p' "$ROOT/rom/common.mk" | grep -Eq '^[[:space:]]*recovery([[:space:]]|\\|$)'; then
    fail "recovery is still in AB_OTA_PARTITIONS"
else
    ok "AB_OTA_PARTITIONS excludes recovery"
fi

if grep -q '^TW_LOAD_VENDOR_MODULES[[:space:]]*:=' "$ROOT/device.mk"; then
    ok "TW_LOAD_VENDOR_MODULES present"
else
    fail "TW_LOAD_VENDOR_MODULES missing from device.mk"
fi

LEVEL=$(sed -n 's/^PRODUCT_SHIPPING_API_LEVEL[[:space:]]*:=[[:space:]]*//p' "$ROOT/rom/common.mk" | head -n 1)
if [ "$LEVEL" = "34" ]; then
    warn "PRODUCT_SHIPPING_API_LEVEL=34 but stock first API is 36; audit before changing (16K prebuilt check)"
else
    ok "PRODUCT_SHIPPING_API_LEVEL=$LEVEL"
fi

if [ -f "$INIT_BOOT" ]; then
    if "$ROOT/rom/tools/verify_init_boot.sh" "$INIT_BOOT" "$UNPACK_BOOTIMG"; then
        ok "init_boot verifier"
    else
        fail "init_boot verifier"
    fi
else
    warn "init_boot not found: $INIT_BOOT"
fi

if [ -d "$SYSTEM_DLKM" ]; then
    if "$ROOT/rom/tools/check_system_dlkm.sh" "$SYSTEM_DLKM"; then
        ok "system_dlkm verifier"
    else
        fail "system_dlkm verifier"
    fi
else
    warn "system_dlkm directory not found: $SYSTEM_DLKM"
fi

if [ -n "$MODULES_REPO" ]; then
    if "$NODE" "$(winpath "$ROOT/rom/tools/check_vendor_modules.js")" "$(winpath "$MODULES_REPO")"; then
        ok "vendor module verifier"
    else
        fail "vendor module verifier"
    fi
else
    warn "module repo not given; skipped vendor module verifier"
fi

if [ "$FAILS" -gt 0 ]; then
    echo "RESULT: FAIL ($FAILS failures, $WARNS warnings)"
    exit 1
fi
if [ "$WARNS" -gt 0 ]; then
    echo "RESULT: PASS WITH WARNINGS ($WARNS warnings)"
else
    echo "RESULT: PASS"
fi
