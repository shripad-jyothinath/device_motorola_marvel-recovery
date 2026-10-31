# ROM bring-up — Motorola Edge 70 Fusion (`marvel`)

This branch (`rom-base`) keeps the TWRP product untouched and adds a separate
ROM-side scaffold. The recovery product is still `twrp_marvel.mk`; the ROM
products are `evolution_marvel` and `lineage_marvel`.

## What is active

- Stock 36-31 `vendor` and `vendor_dlkm` partitions by default. No vendor image
  is rebuilt.
- Stock `manifest.xml`, `manifest_volcano.xml`, `compatibility_matrix.xml`, and
  first-stage `fstab.qcom`.
- `rom/props/vendor.prop` generated from stock `vendor/build.prop`.
- Donor sepolicy, `config.fs`, and RRO overlays; UDFPS coordinates rescaled to
  1272x2772.
- ROM board config is only included for `evolution_marvel` / `lineage_marvel`.

Read `rom/AUDIT.md` first. It records the vendor-tree audit, the donor
cross-checks, and the still-missing pieces.

## Build

Use an Evolution X or LineageOS source tree. Put this repository at
`device/motorola/marvel`.

```sh
source build/envsetup.sh

# Evolution X
lunch evolution_marvel-userdebug
# or LineageOS
lunch lineage_marvel-userdebug

mka bacon
```

The default build uses the stock vendor partitions. Do **not** flash a vendor
image unless you have completed the vendor audit and extracted the missing
vendor_dlkm modules.

## Optional full vendor image

The vendor repository is `shripad-jyothinath/android_vendor_motorola_avenger`,
but it must be checked out at `vendor/motorola/marvel`:

```sh
git clone --depth 1 -b evox-a17 \
  https://github.com/shripad-jyothinath/android_vendor_motorola_avenger.git \
  vendor/motorola/marvel
```

Then remove the 23 duplicate copy rules and set the vendor-image flag:

```sh
node rom/tools/dedupe_vendor_makefile.js \
  --file vendor/motorola/marvel/marvel-vendor.mk \
  --out /tmp/marvel-vendor.mk
# Replace the vendor makefile only after reviewing the diff.
export MARVEL_BUILD_VENDOR_IMAGE=true
```

Do not enable this mode until `rom/AUDIT.md` items 1-3 are resolved. The vendor
blob list matches the old `roadstr W1WRS36...` donor list, not a verified 36-31
vendor dump.

## Device safety

- Recovery-only changes remain safe; ROM flashing touches boot/vbmeta/super.
- Back up stock boot, init_boot, vendor_boot, dtbo, vbmeta, and super images
  before flashing.
- Do not relock the bootloader. Relocking with custom images wipes userdata and
  can leave the device unbootable.
- Do not format userdata during bring-up.

No ROM build or device boot test has been performed yet.
