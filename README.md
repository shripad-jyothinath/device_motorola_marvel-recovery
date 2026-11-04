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
| Shipped Android | 16 (vendor frozen at 14, board API 34) | 14 |
| Recovery layout | dynamic `super`, A/B, **dedicated recovery partition, no kernel** | same |
| Display | 1272×2772 @ 450 dpi | 1220×2712 @ 440 |

**Target firmware: A171WEH.36-31** (Android 17, vendor `UWE34HV-A171-ST4`, 2026-09-01 patch).
Every blob, the fstab, the init triggers and the prebuilts come from that build. Update the
phone to it with the normal OTA before flashing this recovery. Do **not** use Rescue and
Smart Assistant's "Rescue" on a phone you care about: it wipes userdata.
The prebuilt boot DTB is the 36-18 copy (`DA70456E…`, 430,639 B) rather than the
36-31 `B34E9B90…` (430,629 B); the only difference is `__symbols__/msm_vidc`,
so this is a provenance note, not a functional mismatch.

## Build

```sh
# NOTE: the branch is twrp-16.0 (NOT twrp_16 - only 'lvgl' and 'twrp-16.0' exist)
repo init --depth=1 -u https://github.com/TWRP-Test/platform_manifest_twrp_aosp.git -b twrp-16.0
# drop CTS: cts.mk rejects the exact OS version (17) this tree declares, see below
mkdir -p .repo/local_manifests
printf '<manifest>\n  <remove-project name="android_cts" />\n</manifest>\n' > .repo/local_manifests/marvel-no-cts.xml
repo sync

# place this tree at device/motorola/marvel

source build/envsetup.sh
# android-16.0.0_r1 defines: ap2a ap3a ap4a bp1a bp2a (+ eng/user/userdebug)
lunch twrp_marvel-bp2a-eng      # NOT ap2a: its board API 202404 breaks vendor sepolicy (hal_hwcrypto)
mka adbd recoveryimage
```

> **Why no version spoof.** Most TWRP trees set `PLATFORM_VERSION := 99.87.36` and
> `PLATFORM_SECURITY_PATCH := 2127-12-31`. Here they are the installed OS's exact values
> (17 / 2026-09-01), because QTI KeyMint takes the OS version/patch level from the recovery
> image header and from `ro.build.version.*`. Told the OS is newer than its keys, KeyMint
> asks for them to be upgraded; TWRP's `vold` keeps such upgrades in memory only, but
> `keystore2` (stock AOSP) writes them to `/data/misc/keystore`. An upgraded key bound to
> 2127 is rejected by Android on 2026-09-01, which can lock userdata. With equal levels
> nothing is upgraded. After an OTA with a newer patch, bump the values to match; until
> then decryption simply fails, without writing anything.

> `twrp-16.0` (AOSP `android-16.0.0_r1`) is required for the Android 16 decryption blobs — the
> Android 14.1 / OrangeFox 14.1 manifests do not decrypt this platform.

### What the manifest already provides

Verified against the `twrp-16.0` manifest: `vendor/twrp`, `build/make`+`build/soong` (TWRP forks,
base `android-16.0.0_r1`), `base.mk`, `core_64_bit_only.mk`, `to-upper`/`to-lower`,
`external/se_omapi` (for `TW_INCLUDE_OMAPI`), `external/magisk-prebuilt` (repacktools/magiskboot),
`external/ntfs-3g`, `external/lptools`, `external/bash`.

`vendor/lineage` is **absent**; the `-include` lines for optional sepolicy in `BoardConfig.mk`
are harmless no-ops. `fox_marvel.mk` only sets `OF_*` variables, which a pure TWRP build ignores.

## What was changed from amethyst

