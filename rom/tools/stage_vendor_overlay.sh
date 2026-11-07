#!/bin/bash
# Copyright (C) 2026 Shripad
# SPDX-License-Identifier: Apache-2.0
#
# stage_vendor_overlay.sh
# Turnkey tool to assemble and stage the Motorola Edge 70 Fusion (marvel)
# vendor overlay directory for Slot B bringup and ROM execution.
#
# Incorporates all fixes validated in Boots 59-65:
# 1. Neutralized BoringSSL self-test stub binary & RC (prevents reboot loops)
# 2. VINTF manifests:
#    - /vendor/etc/vintf/manifest.xml (Qualcomm IKeyMintDevice/default)
#    - /odm/etc/vintf/manifest.xml (NXP StrongBox IKeyMintDevice/strongbox & IWeaver/default)
# 3. Vendor Init scripts with USB ConfigFS early triggers & module ready overrides
# 4. 44 vendor-required shared libraries for Android 15/16 isolated vendor namespace

set -e

DEST_DIR="${1:-/metadata/overlay/vendor}"
SYSTEM_LIB_DIR="${2:-/system/lib64}"
DEVICE_TREE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "=== Staging Marvel Vendor Overlay ==="
echo "Target overlay directory: ${DEST_DIR}"
echo "System library source:    ${SYSTEM_LIB_DIR}"
echo "Device tree directory:    ${DEVICE_TREE_DIR}"

mkdir -p "${DEST_DIR}/bin"
mkdir -p "${DEST_DIR}/lib64"
mkdir -p "${DEST_DIR}/etc/init/hw"
mkdir -p "${DEST_DIR}/etc/vintf/manifest"
mkdir -p "${DEST_DIR}/odm/etc/vintf"

# 1. Binaries & Shell Scripts (BoringSSL stub & Modprobe scripts)
echo "--> Staging vendor binaries and modprobe scripts..."
if [ -f "${DEVICE_TREE_DIR}/prebuilt/stubs/boringssl_self_test64_static" ]; then
    cp "${DEVICE_TREE_DIR}/prebuilt/stubs/boringssl_self_test64_static" "${DEST_DIR}/bin/boringssl_self_test64"
    chmod 0755 "${DEST_DIR}/bin/boringssl_self_test64"
fi
if [ -f "${DEVICE_TREE_DIR}/rom/bin/vendor_modprobe.sh" ]; then
    cp "${DEVICE_TREE_DIR}/rom/bin/vendor_modprobe.sh" "${DEST_DIR}/bin/vendor_modprobe.sh"
    chmod 0755 "${DEST_DIR}/bin/vendor_modprobe.sh"
fi
if [ -f "${DEVICE_TREE_DIR}/rom/bin/system_dlkm_modprobe.sh" ]; then
    cp "${DEVICE_TREE_DIR}/rom/bin/system_dlkm_modprobe.sh" "${DEST_DIR}/bin/system_dlkm_modprobe.sh"
    chmod 0755 "${DEST_DIR}/bin/system_dlkm_modprobe.sh"
fi
if [ -f "${DEVICE_TREE_DIR}/rom/configs/modules/modules.alias" ]; then
    echo "--> Staging fixed modules.alias (3 tokens)..."
    mkdir -p "${DEST_DIR}/lib/modules"
    cp "${DEVICE_TREE_DIR}/rom/configs/modules/modules.alias" "${DEST_DIR}/lib/modules/modules.alias"
    chmod 0644 "${DEST_DIR}/lib/modules/modules.alias"
fi

# 2. VINTF Manifests
echo "--> Staging VINTF manifests..."
cp "${DEVICE_TREE_DIR}/rom/vintf/manifest.xml" "${DEST_DIR}/etc/vintf/manifest.xml"
cp "${DEVICE_TREE_DIR}/rom/vintf/manifest_volcano.xml" "${DEST_DIR}/etc/vintf/manifest_volcano.xml"
if [ -f "${DEVICE_TREE_DIR}/rom/vintf/manifest/android.hardware.security.keymint-service-qti.xml" ]; then
    cp "${DEVICE_TREE_DIR}/rom/vintf/manifest/android.hardware.security.keymint-service-qti.xml" "${DEST_DIR}/etc/vintf/manifest/"
fi
cp "${DEVICE_TREE_DIR}/rom/vintf/manifest_bnes.xml" "${DEST_DIR}/odm/etc/vintf/manifest.xml"
cp "${DEVICE_TREE_DIR}/rom/vintf/manifest_bnes.xml" "${DEST_DIR}/odm/etc/vintf/manifest_bnes.xml"
chmod 0644 "${DEST_DIR}/etc/vintf/"*.xml "${DEST_DIR}/odm/etc/vintf/"*.xml "${DEST_DIR}/etc/vintf/manifest/"*.xml 2>/dev/null || true

