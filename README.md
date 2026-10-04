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
# NOTE: the branch is twrp-16.0 (NOT twrp_16 - only 'lvgl' and 'twrp-16.0' exist)
repo init --depth=1 -u https://github.com/TWRP-Test/platform_manifest_twrp_aosp.git -b twrp-16.0
repo sync

# place this tree at device/motorola/marvel

source build/envsetup.sh
# android-16.0.0_r1 defines: ap2a ap3a ap4a bp1a bp2a (+ eng/user/userdebug)
# aosp_current -> bp2a, so either of these works:
lunch twrp_marvel-ap2a-eng      # (or twrp_marvel-bp2a-eng)
mka adbd recoveryimage
```

> `twrp-16.0` (AOSP `android-16.0.0_r1`) is required for the Android 16 decryption blobs — the
> Android 14.1 / OrangeFox 14.1 manifests do not decrypt this platform.

### What the manifest already provides

Verified against the `twrp-16.0` manifest: `vendor/twrp`, `build/make`+`build/soong` (TWRP forks,
base `android-16.0.0_r1`), `base.mk`, `core_64_bit_only.mk`, `to-upper`/`to-lower`,
`external/se_omapi` (for `TW_INCLUDE_OMAPI`), `external/magisk-prebuilt` (repacktools/magiskboot),
`external/ntfs-3g`, `external/lptools`, `external/bash`.

`vendor/lineage` is **absent**, so the `-include vendor/lineage/config/BoardConfigReservedSize.mk`
in `BoardConfig.mk` is a harmless no-op. `fox_marvel.mk` only sets `OF_*` variables, which a pure
TWRP build ignores.

## What was changed from amethyst

| area | change |
|---|---|
| identifiers | `device/xiaomi/amethyst` → `device/motorola/marvel`, `twrp_amethyst` → `twrp_marvel`, brand/model/manufacturer → Motorola |
| `board-info.txt` | `require board=marvel\|volcano` |
| partition sizes | `recovery 134217728`, `dtbo 34603008`, `super 21474836480`, group `mot_dp_group` / `21470642176` |
| dynamic list | **no `odm`** (marvel keeps ODM content in `vendor/odm`) |
| touch modules | MMI chain: `mmi_annotate → mmi_info → mmi_relay → panel_event_notifier → sensors_class → touchscreen_mmi → goodix_brl_mmi` (+ `goodix_fod_mmi`, `rbs_fod_mmi`, `mmi_stow`) |
| crypto services | **NXP** variants (`strongbox-nxp`, `weaver-service.nxp-qti`) — amethyst uses Thales; marvel ships both and selects NXP on the `dnes` SKU (see below). There is no `authsecret` service binary in the dump. |
| crypto rc | `init.recovery.encryption.rc` drives the stock units in order: `vendor.qseecomd → vendor.ssgtzd, vendor.keymint-qti, vendor.gatekeeper_default → vendor.secure_element`, with `vendor.keymint-strongbox` / `vendor.weaver_nxp` gated on `ro.boot.strongbox_support` |
| fstab | dropped `odm`; both `erofs`+`ext4` for every logical partition; `/metadata` f2fs + `wrappedkey` + `first_stage_mount`; `/data` **`fileencryption=ice,wrappedkey`** + `keydirectory` + `sysfs_path=…/1d84000.ufshc` (taken verbatim from the stock recovery fstab) |
| USB | new `init.recovery.usb.rc` from stock: forces the dwc3 into peripheral mode and uses Motorola VID/PIDs (`22B8` / adb `2E81` / fastboot `2E80`); `TW_EXCLUDE_DEFAULT_USB_INIT := true` |
| touch probe | `runatboot.sh`'s Xiaomi `touchfeature-service` replaced by `system/bin/touch_probe.sh` (Motorola MMI) |
| UI | `TW_FRAMERATE 120`, `TW_MAX_BRIGHTNESS 2047`, `OF_SCREEN_H 2712`, `OF_MAINTAINER Shripad` |

The whole decryption stack is the same on both devices (QTI keymint on QSEE +
StrongBox/Weaver/AuthSecret + `ssgtzd` + `qseecomd`), so `init.recovery.encryption.rc`
transfers almost verbatim.

### Crypto is a SKU-gated NXP StrongBox stack

`odm/etc/vintf/manifest_dnes.xml` (the "dnes" SKU) declares:

```
android.hardware.security.keymint    IKeyMintDevice/strongbox  v3   (vendor/nxp/.../KM300)
android.hardware.security.sharedsecret ISharedSecret/strongbox
android.hardware.weaver              IWeaver/default           v2   (vendor/nxp/.../weaver/aidl_impl)
android.hardware.secure_element      ISecureElement/SIM1,/SIM2,/eSE1
android.se.omapi                     ISecureElementService/default
```

StrongBox is gated by `vendor/etc/vhw.xml` (`ro.boot.strongbox_support`, hwid-indexed) and
advertised by `odm/etc/permissions/sku_dnes/android.hardware.strongbox_keystore.xml`.
`vendor/etc/hal_uuid_map_config.xml` lists both implementations:
NXP 2910/2911/2915 and STM/Thales 2913/2916 — marvel selects **NXP**.

The always-present TZ path is `android.hardware.security.keymint-service-qti`
(`IKeyMintDevice/default` + secureclock + sharedsecret), plus
`android.hardware.gatekeeper-service-qti`.

## What's included

**Prebuilts** (from the stock `marvel_g` build, verified against the device):

| file | size | note |
|---|---|---|
| `prebuilt/kernel` | 33.99 MB | GKI `6.1.157-android14-11-gc7dd3fa941b3-ab15371444` |
| `prebuilt/dtbo.img` | 33 MB | matches the real `dtbo` partition (34603008) |
| `prebuilt/dtb/marvel.dtb` | 0.41 MB | "Qualcomm Technologies, Inc. Volcano SoC" |
| `prebuilt/kernel-headers.tar.gz` | 1.76 MB | |

**Crypto blobs** under `recovery/root/vendor/` — extracted from the stock vendor partition
(`DumprX` release `marvel-W2WE36.56-32-ST3.2-390dea`), 46 files:

```
vendor/bin/hw/   7 binaries (keymint-qti, strongbox-nxp, weaver-service.nxp-qti,
                            gatekeeper-service-qti, secure_element-service.qti,
                            qseecom@1.0-service, keymaster@4.0-service-qti)
