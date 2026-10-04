# Copyright (C) 2023 The Android Open Source Project
# Copyright (C) 2026 chkndrp
# Copyright (C) 2026 Shripad
# SPDX-License-Identifier: GPL-3.0-only

PRODUCT_MAKEFILES := $(LOCAL_DIR)/twrp_marvel.mk

# Android 16 (TWRP-Test twrp-16.0) uses <product>-<release>-<variant> and its
# product_config rejects the 2-part form; the official twrp-14.1 line is the
# opposite (it rejects the 3-part form). This line must match the manifest
# branch you sync - see the `branch` input in .github/workflows/build-twrp.yml.
COMMON_LUNCH_CHOICES := twrp_marvel-ap2a-eng
