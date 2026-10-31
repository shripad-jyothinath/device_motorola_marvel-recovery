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

# ---------------------------------------------------------------------------
# Android 16 (BP2A) releases crashrecovery as an uninflated module, so its APEX
# classpath fragments live in prebuilts/module_sdk/CrashRecovery and soong
# validates them at analysis time:
#
#   java/systemserver_classpath_fragment.go:189
#     "%s in contents must also be declared in PRODUCT_APEX_SYSTEM_SERVER_JARS"
#   java/bootclasspath_fragment.go:654
#     "%s in contents must also be declared in PRODUCT_APEX_BOOT_JARS"
#
# AOSP declares both in build/make/target/product/default_art_config.mk under
# `ifeq ($(RELEASE_CRASHRECOVERY_MODULE),true)`, but that file is only inherited
# by the module/SDK products (module_common.mk, runtime_libart.mk, sdk.mk) - not
# by base.mk or any minimal recovery product. Without these two lines soong_build
# fails with:
#   prebuilts/module_sdk/CrashRecovery/current/Android.bp:110:1: module
#   "prebuilt_com.android.crashrecovery-systemserverclasspath-fragment" variant
#   "android_common": [service-crashrecovery] in contents must also be declared
#   in PRODUCT_APEX_SYSTEM_SERVER_JARS
# ---------------------------------------------------------------------------
PRODUCT_APEX_BOOT_JARS += \
    com.android.crashrecovery:framework-crashrecovery
PRODUCT_APEX_SYSTEM_SERVER_JARS += \
    com.android.crashrecovery:service-crashrecovery

# OTA assert
TARGET_OTA_ASSERT_DEVICE := marvel,marvel_g,marvel_gh,XT2605,XT2605-1,XT2605-2,XT2605-3,XT2605-4

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

# API - marvel shipped Android 16 (ro.product.first_api_level=36) on a vendor
# frozen at Android 14 (ro.board.first_api_level=34, ro.vndk.version=34)
PRODUCT_SHIPPING_API_LEVEL  := 36
PRODUCT_TARGET_VNDK_VERSION := 36
BOARD_SHIPPING_API_LEVEL    := 34
SHIPPING_API_LEVEL          := 36

# Dynamic partitions
PRODUCT_USE_DYNAMIC_PARTITIONS := true
PRODUCT_BUILD_SUPER_PARTITION  := false

# No micro SD card
PRODUCT_CHARACTERISTICS := nosdcard

# Recovery USB identity, from the stock recovery prop.default. The AOSP
# defaults (18D1 / D001 / 4EE0) have no driver on a typical Windows host.
# These must be VENDOR properties: base_vendor.mk sets them as optional
# (`?=`) vendor properties, and only a value in the same partition replaces
# those. Set in system.prop they landed earlier in the recovery prop.default
# and init's last-definition-wins rule turned them back into 18D1.
PRODUCT_VENDOR_PROPERTIES += \
    ro.recovery.usb.vid=22B8 \
    ro.recovery.usb.adb.pid=2E81 \
    ro.recovery.usb.fastboot.pid=2E80

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
    vendor_boot

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

# NOTE: no PRODUCT_SOONG_NAMESPACES for vendor/qcom/... here. The TWRP-Test
# twrp-16.0 manifest has no vendor/ tree at all except vendor/twrp, so a
# namespace path pointing at vendor/qcom/opensource/... cannot be resolved.
# Nothing in a recovery-only build comes from there - the QTI display HAL is
# prebuilt on the vendor partition, not built from source.

# ---------------------------------------------------------------------------
# TWRP - specifics
# ---------------------------------------------------------------------------
TW_THEME                := portrait_hdpi
TW_DEFAULT_LANGUAGE     := en
TW_USE_TOOLBOX          := true
TW_INCLUDE_NTFS_3G      := true
TW_INCLUDE_RESETPROP    := true
TW_INCLUDE_LIBRESETPROP := true
# panel0-backlight max_brightness=16153 on marvel (read from the running
# kernel in recovery). 2047 is not the hardware max and caps TWRP at ~12%.
TW_MAX_BRIGHTNESS       := 16153
TW_DEFAULT_BRIGHTNESS   := 8000
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
# TWRP loads these through libmodprobe, so modules.dep pulls in the
# dependencies (A171WEH.36-18 vendor_dlkm):
#   goodix_brl_mmi -> touchscreen_mmi mmi_relay mmi_info mmi_annotate
#                     panel_event_notifier sensors_class
#   smcinvoke_dlkm -> qseecom_proxy + gunyah/mem_buf deps   (QSEECom: decryption)
#   adsp_loader_dlkm -> q6/pdr/glink chain                  (ADSP boot)
#
# goodix_brl_mmi / goodix_fod_mmi / rbs_fod_mmi are in the stock
# modules.blocklist, so they must be named here explicitly.
# smcinvoke_dlkm / qseecom_proxy are not in vendor_boot's modules.load.recovery,
# so nothing else loads them in recovery.
#
# Keep this ONE unquoted list: TWRP passes a value that starts and ends with a
# quote through verbatim, so several "quoted" chunks would concatenate into one
# C string and glue neighbouring module names together.
# ---------------------------------------------------------------------------
TW_LOAD_VENDOR_MODULES_EXCLUDE_GKI := true
TW_LOAD_VENDOR_BOOT_MODULES := true
TW_LOAD_VENDOR_MODULES := \
    goodix_brl_mmi.ko goodix_fod_mmi.ko rbs_fod_mmi.ko \
    smcinvoke_dlkm.ko qseecom_proxy.ko \
    qti_battery_charger.ko adsp_loader_dlkm.ko

