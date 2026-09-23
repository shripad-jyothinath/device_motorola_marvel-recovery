# Copyright (C) 2023 The Android Open Source Project
# Copyright (C) 2026 chkndrp
# Copyright (C) 2026 Shripad
# SPDX-License-Identifier: GPL-3.0-only

PRODUCT_MAKEFILES := $(LOCAL_DIR)/twrp_marvel.mk

COMMON_LUNCH_CHOICES := twrp_marvel-ap2a-eng
# NOTE: the release tag ("ap2a") comes from the manifest you sync.
# With TWRP-Test/platform_manifest_twrp_aosp twrp_16 the tag may differ;
# check `lunch` output and adjust here and in the build command.
