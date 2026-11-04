# Board configuration for ROM products only.
# Included from BoardConfig.mk only when TARGET_PRODUCT is a ROM product, so the
# TWRP product keeps its existing recovery-only configuration.

DEVICE_PATH := device/motorola/marvel

# VINTF. These are the stock A171WEH.36-31 files, verified against the running
# recovery session.
DEVICE_MANIFEST_FILE := $(DEVICE_PATH)/rom/vintf/manifest.xml
DEVICE_MATRIX_FILE := $(DEVICE_PATH)/rom/vintf/compatibility_matrix.xml
DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE := $(DEVICE_PATH)/rom/vintf/framework_compatibility_matrix.xml

# Device properties. vendor.prop is generated from the stock 36-31
# vendor/build.prop; build metadata and VNDK identity are intentionally omitted.
TARGET_VENDOR_PROP := $(DEVICE_PATH)/rom/props/vendor.prop
TARGET_SYSTEM_PROP := $(DEVICE_PATH)/rom/system.prop

# Device-specific fstab from the stock 36-31 vendor_boot first-stage ramdisk.
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/rom/fstab.qcom

# Device-specific sepolicy and service UIDs.
SYSTEM_EXT_PUBLIC_SEPOLICY_DIRS += device/lineage/sepolicy/mosey/system_ext/public
SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += device/lineage/sepolicy/mosey/system_ext/private
BOARD_VENDOR_SEPOLICY_DIRS += device/lineage/sepolicy/common/public
BOARD_VENDOR_SEPOLICY_DIRS += device/lineage/sepolicy/common/dynamic
BOARD_VENDOR_SEPOLICY_DIRS += device/lineage/sepolicy/common/vendor
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/rom/sepolicy/vendor
TARGET_FS_CONFIG_GEN := $(DEVICE_PATH)/rom/config.fs

# Lineage's Soong kernel generators reference KERNEL_BUILD_OUT_PREFIX even for
# a prebuilt kernel. EXPORT_TO_SOONG only passes it when Lineage's
# BoardConfigKernel.mk detects the standard relative out dir, so pin it here
# after the vendor board config has been processed.
KERNEL_BUILD_OUT_PREFIX := $(CURDIR)/
TARGET_PREBUILT_KERNEL_HEADERS := $(CURDIR)/device/motorola/marvel/prebuilt/kernel-headers.tar.gz

# Kernel modules are supplied by the stock vendor_dlkm partition in the default
# build. The rom-ready vendor branch also contains the 292 stock .ko files and
# their copy rules for an optional full vendor image.

# Use the exact stock vendor images dumped from the device's slot A. The
# vendor tree on this build host is not a complete 36-31 image, so generating
# vendor from it would overwrite the stock partitions with partial data.
#
# Point MARVEL_STOCK_IMAGE_DIR at the directory holding the two dumps when
# building, for example .../marvel-data/stock-vendor-images.
MARVEL_STOCK_IMAGE_DIR ?= $(CURDIR)/stock-images
BOARD_PREBUILT_VENDORIMAGE := $(MARVEL_STOCK_IMAGE_DIR)/vendor_a_stock.img
BOARD_PREBUILT_VENDOR_DLKMIMAGE := $(MARVEL_STOCK_IMAGE_DIR)/vendor_dlkm_a_stock.img

ifneq ($(MARVEL_BUILD_VENDOR_IMAGE),true)
ifeq ($(wildcard $(BOARD_PREBUILT_VENDORIMAGE)),)
$(error Stock vendor image not found at $(BOARD_PREBUILT_VENDORIMAGE). Set MARVEL_STOCK_IMAGE_DIR to the directory containing vendor_a_stock.img and vendor_dlkm_a_stock.img)
endif
ifeq ($(wildcard $(BOARD_PREBUILT_VENDOR_DLKMIMAGE)),)
$(error Stock vendor_dlkm image not found at $(BOARD_PREBUILT_VENDOR_DLKMIMAGE). Set MARVEL_STOCK_IMAGE_DIR to the directory containing vendor_a_stock.img and vendor_dlkm_a_stock.img)
endif
endif

# The ROM product's generated vendor_boot has no first-stage fstab and no
# kernel modules. The stock vendor_boot carries both (first_stage_ramdisk plus
# 294 modules), and the boot kernel is byte-identical between the stock A and
# ROM B images, so use the stock image directly.
BOARD_PREBUILT_VENDOR_BOOTIMAGE := $(DEVICE_PATH)/prebuilt/vendor_boot_a.img

# Stock marvel's top-level vbmeta has a direct recovery hash descriptor, not a
# chained recovery partition. Do not emit a test-key recovery chain in the ROM
# vbmeta; keep the recovery image buildable without adding that chain.
BOARD_AVB_RECOVERY_KEY_PATH :=
BOARD_AVB_RECOVERY_ALGORITHM :=
BOARD_AVB_RECOVERY_ROLLBACK_INDEX :=
BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION :=
