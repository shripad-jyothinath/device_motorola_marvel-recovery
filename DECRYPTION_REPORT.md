# TWRP userdata decryption failure — Motorola Marvel, A171WEH.36-31 (Android 17)

## Summary

Custom TWRP 3.7.1_16-0 boots on a Motorola "Marvel" (A171WEH, Android 17, patch 2026-09-01), but cannot decrypt userdata. Baseline/full-VINTF logs show `keymaster_ver` empty and `Unable to decrypt metadata encryption`; the QTI gatekeeper/qseecom services abort because their VINTF entries are missing. The latest minimal-manifest image (fixed4) reaches the **Decrypt Data password prompt** (`keymaster_ver=4.x`, set from the `keymaster_ver` prop because the manifest lookup fails), but decryption still fails for both a pattern and a temporary PIN: `Unable to decrypt metadata encryption`, and gatekeeper/qseecom remain in `restarting`. Runtime `/vendor/etc/vintf` contains only `manifest/` and `manifest.xml`, while `ro.board.platform=volcano`; `manifest_volcano.xml` is missing and the servicemanager does not use `manifest.xml`.

The device is **KeyMint-only** (`android.hardware.security.keymint-service-qti` AIDL v3, no `android.hardware.keymaster` service). TWRP's version lookup only searches for `android.hardware.keymaster`.

## Device / firmware

- Motorola Marvel, "dn" SKU; bootloader unlocked; Magisk root.
- Build **A171WEH.36-31**, Android **17**, security patch **2026-09-01**.
- userdata: **f2fs**, FBE `aes-256-xts` (`aes-256-cts:v2+inlinecrypt_optimized+wrappedkey_v0`).
- `/metadata`: `aes-256-xts`, filenames `wrappedkey_v0`.
- Crypto stack: QTI `qseecomd`, `qseecom-service`, `ssgtzd`, `keymint-qti`, `gatekeeper_default`; no StrongBox/weaver on this SKU (`ro.vendor.hw.strongbox=false`).
- TZ manifest: `android.hardware.security.keymint-service-qti` → `IKeyMintDevice/default`, `ISecureClock/default`, `ISharedSecret/default`.

## TWRP image

- TWRP 3.7.1_16-0; boot header v4, `kernel_size=0` (kernel from `boot`), legacy LZ4 ramdisk.
- Header `os_version=0x220001A9` = Android 17.0.0 / 2026-09-01; `prop.default` security patch 2026-09-01.
- Tree: `device_motorola_marvel-recovery`.
- Crypto blobs under `recovery/root/vendor` are taken from **A171WEH.36-18** (see `BLOBS.md`); the phone is **A171WEH.36-31**. This is a known mismatch.
- TWRP base is `twrp-16.0` (Android 16) per CI; the tree's own README (line 410) notes that Android 17 data on a TWRP-16 base is untested and a mismatch may make decryption fail.

## Symptom

- Baseline: no decrypt prompt. Fixed4 (minimal manifest + `keymaster_ver=4.x`) now shows the **Decrypt Data password prompt**, but the credential is a pattern and TWRP does not select its pattern page; there is no Pattern button in this theme.
- `/data` cannot be mounted (`Unable to mount '/data'`; `Can't probe device /dev/block/sde34`; f2fs).
- Log: `I:Unable to decrypt metadata encryption`.
- VINTF: `qseecom-service` and `vendor.gatekeeper_default` receive signal 6 and are restarting; `vendor.qseecomd` is running.

## Log evidence

### `twrp_recovery.log` (full VINTF test — manifest_volcano present)

- Lines 141–149:
  ```
  I:Property ro.boot.product.vendor.sku not found, trying to get vintf manifest file name from ro.board.platform
  I:Separate manifest doesn't exist for 'android.hardware.keymaster'
  I:PageManager::LoadFileToBuffer loading filename: '/vendor/etc/vintf/manifest_volcano.xml' directly
  I:Looking for 'android.hardware.keymaster' service in manifest
  I:Keymaster_Ver::Unable to find vendor manifest on the device, and no default value set. Checking the ramdisk manifest
  I:Property ro.boot.product.vendor.sku not found, trying to get vintf manifest file name from ro.board.platform
  I:Separate manifest doesn't exist for 'android.hardware.keymaster'
  I:/vendor/etc/vintf/manifest_volcano.xml not found. Using default path for manifest.xml
  I:Keymaster_Ver::Using keymaster version '' for decryption
  ```
- Line 236:
  ```
  I:Unable to decrypt metadata encryption
  ```
- Lines 223, 232, 242, 246, 248:
  ```
  I:Unable to mount '/data'
  ...
  Unable to mount storage
  ```
