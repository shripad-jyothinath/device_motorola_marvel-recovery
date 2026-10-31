#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

function arg(name, fallback = null) {
  const i = process.argv.indexOf('--' + name);
  return i >= 0 ? process.argv[i + 1] : fallback;
}

const stockHashFile = arg('stock-hash');
const vendorDir = path.resolve(arg('vendor', 'vendor/motorola/marvel'));
const outFile = path.resolve(arg('out', 'rom/audit/vendor-hash-compare.json'));

if (!stockHashFile) {
  console.error('usage: compare_vendor_hashes.js --stock-hash <sha256sum-file> --vendor <vendor-root> --out <json>');
  process.exit(2);
}

const stock = new Map();
for (const line of fs.readFileSync(stockHashFile, 'utf8').split(/\r?\n/)) {
  const m = line.match(/^([0-9a-f]{64})\s+\/vendor\/(.*)$/);
  if (m) stock.set(m[2], m[1]);
}

function walk(dir, base, out) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, base, out);
    else if (entry.isFile()) out.push(path.relative(base, full).replace(/\\/g, '/'));
  }
}

const repoFiles = [];
walk(path.join(vendorDir, 'proprietary', 'vendor'), path.join(vendorDir, 'proprietary', 'vendor'), repoFiles);

const matches = [];
const differences = [];
const missingInStock = [];
for (const rel of repoFiles) {
  const full = path.join(vendorDir, 'proprietary', 'vendor', rel);
  const hash = crypto.createHash('sha256').update(fs.readFileSync(full)).digest('hex');
  if (!stock.has(rel)) {
    missingInStock.push(rel);
  } else if (stock.get(rel) === hash) {
    matches.push(rel);
  } else {
    differences.push({ path: rel, stock: stock.get(rel), repo: hash });
  }
}

const stockOnly = [...stock.keys()].filter(x => !repoFiles.includes(x)).sort();
const result = {
  summary: {
    stockVendorFiles: stock.size,
    vendorRepoFiles: repoFiles.length,
    exactMatches: matches.length,
    different: differences.length,
    repoOnly: missingInStock.length,
    stockOnly: stockOnly.length,
  },
  differences: differences.slice(0, 100),
  repoOnly: missingInStock.slice(0, 100),
  stockOnly: stockOnly.slice(0, 100),
};

fs.mkdirSync(path.dirname(outFile), { recursive: true });
fs.writeFileSync(outFile, JSON.stringify(result, null, 2));
console.log(JSON.stringify(result.summary, null, 2));
console.log('wrote ' + outFile);
