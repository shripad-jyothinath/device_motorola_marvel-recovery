# ROM bring-up audit — Motorola Edge 70 Fusion (`marvel`)

Branch: `evox-a17`
Target firmware: **A171WEH.36-31** (vendor 14 / API 34 / VNDK 34; product first API 36)
Scope: static audit only. No ROM was built, flashed, or booted in this pass.

## Sources of truth

- Stock 36-31 `vendor/build.prop`, `vendor/etc/vintf/*`, and `odm/etc/vintf/*` from the extracted vendor dump.
- Stock 36-31 `vendor_boot` first-stage `fstab.qcom` and 294 `vendor_boot` kernel modules.
- The working fixed9 recovery session and its VINTF/service state.
- The recovery tree's verified values for kernel, DTBO, display size, brightness, and partition layout.
- The vendor repository was treated as untrusted input and audited mechanically.

## Vendor repository audit

File: `rom/audit/vendor-audit.json` (one entry per copy rule).

- 2,281 makefile lines; **2,219 copy rules**.
- **0 malformed rules, 0 missing sources, 0 non-regular sources**.
- 830.5 MB of files: 1,535 vendor, 675 system_ext, 6 odm, 3 product.
- 2,244 proprietary files: 1,079 `.so`, 413 `.xml`, 110 `.jar`, 25 `.apk`.
- 1,203 ELF files: 1,177 are 64-bit AArch64. The other 26 are DSP/firmware (`rfsa/adsp`, `CAMERA_ICP`, `vpu*`), which are expected 32-bit binary blobs.
- 132 ZIP containers: 25 APKs and 107 JARs.
- 431 XML copy rules from 413 distinct XML files. The audit script does not do
  schema validation; XML well-formedness was validated separately, and the stock
  VINTF files are used instead of the repo's fragments.
- **14 duplicate destination groups / 23 extra entries.** They are exact duplicate rules in the audio and `sku_volcano` sensor permission sets.
- `rom/tools/dedupe_vendor_makefile.js` removes all 23 and leaves 0 duplicate destinations (verified).

### ROM-ready vendor branch

The vendor repository now has a `rom-ready` branch (commit `0de980d`) with:

- the 23 duplicate rules removed: **2,498 copy rules, 0 duplicate destinations,
  0 missing sources** (`rom/audit/vendor-audit-rom-ready.json`);
- the stock 36-31 top-level `manifest.xml`, `manifest_volcano.xml`,
  `compatibility_matrix.xml`, and first-stage `fstab.qcom`;
- copy rules for those four files;
- the real stock **vendor_dlkm** contents pulled from the device: **292 `.ko`
  modules** plus six metadata files, 298 copy rules targeting
  `$(TARGET_COPY_OUT_VENDOR_DLKM)/lib/modules`.

The vendor_dlkm module blocker is resolved. The vendor binary provenance is not.

## Stock super extraction

The Motorola Rescue tool's stock ROM has the full 36-31 `super` image split into
26 sparse chunks. Using `rom/tools/rebuild_super.js` and
`rom/tools/extract_lp.js`:

- reconstructed raw super: **23.62 GB**;
- 12 logical partitions;
- `vendor_a`: **1,047.6 MB**, EROFS;
- `vendor_dlkm_a`: **23.7 MB**, EROFS.

The vendor and vendor_dlkm images are EROFS. Windows 7-Zip does not support
EROFS, so the stock vendor_dlkm contents were pulled from the running device via
ADB instead. The super/LP extraction scripts are committed under `rom/tools/`.

## Provenance warning

The vendor makefile's 2,219 source paths exactly match the dropped device tree's
`proprietary-files.txt` (0 donor-only, 0 vendor-only). That list is headed
`roadstr W1WRS36.39-25-2-1`, not `A171WEH.36-31`. The file list therefore proves
coverage, not provenance. The binary contents cannot be asserted to be 36-31
without hashing a full stock vendor image.

The donor property file also fails cross-checking against the stock 36-31
`vendor/build.prop`:

- 106 donor props vs **437 stock props**.
- 6 donor values differ (all `debug.sf.*` timing/latching values).
- 48 donor props are absent from stock (`ro.hardware.egl`, `ro.vendor.audio_*`,
  several radio/Wi-Fi/display props, etc.).
- The donor `system_ext.prop`, `odm.prop`, and `product.prop` explicitly say
  **SM7750 (sun)**, not SM7635/volcano. They are kept only under
  `rom/reference/` and are not active.

A stock-vs-repo SHA-256 comparison of all `/vendor` files (`rom/tools/compare_vendor_hashes.js`)
is also negative:

- stock `/vendor` files: **3,643**;
- repo `/vendor` files: **1,553**;
- exact matches: **1,029**;
- different contents: **512**;
- repo-only: **12**;
- stock-only: **2,102**.

The vendor repository is therefore **not a 36-31 vendor image**. The default ROM
product intentionally uses the stock vendor and vendor_dlkm partitions. Do not
enable `MARVEL_BUILD_VENDOR_IMAGE` until the vendor tree is rebuilt from the
stock `/vendor` files.