- Props:
  - line 676: `keymaster_ver=`
  - line 713: `init.svc.qseecom-service=restarting`
  - line 817: `init.svc.vendor.qseecomd=running`
  - line 821: `init.svc.vendor.gatekeeper_default=restarting`
  - line 666: `fbe.metadata.wrappedkey=true`
  - lines 674–675: `metadata.contents=aes-256-xts`, `metadata.filenames=wrappedkey_v0`

### `twrp_known_good.log` (baseline, no manifest.xml)

```
I:Separate manifest doesn't exist for 'android.hardware.keymaster'
I:Looking for 'android.hardware.keymaster' service in manifest
I:Keymaster_Ver::Unable to find vendor manifest on the device, and no default value set. Checking the ramdisk manifest
I:Separate manifest doesn't exist for 'android.hardware.keymaster'
I:Keymaster_Ver::Using keymaster version '' for decryption
I:Unable to mount '/data'
I:Can't probe device /dev/block/sde34
I:Actual block device: '/dev/block/sde34', current file system: 'f2fs'
```

### dmesg / servicemanager (known-good build)

```
servicemanager: Caller(pid=1339,uid=0,sid=u:r:recovery:s0) Could not find android.hardware.boot.IBootControl/default in the VINTF manifest.
servicemanager: Caller(pid=1356,uid=0,sid=u:r:recovery:s0) Could not find android.hardware.weaver.IWeaver/default in the VINTF manifest.
servicemanager: Caller(pid=1362,uid=0,sid=u:r:recovery:s0) Could not find vendor.qti.hardware.qseecom.IQSEECom/default in the VINTF manifest.
init: Service 'qseecom-service' (pid 1362) received signal 6
servicemanager: Caller(pid=1365,uid=0,sid=u:r:recovery:s0) Could not find android.hardware.gatekeeper.IGatekeeper/default in the VINTF manifest.
init: Service 'vendor.gatekeeper_default' (pid 1365) received signal 6
```

## VINTF layout on this vendor

- Stock 36-31 vendor ships:
  - `/vendor/etc/vintf/manifest_volcano.xml` (platform manifest)
  - `/vendor/etc/vintf/manifest/` fragments (qseecom, keymint, boot, secure_element, etc.)
  - `/odm/etc/vintf/manifest_dn.xml` (SKU manifest, symlinked/copied from `vendor/odm`)
  - **No `/vendor/etc/vintf/manifest.xml`**.
- `TWFunc::GetServiceFromManifest()` selects:
  1. a fragment filename containing the service name;
  2. `manifest_<ro.boot.product.vendor.sku or ro.board.platform>.xml`;
  3. `/vendor/etc/vintf/manifest.xml`.
- On this device `ro.boot.product.vendor.sku` is not set, so `manifest_volcano.xml` is selected. That file has `android.hardware.gatekeeper` and `android.hardware.secure_element`, but **not** `vendor.qti.hardware.qseecom`, `android.hardware.security.keymint`, `android.hardware.boot`, or `android.hardware.keymaster`.
- A merged `/vendor/etc/vintf/manifest.xml` was tried, but when `manifest_volcano.xml` exists it is chosen first, so the merged file was not used for the keymaster lookup (and the services still missed their entries).

## What was tested

1. **Baseline** (no `manifest.xml`): gatekeeper/qseecom crash; `keymaster_ver` empty; `/data` unmounted.
2. **Full stock VINTF set** (`manifest_volcano.xml` + `compatibility_matrix.xml` + ODM `manifest_dn.xml` + stock fragments): TWRP boots, but USB/adb dies; still no decrypt prompt. `twrp_recovery.log` is from this build. The lookup selected `manifest_volcano.xml` and still returned `keymaster_ver=''`; the merged `manifest.xml` was bypassed.
3. **Minimal `manifest.xml` only** (gatekeeper, qseecom, keymint, sharedsecret, secureclock, boot + `android.hardware.keymaster` 4.0) and `keymaster_ver=4.x` in `prop.default`: TWRP boots and the Decrypt Data page prompts for a password. The pattern page is not selected (`tw_crypto_pwtype=0`); changing the lock to a PIN did not help. The fixed4 log/dmesg were captured over adb. Log: `Keymaster_Ver::Using keymaster version '4.x'`, `Unable to decrypt metadata encryption`; `qseecom-service` and `vendor.gatekeeper_default` still restart. See the fixed4 section below.

### Fixed4 log (captured; PIN attempt)

Runtime `/vendor/etc/vintf` contains only `manifest/` and `manifest.xml` (1287 bytes). There is **no `manifest_volcano.xml`**, although `ro.board.platform=volcano` and `ro.boot.product.vendor.sku` is empty.

`twrp_fixed4.log`:

```
142: I:Separate manifest doesn't exist for 'android.hardware.keymaster'
143: I:PageManager::LoadFileToBuffer loading filename: '/vendor/etc/vintf/manifest_volcano.xml' directly
144: I:Looking for 'android.hardware.keymaster' service in manifest
145: I:Keymaster_Ver::Unable to find vendor manifest on the device. Setting to default value.
146: I:Keymaster_Ver::Using keymaster version '4.x' for decryption
233: I:Unable to decrypt metadata encryption
710: init.svc.qseecom-service=restarting
822: init.svc.vendor.keymint-qti=running
824: init.svc.vendor.gatekeeper_default=restarting
673: keymaster_ver=4.x
680: ro.board.platform=volcano
835: ro.crypto.state=encrypted
```

`dmesg_fixed4.txt`:

```
servicemanager: Caller(pid=10853,...) Could not find vendor.qti.hardware.qseecom.IQSEECom/default in the VINTF manifest.
init: Service 'qseecom-service' (pid 10853) received signal 6
servicemanager: Caller(pid=10856,...) Could not find android.hardware.gatekeeper.IGatekeeper/default in the VINTF manifest.
init: Service 'vendor.gatekeeper_default' (pid 10856) received signal 6
servicemanager: Caller(pid=10868,...) Could not find android.hardware.boot.IBootControl/default in the VINTF manifest.
init: Service 'vendor.boot-qti' (pid 10868) received signal 6
servicemanager: Caller(pid=10870,...) Could not find android.hardware.weaver.IWeaver/default in the VINTF manifest.
init: Service 'keystore2' (pid 10867) received signal 6
init: Service 'vendor.weaver_nxp' (pid 10870) received signal 6
```

The intended keymaster 4.0 entry in `manifest.xml` was not found by `ProcessKeymasterVersion`; the `4.x` value came from the `keymaster_ver` property. The servicemanager also ignored `manifest.xml`. The common factor is the missing **platform manifest** `manifest_volcano.xml`: the lookup and the VINTF consumer both try it first and do not fall back to `manifest.xml`.

**Fixed5** is built with the same crypto entries present as both `/vendor/etc/vintf/manifest_volcano.xml` and `/vendor/etc/vintf/manifest.xml` (attached as `manifest_volcano_fixed5.xml`). It has not yet been tested.

## Source analysis

`PartitionManager::ProcessKeymasterVersion` (TWRP 3.7.1):

```cpp
static std::string KmVerFromManifest(std::string ver) {
    TWFunc::GetServiceFromManifest("/vendor", "android.hardware.keymaster", ver);
    if (ver.find('4') != std::string::npos) ver = "4.x";
    return ver;
}

static void ProcessKeymasterVersion(const TWPartition* ven, const bool display_error) {
    std::string version;
    version = KmVerFromManifest(version);
    if (version.empty()) {
        if (ven) ven->Unmount(display_error);
        version = android::base::GetProperty("keymaster_ver", version);
        if (version.empty()) {
            LOGINFO("Keymaster_Ver::Unable to find vendor manifest ... Checking the ramdisk manifest\n");
            version = KmVerFromManifest(version);
        } else {
            LOGINFO("Keymaster_Ver::Unable to find vendor manifest ... Setting to default value.\n");
        }
    } else {
        if (ven) ven->Unmount(display_error);
    }
    LOGINFO("Keymaster_Ver::Using keymaster version '%s' for decryption\n", version.c_str());
    android::base::SetProperty("keymaster_ver", version);
}
```

The vendor has no `android.hardware.keymaster` HAL. A fake keymaster 4.0 entry in `manifest.xml` produces `keymaster_ver=4.x`, but the real service is KeyMint AIDL v3. Whether the QCOM FBE path can use that through KeyMint is the open question.

## Questions for the reviewer

1. Does TWRP 3.7.1's `BOARD_USES_QCOM_FBE_DECRYPTION` understand KeyMint AIDL v3, or does it require a Keymaster 4.x HIDL service? What is the correct `keymaster_ver` value for a KeyMint-only vendor?
2. Is the fake `android.hardware.keymaster` 4.0 entry + `keymaster_ver=4.x` the right workaround, or should TWRP's `GetServiceFromManifest`/`ProcessKeymasterVersion` be patched to look for `android.hardware.security.keymint`?
3. Android 17 userdata and metadata on a TWRP-16 (SDK 36) base: does this require a TWRP 17/keystore2/vold update independent of the vendor blobs?
4. Are 36-18 keymint/gatekeeper/qseecom blobs compatible with the phone's 36-31 TZ/metadata? We plan to extract the 36-31 blobs from the 36-31 stock recovery ramdisk.
5. VINTF: fixed4 had the crypto entries in `/vendor/etc/vintf/manifest.xml`, but the servicemanager still reported them missing and `ProcessKeymasterVersion` failed (it used the `keymaster_ver` prop). Runtime has `ro.board.platform=volcano` and no `manifest_volcano.xml`. Is the correct recovery layout to ship the crypto entries as **`manifest_volcano.xml`** (the platform manifest) rather than/in addition to `manifest.xml`? Fixed5 does that.
6. Pattern UI: TWRP's decrypt page redirects to `decrypt_pattern` only when `tw_crypto_pwtype=2`; the theme has no Pattern button, and `tw_crypto_pwtype_0` is 0 on a recovery-only boot (settings are under encrypted `/data`). Is there a supported way to force `tw_crypto_pwtype=2` in the recovery ramdisk (pre-seeded settings, `twrp.flags`, or a theme patch), or should the theme/device tree be patched?

## Reviewer request: full logcat/dmesg

The reviewer wants the **full logcat or dmesg**, not excerpts. Attach the complete files:

- TWRP: `/tmp/recovery.log`, full `dmesg`, and `logcat -d` if the TWRP build provides logcat. Save them to `/metadata` or `/mnt/vendor/persist` before rebooting (the TWRP `/tmp` is tmpfs and is lost on reboot).
- Android after Magisk root:
  ```
  adb logcat -d -v threadtime > logcat_full.txt
  adb shell su -c dmesg > android_dmesg.txt
  adb shell su -c "cat /sys/fs/pstore/console-ramoops-0" > pstore_console.txt
  ```
- Keep the full files; do not truncate. The fixed4 dmesg is already attached; fixed5 and Android logcat/dmesg/pstore will be added when available.

## Android full logs (captured)

After Magisk root (`su -c id` = uid=0, `magisk -v` = 31.1:MAGISK:R), the full Android logs were captured:

- `logcat_full.txt` — 4.3 MB, `adb logcat -d -v threadtime`.
- `android_dmesg.txt` — 532 KB, root dmesg.
- `pstore_console.txt` — 832 B, `/sys/fs/pstore/console-ramoops-0`.

The fixed5 TWRP log was not saved before rebooting to Android and is lost. The fixed4 TWRP log remains attached; the fixed5 log can be reproduced by booting recovery again and saving `/tmp/recovery.log` to `/metadata`/persist before leaving.

## Attached files

- `twrp_recovery.log` — full TWRP log from the full-VINTF build (73 KB).
- `twrp_known_good.log` — full TWRP log from the baseline build (no manifest).
- `twrp_fixed4.log` — full TWRP log from the minimal-manifest build (93 KB, including the failed PIN attempt).
- `dmesg_fixed4.txt` — dmesg from the minimal-manifest build (VINTF/SIGABRT).
- `manifest_volcano_fixed5.xml` — crypto manifest used as the proposed `manifest_volcano.xml` in fixed5.
- `logcat_full.txt` — full Android logcat after root (4.3 MB).
- `android_dmesg.txt` — full Android dmesg after root (532 KB).
- `pstore_console.txt` — Android pstore/console-ramoops (832 B).
- `dmesg_vintf_known_good.txt` — servicemanager/VINTF/SIGABRT lines.
- `manifest_fixed4.xml` — minimal manifest used in the latest test (with keymaster 4.0 entry).
- `manifest_full_merged.xml` — merged manifest used in the full-VINTF test.
- `manifest_volcano_36-31.xml` — stock 36-31 platform manifest.
- `source_keymaster_lookup.txt` — TWRP source excerpt for the lookup.
- `props_known_good.txt` — selected props from the logs.

## How to capture the fixed4 log (not captured yet)

On the fixed4 TWRP (no adb/ USB):

```
# Advanced -> Terminal
cp /tmp/recovery.log /mnt/vendor/persist/recovery_fixed4.log
dmesg > /mnt/vendor/persist/dmesg_fixed4.txt
sync
```

Then boot Android (Magisk root) and pull:

```
adb shell su -c "cp /mnt/vendor/persist/recovery_fixed4.log /sdcard/Download/"
adb shell su -c "cp /mnt/vendor/persist/dmesg_fixed4.txt /sdcard/Download/"
adb pull /sdcard/Download/recovery_fixed4.log
adb pull /sdcard/Download/dmesg_fixed4.txt
```

If `/mnt/vendor/persist` is not mounted, use `/metadata` instead.
