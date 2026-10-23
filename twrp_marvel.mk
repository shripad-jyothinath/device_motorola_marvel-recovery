# Copyright (C) 2025-2026 OrangeFox Recovery Project
# Copyright (C) 2026 chkndrp
# Copyright (C) 2026 Shripad
# SPDX-License-Identifier: GPL-3.0-only
#
# Motorola Edge 70 Fusion (marvel)

# Inherit from these configurations
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)

# Inherit from device configuration
$(call inherit-product, device/motorola/marvel/device.mk)

# Inherit from TWRP common configuration
$(call inherit-product, vendor/twrp/config/common.mk)

# Import OrangeFox specifics
$(call inherit-product, device/motorola/marvel/fox_marvel.mk)

PRODUCT_DEVICE := marvel
PRODUCT_BRAND := motorola
PRODUCT_MODEL := motorola edge 70 fusion
PRODUCT_MANUFACTURER := motorola
PRODUCT_NAME := twrp_$(PRODUCT_DEVICE)

# No PRODUCT_BUILD_PROP_OVERRIDES (DeviceName/BuildDesc/BuildFingerprint): those
# keys are a LineageOS build extension. In this AOSP/TWRP tree they were a
# silent no-op, and stock recovery carries no fingerprint either. The target
# firmware is A171WEH.36-18 (marvel_gh-user 17, ccd1da-3f1b2) - see device.mk.
