# ROM bring-up — Motorola Edge 70 Fusion (`marvel`)

This branch (`evox-a17`) keeps the TWRP product untouched and adds a separate
ROM-side scaffold. The recovery product is still `twrp_marvel.mk`; the only
active ROM product is `evolution_marvel`.

## What is active

- Stock 36-31 `vendor` and `vendor_dlkm` partitions by default. No vendor image
  is rebuilt.
- Stock `manifest.xml`, `manifest_volcano.xml`, `compatibility_matrix.xml`, and
  first-stage `fstab.qcom`.
- `rom/props/vendor.prop` generated from stock `vendor/build.prop`.
- Donor sepolicy, `config.fs`, and RRO overlays; UDFPS coordinates rescaled to
  1272x2772.
- ROM board config is only included for `evolution_marvel`.

Read `rom/AUDIT.md` first. It records the vendor-tree audit, the donor
cross-checks, and the still-missing pieces.

## Build

Use an Evolution X source tree. Evolution X is the only active ROM target;
LineageOS is not supported in this branch. Put this repository at
`device/motorola/marvel` and apply `rom/local_manifest.xml` if you use `repo`.
Read `rom/DEPENDENCIES.md` for the current blockers.

```sh
source build/envsetup.sh
lunch evolution_marvel-userdebug
mka bacon
```

The default build uses the stock vendor partitions. Do **not** flash a vendor
image: the vendor repository still has 512 files that differ from stock and 2,102
stock files missing. Rebuild the vendor tree from the stock `/vendor` contents
before enabling a vendor image.

## Optional full vendor image

The vendor repository is `shripad-jyothinath/android_vendor_motorola_avenger`,
but it must be checked out at `vendor/motorola/marvel` on the `rom-ready`
branch:

```sh
git clone --depth 1 -b rom-ready \
  https://github.com/shripad-jyothinath/android_vendor_motorola_avenger.git \
  vendor/motorola/marvel
```

The `rom-ready` branch already has the 23 duplicate rules removed and the real
292 vendor_dlkm modules committed. Do not enable the vendor-image flag: the
stock `/vendor` hash comparison still shows 512 different files and 2,102
missing stock files.

```sh
node rom/tools/dedupe_vendor_makefile.js \
  --file vendor/motorola/marvel/marvel-vendor.mk \
  --out /tmp/marvel-vendor.mk
# rom-ready should report removed=0.
```

Do not enable this mode until `rom/AUDIT.md` items 2-3 are resolved. The vendor
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
