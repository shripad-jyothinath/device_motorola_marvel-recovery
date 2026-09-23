# Copyright (C) 2025-2026 OrangeFox Recovery Project
# Copyright (C) 2026 chkndrp
# Copyright (C) 2026 Shripad
# SPDX-License-Identifier: GPL-3.0-only
#
# OrangeFox specifics for marvel
# Build vars: https://gitlab.com/OrangeFox/infrastructure/doc/-/blob/main/dev/build_vars.md

# Maintainer
OF_MAINTAINER := Shripad

# Screen settings (1220x2712 panel)
OF_SCREEN_H := 2712
OF_STATUS_H := 96
OF_STATUS_INDENT_LEFT := 48
OF_STATUS_INDENT_RIGHT := 48
OF_ALLOW_DISABLE_NAVBAR := 0
OF_CLOCK_POS := 1
OF_OPTIONS_LIST_NUM := 9

# Quick backup
OF_QUICK_BACKUP_LIST := /boot;/persist_image;

# Flashlight & LEDs
OF_FL_PATH1 := /tmp/of_torch
OF_USE_GREEN_LED := 0

# Security (disables MTP & ADB during the password prompt)
OF_ADVANCED_SECURITY := 1

# A/B + dedicated recovery partition
OF_VAB_ORS_WIPE_DATA_IS_FORMAT := 1
OF_AB_DEVICE_WITH_RECOVERY_PARTITION := 1
OF_ENABLE_ALL_PARTITION_TOOLS := 1

# Workarounds
OF_LOOP_DEVICE_ERRORS_TO_LOG := 1
OF_NO_TREBLE_COMPATIBILITY_CHECK := 1
OF_USE_LEGACY_TIME_FIXUP := 1

# Data / metadata
OF_WIPE_METADATA_AFTER_DATAFORMAT := 1
OF_FORCE_DATA_FORMAT_F2FS := 1
OF_UNBIND_SDCARD_F2FS := 1
OF_FORCE_CASEFOLDING := 1
OF_USE_DMCTL := 1

# FRP reset addon
OF_ENABLE_FRP_ADDON := 1

# marvel uses the AIDL boot HAL (android.hardware.boot-service.qti) - verify on device
OF_USE_AIDL_BOOT_CONTROL := 1