| area | change |
|---|---|
| identifiers | `device/xiaomi/amethyst` → `device/motorola/marvel`, `twrp_amethyst` → `twrp_marvel`, brand/model/manufacturer → Motorola |
| `board-info.txt` | `require board=marvel\|volcano` |
| partition sizes | `recovery 134217728`, `dtbo 34603008`, `super 23622320128`, group `mot_dp_group` / `23618125824` |
| dynamic list | **no `odm`** (marvel keeps ODM content in `vendor/odm`) |
| kernel modules | one unquoted `TW_LOAD_VENDOR_MODULES` list: `goodix_brl_mmi` (+ `goodix_fod_mmi`, `rbs_fod_mmi`; all three are blocklisted on stock), `smcinvoke_dlkm` + `qseecom_proxy` (QSEECom, needed for decryption; both are present in the stock `modules.load.recovery`, but kept explicit for TWRP), `qti_battery_charger`, `adsp_loader_dlkm`. libmodprobe resolves the MMI chain (`touchscreen_mmi`, `mmi_*`, `panel_event_notifier`, `sensors_class`) from `modules.dep`. |
| crypto services | QTI stack on every unit: `qseecomd`, `qseecom-service`, `ssgtzd`, `keymint-qti`, `gatekeeper_default`. **NXP** StrongBox/weaver/secure_element only on `dnes` SKUs, gated on `ro.boot.strongbox_support`. Blobs are the full dependency closure from A171WEH.36-18 (see `BLOBS.md`); the crypto VINTF manifests are from 36-31. |
| crypto rc | `init.recovery.encryption.rc`: firmware mounted → `vendor.qseecomd`, `qseecom-service`, `vendor.ssgtzd`; listeners registered → `vendor.keymint-qti`, `vendor.gatekeeper_default`; StrongBox SKUs additionally `vendor.secure_element`, `vendor.keymint-strongbox`, `vendor.weaver_nxp` |
| fstab | dropped `odm`; both `erofs`+`ext4` for every logical partition; `/metadata` and `/data` exactly as the OS's `vendor/etc/fstab.qcom`: **`fileencryption=aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized+wrappedkey_v0`**, **`metadata_encryption=aes-256-xts:wrappedkey_v0`**, `inlinecrypt` mount option; `modem` is **ext4** |
| USB | `init.recovery.usb.rc` from stock: forces the dwc3 into peripheral mode and uses Motorola VID/PIDs (`22B8` / adb `2E81` / fastboot `2E80`), plus MTP handlers this tree adds (`mtp` `2E82`, `mtp,adb` `2E76`, from stock `init.mmi.usb.rc`); `TW_EXCLUDE_DEFAULT_USB_INIT := true` |
| boot control | stock recovery's AIDL `android.hardware.boot-service.qti.recovery` + `libboot_control_qti`, bundled under `/vendor` |
| UI | `TW_FRAMERATE 120`, `TW_MAX_BRIGHTNESS 16153`, 1272×2772 @ 450, `OF_SCREEN_H 2772`, `OF_MAINTAINER Shripad` |

The QTI part of the decryption stack (keymint + gatekeeper on QSEE, `qseecomd`, `ssgtzd`)
is the same on both devices, so `init.recovery.encryption.rc` transfers almost verbatim.

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
`android.hardware.gatekeeper-service-qti`. **The XT2605-4 ("dn" SKU) has no StrongBox:**
`ro.vendor.hw.strongbox=false`, no `ro.boot.strongbox_support`, and no weaver registered on
a running phone — on it, decryption is the TZ path alone.

## What's included

**Prebuilts** (kernel and vendor blobs from A171WEH.36-18; dtbo/dtb from 36-31). Recovery is built without a kernel, so these only feed
the build plumbing; the device boots recovery with the kernel from its `boot` partition.

| file | size | note |
|---|---|---|
| `prebuilt/kernel` | 33.99 MB | GKI `6.1.157-android14-11-ga8b0b542991e-ab15601211` (from `boot.img`) |
| `prebuilt/dtbo.img` | 33 MB | the package's `dtbo.img` (34603008 = partition size) |
| `prebuilt/dtb/marvel.dtb` | 0.41 MB | the dtb section of the package's `vendor_boot.img` |
| `prebuilt/kernel-headers.tar.gz` | 1.76 MB | from the earlier 6.1.157 build |

