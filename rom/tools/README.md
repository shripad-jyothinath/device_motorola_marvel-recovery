# ROM tools

These are static/offline helpers used to audit and unpack the stock firmware.

## `audit_vendor.js`

Parses every `PRODUCT_COPY_FILES` rule in the vendor makefile, verifies source
existence, duplicate destinations, ELF class/machine, ZIP containers, and
cross-checks props, fstab, modules, and VINTF against stock 36-31 inputs.

## `dedupe_vendor_makefile.js`

Keeps the first copy rule per destination and drops later exact duplicates.

```sh
node rom/tools/dedupe_vendor_makefile.js \
  --file vendor/motorola/marvel/marvel-vendor.mk \
  --out /tmp/marvel-vendor.mk
```

## `add_vendor_dlkm_rules.js`

Generates the `$(TARGET_COPY_OUT_VENDOR_DLKM)` copy rules for every file in a
pulled vendor_dlkm module directory.

## `compare_vendor_hashes.js`

Compares a stock `sha256sum` manifest of `/vendor` with the vendor repository.
It reports exact matches, differing files, repo-only files, and stock-only files.

## `rebuild_super.js`

Reconstructs `super.raw` from the Motorola RSA `super.img_sparsechunk.0..25`
files. The chunks use DONT_CARE padding to preserve their offsets.

```sh
node rom/tools/rebuild_super.js /path/to/RomFiles/super.img_sparsechunk-dir super.raw
```

## `extract_lp.js`

Lists or extracts logical partitions from the raw super image.

```sh
node rom/tools/extract_lp.js super.raw --list
node rom/tools/extract_lp.js super.raw vendor_dlkm_a vendor_dlkm.img
```

The extracted vendor and vendor_dlkm images are EROFS. Use `fsck.erofs
--extract` on Linux/Android (or ADB) to read their file trees; 7-Zip does not
support EROFS.
