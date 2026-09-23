#!/system/bin/sh
#
# Copyright (C) 2026 Shripad
# SPDX-License-Identifier: GPL-3.0-only
#
# Motorola Edge 70 Fusion (marvel) recovery touch bring-up.
#
# Marvel uses the Motorola "MMI" touch stack with a Goodix BRL controller.
# The controller driver is listed in modules.blocklist on the stock ROM, so it
# is never auto-loaded - recovery has to pull the chain in explicitly.
#
# Dependency order from the firmware dump modules.dep:
#   mmi_annotate -> mmi_info -> mmi_relay -> panel_event_notifier -> sensors_class
#     -> touchscreen_mmi -> goodix_brl_mmi

LOG_TAG="marvel_touch"
log() { echo "$LOG_TAG: $*"; }

if [ "$(getprop twrp.marvel.touch.loaded)" = "1" ]; then
    log "already loaded, skipping"
    exit 0
fi

MODULE_DIRS="/vendor/lib/modules /vendor_dlkm/lib/modules /lib/modules /system/lib/modules /system_dlkm/lib/modules"

TOUCH_MODULES="mmi_annotate mmi_info mmi_relay panel_event_notifier sensors_class touchscreen_mmi goodix_brl_mmi goodix_fod_mmi rbs_fod_mmi"

is_loaded() { grep -q "^$1 " /proc/modules 2>/dev/null; }

for mod in $TOUCH_MODULES; do
    is_loaded "$mod" && continue
    for dir in $MODULE_DIRS; do
        ko="$dir/$mod.ko"
        if [ -f "$ko" ]; then
            insmod "$ko" 2>/dev/null && log "loaded $mod from $dir" || log "insmod $mod failed"
            break
        fi
    done
done

# Give the input subsystem a moment to register the touch device.
i=0
while [ $i -lt 10 ]; do
    grep -qiE "goodix|touchscreen|mmi" /proc/bus/input/devices 2>/dev/null && break
    sleep 1
    i=$((i + 1))
done

setprop twrp.marvel.touch.loaded 1
log "done"
exit 0