**Vendor blobs** under `recovery/root/vendor/`: 79 binaries and libraries (7.9 MB), the full
dependency closure of the decryption services plus the boot-control HAL, all from
A171WEH.36-18. `BLOBS.md` lists how the set was derived and what `/system` must provide.

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

## The stock recovery ramdisk (reference for layout, NOT for decryption)

`recovery.img` of A171WEH.36-31 (the earlier Android 16 image had the same shape):

```
header_version=4  kernel_size=0  ramdisk_size=19245698   -> ramdisk-only, NO kernel
488 cpio entries, no kernel modules
ships: android.hardware.boot-service.qti.recovery (+ libboot_control_qti),
       android.hardware.health-service.qti_recovery, fastbootd
```

Notable:

- **No kernel** → confirms `BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true` is how marvel ships.
- **No kernel modules either** → the modules are *not* bundled; recovery gets them from the mounted
  vendor/vendor_boot. This is why `TW_LOAD_VENDOR_MODULES` (what amethyst uses) is the right
  mechanism, not ramdisk bundling.
- Its `system/etc/recovery.fstab` says `fileencryption=ice,wrappedkey` for `/data`. That is
  **not** what the data is encrypted with — stock recovery never decrypts, so nothing checks
  it. This tree's fstab follows the OS's `vendor/etc/fstab.qcom` instead (v2 policy,
  `wrappedkey_v0`, metadata encryption with `wrappedkey_v0`).
- USB config + props as above.

## Not bundled, on purpose

- `vendor/firmware_mnt/image/*` — these live on the **modem** partition (ext4,
  `/vendor/firmware_mnt`), which `init.recovery.qcom.rc` mounts itself. The `adsp.mdt`/`adsp.b*`
  chain it waits for comes from there.
- Kernel modules: recovery loads them at runtime from `vendor_dlkm` via
  `TW_LOAD_VENDOR_MODULES` (see `device.mk`), so they always match the installed firmware.

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

