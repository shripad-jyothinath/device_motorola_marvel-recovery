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
# Stock vendor was originally Android 14 / API 34. In Android 15/16 (BP2A), VNDK
# has been completely removed from AOSP. Setting PRODUCT_TARGET_VNDK_VERSION := 34
# forces ro.vndk.version=34 in build.prop, triggering a fatal linkerconfig SIGABRT
# crash on boot ("Unable to access VNDK APEX at path: /apex/com.android.vndk.v34").
# Align with device.mk by targeting API 36 / VNDK 36 so linkerconfig configures
# the modern isolated vendor namespace without VNDK APEX dependencies.
PRODUCT_TARGET_VNDK_VERSION := 36
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
    vbmeta_system \
    vendor \
    vendor_boot \
    vendor_dlkm

# TWRP's update_engine cannot complete postinstall on this VABC layout:
# it unmaps the target snapshots before otapreopt/checkpoint_gc and then fails
# to mount /dev/block/mapper/system_b. The payload is still complete; skip the
# optional postinstall hooks so the update can finish and switch slots.
# AB_OTA_POSTINSTALL_CONFIG is intentionally omitted.

# Device-side packages that are not recovery-specific.
PRODUCT_PACKAGES += android.hidl.allocator@1.0-service
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

# ---------------------------------------------------------------------------
# VINTF Manifests
#
# Standard AOSP libvintf expects /vendor/etc/vintf/manifest.xml and
# /odm/etc/vintf/manifest.xml. Stock Motorola firmware names them
# manifest_volcano.xml and manifest_bnes.xml.
# - /vendor/etc/vintf/manifest.xml: Qualcomm vendor HALs (IKeyMintDevice/default)
# - /odm/etc/vintf/manifest.xml: NXP StrongBox on eSE (IKeyMintDevice/strongbox,
#   IWeaver/default)
# Installing both satisfies libvintf and prevents "NULL VINTF MANIFEST" errors
# during KeyMint registration in servicemanager.
# ---------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/rom/vintf/manifest.xml:$(TARGET_COPY_OUT_VENDOR)/etc/vintf/manifest.xml \
    $(DEVICE_PATH)/rom/vintf/manifest_volcano.xml:$(TARGET_COPY_OUT_VENDOR)/etc/vintf/manifest_volcano.xml \
    $(DEVICE_PATH)/rom/vintf/manifest/android.hardware.security.keymint-service-qti.xml:$(TARGET_COPY_OUT_VENDOR)/etc/vintf/manifest/android.hardware.security.keymint-service-qti.xml \
    $(DEVICE_PATH)/rom/vintf/manifest_bnes.xml:$(TARGET_COPY_OUT_VENDOR)/odm/etc/vintf/manifest.xml \
    $(DEVICE_PATH)/rom/vintf/manifest_bnes.xml:$(TARGET_COPY_OUT_VENDOR)/odm/etc/vintf/manifest_bnes.xml

# ---------------------------------------------------------------------------
# Vendor Init Scripts & Overrides
#
# - init.target.rc: early-init USB ConfigFS setup (VID 0x22b8, PID 0x2e81),
#   early UDC binding on a600000.dwc3, vendor.all.modules.ready=1 trigger,
#   and late-fs mount fixes.
# - init.mmi.chipset.rc: module readiness and USB peripheral mode initialization.
# - init.qti.kernel.rc: early kernel dlkm loading triggers.
# - boringssl_self_test.rc: neutralized self-test (strips reboot_on_failure, 64-bit only).
# ---------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/rom/configs/init/init.target.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.target.rc \
    $(DEVICE_PATH)/rom/configs/init/init.mmi.chipset.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.mmi.chipset.rc \
    $(DEVICE_PATH)/rom/configs/init/init.qti.kernel.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.qti.kernel.rc \
    $(DEVICE_PATH)/rom/configs/init/boringssl_self_test.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/boringssl_self_test.rc \
    $(DEVICE_PATH)/rom/bin/vendor_modprobe.sh:$(TARGET_COPY_OUT_VENDOR)/bin/vendor_modprobe.sh \
    $(DEVICE_PATH)/rom/bin/system_dlkm_modprobe.sh:$(TARGET_COPY_OUT_VENDOR)/bin/system_dlkm_modprobe.sh \
    $(DEVICE_PATH)/rom/configs/modules/modules.alias:$(TARGET_COPY_OUT_VENDOR)/lib/modules/modules.alias

