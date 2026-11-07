#! /vendor/bin/sh
#=============================================================================
# Robust vendor_modprobe.sh for SM7635 (marvel) Evolution X (Boot #73)
# - Corrected shell redirection: > /dev/kmsg 2>&1
# - Explicit insmod for qseecom_proxy and smcinvoke_dlkm
# - Strict gate: vendor.all.modules.ready=1 ONLY set if /dev/smcinvoke exists
#=============================================================================

echo "vendor_modprobe: starting..." > /dev/kmsg 2>&1

# 1. Ensure /vendor_dlkm is mounted if not already
if [ ! -f /vendor_dlkm/lib/modules/modules.load ]; then
    echo "vendor_modprobe: mounting /vendor_dlkm..." > /dev/kmsg 2>&1
    mkdir -p /vendor_dlkm
    mount -t erofs -o ro /dev/block/mapper/vendor_dlkm_b /vendor_dlkm > /dev/kmsg 2>&1 || \
    mount -t ext4 -o ro /dev/block/mapper/vendor_dlkm_b /vendor_dlkm > /dev/kmsg 2>&1 || \
    mount -t erofs -o ro /dev/block/by-name/vendor_dlkm_b /vendor_dlkm > /dev/kmsg 2>&1 || \
    mount -t ext4 -o ro /dev/block/by-name/vendor_dlkm_b /vendor_dlkm > /dev/kmsg 2>&1
fi

# Determine active module directory
MODULE_DIR="/vendor/lib/modules"
if [ ! -f "${MODULE_DIR}/modules.load" ]; then
    MODULE_DIR="/vendor_dlkm/lib/modules"
fi

echo "vendor_modprobe: using MODULE_DIR=${MODULE_DIR}" > /dev/kmsg 2>&1

MODPROBE="/vendor/bin/modprobe"
INSMOD="/vendor/bin/insmod"

# 2. Explicitly load TrustZone & security modules with full error logging
echo "vendor_modprobe: loading qseecom_proxy..." > /dev/kmsg 2>&1
${INSMOD} ${MODULE_DIR}/qseecom_proxy.ko > /dev/kmsg 2>&1 || \
${MODPROBE} -b -s -d ${MODULE_DIR} -a qseecom_proxy > /dev/kmsg 2>&1

echo "vendor_modprobe: loading smcinvoke_dlkm..." > /dev/kmsg 2>&1
${INSMOD} ${MODULE_DIR}/smcinvoke_dlkm.ko > /dev/kmsg 2>&1 || \
${MODPROBE} -b -s -d ${MODULE_DIR} -a smcinvoke_dlkm > /dev/kmsg 2>&1

# Early load display driver for splash -> boot animation transition
echo "vendor_modprobe: loading msm_drm..." > /dev/kmsg 2>&1
${MODPROBE} -b -s -d ${MODULE_DIR} -a msm_drm > /dev/kmsg 2>&1

# 3. Configure /dev/smcinvoke permissions immediately if present
if [ -e /dev/smcinvoke ]; then
    chmod 0660 /dev/smcinvoke
    chown system:drmrpc /dev/smcinvoke 2>/dev/null || chown 1000:1026 /dev/smcinvoke 2>/dev/null
    echo "vendor_modprobe: /dev/smcinvoke created and permissions set" > /dev/kmsg 2>&1
else
    echo "vendor_modprobe: WARNING: /dev/smcinvoke not found immediately after insmod" > /dev/kmsg 2>&1
fi

# 4. Load remaining modules from modules.load (stripping CRLF \r)
if [ -f ${MODULE_DIR}/modules.load ]; then
    BLOCKLIST_EXPR="-e %"
    if [ -f ${MODULE_DIR}/modules.blocklist ]; then
        BLOCKLIST_EXPR=$(tr -d '\r' < ${MODULE_DIR}/modules.blocklist | sed -n -e 's/blocklist \(.*\)/\1/p' | sed -e 's/-/_/g' -e 's/^/-e /')
        if [ -z "${BLOCKLIST_EXPR}" ]; then
            BLOCKLIST_EXPR="-e %"
        fi
    fi

    LOAD_MODULES=$(tr -d '\r' < ${MODULE_DIR}/modules.load | grep -w -v ${BLOCKLIST_EXPR})

    for mod in ${LOAD_MODULES}; do
        ( ${MODPROBE} -b -d ${MODULE_DIR} -a ${mod} > /dev/kmsg 2>&1 ) &
    done
    wait
    echo "vendor_modprobe: all background modules loaded" > /dev/kmsg 2>&1
fi

# 5. Strict verification of /dev/smcinvoke before setting vendor.all.modules.ready
if [ ! -e /dev/smcinvoke ]; then
    for i in 1 2 3 4 5 6 7 8 9 10; do
        sleep 1
        if [ -e /dev/smcinvoke ]; then
            break
        fi
    done
fi

if [ -e /dev/smcinvoke ]; then
    chmod 0660 /dev/smcinvoke
    chown system:drmrpc /dev/smcinvoke 2>/dev/null || chown 1000:1026 /dev/smcinvoke 2>/dev/null
    echo "vendor_modprobe: SUCCESS: /dev/smcinvoke confirmed ready" > /dev/kmsg 2>&1
    setprop vendor.all.modules.ready 1
    echo "vendor_modprobe: vendor.all.modules.ready=1 set, exiting 0" > /dev/kmsg 2>&1
    exit 0
else
    echo "vendor_modprobe: FATAL: /dev/smcinvoke does not exist! REFUSING to set vendor.all.modules.ready" > /dev/kmsg 2>&1
    exit 1
fi
