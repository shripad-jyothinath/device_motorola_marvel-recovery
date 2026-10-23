# Bundled vendor blobs

Everything under `recovery/root/vendor/` comes from the stock **A171WEH.36-18** firmware
(Android 17, `marvel_g-user 17 A171WEH.36-18 ccd1da-3f1b2`, vendor `UWE34HV-A171-ST4`,
security patch 2026-08-01). That is the package Motorola's Rescue and Smart Assistant
serves for XT2605 retail (cid 50), and the build the phone runs after the OTA.

The previous set (46 files from `W2WE36.56-32-ST3.2`) was replaced wholesale: it was
from an older TrustZone build and was missing most of the libraries the services
actually link against.

## How the set was chosen

The list is the **dependency closure** (`DT_NEEDED`, followed recursively inside
`/vendor`) of the services stock runs for decryption, plus the libraries those
services `dlopen()` by name:

| service | binary | needed on |
|---|---|---|
| `vendor.qseecomd` | `bin/qseecomd` (+ dlopen: librpmb, libssd, libdrmfs, libdrmtime, libgpt, libops, libqisl, libspl, libGPreqcancel, libtaautoload) | every unit |
| `qseecom-service` | `bin/hw/vendor.qti.hardware.qseecom@1.0-service` | every unit |
| `vendor.ssgtzd` | `bin/ssgtzd` | every unit |
| `vendor.keymint-qti` | `bin/hw/android.hardware.security.keymint-service-qti` | every unit |
| `vendor.gatekeeper_default` | `bin/hw/android.hardware.gatekeeper-service-qti` (+ dlopen `hw/libqtigatekeeper.so`) | every unit |
| `vendor.keymint-strongbox` | `bin/hw/android.hardware.security.keymint-service.strongbox-nxp` | StrongBox SKUs only |
| `vendor.weaver_nxp` | `bin/hw/android.hardware.weaver-service.nxp-qti` | StrongBox SKUs only |
| `vendor.secure_element` | `bin/hw/android.hardware.secure_element-service.qti` | StrongBox SKUs only |
| `vendor.boot-qti` | `bin/hw/android.hardware.boot-service.qti.recovery` (+ dlopen `libboot_control_qti.so`) | every unit (A/B slot control) |

The boot-control HAL and its five libraries come from the **stock recovery ramdisk**
of the same package (`system/bin/hw/…`, `system/lib64/…`), relocated under `/vendor`
so they cannot collide with anything TWRP builds into `/system`.

On a running XT2605-4 ("dn" SKU), `ps -A` shows exactly qseecomd, ssgtzd,
qseecom@1.0-service, keymint-service-qti, gatekeeper-service-qti and boot-service.qti;
`ro.vendor.hw.strongbox=false` and no weaver is registered.

## What /system must provide

After bundling, every remaining `DT_NEEDED` entry is a system library:

- already in TWRP's ramdisk: libc, libm, libdl, libc++, libbase, libutils, libcutils,
  liblog, libbinder, libbinder_ndk, libhidlbase, libcrypto, libz
- relinked by TWRP itself with `TW_INCLUDE_CRYPTO`: libhardware, libgatekeeper,
  libhardware_legacy, libxml2
- added by this tree (`MARVEL_RECOVERY_SYSTEM_LIBS` in `device.mk`):
  android.hardware.common-V2-ndk, libdmabufheap, libion, libjsoncpp, libnetutils, libssl

## VINTF

| fragment | source |
|---|---|
| `android.hardware.security.keymint-service-qti.xml` | stock `vendor/etc/vintf/manifest/` |
| `vendor.qti.hardware.qseecom@1.0-service.xml` | stock `vendor/etc/vintf/manifest/` |
| `android.hardware.secure_element.xml` (SIM1/SIM2) | stock `vendor/etc/vintf/manifest/` |
| `android.hardware.gatekeeper-service-qti.xml` | written here from the `IGatekeeper/default` entry in stock `manifest_volcano.xml` |
| `android.hardware.security.strongbox-nxp.xml` | written here from stock `vendor/odm/etc/vintf/manifest_dnes.xml` |
| `android.hardware.boot-service.qti.xml` | stock recovery ramdisk `system/etc/vintf/manifest/boot-service.qti.xml` |

## Other files

- `vendor/etc/ueventd.rc`, `vendor/odm/etc/ueventd.rc`: stock, for the QTI device
  nodes and `firmware_directories`.
- `vendor/firmware/*goodix*`: the touch controller's firmware/config for all three
  panel vendors (boe/csot/tm), so the Goodix driver finds them while `/vendor` is not
  mounted.
- `vendor/firmware_mnt/image/*` is **not** bundled: it is the `modem` partition (ext4),
  which `init.recovery.qcom.rc` mounts itself.
- Kernel modules are **not** bundled: TWRP loads them from `vendor_dlkm` at runtime
  (`TW_LOAD_VENDOR_MODULES` in `device.mk`).
