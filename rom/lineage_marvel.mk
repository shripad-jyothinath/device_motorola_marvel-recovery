#
# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

TARGET_DISABLE_EPPE := true

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# LineageOS configuration.
$(call inherit-product-if-exists, vendor/lineage/config/common_full_phone.mk)

# Device configuration. This is ROM-only; the TWRP product is twrp_marvel.mk.
$(call inherit-product, device/motorola/marvel/rom/common.mk)

PRODUCT_NAME := lineage_marvel
PRODUCT_DEVICE := marvel
PRODUCT_BRAND := motorola
PRODUCT_MODEL := motorola edge 70 fusion
PRODUCT_MANUFACTURER := motorola
PRODUCT_GMS_CLIENTID_BASE := android-motorola

TARGET_BOOT_ANIMATION_RES := 1272
