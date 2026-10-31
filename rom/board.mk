# Board configuration for ROM products only.
# Included from BoardConfig.mk only when TARGET_PRODUCT is a ROM product, so the
# TWRP product keeps its existing recovery-only configuration.

DEVICE_PATH := device/motorola/marvel

# VINTF. These are the stock A171WEH.36-31 files, verified against the running
# recovery session.
DEVICE_MANIFEST_FILE := $(DEVICE_PATH)/rom/vintf/manifest.xml
DEVICE_MATRIX_FILE := $(DEVICE_PATH)/rom/vintf/compatibility_matrix.xml

# Device properties. vendor.prop is generated from the stock 36-31
# vendor/build.prop; build metadata and VNDK identity are intentionally omitted.
TARGET_VENDOR_PROP := $(DEVICE_PATH)/rom/props/vendor.prop
TARGET_SYSTEM_PROP := $(DEVICE_PATH)/rom/system.prop

# Device-specific fstab from the stock 36-31 vendor_boot first-stage ramdisk.
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/rom/fstab.qcom

# Device-specific sepolicy and service UIDs.
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/rom/sepolicy/vendor
TARGET_FS_CONFIG_GEN := $(DEVICE_PATH)/rom/config.fs

# Kernel modules are intentionally not wired here. The stock vendor_boot has
# 294 modules, but the vendor_dlkm half is not in the vendor repository or the
# extracted firmware yet. See rom/AUDIT.md.
