# Board configuration for ROM products only.
# Included from BoardConfig.mk only when TARGET_PRODUCT is a ROM product, so the
# TWRP product keeps its existing recovery-only configuration.

DEVICE_PATH := device/motorola/marvel

# The board is API 34 even though the product first API is 36.
BOARD_SHIPPING_API_LEVEL := 34

# VINTF. These are the stock A171WEH.36-31 files, verified against the running
# recovery session.
# VINTF manifests:
# - Vendor primary manifest (manifest_volcano.xml): the HIDL/QTI HAL set. The
#   KeyMint/QSEECom/boot AIDL declarations are in the stock fragments under
#   /vendor/etc/vintf/manifest/, which the stock vendor image supplies at runtime.
# - ODM manifest: stock per-SKU file. The verified unit is the "dn" SKU
#   (XT2605-4); its manifest declares NFC, secure_element SIM1/SIM2 and NXP NFC
#   only. The bnes/dnes variants add NXP StrongBox/weaver on the eSE; selecting
#   one of those on a dn unit reintroduces the Boot 66/67 FqInstance conflicts.
# Separating vendor and ODM avoids duplicate FqInstance errors in libvintf.
ifeq ($(MARVEL_BUILD_VENDOR_IMAGE),true)
DEVICE_MANIFEST_FILE := vendor/motorola/marvel/proprietary/vendor/etc/vintf/manifest_volcano.xml
# The verified unit is the "dn" SKU (XT2605-4). The stock ODM tree carries
# manifest_bn/bnes/dn/dnes; using bnes here declares NXP StrongBox/weaver on a
# device that has neither and reintroduces the Boot 66/67 FqInstance conflicts.
ODM_MANIFEST_FILES += vendor/motorola/marvel/proprietary/odm/etc/vintf/manifest_dn.xml
DEVICE_MATRIX_FILE := vendor/motorola/marvel/proprietary/vendor/etc/vintf/compatibility_matrix.xml
else
DEVICE_MANIFEST_FILE := $(DEVICE_PATH)/rom/vintf/manifest.xml
ODM_MANIFEST_FILES += $(DEVICE_PATH)/rom/vintf/manifest_dn.xml
DEVICE_MATRIX_FILE := $(DEVICE_PATH)/rom/vintf/compatibility_matrix.xml
endif
DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE := $(DEVICE_PATH)/rom/vintf/framework_compatibility_matrix.xml

# Device properties. vendor.prop is generated from the stock 36-31
# vendor/build.prop. Stock build metadata (ro.vendor.build.*) is intentionally
# omitted so the build can re-stamp it; the VNDK/API identity
# (ro.vndk.version=34, ro.board.api_level=34, ro.product.first_api_level=36)
# is kept from stock, and the three Motorola SKU/hardware/carrier imports are
# present. The default prebuilt-stock-vendor product uses the stock vendor
# image's own build.prop on the device; this file is consumed by the optional
# vendor-image build.
TARGET_VENDOR_PROP := $(DEVICE_PATH)/rom/props/vendor.prop
TARGET_SYSTEM_PROP := $(DEVICE_PATH)/rom/system.prop

# Device-specific fstab from the stock 36-31 vendor_boot first-stage ramdisk.
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/rom/fstab.qcom

# Device-specific sepolicy and service UIDs. The mosey paths are donor
# system_ext rules; include each only when the source tree actually has it.
ifneq ($(wildcard device/lineage/sepolicy/mosey/system_ext/public),)
SYSTEM_EXT_PUBLIC_SEPOLICY_DIRS += device/lineage/sepolicy/mosey/system_ext/public
endif
ifneq ($(wildcard device/lineage/sepolicy/mosey/system_ext/private),)
SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += device/lineage/sepolicy/mosey/system_ext/private
endif
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

# BoardConfigSoong.mk exports these before this file sets them; refresh the
# exported Soong values now that the final paths are known.

# Kernel modules are supplied by the stock vendor_dlkm partition in the default
# build. The stock-vendor-36-31 vendor tree does not contain .ko files; the
# vendor_dlkm partition remains the prebuilt stock/patched image.

