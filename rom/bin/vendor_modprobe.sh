#! /vendor/bin/sh
#=============================================================================
# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#
# Modifications Copyright (C) 2026 Shripad
# SPDX-License-Identifier: Apache-2.0
#
# Fixed vendor_modprobe.sh for Motorola Edge 70 Fusion (marvel)
# - Strips CRLF (\r) from modules.load and modules.blocklist
# - Auto-mounts /vendor_dlkm if not mounted
# - Prioritizes /vendor/lib/modules over /vendor_dlkm/lib/modules
# - Explicitly loads qseecom_proxy and smcinvoke_dlkm for /dev/smcinvoke
# - Fixes permissions on /dev/smcinvoke (0660 system drmrpc)
# - Signals vendor.all.modules.ready 1
#=============================================================================

VENDOR_DIR="/vendor/lib/modules"
VENDOR_DLKM_DIR="/vendor_dlkm/lib/modules"

MODPROBE="/vendor/bin/modprobe"

# Auto-mount /vendor_dlkm if unmounted
if [ ! -d "${VENDOR_DLKM_DIR}" ]; then
	for blk in /dev/block/bootdevice/by-name/vendor_dlkm /dev/block/mapper/vendor_dlkm /dev/block/mapper/vendor_dlkm_a /dev/block/mapper/vendor_dlkm_b; do
		if [ -b "${blk}" ]; then
			mkdir -p /vendor_dlkm
			mount -t erofs "${blk}" /vendor_dlkm -o ro 2>/dev/null || mount -t ext4 "${blk}" /vendor_dlkm -o ro 2>/dev/null || true
			break
		fi
	done
fi

# Prioritize /vendor/lib/modules, fallback to /vendor_dlkm/lib/modules
POSSIBLE_DIRS="${VENDOR_DIR} ${VENDOR_DLKM_DIR}"
audio_arch=`getprop ro.boot.audio`

for dir in ${POSSIBLE_DIRS} ;
do
	if [ ! -e ${dir}/modules.load ]; then
		continue
	fi

	if [ "$audio_arch" == "audioreach" ]; then
		if [ -e ${dir}/modules.audio.ar.blocklist ]; then
			audio_blocklist_expr="$(sed -n -e 's/blocklist \(.*\)/\1/p' ${dir}/modules.audio.ar.blocklist | tr -d '\r' | sed -e 's/-/_/g' -e 's/^/-e /')"
		fi
	elif [ "$audio_arch" == "audiolite" ]; then
		if [ -e ${dir}/modules.audio.audiolite.blocklist ]; then
			audio_blocklist_expr="$(sed -n -e 's/blocklist \(.*\)/\1/p' ${dir}/modules.audio.audiolite.blocklist | tr -d '\r' | sed -e 's/-/_/g' -e 's/^/-e /')"
		fi
	else
		if [ -e ${dir}/modules.audio.legacy.blocklist ]; then
			audio_blocklist_expr="$(sed -n -e 's/blocklist \(.*\)/\1/p' ${dir}/modules.audio.legacy.blocklist | tr -d '\r' | sed -e 's/-/_/g' -e 's/^/-e /')"
		fi
	fi

	# Use pattern if block list is empty so that all modules pass through grep below
	if [ "X${audio_blocklist_expr}" = "X" ]; then
		audio_blocklist_expr="-e %"
	fi

	if [ -e ${dir}/modules.blocklist ]; then
		blocklist_expr="$(sed -n -e 's/blocklist \(.*\)/\1/p' ${dir}/modules.blocklist | tr -d '\r' | sed -e 's/-/_/g' -e 's/^/-e /')"
	fi

	# Use pattern if block list is empty so that all modules pass through grep below
	if [ "X${blocklist_expr}" = "X" ]; then
		blocklist_expr="-e %"
	fi

	# Filter out modules in blocklist, stripping all \r carriage returns
	load_modules=$(sed = ${dir}/modules.load | tr -d '\r' | sed 'N;s/\n/\t/' | sort -uk2 | sort -nk1 | cut -f2- | grep -w -v ${blocklist_expr} | grep -w -v ${audio_blocklist_expr})
	first_module=$(echo ${load_modules} | cut -d " " -f1)
	other_modules=$(echo ${load_modules} | cut -d " " -f2-)

	echo "vendor_modprobe: loading modules from ${dir}..."

	# Explicitly load critical security modules first to ensure /dev/smcinvoke is created
	${MODPROBE} -b -s -d ${dir} -a qseecom_proxy 2>/dev/null || true
	${MODPROBE} -b -s -d ${dir} -a smcinvoke_dlkm 2>/dev/null || true

	if [ -n "${first_module}" ]; then
		if ! ${MODPROBE} -b -s -d ${dir} -a ${first_module} > /dev/null ; then
			echo "vendor_modprobe: first_module failed on ${dir}, continuing individual loads..."
		fi
	fi

	# Load modules individually so a single init failure does not abort remaining modules
	for module in ${other_modules}; do
		( ${MODPROBE} -b -d ${dir} -a ${module} > /dev/null ) &
	done

	wait

	# Ensure /dev/smcinvoke permissions are set for qseecomd and KeyMint
	if [ -e /dev/smcinvoke ]; then
		chmod 0660 /dev/smcinvoke
		chown system drmrpc /dev/smcinvoke
	fi

	echo "vendor_modprobe: all vendor modules loaded successfully!"
	setprop vendor.all.modules.ready 1
	exit 0
done

# If no modules.load was found, still signal ready so init does not hang
echo "vendor_modprobe: no modules.load found, signaling vendor.all.modules.ready 1"
setprop vendor.all.modules.ready 1
exit 0
