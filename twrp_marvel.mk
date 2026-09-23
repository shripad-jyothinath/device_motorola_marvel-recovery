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

PRODUCT_BUILD_PROP_OVERRIDES += \
    DeviceName=marvel \
    BuildDesc="marvel-user 16 W2WE6.56-98-19 421c6f release-keys" \
    BuildFingerprint=motorola/marvel_gh/marvel:16/W2WE6.56-98-19/421c6f-2d7396:user/release-keys
