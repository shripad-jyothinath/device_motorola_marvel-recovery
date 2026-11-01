# ROM product configuration for Motorola Edge 70 Fusion (marvel).
#
# This is deliberately separate from device.mk: device.mk is the TWRP/recovery
# product and must keep building exactly as it does today.
#
# Default mode uses the stock vendor and stock vendor_dlkm partitions. The
# vendor repository is only needed when MARVEL_BUILD_VENDOR_IMAGE=true, and the
# audit in rom/AUDIT.md must be addressed first.

DEVICE_PATH := device/motorola/marvel

$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/compression_with_xor.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/updatable_apex.mk)

# Stock vendor is Android 14 / API 34 / VNDK 34. The product first API is 36,
# but the VINTF level must stay at the vendor's FCM level for this vendor.
PRODUCT_SHIPPING_API_LEVEL := 34
PRODUCT_TARGET_VNDK_VERSION := 34

PRODUCT_USE_DYNAMIC_PARTITIONS := true
PRODUCT_BUILD_SUPER_PARTITION := false
PRODUCT_BUILD_VENDOR_BOOT_IMAGE := false
PRODUCT_CHARACTERISTICS := nosdcard

# Optional full vendor image. Disabled by default: the stock vendor partition
# already contains the matching 36-31 HALs and props. See rom/vendor/README.md.
# The rom-ready vendor makefile installs its own VINTF/fstab files, so do not
# duplicate those PRODUCT_COPY_FILES here.
ifeq ($(MARVEL_BUILD_VENDOR_IMAGE),true)
$(call inherit-product, vendor/motorola/marvel/marvel-vendor.mk)
endif

# Virtual A/B OTA
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
    vendor \
    vendor_boot \
    vendor_dlkm

# TWRP's update_engine cannot complete postinstall on this VABC layout:
# it unmaps the target snapshots before otapreopt/checkpoint_gc and then fails
# to mount /dev/block/mapper/system_b. The payload is still complete; skip the
# optional postinstall hooks so the update can finish and switch slots.
# AB_OTA_POSTINSTALL_CONFIG is intentionally omitted.

# Device-side packages that are not recovery-specific.
PRODUCT_PACKAGES += \
    fastbootd \
    update_engine \
    update_engine_sideload \
    update_verifier \
    checkpoint_gc \
    otapreopt_script \
    snapuserd_ramdisk

PRODUCT_PACKAGES_DEBUG += \
    update_engine_client

# RRO overlays, verified and rescaled for the 1272x2772 panel in this tree.
PRODUCT_PACKAGES += \
    MarvelFrameworksOverlay \
    MarvelSystemUIOverlay

# ROM system props only. Vendor props live in rom/props/vendor.prop and are
# only used when building a vendor image. TARGET_SYSTEM_PROP is wired in
# rom/board.mk and currently contains no unverified properties.
