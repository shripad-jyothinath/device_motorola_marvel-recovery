# ROM bring-up audit — Motorola Edge 70 Fusion (`marvel`)

Branch: `rom-base`
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

Because of this, the default ROM product uses the **stock vendor and stock
vendor_dlkm partitions**. The vendor repo is only used when
`MARVEL_BUILD_VENDOR_IMAGE=true`, and only after the provenance/gap issues below
are resolved.

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
- The donor `modules.load` lists **310**; **149** are not in vendor_boot and therefore belong to **vendor_dlkm**.
- The vendor repository contains **0 `.ko`** files.
- The donor `modules.load.vendor_boot` covers all 294 vendor_boot modules, so the split is understood. The actual 149 vendor_dlkm `.ko` files are still missing.

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
- `rom/evolution_marvel.mk`, `rom/lineage_marvel.mk` — product entry points.
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

1. **vendor_dlkm modules**: pull the 149 missing `.ko` files from stock
   `/vendor_dlkm/lib/modules` (or from a stock `vendor_dlkm` image). This needs
   device ADB or a firmware image that was not extracted here.
2. **Binary provenance**: hash stock `/vendor` files against the vendor repo if a
   full vendor image is wanted.
3. **VINTF merge**: reconcile the 58 vendor fragments with the stock top-level
   manifest before building a vendor image.
4. **UDFPS HBM**: the SystemUI overlay references
   `vendor.lineage.biometrics.udfps.IUdfpsHbm`, but the donor HAL source is not
   part of this tree. Port it or disable the overlay until the HAL is built.
5. **Build/test**: no ROM build has been run. Expect boot, SELinux, camera,
   telephony, and fingerprint work after the first boot.

ADB was not used in this pass.
