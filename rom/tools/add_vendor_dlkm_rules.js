#!/usr/bin/env node
'use strict';

const fs = require('fs');

const mk = process.argv[2];
const dir = process.argv[3];

const files = fs.readdirSync(dir, { withFileTypes: true })
  .filter(x => x.isFile())
  .map(x => x.name)
  .sort();

if (!files.length) throw new Error('no files in ' + dir);

let out = '\n# Stock A171WEH.36-31 vendor_dlkm modules and metadata, pulled from the device.\n';
out += 'PRODUCT_COPY_FILES += \\\n';
files.forEach((f, i) => {
  const src = 'vendor/motorola/marvel/proprietary/vendor_dlkm/lib/modules/' + f;
  const dst = '$(TARGET_COPY_OUT_VENDOR_DLKM)/lib/modules/' + f;
  out += '    ' + src + ':' + dst + (i < files.length - 1 ? ' \\' : '') + '\n';
});

fs.appendFileSync(mk, out);
console.log('added_files=' + files.length);
