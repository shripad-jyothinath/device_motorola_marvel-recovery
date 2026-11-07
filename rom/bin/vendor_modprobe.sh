#! /vendor/bin/sh
#=============================================================================
# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#
# Modifications Copyright (C) 2026 Shripad
# SPDX-License-Identifier: Apache-2.0
#
# Robust vendor_modprobe.sh for Motorola Edge 70 Fusion (marvel - SM7635)
# - Auto-mounts /vendor_dlkm if not mounted
# - Fallback detection of MODULE_DIR between /vendor/lib/modules and /vendor_dlkm/lib/modules
# - Explicitly loads qseecom_proxy and smcinvoke_dlkm for /dev/smcinvoke
# - Fixes permissions on /dev/smcinvoke (0660 system drmrpc / 1000:1026)
# - Strips CRLF (\r) from modules.load and modules.blocklist
# - Loads all modules with individual background execution and insmod fallback
# - Signals vendor.all.modules.ready 1
#=============================================================================

echo "vendor_modprobe: starting..." > /dev/kmsg

# 1. Ensure /vendor_dlkm is mounted
if [ ! -d /vendor_dlkm/lib/modules ]; then
	echo "vendor_modprobe: mounting /vendor_dlkm..." > /dev/kmsg
	mkdir -p /vendor_dlkm
	mount -t erofs -o ro /dev/block/mapper/vendor_dlkm_b /vendor_dlkm 2>/dev/null || \
	mount -t ext4 -o ro /dev/block/mapper/vendor_dlkm_b /vendor_dlkm 2>/dev/null || \
	mount -t erofs -o ro /dev/block/mapper/vendor_dlkm_a /vendor_dlkm 2>/dev/null || \
	mount -t ext4 -o ro /dev/block/mapper/vendor_dlkm_a /vendor_dlkm 2>/dev/null || \
	mount -t erofs -o ro /dev/block/bootdevice/by-name/vendor_dlkm_b /vendor_dlkm 2>/dev/null || \
	mount -t ext4 -o ro /dev/block/bootdevice/by-name/vendor_dlkm_b /vendor_dlkm 2>/dev/null || \
	mount -t erofs -o ro /dev/block/bootdevice/by-name/vendor_dlkm /vendor_dlkm 2>/dev/null || \
	mount -t ext4 -o ro /dev/block/bootdevice/by-name/vendor_dlkm /vendor_dlkm 2>/dev/null || true
fi

# 2. Ensure /vendor/lib/modules exists and has modules.dep
if [ ! -f /vendor/lib/modules/modules.dep ] && [ -d /vendor_dlkm/lib/modules ]; then
	echo "vendor_modprobe: bind mounting /vendor_dlkm/lib/modules to /vendor/lib/modules..." > /dev/kmsg
	mkdir -p /vendor/lib/modules
	mount -o bind /vendor_dlkm/lib/modules /vendor/lib/modules 2>/dev/null || true
fi

# 3. Determine MODULE_DIR (prefer where modules.dep or qseecom_proxy.ko actually resides)
MODULE_DIR="/vendor/lib/modules"
if [ ! -f "${MODULE_DIR}/modules.dep" ] && [ -f "/vendor_dlkm/lib/modules/modules.dep" ]; then
	MODULE_DIR="/vendor_dlkm/lib/modules"
elif [ ! -f "${MODULE_DIR}/qseecom_proxy.ko" ] && [ -f "/vendor_dlkm/lib/modules/qseecom_proxy.ko" ]; then
	MODULE_DIR="/vendor_dlkm/lib/modules"
fi

echo "vendor_modprobe: using MODULE_DIR=${MODULE_DIR}" > /dev/kmsg

# 4. Explicitly load TrustZone & security modules first via insmod & modprobe
echo "vendor_modprobe: loading qseecom_proxy, smcinvoke_dlkm, and msm_drm..." > /dev/kmsg
insmod ${MODULE_DIR}/qseecom_proxy.ko 2>/dev/null || /vendor/bin/modprobe -b -d ${MODULE_DIR} -a qseecom_proxy 2>/dev/null || true
insmod ${MODULE_DIR}/smcinvoke_dlkm.ko 2>/dev/null || /vendor/bin/modprobe -b -d ${MODULE_DIR} -a smcinvoke_dlkm 2>/dev/null || true
insmod ${MODULE_DIR}/msm_drm.ko 2>/dev/null || /vendor/bin/modprobe -b -d ${MODULE_DIR} -a msm_drm 2>/dev/null || true

# 5. Ensure /dev/smcinvoke node permissions
if [ -e /dev/smcinvoke ]; then
	chmod 0660 /dev/smcinvoke
	chown system:drmrpc /dev/smcinvoke 2>/dev/null || chown 1000:1026 /dev/smcinvoke 2>/dev/null
	echo "vendor_modprobe: /dev/smcinvoke node configured successfully" > /dev/kmsg
else
	echo "vendor_modprobe: /dev/smcinvoke not found immediately after insmod" > /dev/kmsg
fi

# 6. Load remaining modules from modules.load
if [ -f ${MODULE_DIR}/modules.load ]; then
	BLOCKLIST_EXPR="-e %"
	if [ -f ${MODULE_DIR}/modules.blocklist ]; then
		BLOCKLIST_EXPR=$(tr -d '\r' < ${MODULE_DIR}/modules.blocklist | sed -n -e 's/blocklist \(.*\)/\1/p' | sed -e 's/-/_/g' -e 's/^/-e /')
		if [ -z "${BLOCKLIST_EXPR}" ]; then
			BLOCKLIST_EXPR="-e %"
		fi
	fi

	echo "vendor_modprobe: loading modules from modules.load..." > /dev/kmsg
	LOAD_MODULES=$(tr -d '\r' < ${MODULE_DIR}/modules.load | grep -w -v ${BLOCKLIST_EXPR})

	for mod in ${LOAD_MODULES}; do
		( /vendor/bin/modprobe -b -d ${MODULE_DIR} -a ${mod} 2>/dev/null || insmod ${MODULE_DIR}/${mod} 2>/dev/null || insmod ${MODULE_DIR}/${mod}.ko 2>/dev/null ) &
	done
	wait
	echo "vendor_modprobe: all modules loaded" > /dev/kmsg
fi

# 7. Final check for /dev/smcinvoke permissions
if [ -e /dev/smcinvoke ]; then
	chmod 0660 /dev/smcinvoke
	chown system:drmrpc /dev/smcinvoke 2>/dev/null || chown 1000:1026 /dev/smcinvoke 2>/dev/null
fi

setprop vendor.all.modules.ready 1
echo "vendor_modprobe: vendor.all.modules.ready=1 set, exiting 0" > /dev/kmsg
exit 0
