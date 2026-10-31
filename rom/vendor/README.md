# Vendor repository — read before enabling

Repository: `shripad-jyothinath/android_vendor_motorola_avenger`
Required checkout path: `vendor/motorola/marvel`
Branch: `rom-ready`

The repository name is legacy (`avenger`), but every path in
`marvel-vendor.mk` uses `vendor/motorola/marvel`. Cloning it anywhere else
breaks all copy rules.

The `rom-ready` branch already removes the 23 duplicate destination rules, adds
the stock 36-31 top-level VINTF and first-stage fstab, and commits the real stock
vendor_dlkm tree: **292 `.ko` modules** plus six metadata files. The audit result
is `rom/audit/vendor-audit-rom-ready.json`.

The stock-vs-repo `/vendor` comparison is still negative: 1,029 exact matches,
512 different files, 12 repo-only, and 2,102 stock-only. Do not build a full
vendor image from this tree; the ROM uses the stock vendor partition.

A full 1.95 GB stock `/vendor` tar was pulled over ADB (3,643 regular files,
3,415 symlinks). Windows cannot materialize the symlinks, so it is kept for a
Linux-server rebuild rather than committed as a broken tree.

## Audit first

`rom/tools/audit_vendor.js` parses every copy rule and checks source existence,
duplicates, ELF class/machine, ZIP containers, props, fstab, modules, and VINTF
coverage. The committed result is `rom/audit/vendor-audit.json`.

```sh
node rom/tools/audit_vendor.js \
  --vendor vendor/motorola/marvel \
  --stock-vendor /path/to/stock/vendor31 \
  --stock-fw /path/to/stock/fw31 \
  --donor /path/to/old/device/tree \
  --out rom/audit/vendor-audit.json
```

## Clean duplicates

The `rom-ready` branch has no duplicate destinations. The dedupe tool is kept for
verification and for the old `evox-a17` branch:

```sh
node rom/tools/dedupe_vendor_makefile.js \
  --file vendor/motorola/marvel/marvel-vendor.mk \
  --out /tmp/marvel-vendor.mk
```

Review the diff and replace the makefile only after the audit passes.

## Do not trust it yet

- The path list exactly matches the old `roadstr W1WRS36.39-25-2-1` donor list.
- The donor `vendor.prop` has six changed values and 48 properties missing from
  the stock 36-31 build.prop; the donor `system_ext.prop`, `odm.prop`, and
  `product.prop` are explicitly SM7750/sun, not volcano.
- The vendor repo has no top-level VINTF manifest, no `build.prop`, and no
  `vendor_dlkm` kernel modules.
- 149 modules from the donor list are not in stock vendor_boot and must come
  from stock vendor_dlkm.

Keep `MARVEL_BUILD_VENDOR_IMAGE` unset until those are resolved.
