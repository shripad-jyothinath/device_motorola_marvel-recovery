# Copyright (C) 2025-2026 OrangeFox Recovery Project
# Copyright (C) 2026 chkndrp
# Copyright (C) 2026 Shripad
# SPDX-License-Identifier: GPL-3.0-only
#
# Motorola Edge 70 Fusion (marvel / XT2605)
# Rebranded from chkndrp/device_xiaomi_amethyst-recovery (same SoC SM7635 "volcano",
# same partition scheme: dynamic super + A/B + dedicated recovery partition,
# recovery image built without a kernel).

DEVICE_PATH := device/motorola/marvel

# 64-bit-only architecture
TARGET_ARCH                := arm64
TARGET_ARCH_VARIANT        := armv8-2a-dotprod
TARGET_CPU_ABI             := arm64-v8a
TARGET_CPU_VARIANT         := generic
# Same SoC as amethyst (SM7635: 1x2.5GHz A720 + 3x2.4GHz A720 + 4x1.8GHz A520)
TARGET_CPU_VARIANT_RUNTIME := kryo300

# Platform
TARGET_BOOTLOADER_BOARD_NAME  := marvel
TARGET_BOARD_PLATFORM         := volcano
TARGET_BOARD_PLATFORM_GPU     := qcom-adreno810
TARGET_USES_UEFI              := true
BOARD_USES_QCOM_HARDWARE      := true

# Kernel / recovery image
TARGET_PREBUILT_KERNEL        := $(DEVICE_PATH)/prebuilt/kernel
TARGET_KERNEL_ARCH            := $(TARGET_ARCH)
TARGET_KERNEL_HEADER_ARCH     := $(TARGET_ARCH)

BOARD_KERNEL_PAGESIZE         := 4096
BOARD_KERNEL_IMAGE_NAME       := kernel
BOARD_BOOT_HEADER_VERSION     := 4
BOARD_MKBOOTIMG_ARGS          += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS          += --pagesize $(BOARD_KERNEL_PAGESIZE)
BOARD_INIT_BOOT_HEADER_VERSION := 4
BOARD_MKBOOTIMG_INIT_ARGS     += --header_version $(BOARD_INIT_BOOT_HEADER_VERSION)

# Generic system/kernel image
BOARD_USES_GENERIC_KERNEL_IMAGE := true
BOARD_MOVE_GSI_AVB_KEYS_TO_VENDOR_BOOT := true
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true

# VA/B with a dedicated recovery partition. Leave these blank as Google recommends.
BOARD_USES_RECOVERY_AS_BOOT :=
BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT :=

# LZ4 ramdisk
BOARD_RAMDISK_USE_LZ4 := true

# DTB / DTBO
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
BOARD_PREBUILT_DTBIMAGE_DIR  := $(DEVICE_PATH)/prebuilt/dtb
TARGET_NEEDS_DTBOIMAGE       := true
BOARD_PREBUILT_DTBOIMAGE     := $(DEVICE_PATH)/prebuilt/dtbo.img

# AVB
BOARD_AVB_ENABLE := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3
BOARD_AVB_ROLLBACK_INDEX := 1

# Recovery image signing. Mirrors android_device_motorola_genevn - the closest
# official tree in existence for this shape (Motorola + kernel-less recovery +
# dedicated recovery partition + A/B + BOARD_AVB_ENABLE), see
# docs/13 in the bringup repo. With BOARD_AVB_ENABLE := true and no key for the
# recovery partition, the recoveryimage target has no AVB key to use.
# NOTE: this does NOT make the image verify on marvel - stock vbmeta.img carries
# its own hash descriptor for `recovery` (OEM key), so a self-built recovery
# cannot match it. Signing with test keys is what every official tree does and
# it only affects the image's own footer.
BOARD_AVB_RECOVERY_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_RECOVERY_ALGORITHM := SHA256_RSA4096
BOARD_AVB_RECOVERY_ROLLBACK_INDEX := 1
BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION := 1

BOARD_AVB_VBMETA_SYSTEM := system
BOARD_AVB_VBMETA_SYSTEM_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_VBMETA_SYSTEM_ALGORITHM := SHA256_RSA2048
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX_LOCATION := 1

