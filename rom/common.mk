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

# Stock vendor is Android 14 / API 34 / VNDK 34. The product first API is 36;
# keep the vendor compatibility level at 34. API 36 also enables AOSP's 16 KB
# prebuilt check, so audit the prebuilts before a build rather than hiding the
# mismatch behind an API 34 override.
PRODUCT_SHIPPING_API_LEVEL := 36
PRODUCT_TARGET_VNDK_VERSION := 34
SHIPPING_API_LEVEL := 36

# The ROM product intentionally does not inherit device.mk (that is the TWRP
# product). Keep the ROM-relevant pieces it carries.
TARGET_OTA_ASSERT_DEVICE := marvel,marvel_g,marvel_gh,XT2605,XT2605-1,XT2605-2,XT2605-3,XT2605-4
PRODUCT_APEX_BOOT_JARS += \
    com.android.crashrecovery:framework-crashrecovery
PRODUCT_APEX_SYSTEM_SERVER_JARS += \
    com.android.crashrecovery:service-crashrecovery

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
#
# recovery is intentionally excluded. The ROM product still builds a recovery
# image (BoardConfig sets BOARD_RECOVERYIMAGE_PARTITION_SIZE), but shipping it
# in AB_OTA_PARTITIONS overwrites the TWRP recovery partition with AOSP recovery.
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    boot \
    dtbo \
    init_boot \
    product \
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
    snapuserd_ramdisk \
    modprobe \
    toolbox_ramdisk \
    ramdisk_build_prop

PRODUCT_PACKAGES_DEBUG += \
    update_engine_client

# snapuserd_ramdisk installs into the generic (init_boot) ramdisk. The stock
# prebuilt vendor_boot cannot carry it, so verify the built init_boot contains
# system/bin/snapuserd, system/bin/snapuserd_ramdisk and
# system/etc/init/snapuserd.rc (rom/tools/verify_init_boot.sh). Without it a
# VABC mount waits on dm-user forever: splash, no kernel panic. The stock
# first-stage ramdisk also carries modprobe, toolbox_ramdisk and
# system/etc/ramdisk/build.prop; keep those so the ROM init_boot matches the
# stock first-stage environment.

# RRO overlays, verified and rescaled for the 1272x2772 panel in this tree.
PRODUCT_PACKAGES += \
    MarvelFrameworksOverlay \
    MarvelSystemUIOverlay

# ROM system props only. Vendor props live in rom/props/vendor.prop and are
# only used when building a vendor image. TARGET_SYSTEM_PROP is wired in
# rom/board.mk and currently contains no unverified properties.