# ---------------------------------------------------------------------------
# BoringSSL self-test bypass / 0-dependency stub
#
# Static 0-dependency binary that executes sys_exit(0). Neutralizes the
# "reboot,boringssl-self-check-failed" loop occurring before APEX activation.
# ---------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/prebuilt/stubs/boringssl_self_test64_static:$(TARGET_COPY_OUT_VENDOR)/bin/boringssl_self_test64

PRODUCT_PACKAGES += \
    boringssl_self_test64_vendor

# ---------------------------------------------------------------------------
# Vendor namespace library staging (Android 15+ VNDK deprecation)
#
# In Android 15/16 (BP2A), VNDK has been completely deprecated and removed.
# Linker namespaces isolate /vendor from /system/lib64, causing stock Motorola
# and Qualcomm vendor HALs and daemons to crash when searching for shared
# libraries they were compiled against.
#
# Package vendor-available variants into $(TARGET_COPY_OUT_VENDOR)/lib64:
# - KeyMint, Gatekeeper, vndservicemanager, ssgtzd, qseecom:
#     libbase.vendor, libcutils.vendor, libutils.vendor, libcrypto.vendor,
#     libselinux.vendor, libpcre2.vendor, libion.vendor, libgatekeeper.vendor,
#     libhardware.vendor, libhardware_legacy.vendor, libhidlbase.vendor,
#     android.hardware.common-V2-ndk
# - Audio, Display, ADSP/CDSP FastRPC daemons (adsprpcd, cdsprpcd):
#     libdmabufheap, libfmq, libui.vendor, libgralloctypes,
#     android.hardware.graphics.allocator@4.0.vendor,
#     android.hardware.graphics.bufferqueue@2.0,
#     android.hardware.graphics.mapper@4.0.vendor
# - Networking, Sensors, RIL, Power & Utilities:
#     libjsoncpp.vendor, libnetutils, libssl.vendor, libz.vendor,
#     libminijail.vendor, libnl, libprocessgroup.vendor,
#     libstagefright_foundation.vendor, android.hidl.memory@1.0.vendor,
#     android.hidl.memory.token@1.0.vendor, android.system.suspend-V1-ndk,
#     android.hardware.memtrack-V1-ndk
# ---------------------------------------------------------------------------
PRODUCT_PACKAGES += \
    android.hardware.common-V2-ndk \
    android.hardware.graphics.allocator@4.0.vendor \
    android.hardware.graphics.bufferqueue@2.0 \
    android.hardware.graphics.common@1.0.vendor \
    android.hardware.graphics.common@1.1.vendor \
    android.hardware.graphics.common@1.2.vendor \
    android.hardware.graphics.mapper@4.0.vendor \
    android.hardware.memtrack-V1-ndk \
    android.hidl.memory@1.0.vendor \
    android.hidl.memory.token@1.0.vendor \
    android.system.suspend-V1-ndk \
    libbase.vendor \
    libbinder.vendor \
    libcutils.vendor \
    libdmabufheap \
    libexpat.vendor \
    libfmq \
    libgatekeeper.vendor \
    libgralloctypes \
    libhardware.vendor \
    libhardware_legacy.vendor \
    libhidlbase.vendor \
    libhidlmemory.vendor \
    libion.vendor \
    libjsoncpp.vendor \
    libminijail.vendor \
    libnetutils \
    libnl \
    libpcre2.vendor \
    libprocessgroup.vendor \
    libselinux.vendor \
    libssl.vendor \
    libstagefright_foundation.vendor \
    libui.vendor \
    libutils.vendor \
    libxml2.vendor \
    libz.vendor
