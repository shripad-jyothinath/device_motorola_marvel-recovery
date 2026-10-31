# ROM dependencies and what is still needed

## Ready / pushed

- Device tree: `shripad-jyothinath/device_motorola_marvel-recovery`, branch
  `evox-a17`.
- Vendor tree: `shripad-jyothinath/android_vendor_motorola_avenger`, branch
  `rom-ready`; must be checked out at `vendor/motorola/marvel`.
- Evolution X is the only active ROM target.
- Stock 36-31 VINTF, fstab, and a generated `vendor.prop` are in `rom/`.
- The real stock vendor_dlkm tree is committed on `rom-ready`: 292 `.ko` modules
  plus six metadata files, 298 copy rules.
- Vendor audit: 2,498 rules, 0 duplicate destinations, 0 missing sources.
- Stock super extraction helpers are in `rom/tools/`; the stock `/vendor` hash
  comparison is in `rom/audit/vendor-hash-compare.json`.

## Still needed from you

1. **Evolution X source tree + build server.**
   Roughly 32 GB RAM and 150 GB free disk. Once the source and server are
   available, I can run the first build and report the real errors.

2. **Device test window after the build.**
   Keep a stock firmware backup. Do not relock the bootloader. The first system
   image may require a data wipe, so schedule that deliberately.

## Optional: full vendor image

The vendor repository is not a verified 36-31 vendor image. The stock device
comparison is:

- 1,029 exact matches
- 512 files with different contents
- 12 repo-only files
- 2,102 stock vendor files not in the repo

The default ROM product uses the **stock vendor and vendor_dlkm partitions**, so
this does not block an Evolution X system-only build. A full vendor image would
require rebuilding the vendor tree from the stock `/vendor` contents first.

I pulled the full stock `/vendor` tar over ADB: **1.95 GB**, 3,643 regular files
and 3,415 symlinks. Windows cannot create those symlinks, so it is kept locally
rather than committed as a broken tree. On the build server I can extract it and
regenerate the vendor tree if you want full vendor-image support.

## No longer needed

- ADB: used to pull the stock vendor_dlkm modules and the `/vendor` SHA-256
  manifest.
- EROFS extraction on the host: the device pull avoided it.
