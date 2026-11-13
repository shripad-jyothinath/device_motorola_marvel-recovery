#!/bin/bash
# Legacy /vendor overlay is retired.
#
# The stock vendor tree is used instead. Installing this overlay hides the
# stock /vendor/etc/init files (including the KeyMint rc) and resurrects the
# Boot 54 hwservicemanager workaround. The script is kept only as a guard so
# an old command fails loudly instead of silently installing the overlay.
echo "ERROR: stage_vendor_overlay.sh is retired; use the source vendor tree" >&2
exit 1