vendor/bin/      qseecomd, ssgtzd
vendor/lib64/    24 libraries + 2 under hw/
vendor/etc/init/ 8 stock-derived service units (recovery seclabel)
vendor/etc/vintf/manifest/ 3 XML fragments
vendor/etc/ueventd.rc, vendor/odm/etc/ueventd.rc
```

See `BLOBS.md` for the full dump→tree path map.

## Why USB was dead (and the fix)

The stock recovery ramdisk contains the answer. Its own `init.recovery.qcom.rc`:

```
on property:ro.boot.usbcontroller=*
    setprop sys.usb.controller ${ro.boot.usbcontroller}
    wait /sys/bus/platform/devices/${ro.boot.usb.dwc3_msm:-a600000.ssusb}/mode
    write /sys/bus/platform/devices/${ro.boot.usb.dwc3_msm:-a600000.ssusb}/mode peripheral
    wait /sys/class/udc/${ro.boot.usbcontroller} 1
```

and the stock `prop.default`:

```
ro.recovery.usb.vid=22B8
ro.recovery.usb.adb.pid=2E81
ro.recovery.usb.fastboot.pid=2E80
# (overriding the AOSP defaults 18D1 / D001 / 4EE0)
```

Two things were missing from every custom tree so far:

1. **The QTI dwc3 must be forced into peripheral mode** — without
   `write .../a600000.ssusb/mode peripheral` the controller never presents a gadget, so the host
   sees nothing at all (no `adb devices`, no Device Manager entry).
2. **Motorola's VID/PIDs must be used.** The AOSP/TWRP defaults (`18D1:D001`) have **no driver on a
   typical Windows host**, which is exactly the "Device Manager doesn't even react" symptom.
   `22B8:2E81`/`22B8:2E80` match the Motorola drivers that ship for this device.

Both are now in the tree:

- `recovery/root/init.recovery.usb.rc` — verbatim from stock (peripheral mode + VID/PIDs)
- `system.prop` — `ro.recovery.usb.vid=22B8`, `ro.recovery.usb.adb.pid=2E81`,
  `ro.recovery.usb.fastboot.pid=2E80`, `ro.recovery.ui.margin_height=110`
- `BoardConfig.mk` — `TW_EXCLUDE_DEFAULT_USB_INIT := true` so TWRP's own USB init does not fight it

## The stock recovery ramdisk (authoritative reference)

Extracted from `marvel-boot-images.tar.zst` → `recovery.img`:

```
header_version=4  kernel_size=0  ramdisk_size=19245719   -> ramdisk-only, NO kernel
5 lz4-legacy blocks -> 36,921,088 bytes cpio, 489 entries (449 files)
modules in the ramdisk: 0
```

Notable:

- **No kernel** → confirms `BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true` is how marvel ships.
- **No kernel modules either** → the modules are *not* bundled; recovery gets them from the mounted
  vendor/vendor_boot. This is why `TW_LOAD_VENDOR_MODULES` (what amethyst uses) is the right
  mechanism, not ramdisk bundling.
- `system/etc/recovery.fstab` — the authoritative fstab, now copied:
  `fileencryption=ice,wrappedkey` for `/data` (not the older `aes-256-xts` string),
  `wrappedkey` for `/metadata`, and the `odm` line **commented out**.
- USB config + props as above.

## Still missing

- `vendor/firmware_mnt/image/*` — these live on the **modem** partition (`/vendor/firmware_mnt`),
  which `init.recovery.qcom.rc` mounts itself. The `adsp.mdt`/`adsp.b*` chain it waits for comes
  from there.
- Kernel modules are **not** bundled: recovery loads them at runtime from `/vendor/lib/modules`
  via `TW_LOAD_VENDOR_MODULES` (see `device.mk`) — so the stock `vendor` / `vendor_dlkm` partitions
  must be present on the device (they are).

## CI: `.github/workflows/build-twrp.yml`

Modelled on the **working** OrangeFox workflow in
`shripad-jyothinath/android_device_motorola_avenger @ ofrp` — same method:

- GitHub-hosted **`ubuntu-22.04`** runner by default
- **12 GB swapfile** (16 GB RAM is not enough for Soong+ninja on its own)
- `actions/cache` for `~/.ccache`
- `repo` launcher downloaded; `repo init --depth=1 --no-repo-verify`
- `repo sync -c -j$(nproc) --force-sync --no-clone-bundle --no-tags`
- build loop with retries that **re-pulls the device tree** between attempts
- flashable zip + auto-published GitHub release

**One difference from the ofrp job:** that job syncs the OrangeFox **12.1** manifest, which fits
on a hosted runner. This targets **`twrp-16.0`** (AOSP `android-16.0.0_r1`, ~990 projects —
required for this platform's decryption), which is much larger. So this workflow adds a
free-disk-space step, a hard disk guard, and a `runner` input to fall back to self-hosted.

| runner | vCPU | RAM | disk |
|---|---|---|---|
| `ubuntu-22.04` / `ubuntu-latest` (public repo) | 4 | 16 GB | **14 GB guaranteed** (~16–24 GB actual on `/`, ~66 GB on `/mnt`) |
| same, private repo | 2 | 8 GB | 14 GB |
| `ubuntu-slim` | 1 | 5 GB | 14 GB, 15-min cap |
| GitHub-hosted max job time | — | — | **360 min** |
| **self-hosted (fallback)** | ≥8 | ≥16 GB | **≥150 GB** |

If the `twrp-16.0` sync does not fit, re-run with
`runner: ["self-hosted","linux","x64"]` on a machine with ≥150 GB:

```sh
TOKEN=$(gh api -X POST repos/OWNER/REPO/actions/runners/registration-token --jq .token)
./config.sh --url https://github.com/OWNER/REPO --token "$TOKEN" \
            --labels self-hosted,linux,x64 --name serverhive --unattended
sudo ./svc.sh install && sudo ./svc.sh start
```

> **Security:** don't attach a self-hosted runner to a public repo if untrusted users can trigger
> workflows — a fork PR would execute on your machine. This workflow triggers on
> `workflow_dispatch` + push to `master`/tags only, so only you can start it.

## Status — not built yet

Everything in this tree is sourced from the stock dump (see the two sections above), but the tree
**has never been compiled**. Known open items before the first flash:

| item | risk |
|---|---|
| `lunch twrp_marvel-ap2a-eng` | the release tag comes from the manifest you sync; verify with `lunch` and adjust `AndroidProducts.mk` |
| `TARGET_CPU_VARIANT_RUNTIME := kryo300` | copied from amethyst (same SoC); ignored or an error depending on the Soong in your manifest |
| `OF_USE_AIDL_BOOT_CONTROL := 1` | marvel's boot HAL type (AIDL vs HIDL) is unverified |
| bundled `/vendor/**` blobs | when the real `vendor` partition is mounted over `/vendor`, the bundled copies and `vendor/etc/init/*.rc` are shadowed — stock does not bundle at all, so either path may be what actually executes |
| SELinux | the tree runs permissive (`write /sys/fs/selinux/enforce 0`); stock is enforcing |
| `ro.boot.strongbox_support` | if `false` on your unit, StrongBox/Weaver do not start and decryption falls back to the TZ keymint path |

## Analysis

The full analysis behind this tree (device/vendor trees, root cause, cybert-vs-marvel,
firmware-dump findings, self-review) lives in
[`shripad-jyothinath/marvel-recovery-bringup`](https://github.com/shripad-jyothinath/marvel-recovery-bringup).
