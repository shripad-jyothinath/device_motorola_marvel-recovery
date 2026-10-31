# Copyright (C) 2023 The Android Open Source Project
# Copyright (C) 2026 chkndrp
# Copyright (C) 2026 Shripad
# SPDX-License-Identifier: GPL-3.0-only

PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/twrp_marvel.mk \
    $(LOCAL_DIR)/rom/evolution_marvel.mk \
    $(LOCAL_DIR)/rom/lineage_marvel.mk

# Android 16 (TWRP-Test twrp-16.0) uses <product>-<release>-<variant> and its
# product_config rejects the 2-part form; the official twrp-14.1 line is the
# opposite (it rejects the 3-part form). This line must match the manifest
# branch you sync - see the `branch` input in .github/workflows/build-twrp.yml.
#
# Release must be bp2a (RELEASE_BOARD_API_LEVEL 202504). ap2a (202404) cannot
# build this tree: system/sepolicy/vendor/hal_hwcrypto_default.te uses
# hal_hwcrypto unconditionally, but public/attributes only declares it
# starting_at_board_api(202504), so checkpolicy fails on vendor_sepolicy.cil.
COMMON_LUNCH_CHOICES := twrp_marvel-bp2a-eng