# Default to the exact stock vendor images dumped from the device's slot A.
# MARVEL_BUILD_VENDOR_IMAGE=true switches to the source-complete vendor tree
# and leaves BOARD_PREBUILT_VENDORIMAGE empty so the vendor image is generated.
#
# Point MARVEL_STOCK_IMAGE_DIR at the directory holding the stock vendor_dlkm
# dump when building, for example .../marvel-data/stock-vendor-images.
MARVEL_STOCK_IMAGE_DIR ?= $(CURDIR)/stock-images
ifneq ($(MARVEL_BUILD_VENDOR_IMAGE),true)
BOARD_PREBUILT_VENDORIMAGE := $(MARVEL_STOCK_IMAGE_DIR)/vendor_a_stock.img
else
BOARD_PREBUILT_VENDORIMAGE :=
endif
BOARD_PREBUILT_VENDOR_DLKMIMAGE := $(MARVEL_STOCK_IMAGE_DIR)/vendor_dlkm_a_stock.img

# GKI modules for system_dlkm. The stock 60-module set is the only set that
# matches the stock 6.1 kernel; an empty system_dlkm breaks Bluetooth, NFC,
# USB tethering, zram and every vendor module that depends on those GKI
# modules. Keep the source directory next to the stock vendor images.
MARVEL_STOCK_DLKM_DIR ?= $(MARVEL_STOCK_IMAGE_DIR)/system_dlkm

ifeq ($(MARVEL_BUILD_VENDOR_IMAGE),true)
# Vendor-image mode uses the flat AOSP-generated system_dlkm layout and the
# robust device-tree system_dlkm_modprobe.sh (installed from rom/common.mk).
BOARD_SYSTEM_KERNEL_MODULES := $(shell find -L $(MARVEL_STOCK_DLKM_DIR)/lib/modules -type f -name '*.ko' | sort)
ifeq ($(strip $(BOARD_SYSTEM_KERNEL_MODULES)),)
$(error Stock system_dlkm modules not found under $(MARVEL_STOCK_DLKM_DIR)/lib/modules; copy the 60 stock GKI .ko files there)
endif
# AOSP treats BOARD_SYSTEM_KERNEL_MODULES_LOAD as a module list, not a
# boolean. Keep the exact stock 60-entry order; AOSP writes the basenames into
# the generated modules.load. Fall back to the module list if the stock
# modules.load is absent (for example a flattened donor tree).
BOARD_SYSTEM_KERNEL_MODULES_LOAD := $(shell cat $(MARVEL_STOCK_DLKM_DIR)/lib/modules/*/modules.load 2>/dev/null)
ifeq ($(strip $(BOARD_SYSTEM_KERNEL_MODULES_LOAD)),)
BOARD_SYSTEM_KERNEL_MODULES_LOAD := $(notdir $(BOARD_SYSTEM_KERNEL_MODULES))
endif
else
# Default stock-vendor mode keeps the stock nested system_dlkm tree
# (lib/modules/<kernel>/...); the stock vendor system_dlkm_modprobe.sh then
# finds the versioned modules.load without a device-tree override.
BOARD_SYSTEM_DLKM_SRC := $(realpath $(MARVEL_STOCK_DLKM_DIR))
ifeq ($(strip $(BOARD_SYSTEM_DLKM_SRC)),)
$(error Stock system_dlkm source not found at $(MARVEL_STOCK_DLKM_DIR); point MARVEL_STOCK_DLKM_DIR at the stock system_dlkm tree)
endif
ifeq ($(wildcard $(BOARD_SYSTEM_DLKM_SRC)/lib/modules/*/modules.load),)
$(error Default stock-vendor mode needs the nested lib/modules/<kernel>/modules.load tree; point MARVEL_STOCK_DLKM_DIR at the stock system_dlkm tree or set MARVEL_BUILD_VENDOR_IMAGE=true)
endif
endif

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
#
# MARVEL_VENDOR_BOOT_IMAGE overrides it for a locally patched stock
# vendor_boot (the 4-token modules.alias fix, or a permissive diagnostic build).
# The patched images are not covered by rom/tools/vendor-modules.lock, which
# records the stock ed750888... image.
MARVEL_VENDOR_BOOT_IMAGE ?= $(DEVICE_PATH)/prebuilt/vendor_boot_a.img
BOARD_PREBUILT_VENDOR_BOOTIMAGE := $(MARVEL_VENDOR_BOOT_IMAGE)

# Stock marvel's top-level vbmeta has a direct recovery hash descriptor, not a
# chained recovery partition. Do not emit a test-key recovery chain in the ROM
# vbmeta; keep the recovery image buildable without adding that chain.
BOARD_AVB_RECOVERY_KEY_PATH :=
BOARD_AVB_RECOVERY_ALGORITHM :=
BOARD_AVB_RECOVERY_ROLLBACK_INDEX :=
BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION :=

# Register the full Lineage Soong variable set after all local paths are set.
include vendor/lineage/config/BoardConfigKernel.mk
include vendor/lineage/config/BoardConfigSoong.mk