A full stock `/vendor` tar was also pulled over ADB: **1.95 GB**, with 3,643
regular files and 3,415 symlinks. Windows cannot materialize those symlinks, so
the vendor repository was not overwritten with a broken tree. The tar is kept
locally for a Linux-server rebuild if a full vendor image is wanted later.

## Fstab and modules

Donor fstab vs stock 36-31 fstab:

- Stock: 23 mount entries; donor: 13.
- 7 material differences, including:
  - `/metadata`: donor `ext4`, stock `f2fs`.
  - `/vendor/firmware_mnt`: donor `vfat`, stock `ext4`.
  - `/system`, `/system_ext`, `/vendor`, `/system_dlkm`: donor lists only `erofs`; stock lists both `erofs` and `ext4`.
  - `/odm`: donor entry is not present in stock (marvel has no ODM partition).
- The ROM uses the stock fstab (`rom/fstab.qcom`), not the donor.

Kernel modules:

- Stock vendor_boot contains **294 `.ko`** files.
- The stock vendor_dlkm partition contains **292 `.ko`** files plus six metadata
  files; all 298 files were pulled from the running device and added to the
  `rom-ready` vendor branch.
- The old donor `modules.load` lists 310 modules. Of the 149 donor names not in
  stock vendor_boot, only 89 exist on this device; 60 donor names (for example
  `evacc-tuna`, `debugcc-sun`, `zram`) are from another firmware and are not
  present here. The donor module list is stale.
- The vendor repository previously contained **0 `.ko`** files; that gap is now
  closed.

## VINTF

- Vendor repo: **0 top-level** `manifest.xml` / `manifest_volcano.xml`; 58 vendor fragments and 6 system_ext fragments.
- Stock 36-31 provides the real files:
  - `manifest.xml` — 4,725 bytes, `target-level=8`, gatekeeper/keymint/qseecom/boot declared.
  - `manifest_volcano.xml` — 3,772 bytes.
  - `compatibility_matrix.xml` — 2,071 bytes, type `device`, VNDK 34.
- The ROM uses those stock files. A full vendor-image build needs the fragments
  reconciled against the stock top-level manifest; do not merge them blindly.
- The older recovery manifest (4,799 bytes) added a fake keymaster 4.0 entry for
  TWRP. It is **not** used for the ROM.

## Other vendor-tree gaps

- No `build.prop`; stock `vendor/build.prop` is 19,404 bytes and is used as the
  source for the generated `rom/props/vendor.prop`.
- Referenced `vendor/motorola/sm7750-common` does not exist publicly (HTTP 404);
  the `inherit-product-if-exists` is silently skipped.
- Repo name is `avenger`, but every path and the device tree expect
  `vendor/motorola/marvel`. It must be checked out at that path.
- Latest commit says copy rules for source-built modules were dropped, but there
  are still zero `PRODUCT_PACKAGES`; the tree is half-migrated.
- 675 system_ext files include CQATest, IMS/RCS, and QTI telephony packages.
  These need curation before a vendor image is shipped.

## ROM scaffold in this branch

- `rom/common.mk` — ROM product config, stock-vendor by default.
- `rom/evolution_marvel.mk` — Evolution X product entry point.
- `rom/board.mk` — ROM-only VINTF, props, fstab, sepolicy, and fs config.
- `rom/vintf/` — stock 36-31 manifest, volcano manifest, and compatibility matrix.
- `rom/fstab.qcom` — stock 36-31 first-stage fstab.
- `rom/props/vendor.prop` — generated from stock 36-31 `vendor/build.prop`; build
  metadata and VNDK/API identity omitted.
- `rom/system.prop` — intentionally contains no unverified properties.
- `rom/sepolicy/vendor/`, `rom/config.fs`, `rom/rro_overlays/` — carried from the
  donor tree, reviewed but not runtime-tested.
- RRO UDFPS coordinates rescaled from 1220x2712 to the verified 1272x2772 panel.
- TWRP product (`twrp_marvel.mk`) and `device.mk` are unchanged.

## Still blocked / next phase

1. **vendor_dlkm modules**: **resolved** — 292 stock `.ko` files plus metadata
   were pulled from the device and added to the `rom-ready` vendor branch.
2. **Binary provenance**: **not resolved** — only 1,029 of 1,553 repo `/vendor`
   files match stock; 512 differ and 2,102 stock files are absent. Rebuild the
   vendor tree from the stock `/vendor` contents before a full vendor image.
3. **VINTF merge**: reconcile the 58 vendor fragments with the stock top-level
   manifest before building a vendor image.
4. **UDFPS HBM**: the SystemUI overlay references
   `vendor.lineage.biometrics.udfps.IUdfpsHbm`, but the donor HAL source is not
   part of this tree. Port it or disable the overlay until the HAL is built.
5. **Build/test**: no ROM build has been run. Expect boot, SELinux, camera,
   telephony, and fingerprint work after the first boot.

ADB was not used in this pass.
