# Blobs to copy from the stock dump

Extracted and verified against the stock vendor partition
(`DumprX` release `marvel-W2WE36.56-32-ST3.2-390dea`, asset `marvel-vendor.tar.zst`).

## Where they go

In this tree everything lives under `recovery/root/`, mirroring the device layout:

| dump path | tree path |
|---|---|
| `vendor/bin/...` | `recovery/root/vendor/bin/...` |
| `vendor/lib64/...` | `recovery/root/vendor/lib64/...` |
| `vendor/etc/init/*.rc` | `recovery/root/vendor/etc/init/*.rc` |
| `vendor/etc/vintf/manifest/*.xml` | `recovery/root/vendor/etc/vintf/manifest/*.xml` |
| `vendor/etc/ueventd.rc` | `recovery/root/vendor/etc/ueventd.rc` |
| `vendor/odm/etc/ueventd.rc` | `recovery/root/vendor/odm/etc/ueventd.rc` |

## Crypto stack (verified present in the dump)

### `vendor/bin/hw/`
```
android.hardware.security.keymint-service-qti              45616   TZ keymint (always present)
android.hardware.security.keymint-service.strongbox-nxp    37728   NXP KM300 keymint (SKU-gated)
android.hardware.weaver-service.nxp-qti                    29304   NXP weaver      (SKU-gated)
android.hardware.gatekeeper-service-qti                    15056
android.hardware.secure_element-service.qti                66928
vendor.qti.hardware.qseecom@1.0-service                    36808
android.hardware.keymaster@4.0-service-qti                 32288   legacy
```

### `vendor/bin/`
```
qseecomd                                                   45776
ssgtzd                                                    172192
```

### `vendor/lib64/`
```
libjc_keymint-nxp.so                    386216   NXP keymint backend
libjc_keymint_transport_nxp.so          109440
ese_weaver.so                            57664
libkeymint.so                           147752
libkeymint_crypto.so                    102400
lib_android_keymaster_keymint_utils.so   24968
libqtikeymint.so                        304464
libQSEEComAPI.so                         70568
vendor.qti.hardware.qseecom@1.0.so      166344
vendor.qti.hardware.qseecom-V1-ndk.so    93504
hw/vendor.qti.hardware.qseecom@1.0-impl.so  70800
hw/libqtigatekeeper.so                   70720
android.hardware.security.keymint-V1-ndk.so  128472
android.hardware.security.keymint-V2-ndk.so  136920
android.hardware.security.keymint-V3-ndk.so  136920
android.hardware.weaver-V2-ndk.so        50592
android.hardware.gatekeeper-V1-ndk.so    50720
android.hardware.gatekeeper@1.0.so      123424
android.hardware.secure_element-V1-ndk.so  72256
android.hardware.secure_element@1.0.so  195904
android.hardware.authsecret@1.0.so      109128
android.hardware.keymaster@3.0.so       186440
android.hardware.keymaster@4.0.so       214000
android.hardware.keymaster@4.1.so       151192
android.hardware.keymaster-V3-ndk.so     19712
android.hardware.keymaster-V4-ndk.so     19712
```

### `vendor/etc/vintf/manifest/`
```
android.hardware.security.keymint-service-qti.xml
android.hardware.secure_element.xml
vendor.qti.hardware.qseecom@1.0-service.xml
```

## Other

- `vendor/etc/ueventd.rc` (35645 B) and `vendor/odm/etc/ueventd.rc` (5334 B) — required for the QTI
  device nodes and `firmware_directories`.
- `vendor/firmware_mnt/image/*` — **not in the vendor tar** (it is the modem partition mounted at
  `/vendor/firmware_mnt`). The recovery init mounts `modem` itself; the `adsp.mdt`/`adsp.b*` files
  it waits for come from there.
- `system_dlkm/lib/modules/*` and `vendor_dlkm/lib/modules/*` — the kernel modules. Recovery loads
  them at runtime via `TW_LOAD_VENDOR_MODULES` (see `device.mk`), so nothing needs bundling.

## Found by extraction (summary)

`dump_assets/vendor_extract/` after running the extractor:

```
bin/hw/  (7 binaries)
bin/     (qseecomd, ssgtzd)
lib64/   (26 libraries + 2 under hw/)
etc/init/ (8 .rc files — all service definitions used by init.recovery.encryption.rc)
etc/vintf/manifest/ (3 xml)
etc/ueventd.rc, odm/etc/ueventd.rc
```

**46 files, 3.56 MB.**
