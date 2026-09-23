# Copyright (C) 2025-2026 OrangeFox Recovery Project
# Copyright (C) 2026 chkndrp
# Copyright (C) 2026 Shripad
# SPDX-License-Identifier: GPL-3.0-only

DEVICE_PATH := device/motorola/marvel

# Configure Virtual A/B
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/compression_with_xor.mk)

# Enable updating of APEXes
$(call inherit-product, $(SRC_TARGET_DIR)/product/updatable_apex.mk)

# Enable developer GSI keys
$(call inherit-product, $(SRC_TARGET_DIR)/product/developer_gsi_keys.mk)

# Emulated storage
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)

# OTA assert
TARGET_OTA_ASSERT_DEVICE := marvel,marvel_g,XT2605,XT2605-1,XT2605-2,XT2605-3,XT2605-4

# FastbootD support
PRODUCT_PACKAGES += \
    android.hardware.fastboot@1.1-impl-mock \
    fastbootd

# Update engine
PRODUCT_PACKAGES += \
    update_engine \
    update_engine_sideload \
    update_verifier

PRODUCT_PACKAGES_DEBUG += \
    update_engine_client

PRODUCT_PACKAGES += \
    otapreopt_script \
    checkpoint_gc

# Motorola keeps ODM content inside vendor/odm
TARGET_COPY_OUT_ODM := vendor/odm

# API - stock marvel shipped Android 16
PRODUCT_SHIPPING_API_LEVEL  := 36
PRODUCT_TARGET_VNDK_VERSION := 36
BOARD_SHIPPING_API_LEVEL    := 36
SHIPPING_API_LEVEL          := 36

# Dynamic partitions
PRODUCT_USE_DYNAMIC_PARTITIONS := true
PRODUCT_BUILD_SUPER_PARTITION  := false

# No micro SD card
PRODUCT_CHARACTERISTICS := nosdcard

# Virtual A/B
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    boot \
    dtbo \
    init_boot \
    product \
    recovery \
    system \
    system_dlkm \
    system_ext \
    vbmeta \
    vbmeta_system \
    vendor \
    vendor_boot \
    vendor_dlkm

AB_OTA_POSTINSTALL_CONFIG += \
    RUN_POSTINSTALL_system=true \
    POSTINSTALL_PATH_system=system/bin/otapreopt_script \
    FILESYSTEM_TYPE_system=erofs \
    POSTINSTALL_OPTIONAL_system=true

AB_OTA_POSTINSTALL_CONFIG += \
    RUN_POSTINSTALL_vendor=true \
    POSTINSTALL_PATH_vendor=bin/checkpoint_gc \
    FILESYSTEM_TYPE_vendor=erofs \
    POSTINSTALL_OPTIONAL_vendor=true

PRODUCT_SOONG_NAMESPACES += \
    vendor/qcom/opensource/commonsys-intf/display

# ---------------------------------------------------------------------------
# TWRP - specifics
# ---------------------------------------------------------------------------
TW_THEME                := portrait_hdpi
TW_DEFAULT_LANGUAGE     := en
TW_USE_TOOLBOX          := true
TW_INCLUDE_NTFS_3G      := true
TW_INCLUDE_RESETPROP    := true
TW_INCLUDE_LIBRESETPROP := true
TW_MAX_BRIGHTNESS       := 2047
TW_DEFAULT_BRIGHTNESS   := 1200
TW_EXTRA_LANGUAGES      := true
TW_EXCLUDE_APEX         := true
TW_INCLUDE_FASTBOOTD    := true
TWRP_INCLUDE_LOGCAT     := true
TW_INCLUDE_PYTHON       := true
TW_NO_SCREEN_BLANK      := true
TW_NO_SCREEN_TIMEOUT    := true
TW_FRAMERATE            := 120
TW_MTP_DEVICE           := "motorola edge 70 fusion"
TW_USE_SERIALNO_PROPERTY_FOR_DEVICE_ID := true
TW_INCLUDE_FB2PNG       := true
TW_INCLUDE_REPACKTOOLS  := true
TW_EXCLUDE_TWRPAPP      := true

# ---------------------------------------------------------------------------
# TWRP - kernel modules loaded at runtime from /vendor/lib/modules
#
# Dependency order from the marvel firmware dump modules.dep:
#   mmi_annotate -> mmi_info -> mmi_relay -> panel_event_notifier -> sensors_class
#     -> touchscreen_mmi -> goodix_brl_mmi
#
# goodix_brl_mmi / goodix_fod_mmi / rbs_fod_mmi are listed in modules.blocklist
# on the stock ROM, so they must be pulled in explicitly.
# ---------------------------------------------------------------------------
TW_LOAD_VENDOR_MODULES_EXCLUDE_GKI := true
TW_LOAD_VENDOR_BOOT_MODULES := true
TW_LOAD_VENDOR_MODULES += \
    "mmi_annotate.ko mmi_info.ko mmi_relay.ko panel_event_notifier.ko"
TW_LOAD_VENDOR_MODULES += \
    "sensors_class.ko touchscreen_mmi.ko goodix_brl_mmi.ko"
TW_LOAD_VENDOR_MODULES += \
    "goodix_fod_mmi.ko rbs_fod_mmi.ko mmi_stow.ko"
TW_LOAD_VENDOR_MODULES += \
    "qti_battery_charger.ko camera.ko adsp_loader_dlkm.ko"

# ---------------------------------------------------------------------------
# TWRP - paths
# ---------------------------------------------------------------------------
TW_CUSTOM_CPU_TEMP_PATH := "/sys/class/thermal/thermal_zone0/temp"
TW_BRIGHTNESS_PATH      := "/sys/class/backlight/panel0-backlight/brightness"

# ---------------------------------------------------------------------------
# TWRP - crypto / decryption
#
# marvel: QTI keymint/gatekeeper (QSEE) + StrongBox/Weaver/AuthSecret.
# The vendor tree ships both NXP and Thales implementations; this device uses NXP.
# (vendor/motorola/marvel/config.fs owns:
#    AID_VENDOR_NXP_STRONGBOX / AID_VENDOR_NXP_WEAVER / AID_VENDOR_NXP_AUTHSECRET
#    AID_VENDOR_SSGTZD)
# ---------------------------------------------------------------------------
TW_INCLUDE_CRYPTO               := true
TW_INCLUDE_CRYPTO_FBE           := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
TW_INCLUDE_OMAPI                := true
BOARD_USES_QCOM_FBE_DECRYPTION  := true

PLATFORM_VERSION             := 99.87.36
PLATFORM_VERSION_LAST_STABLE := $(PLATFORM_VERSION)

PLATFORM_SECURITY_PATCH := 2127-12-31
VENDOR_SECURITY_PATCH   := $(PLATFORM_SECURITY_PATCH)
BOOT_SECURITY_PATCH     := $(PLATFORM_SECURITY_PATCH)
