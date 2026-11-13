#! /vendor/bin/sh
#=============================================================================
# Copyright (c) 2022 Qualcomm Technologies, Inc.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#
# Modifications Copyright (C) 2026 Shripad
# SPDX-License-Identifier: Apache-2.0
#
# Robust system_dlkm_modprobe.sh for Motorola Edge 70 Fusion (marvel)
# - Strips CRLF (\r)
# - Exits cleanly (status 0) when modules.load is empty or missing,
#   preventing "modprobe: No modules given." failure.
#=============================================================================

echo "system_dlkm_modprobe: starting..." > /dev/kmsg

SYSTEM_DLKM_DIR="/system_dlkm/lib/modules"

# Check if any modules.load exists and is non-empty
LOAD_FILE=""
if [ -s "${SYSTEM_DLKM_DIR}/modules.load" ]; then
	LOAD_FILE="${SYSTEM_DLKM_DIR}/modules.load"
elif [ -d "${SYSTEM_DLKM_DIR}" ]; then
	for f in ${SYSTEM_DLKM_DIR}/*/modules.load; do
		if [ -s "$f" ]; then
			LOAD_FILE="$f"
			break
		fi
	done
fi

if [ -z "${LOAD_FILE}" ]; then
	echo "system_dlkm_modprobe: No system_dlkm modules to load (empty or missing), exiting 0" > /dev/kmsg
	exit 0
fi

# If modules exist, load the first one sequentially (matching the stock
# script's dependency-safe first load), then load the rest in parallel.
DIR=$(dirname "${LOAD_FILE}")
VENDOR_DLKM_DIR="/vendor_dlkm/lib/modules"
BLOCKLIST_EXPR="-e %"
if [ -e "${VENDOR_DLKM_DIR}/system_dlkm.modules.blocklist" ] && \
   grep -q blocklist "${VENDOR_DLKM_DIR}/system_dlkm.modules.blocklist"; then
	BLOCKLIST_EXPR="$(sed -n -e 's/blocklist \(.*\)/\1/p' "${VENDOR_DLKM_DIR}/system_dlkm.modules.blocklist" | \
		sed -e 's/-/[-_]/g' -e 's/^/-e /')"
	[ -n "${BLOCKLIST_EXPR}" ] || BLOCKLIST_EXPR="-e %"
fi
LOAD_MODULES=$(tr -d '\r' < "${LOAD_FILE}" | grep -w -v ${BLOCKLIST_EXPR})
FIRST=""
OTHERS=""
for mod in ${LOAD_MODULES}; do
	if [ -z "${FIRST}" ]; then
		FIRST="${mod}"
	else
		OTHERS="${OTHERS} ${mod}"
	fi
done

if [ -n "${FIRST}" ]; then
	/vendor/bin/modprobe -b -d "${DIR}" -a "${FIRST}" 2>/dev/null || \
		insmod "${DIR}/${FIRST}" 2>/dev/null || \
		insmod "${DIR}/${FIRST}.ko" 2>/dev/null
fi

for mod in ${OTHERS}; do
	( /vendor/bin/modprobe -b -d "${DIR}" -a "${mod}" 2>/dev/null || insmod "${DIR}/${mod}" 2>/dev/null || insmod "${DIR}/${mod}.ko" 2>/dev/null ) &
done
wait

echo "system_dlkm_modprobe: done, exiting 0" > /dev/kmsg
exit 0