# ---------------------------------------------------------------------------
# TWRP - paths
# ---------------------------------------------------------------------------
# thermal_zone0 is pmxr2230-bcl-lvl0 (battery current limit, always 0);
# zone 10 is cpuss-0. Zone numbering follows tsens registration - re-check
# /sys/class/thermal/thermal_zone*/type in recovery if the reading looks wrong.
TW_CUSTOM_CPU_TEMP_PATH := "/sys/class/thermal/thermal_zone10/temp"
TW_BRIGHTNESS_PATH      := "/sys/class/backlight/panel0-backlight/brightness"

# ---------------------------------------------------------------------------
# TWRP - crypto / decryption
#
# Running on stock (XT2605-4): qseecomd, ssgtzd, qseecom@1.0-service,
# keymint-service-qti, gatekeeper-service-qti. StrongBox SKUs ("dnes") add the
# NXP keymint/weaver on the eSE, gated on ro.boot.strongbox_support.
# The blobs under recovery/root/vendor are the full dependency closure of those
# services, extracted from A171WEH.36-18 (see BLOBS.md).
# ---------------------------------------------------------------------------
TW_INCLUDE_CRYPTO               := true
TW_INCLUDE_CRYPTO_FBE           := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
TW_INCLUDE_OMAPI                := true
BOARD_USES_QCOM_FBE_DECRYPTION  := true

# System-side libraries the vendor blobs link against that TWRP does not
# already relink into the ramdisk with TW_INCLUDE_CRYPTO (libhardware,
# libgatekeeper, libhardware_legacy and libxml2 it does).
#   android.hardware.common-V2-ndk <- vendor.qti.hardware.qseecom-V1-ndk
#   libdmabufheap                  <- qseecomd, libQSEEComAPI, qseecom service
#   libnetutils, libssl            <- ssgtzd's dsi_netctrl/nicm chain
#   libion                         <- libkeymasterdeviceutils, librecovery_updater
#   libjsoncpp                     <- ssgtzd, libtaautoload
MARVEL_RECOVERY_SYSTEM_LIBS := \
    android.hardware.common-V2-ndk \
    libdmabufheap \
    libion \
    libjsoncpp \
    libnetutils \
    libssl
TARGET_RECOVERY_DEVICE_MODULES += $(MARVEL_RECOVERY_SYSTEM_LIBS)
TW_RECOVERY_ADDITIONAL_RELINK_LIBRARY_FILES += \
    $(foreach lib,$(MARVEL_RECOVERY_SYSTEM_LIBS),$(TARGET_OUT_SHARED_LIBRARIES)/$(lib).so)

# Exactly the installed OS: A171WEH.36-31 is Android 17, patch 2026-09-01
# (system and vendor). These go into the recovery image header, which the
# bootloader hands to the KeyMint TA as the running OS version/patch level.
# Do NOT use the usual 99.87.36 / 2127-12-31 spoof: a TA told the OS is newer
# than the keys treats them as needing an upgrade, and an upgraded key blob
# bound to 2127 would be rejected by Android back on 2026-08-01 (rollback),
# locking userdata. With equal levels nothing is upgraded; after a newer OTA
# the worst case is that decryption fails (writes nothing) until this is
# bumped to match.
PLATFORM_VERSION             := 17
PLATFORM_VERSION_LAST_STABLE := $(PLATFORM_VERSION)

PLATFORM_SECURITY_PATCH := 2026-09-01
VENDOR_SECURITY_PATCH   := $(PLATFORM_SECURITY_PATCH)
BOOT_SECURITY_PATCH     := $(PLATFORM_SECURITY_PATCH)