# 3. Init Scripts
echo "--> Staging Init scripts..."
cp "${DEVICE_TREE_DIR}/rom/configs/init/init.target.rc" "${DEST_DIR}/etc/init/hw/init.target.rc"
cp "${DEVICE_TREE_DIR}/rom/configs/init/init.mmi.chipset.rc" "${DEST_DIR}/etc/init/hw/init.mmi.chipset.rc"
cp "${DEVICE_TREE_DIR}/rom/configs/init/init.qti.kernel.rc" "${DEST_DIR}/etc/init/hw/init.qti.kernel.rc"
cp "${DEVICE_TREE_DIR}/rom/configs/init/boringssl_self_test.rc" "${DEST_DIR}/etc/init/boringssl_self_test.rc"
chmod 0644 "${DEST_DIR}/etc/init/hw/"*.rc "${DEST_DIR}/etc/init/"*.rc

# 4. Required Vendor Libraries (Closure of libraries)
LIBS=(
    "libbase.so"
    "libbinder.so"
    "libc++.so"
    "libcgrouprc.so"
    "libcodec2.so"
    "libcrypto.so"
    "libcutils.so"
    "libhardware.so"
    "libhidlbase.so"
    "libutils.so"
    "libxml2.so"
    "libexpat.so"
    "libjsoncpp.so"
    "liblzma.so"
    "libnetutils.so"
    "libpackagelistparser.so"
    "libpng.so"
    "libselinux.so"
    "libpcre2.so"
    "libion.so"
    "libgatekeeper.so"
    "libhardware_legacy.so"
    "libdmabufheap.so"
    "libz.so"
    "libminijail.so"
    "libcap.so"
    "libnl.so"
    "libssl.so"
    "libfmq.so"
    "libstatssocket.so"
    "libui.so"
    "libunwindstack.so"
    "libutilscallstack.so"
    "libgralloctypes.so"
    "android.hardware.common-V2-ndk.so"
    "android.hardware.graphics.allocator@4.0.so"
    "android.hardware.graphics.bufferqueue@2.0.so"
    "android.hardware.graphics.common@1.0.so"
    "android.hardware.graphics.common@1.1.so"
    "android.hardware.graphics.common@1.2.so"
    "android.hardware.graphics.mapper@4.0.so"
    "android.hardware.memtrack-V1-ndk.so"
    "android.hidl.memory@1.0.so"
    "android.hidl.memory.token@1.0.so"
    "android.system.suspend-V1-ndk.so"
    "libaconfig_storage_read_api_cc.so"
    "libhidlmemory.so"
    "libprocessgroup.so"
    "libstagefright_foundation.so"
    "server_configurable_flags.so"
)

echo "--> Staging vendor libraries from ${SYSTEM_LIB_DIR}..."
MISSING_COUNT=0
for lib in "${LIBS[@]}"; do
    if [ -f "${SYSTEM_LIB_DIR}/${lib}" ]; then
        cp "${SYSTEM_LIB_DIR}/${lib}" "${DEST_DIR}/lib64/${lib}"
        chmod 0644 "${DEST_DIR}/lib64/${lib}"
    else
        echo "    [WARN] Library ${lib} not found in ${SYSTEM_LIB_DIR}"
        MISSING_COUNT=$((MISSING_COUNT + 1))
    fi
done

if command -v chcon >/dev/null 2>&1; then
    echo "--> Applying SELinux contexts (u:object_r:vendor_file:s0)..."
    chcon -hR u:object_r:vendor_file:s0 "${DEST_DIR}" || true
    chcon u:object_r:vendor_modinstall-sh_exec:s0 "${DEST_DIR}/bin/vendor_modprobe.sh" 2>/dev/null || true
    chcon u:object_r:vendor_modinstall-sh_exec:s0 "${DEST_DIR}/bin/system_dlkm_modprobe.sh" 2>/dev/null || true
fi

# 5. QSEECom 1.0 Implementation Symlink
# vendor.qti.hardware.qseecom@1.0-service links directly against vendor.qti.hardware.qseecom@1.0-impl.so
# in /vendor/lib64/ (stock vendor places it only in /vendor/lib64/hw/)
if [ -f "/vendor/lib64/hw/vendor.qti.hardware.qseecom@1.0-impl.so" ]; then
    echo "--> Creating QSEECom 1.0 impl symlink in lib64..."
    ln -sf hw/vendor.qti.hardware.qseecom@1.0-impl.so "${DEST_DIR}/lib64/vendor.qti.hardware.qseecom@1.0-impl.so"
elif [ -f "${DEST_DIR}/lib64/hw/vendor.qti.hardware.qseecom@1.0-impl.so" ]; then
    echo "--> Creating QSEECom 1.0 impl symlink in lib64..."
    ln -sf hw/vendor.qti.hardware.qseecom@1.0-impl.so "${DEST_DIR}/lib64/vendor.qti.hardware.qseecom@1.0-impl.so"
fi

# 6. Dynamic Linker Namespace Bridge (APEX i18n resolution)
if [ -f "${DEVICE_TREE_DIR}/rom/configs/linker/ld.config.txt" ]; then
    echo "--> Staging dynamic linker configuration bridge..."
    OVERLAY_ROOT="$(dirname "${DEST_DIR}")"
    cp "${DEVICE_TREE_DIR}/rom/configs/linker/ld.config.txt" "${OVERLAY_ROOT}/ld.config.txt"
    chmod 0644 "${OVERLAY_ROOT}/ld.config.txt"
fi

echo "=== Staging Complete! (${MISSING_COUNT} warnings) ==="
