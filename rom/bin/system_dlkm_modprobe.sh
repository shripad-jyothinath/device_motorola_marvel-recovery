#! /vendor/bin/sh
#=============================================================================
# Copyright (c) 2022 Qualcomm Technologies, Inc.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#
# Modifications Copyright (C) 2026 Shripad
# SPDX-License-Identifier: Apache-2.0
#
# Fixed system_dlkm_modprobe.sh for Motorola Edge 70 Fusion (marvel)
# - Strips CRLF (\r)
# - Exits cleanly (status 0) when modules.load is empty or missing,
#   preventing "modprobe: No modules given." failure.
#=============================================================================

SYSTEM_DLKM_DIR="/system_dlkm/lib/modules"
VENDOR_DLKM_DIR="/vendor_dlkm/lib/modules"

MODPROBE="/vendor/bin/modprobe"

for dir in ${SYSTEM_DLKM_DIR} ;
do
	if [ ! -e ${dir}/*/modules.load ]; then
		continue
	fi
	if [ -e ${VENDOR_DLKM_DIR}/system_dlkm.modules.blocklist ] && grep -q blocklist ${VENDOR_DLKM_DIR}/system_dlkm.modules.blocklist; then
		blocklist_expr="$(sed -n -e 's/blocklist \(.*\)/\1/p' ${VENDOR_DLKM_DIR}/system_dlkm.modules.blocklist | tr -d '\r' | sed -e 's/-/[-_]/g' -e 's/^/-e /')"
	else
		blocklist_expr="-e %"
	fi

	# Filter out modules in blocklist, stripping \r
	load_modules=$(cat ${dir}/*/modules.load 2>/dev/null | tr -d '\r' | grep -w -v ${blocklist_expr} || true)
	if [ -z "${load_modules}" ]; then
		echo "system_dlkm_modprobe: modules.load is empty, exiting cleanly."
		exit 0
	fi

	first_module=$(echo ${load_modules} | cut -d " " -f1)
	other_modules=$(echo ${load_modules} | cut -d " " -f2-)

	if [ -n "${first_module}" ]; then
		if ! ${MODPROBE} -b -s -d ${dir}/*/ -a ${first_module} > /dev/null ; then
			echo "system_dlkm_modprobe: first_module failed, continuing individual loads..."
		fi
	fi

	# Load modules individually in case one of them fails to init
	for module in ${other_modules}; do
		( ${MODPROBE} -b -s -d ${dir}/*/ -a ${module} > /dev/null ) &
	done

	wait

	exit 0
done

# If no system_dlkm modules found, exit cleanly
exit 0