# Build errors we knowingly accept
ALLOW_MISSING_DEPENDENCIES := true
BUILD_BROKEN_USES_NETWORK := true
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_MISSING_REQUIRED_MODULES := true

# Partitions - sizes verified against the device with `fastboot getvar partition-size:*`
BOARD_FLASH_BLOCK_SIZE                := 262144
BOARD_RECOVERYIMAGE_PARTITION_SIZE    := 134217728
BOARD_BOOTIMAGE_PARTITION_SIZE        := 100663296
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE  := 8388608
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_DTBOIMG_PARTITION_SIZE          := 34603008

BOARD_USES_METADATA_PARTITION := true
BOARD_HAS_NO_REAL_SDCARD := true
BOARD_BUILD_VENDOR_RAMDISK_IMAGE := true

# Dynamic partitions
BOARD_SUPER_PARTITION_SIZE        := 21474836480
BOARD_SUPER_PARTITION_GROUPS      := mot_dp_group
BOARD_MOT_DP_GROUP_SIZE           := 21470642176
# NOTE: marvel has no "odm" partition (TARGET_COPY_OUT_ODM := vendor/odm)
BOARD_MOT_DP_GROUP_PARTITION_LIST := \
    system \
    system_ext \
    product \
    vendor \
    vendor_dlkm \
    system_dlkm

BOARD_PARTITION_LIST := $(call to-upper, $(BOARD_MOT_DP_GROUP_PARTITION_LIST))
$(foreach p, $(BOARD_PARTITION_LIST), $(eval BOARD_$(p)IMAGE_FILE_SYSTEM_TYPE ?= erofs))
$(foreach p, $(BOARD_PARTITION_LIST), $(eval TARGET_COPY_OUT_$(p) := $(call to-lower, $(p))))
$(foreach p, $(filter-out SYSTEM, $(BOARD_PARTITION_LIST)), $(eval BOARD_USES_$(p)IMAGE := true))

# Marvel's shipped layout uses ext4 for product/vendor_dlkm/system_dlkm
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE     := ext4
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE := ext4
TARGET_COPY_OUT_ODM := vendor/odm

# Display (same 1220x2712 panel family as amethyst)
TARGET_SCREEN_HEIGHT  := 2712
TARGET_SCREEN_WIDTH   := 1220
TARGET_SCREEN_DENSITY := 440

# Filesystems
TARGET_USERIMAGES_USE_EXT4    := true
TARGET_USERIMAGES_USE_F2FS    := true
TARGET_USES_MKE2FS            := true

# Recovery
TARGET_SYSTEM_PROP := $(DEVICE_PATH)/system.prop
TARGET_ODM_PROP    += $(DEVICE_PATH)/odm.prop
TARGET_PRODUCT_PROP += $(DEVICE_PATH)/product.prop
TARGET_VENDOR_PROP += $(DEVICE_PATH)/vendor.prop
TARGET_SYSTEM_EXT_PROP += $(DEVICE_PATH)/system_ext.prop

TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery/root/system/etc/recovery.fstab
TARGET_BOARD_INFO_FILE := $(DEVICE_PATH)/board-info.txt

TARGET_USE_CUSTOM_LUN_FILE_PATH := /config/usb_gadget/g1/functions/mass_storage.0/lun.%d/file

# USB: we ship the stock-derived init.recovery.usb.rc, so TWRP's default one
# must not fight with it. The stock unit forces the QTI dwc3 into peripheral
# mode and uses Motorola VID/PIDs (0x22B8 / 0x2E81 adb / 0x2E80 fastboot).
TW_EXCLUDE_DEFAULT_USB_INIT := true

TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
RECOVERY_GRAPHICS_FORCE_USE_LINELENGTH := true
TARGET_RECOVERY_QCOM_RTC_FIX := true
TARGET_RECOVERY_DEVICE_DIRS += $(DEVICE_PATH)

# Kernel modules: see TW_LOAD_VENDOR_MODULES in device.mk
# (module names TWRP loads at runtime from /vendor/lib/modules, dependency order
#  taken from the marvel firmware dump modules.dep)

# Debugging
TARGET_USES_LOGD := true

# SELinux
-include device/qcom/sepolicy_vndr/SEPolicy.mk
-include device/lineage/sepolicy/libperfmgr/sepolicy.mk
-include hardware/motorola/sepolicy/qti/SEPolicy.mk
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor
