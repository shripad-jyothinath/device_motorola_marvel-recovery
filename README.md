# device_motorola_marvel-recovery

Recovery device tree for the **Motorola Edge 70 Fusion** (`marvel`, XT2605).

Rebranded from [`chkndrp/device_xiaomi_amethyst-recovery`](https://github.com/chkndrp/device_xiaomi_amethyst-recovery),
which is the same SoC and the same partition scheme.

| | marvel | amethyst (reference) |
|---|---|---|
| SoC | Qualcomm **SM7635 "volcano"** | Qualcomm SM7635 "volcano" |
| Board | `volcano` | `volcano` |
| CPU | 1x2.5 GHz A720 + 3x2.4 GHz A720 + 4x1.8 GHz A520 | same |
| GPU | Adreno 810 | Adreno 810 |
| Shipped Android | 16 | 14 |
| Recovery layout | dynamic `super`, A/B, **dedicated recovery partition, no kernel** | same |

## Build

```sh
repo init --depth=1 -u https://github.com/TWRP-Test/platform_manifest_twrp_aosp.git -b twrp_16
repo sync

# place this tree at device/motorola/marvel

source build/envsetup.sh
lunch twrp_marvel-ap2a-eng
mka adbd recoveryimage
```

> `twrp_16` is required for the Android 16 decryption blobs — the Android 14.1 /
> OrangeFox 14.1 manifests do not decrypt this platform.

## What was changed from amethyst

| area | change |
|---|---|
| identifiers | `device/xiaomi/amethyst` → `device/motorola/marvel`, `twrp_amethyst` → `twrp_marvel`, brand/model/manufacturer → Motorola |
| `board-info.txt` | `require board=marvel\|volcano` |
| partition sizes | `recovery 134217728`, `dtbo 34603008`, `super 21474836480`, group `mot_dp_group` / `21470642176` |
| dynamic list | **no `odm`** (marvel keeps ODM content in `vendor/odm`) |
| touch modules | MMI chain: `mmi_annotate → mmi_info → mmi_relay → panel_event_notifier → sensors_class → touchscreen_mmi → goodix_brl_mmi` (+ `goodix_fod_mmi`, `rbs_fod_mmi`, `mmi_stow`) |
| crypto services | **NXP** variants (`strongbox-nxp`, `weaver-service.nxp`, `authsecret-service.nxp-qti`) — amethyst uses Thales; marvel ships both and uses NXP |
| crypto rc | `init.recovery.encryption.rc` keeps the amethyst bring-up sequence (`qseecomd → ssgtzd/keymint-qti/gatekeeper-qti → keymint-strongbox/weaver/secure_element`) |
| fstab | dropped `odm`; kept dual `erofs`+`ext4` for every logical partition; `/metadata` f2fs + `wrappedkey`; `/data` with `wrappedkey_v0` + `metadata_encryption` + `sysfs_path=…/1d84000.ufshc` |
| touch probe | `runatboot.sh`'s Xiaomi `touchfeature-service` replaced by `system/bin/touch_probe.sh` (Motorola MMI) |
| UI | `TW_FRAMERATE 120`, `TW_MAX_BRIGHTNESS 2047`, `OF_SCREEN_H 2712`, `OF_MAINTAINER Shripad` |

The whole decryption stack is the same on both devices (QTI keymint on QSEE +
StrongBox/Weaver/AuthSecret + `ssgtzd` + `qseecomd`), so `init.recovery.encryption.rc`
transfers almost verbatim.

## Still to add before building

This repo contains the **tree** only. You also need, under `prebuilt/`:

- `prebuilt/kernel` — marvel's GKI image (`6.1.157-android14-11-…`)
- `prebuilt/dtb/` — `marvel.dtb`
- `prebuilt/dtbo.img`
- `prebuilt/kernel-uapi-headers.tar.gz`

and under `recovery/root/`:

- the QTI/NXP **blobs** the crypto `.rc` files reference (`/vendor/bin/hw/...strongbox-nxp`,
  `weaver-service.nxp`, `authsecret-service.nxp-qti`, `secure_element-service.qti`,
  `qseecomd`, `ssgtzd`, `keymint-service-qti`, `gatekeeper@1.0-service-qti`) plus their
  `/vendor/lib64` dependencies
- the firmware files (`/vendor/firmware_mnt/image/adsp.mdt` …)
- `ueventd.rc` for system / vendor / vendor-odm (carry over from amethyst, adjust
  `external_firmware_handler` paths)

These must be extracted from **marvel's own** firmware
(`dumps.tadiphone.dev/dumps/motorola/marvel`, build `WWE36V.56-32-ST3.2-390dea`) —
do not reuse amethyst's.

## Analysis

The full analysis behind this tree (device/vendor trees, root cause, cybert-vs-marvel,
firmware-dump findings, self-review) lives in
[`shripad-jyothinath/marvel-recovery-bringup`](https://github.com/shripad-jyothinath/marvel-recovery-bringup).
