#!/usr/bin/env node
'use strict';

// Remove later PRODUCT_COPY_FILES entries that duplicate a destination already
// copied by an earlier rule. The first occurrence wins.
//
// Usage:
//   node rom/tools/dedupe_vendor_makefile.js \
//     --file vendor/motorola/marvel/marvel-vendor.mk \
//     --out /tmp/marvel-vendor.mk

const fs = require('fs');

function arg(name, fallback = null) {
  const i = process.argv.indexOf('--' + name);
  return i >= 0 ? process.argv[i + 1] : fallback;
}

const file = arg('file');
const out = arg('out', '/tmp/marvel-vendor.mk');
if (!file) {
  console.error('usage: dedupe_vendor_makefile.js --file <marvel-vendor.mk> --out <cleaned.mk>');
  process.exit(2);
}

const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);
const ruleRe = /^\s*(vendor\/motorola\/marvel\/proprietary\/[^:\s]+):(\$\(TARGET_COPY_OUT_[A-Z_]+\)\/[^\\\s]+)\s*\\?\s*$/;
const seen = new Set();
const kept = [];
let removed = 0;

for (const line of lines) {
  if (/^\s*#/.test(line)) {
    kept.push(line);
    continue;
  }
  const m = line.match(ruleRe);
  if (!m) {
    kept.push(line);
    continue;
  }
  const dst = m[2];
  if (seen.has(dst)) {
    removed++;
    continue;
  }
  seen.add(dst);
  kept.push(line);
}

fs.writeFileSync(out, kept.join('\n'));
console.log('removed=' + removed + ' kept=' + (lines.length - removed) + ' out=' + out);