**The one difference from the ofrp job:** that job syncs the OrangeFox **12.1** manifest;
this targets **`twrp-16.0`** (AOSP `android-16.0.0_r1`, ~990 projects — required for this
platform's decryption), which is a much bigger tree. So this workflow adds a disk-reclaim
step and a disk-aware build plan.

### Storage — measured on real runners, not read off the docs table

GitHub's hardware table says "14 GB SSD" for the standard Linux runner. That is the
**guaranteed minimum**, and it is not the whole story:

| what | measured | source |
|---|---|---|
| documented guarantee | 14 GB | GitHub docs, *GitHub-hosted runners reference* |
| `/` (`/dev/root`) at job start | **72–84 GB device, 16–19 GB free** | godotengine/godot#80115 (`84G 66G 19G 79% /`), thiagokokada, HastD (`72 GB total, 19 GB available`) |
| `/mnt` (Azure temp disk, separate device) | **74 GB device, ~66 GB free** | cilium/cilium#39726, kserve/kserve#3411 (`/dev/sda1 74G 4.1G 66G /mnt`) |
| after deleting unused toolchains | **49–65 GB free on `/`** (30–41 GB reclaimed) | thiagokokada `free-disk-space` (16G → 65G), jlumbroso (~30 GB), insightsengineering (34 GB) |
| **combined usable** | **~115–130 GB** | `/` after cleanup + `/mnt` |
| cache storage per repository | 10 GB | GitHub docs, *Actions limits* |
| artifact storage (GitHub Free) | **500 MB total** | same — that is why only logs are uploaded as artifacts and the image itself goes to a Release |
| job time cap | 6 h (this workflow uses 350 min) | same |
| runner spec, public repo | 4 vCPU / 16 GB | same |

So a TWRP-16 build *does* fit on a hosted runner — but the numbers below are from the first
real run, and the tree is a lot bigger than I first assumed.

### What the first real run measured (run `37225313615`)

| | |
|---|---|
| runner disk | `/dev/root 146G`, **121 GB free** after the cleanup step (larger than the 72–84 GB seen elsewhere) |
| `/mnt` | **not** a separate device on that image — the dual-disk split never engaged, `OUT_DIR` stayed default |
| source tree after `repo sync -c --depth=1` | **74 GB** (not the 30 GB I originally estimated) |
| sync wall-clock | **14.5 min** for all 990 projects |
| free space after the sync | 47 GB — enough for `out/`, but only just |
| whole job | 19 min (it died in `lunch`, see below) |

**The `lunch` failure was my bug, recorded in the workflow now:** an **empty but *set* `OUT_DIR`**
resolves to the *source root* inside soong (`filepath.Clean("") == "."` in
`build/soong/ui/build/config.go`), so `SetupOutDir()` dies on `ensureEmptyFileExists(<src>/.out-dir)`,
the paths step never writes `out/.module_paths/AndroidProducts.mk.list`, and `product_config.mk`
— which reads exactly that file to find device trees — reports
`Don't have a product spec for: 'twrp_marvel'`. The workflow now only exports `OUT_DIR` when it
actually relocates it, and unsets it otherwise.

If the runner is a classic 72–84 GB one, the 74 GB tree does not fit and the guard now stops in
the first minute instead of 15 minutes in. Two ways out:

1. **Trim the sync.** The manifest ships `remove-minimal.xml` — 607 projects (cts, kernel
   prebuilts 6.1/6.6/6.12, `device/generic/*`, 311 unused `external/*`, …). It keeps every
   project the recovery build needs: `bash`, `nano`, `tools-lineage`, e2fsprogs, ntfs-3g,
   exfatprogs, magisk-prebuilt, libncurses, `system/core`, `frameworks/base` and the rest of
   the 27 I checked. Apply it as a local-manifest overlay *before* `repo sync`:

   ```sh
   mkdir -p .repo/local_manifests
   cp .repo/manifests/remove-minimal.xml .repo/local_manifests/
   printf '<manifest><include name="remove-minimal.xml"/></manifest>\n' \
     > .repo/local_manifests/minimal.xml
   ```

2. **Self-hosted runner** with ≥150 GB (see below).

`Choose build directories` works out the layout at run time:

- compares `stat -c %d /` with `stat -c %d /mnt`, so `/mnt` is only counted when it really is a
  separate device (on some runner classes it is just a directory on `/dev/root`),
- ignores `/mnt` entirely when it is nearly full (it has been seen 100 % full out of the box —
  actions/runner#3968),
- puts the source on the roomier disk and `OUT_DIR` on the other one, but keeps `out/` next to
  the source when the second disk cannot hold it,
- fails in the first minute, with instructions, when the space genuinely is not there.

That logic was exercised offline against the eight layouts above (fresh two-disk runner, after
cleanup, single disk, `/mnt` full, `/mnt` too small, tight root, and two must-fail cases) using
`df`/`stat` shims — all eight decide correctly, and every shell step passes `bash -n`.

| runner | vCPU | RAM | disk |
|---|---|---|---|
| `ubuntu-22.04` (default) | 4 | 16 GB | 14 GB guaranteed, ~115–130 GB usable in practice |
| `ubuntu-latest` / `ubuntu-24.04` | 4 | 16 GB | same layout (22.04 is deprecated Sep 2026 → Apr 2027, still supported today) |
| same, private repo | 2 | 8 GB | same layout |
| `ubuntu-slim` | 1 | 5 GB | 14 GB, **15-min job cap** — unusable for this |
| **self-hosted (needed to finish)** | ≥8 | **≥32 GB** | **≥150 GB** |

### RAM is the wall, not disk — measured

Every hosted run gets **15.6 GB** and dies at the same place, reproducibly (runs
37232604397, 37355587032, and the earlier pair):

```
resolved: TARGET_PRODUCT=twrp_marvel TARGET_RELEASE=ap2a TARGET_BUILD_VARIANT=eng   ← lunch is fine
[ 99% 131/132] cp out/host/linux-x86/bin/soong_build
   ~3 minutes of silence, then
##[error]Process completed with exit code 143.
##[error]The runner has received a shutdown signal.
```

Exit 143 is SIGTERM to the runner service — the machine is taken away during
`soong_build`'s `Android.bp` analysis, which is the memory peak of the whole build.
`build.oom.txt` is empty every time, so it is not the kernel OOM killer; it is the
platform shutting the runner down under memory pressure. AOSP's own banner says it
plainly:

```
You are building on a machine with 15.6GB of RAM
The minimum required amount of free memory is around 16GB,
and even with that, some configurations may not work.
```

`GOMEMLIMIT=6GiB` and `-j3` are already in place (they removed the earlier,
worse failure modes), and the tree is already minimal: `repo manifest` reports
**392 projects**, and `remove-minimal.xml` only lists projects in non-default
groups that `repo sync` never fetches — so there is nothing left to trim.

To finish the build, register a self-hosted runner with **≥32 GB RAM** (the
96-core ServerHive box qualifies) and dispatch with
`runner: ["self-hosted","linux","x64"]`:

```sh
TOKEN=$(gh api -X POST repos/OWNER/REPO/actions/runners/registration-token --jq .token)
./config.sh --url https://github.com/OWNER/REPO --token "$TOKEN" \
            --labels self-hosted,linux,x64 --name serverhive --unattended
sudo ./svc.sh install && sudo ./svc.sh start
```

A self-hosted runner also keeps `SRC_ROOT` between runs, which removes the
15–21 minute sync from every subsequent build.

> **Security:** don't attach a self-hosted runner to a public repo if untrusted users can trigger
> workflows — a fork PR would execute on your machine. This workflow triggers on
> `workflow_dispatch` + push to `master`/tags only, so only you can start it.

## Brick safety — read this before flashing anything

Parsing the stock images with AOSP's own `avbtool` gives one fact that decides everything
about risk on this device:

```
$ python avbtool.py info_image --image vbmeta.img
Algorithm: SHA256_RSA4096   Flags: 0
Descriptors:
    Chain Partition descriptor:  Partition Name: vbmeta_system
    Hash descriptor: boot         (35659776 bytes)
    Hash descriptor: dtbo         (598379 bytes)
    Hash descriptor: init_boot    (2105344 bytes)
    Hash descriptor: recovery     (19251200 bytes)   <-- recovery is verified
    Hash descriptor: vendor_boot  (8826880 bytes)
    Hashtree descriptor: product / system_dlkm / ...
```

**`recovery` is inside verified boot on marvel.** Unlike most TWRP devices, stock `vbmeta.img`
carries a hash descriptor for the recovery partition (`Flags: 0` = verification enabled). So a
modified recovery partition does not verify. That is contained, but it has three consequences:

1. **Flashing TWRP changes only the `recovery` partition** — the build outputs `recovery.img`
   and `ramdisk-recovery.img`, `BOARD_USES_RECOVERY_AS_BOOT` and
   `BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT` are empty, `BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE`
   is `true` (matching stock, which is kernel-less), and `TW_HAS_NO_RECOVERY_PARTITION` is **not**
   set anywhere in the tree (TWRP treats *defined* as true, so setting it even to `false` breaks
   recovery handling). `boot`, `init_boot`, `vendor_boot`, `dtbo`, `vbmeta` and the OS are untouched.
2. **Never relock the bootloader while TWRP is installed.** Unlocking is required to `fastboot
   flash` here, and an unlocked bootloader tolerates the verification failure (recovery boots with
   the usual "device is unlocked / can't be verified" warning). A **locked** bootloader would refuse
   to boot a partition that fails AVB, and on Motorola relocking also wipes userdata.
3. **Do not touch vbmeta.** Specifically, do *not* run the advice that is common for other devices:

   ```
   fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img   # DON'T
   ```

   It is not required (the recovery partition does not depend on it) and it modifies a signed
   verified-boot component — that is the operation that can leave the device unbootable or force a
   data wipe. The same reason is why `twrp.flags` lists `/vbmeta` and `/vbmeta_system` as
   **backup-only** (`backup=1`, no `flashimg`), and why `/persist`/`/persist_image` are backup-only
   too (sensor/camera calibration is not recoverable without a stock dump).

**Reverting is a single fastboot command.** The byte-exact stock `recovery.img` is in the firmware
dump and its MD5 matches `flashfile.xml`, so:

```sh
fastboot flash recovery stock_recovery.img     # restores the verified state
```

**`fastboot boot` cannot be used to try this recovery out.** Marvel's ABL needs a kernel-less
recovery image, and `fastboot boot` of a kernel-less image fails with "No OS could be found"
(booting a kernel-present image just boots the installed OS). The only way to test is to flash the
recovery partition and enter recovery mode from the bootloader menu.

## Status — boots; data decryption works

`mka recoveryimage` succeeds on `twrp-16.0` / `bp2a` (ServerHive, with its RBE profile). The image
unpacks to header v4, `kernel_size=0`, `os_version=17.0.0`, `os_patch_level=2026-09`, AVB footer,
and every tree file. **TWRP boots after removing the early-init UFS writes**, and the fixed9
ramdisk **decrypts userdata with the device PIN**. The fix is the recovery VINTF path: recovery's
`servicemanager` reads `/system/etc/vintf/manifest.xml` (not the platform manifest under
`/vendor`). The image now ships the merged stock 36-31 manifest there and in
`/vendor/etc/vintf/{manifest.xml,manifest_volcano.xml}`, plus `compatibility_matrix.xml`; the
QTI qseecom/gatekeeper/keymint/boot services stay running and `/data` mounts. See
`DECRYPTION_REPORT.md` for the before/after logs. Two things learned from the test:

- start TWRP from Android with `adb reboot recovery`. `fastboot reboot recovery` makes this
  bootloader retry recovery on every boot, so a failing recovery loops until stock is restored;
- stock recovery's adb gives no shell (SELinux), so it cannot be used to read the crash log.

Open items:

| item | risk |
|---|---|
| boot failure | **resolved**: the early-init UFS `auto_hibern8`/`clkgate` writes panic in `ufshcd_auto_hibern8_update`; removed from `init.recovery.qcom.rc` and `init.recovery.encryption.rc`. |
| decryption | **resolved**: the missing `/system/etc/vintf/manifest.xml` made servicemanager reject the QTI crypto services. Shipping the merged manifest there (and under `/vendor`) lets the PIN decrypt userdata; see `DECRYPTION_REPORT.md`. |
| release config | must be `bp2a`; `ap2a` fails in `vendor_sepolicy.cil` (`hal_hwcrypto_server` not declared below board API 202504) |
| Android 17 data on a `twrp-16.0` base | OS version (17) and patch (2026-09-01) match; the Android 16 vold/keystore2 decrypted the Android 17 userdata with a PIN once the recovery VINTF manifest was fixed. |
| brightness | `TW_MAX_BRIGHTNESS` is 16153 in the tree; a prebuilt TWRP binary still carries the old 2047 value until the next full `recoveryimage` build. |
| keymaster fallback | `keymaster_ver` still falls back to `4.x` from the prop because TWRP looks for `android.hardware.keymaster`; decryption works, but a KeyMint-aware lookup would be cleaner. |
| `TARGET_CPU_VARIANT_RUNTIME := kryo300` | copied from amethyst (same SoC); ignored or an error depending on the Soong in your manifest |
| bundled `/vendor/**` blobs | when the real `vendor` partition is mounted over `/vendor` (TWRP does so briefly to load modules), the bundled copies are shadowed while it is mounted |
| `TW_CUSTOM_CPU_TEMP_PATH` | `thermal_zone10` is `cpuss-0` on Android; recovery registers fewer zones, so the index may differ |
| MTP | handlers written for TWRP from stock PIDs; untested on device |
| StrongBox SKUs (`dnes`) | blobs, vintf and gating are in place, but only the non-StrongBox path matches a phone that was actually inspected |
| SELinux | the tree runs permissive (`write /sys/fs/selinux/enforce 0`); stock is enforcing |

## Analysis

The full analysis behind this tree (device/vendor trees, root cause, cybert-vs-marvel,
firmware-dump findings, self-review) lives in
[`shripad-jyothinath/marvel-recovery-bringup`](https://github.com/shripad-jyothinath/marvel-recovery-bringup).
