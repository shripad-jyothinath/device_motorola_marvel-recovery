# ROM dependencies and what is still needed

## Ready / pushed

- Device tree: `shripad-jyothinath/device_motorola_marvel-recovery`, branch
  `evox-a17` (this branch).
- Vendor tree: `shripad-jyothinath/android_vendor_motorola_avenger`, branch
  `rom-ready`; must be checked out at `vendor/motorola/marvel`.
- Stock 36-31 VINTF, fstab, and a generated `vendor.prop` are in `rom/`.
- Vendor makefile is deduped from 2,219 to 2,200 copy rules; 0 missing sources,
  0 duplicate destinations.
- Stock ROM extraction helpers are in `rom/tools/`:
  - `rebuild_super.js` reconstructs the 23.62 GB raw super from the RSA sparse
    chunks.
  - `extract_lp.js` extracts logical partitions from the raw super.

## Still needed from you

1. **ADB (preferred) or a Linux/WSL EROFS extractor.**
   The stock `vendor_dlkm_a` image is 23.7 MB of **EROFS**, not ext4. Windows
   7-Zip misreads it. I need one of:
   - ADB access with the device in Android or TWRP, so I can pull
     `/vendor_dlkm/lib/modules` directly; or
   - a Linux/WSL environment with `erofs-utils` (`fsck.erofs --extract`), or a
     Windows EROFS extractor.

   This is the only missing piece for the 149 vendor_dlkm modules.

   If ADB is available, the exact pull is:

   ```sh
   adb shell ls -l /vendor_dlkm/lib/modules
   adb pull /vendor_dlkm/lib/modules rom/stock-vendor-dlkm-modules
   ```

   In TWRP, mount `vendor_dlkm` first if it is not already mounted.

2. **Choose the ROM target.**
   Evolution X (`evox-a17`, matching the vendor branch) is the default. Confirm
   if you want LineageOS instead.

3. **Build server.**
   A ROM build needs roughly 32 GB RAM and 150 GB free disk; the hosted runner
   numbers in the recovery README are not enough. If you provide the server, I
   can run the first build and return the actual errors.

4. **Device test window.**
   First boot needs the device, a stock firmware backup, and a willingness to
   wipe data if the first system image does not boot. Do not relock the
   bootloader.

## Optional but valuable

- A full stock vendor image hash manifest (or ADB access to `/vendor`) lets me
  prove whether the 830 MB vendor blob set is actually 36-31 rather than the old
  `roadstr W1WRS36...` list.
- A complete `vendor_dlkm` image, if you have one separate from the super chunks.

## What is already known to be blocked

- The vendor repo has no top-level VINTF/fstab before `rom-ready`; fixed.
- 149 donor module names are not in stock vendor_boot; they are in vendor_dlkm.
- The vendor repo has 0 `.ko` files and no `build.prop`.
- The stock vendor and vendor_dlkm partitions are EROFS.
