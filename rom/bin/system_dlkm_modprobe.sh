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

# If modules exist, load them
DIR=$(dirname "${LOAD_FILE}")
LOAD_MODULES=$(tr -d '\r' < "${LOAD_FILE}")
for mod in ${LOAD_MODULES}; do
	( /vendor/bin/modprobe -b -d "${DIR}" -a "${mod}" 2>/dev/null || insmod "${DIR}/${mod}" 2>/dev/null || insmod "${DIR}/${mod}.ko" 2>/dev/null ) &
done
wait

echo "system_dlkm_modprobe: done, exiting 0" > /dev/kmsg
exit 0
