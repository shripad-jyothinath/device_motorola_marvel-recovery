#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const repoRoot = path.resolve(__dirname, '..', '..');
const lock = JSON.parse(fs.readFileSync(path.join(__dirname, 'vendor-modules.lock'), 'utf8'));

const args = process.argv.slice(2);
let modulesRoot = null;
let vendorDlkmImage = process.env.VENDOR_DLKM_IMAGE || null;

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--vendor-dlkm-image') {
    vendorDlkmImage = args[++i];
  } else if (!modulesRoot) {
    modulesRoot = args[i];
  } else {
    console.error(`unknown argument: ${args[i]}`);
    process.exit(2);
  }
}

if (!modulesRoot) {
  console.error('usage: node rom/tools/check_vendor_modules.js <modules-repo> [--vendor-dlkm-image <vendor_dlkm_a_stock.img>]');
  process.exit(2);
}

const failures = [];
const ok = (msg) => console.log(`OK   ${msg}`);
const fail = (msg) => {
  failures.push(msg);
  console.log(`FAIL ${msg}`);
};
const finish = () => {
  if (failures.length) {
    console.log('RESULT: FAIL');
    process.exit(1);
  }
  console.log('RESULT: PASS');
  process.exit(0);
};

const tsvPath = path.join(modulesRoot, 'module-info.tsv');
if (!fs.existsSync(tsvPath)) {
  fail(`missing ${tsvPath}`);
  finish();
}

const lines = fs.readFileSync(tsvPath, 'utf8').replace(/\r/g, '').split('\n').filter(Boolean);
const header = lines.shift().split('\t');
const rows = lines.map((line) => {
  const fields = line.split('\t');
  const row = {};
  for (let i = 0; i < header.length; i++) row[header[i]] = fields[i] || '';
  return row;
});

const sets = {};
for (const row of rows) sets[row.set] = (sets[row.set] || 0) + 1;
for (const [set, expected] of Object.entries(lock.modules)) {
  if (sets[set] !== expected) {
    fail(`${set}: expected ${expected} modules, found ${sets[set] || 0}`);
  } else {
    ok(`${set}: ${sets[set]} modules`);
  }
}

const byFile = new Set(rows.map((row) => row.file));
const deviceMk = fs.readFileSync(path.join(repoRoot, 'device.mk'), 'utf8').replace(/\r/g, '');
const deviceLines = deviceMk.split('\n');
const roots = [];
const start = deviceLines.findIndex((line) => line.includes('TW_LOAD_VENDOR_MODULES :='));
if (start < 0) {
  fail('TW_LOAD_VENDOR_MODULES not found in device.mk');
} else {
  for (let i = start; i < deviceLines.length; i++) {
    const raw = deviceLines[i];
    const cleaned = raw.replace(/TW_LOAD_VENDOR_MODULES\s*:=\s*/, '').replace(/\\\s*$/, '').trim();
    if (cleaned) {
      roots.push(...cleaned.split(/\s+/).filter((item) => item.endsWith('.ko')));
    }
    if (!raw.trim().endsWith('\\')) break;
  }
  if (!roots.length) {
    fail('TW_LOAD_VENDOR_MODULES parsed empty');
  } else {
    ok(`device.mk roots: ${roots.length}`);
  }
  for (const root of roots) {
    if (!byFile.has(root)) fail(`device.mk root not in module dump: ${root}`);
  }
}

const depMap = new Map();
for (const set of ['vendor_boot', 'vendor_dlkm']) {
  const depPath = path.join(modulesRoot, set, 'lib', 'modules', 'modules.dep');
  if (!fs.existsSync(depPath)) {
    fail(`missing ${depPath}`);
    continue;
  }
  for (const line of fs.readFileSync(depPath, 'utf8').replace(/\r/g, '').split('\n')) {
    const match = /^(.+?):\s*(.*)$/.exec(line);
    if (!match) continue;
    const key = path.basename(match[1]);
    if (!depMap.has(key)) depMap.set(key, new Set());
    for (const dep of match[2].split(/\s+/).filter(Boolean)) depMap.get(key).add(path.basename(dep));
  }
}

// .modinfo depends is a second source and uses bare names.
for (const row of rows) {
  if (!depMap.has(row.file)) depMap.set(row.file, new Set());
  for (const dep of row.depends.split(',').map((item) => item.trim()).filter(Boolean)) {
    depMap.get(row.file).add(dep.endsWith('.ko') ? dep : `${dep}.ko`);
  }
}

const seen = new Set();
const missing = [];
const walk = (name) => {
  if (seen.has(name)) return;
  seen.add(name);
  if (!byFile.has(name)) {
    missing.push(name);
    return;
  }
  for (const dep of depMap.get(name) || []) walk(dep);
};
for (const root of roots) walk(root);
if (missing.length) {
  fail(`missing dependency closure: ${missing.join(', ')}`);
} else {
  ok(`dependency closure: ${seen.size} modules`);
}

const sha256 = (file) => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
for (const [name, entry] of Object.entries(lock.hashes)) {
  const file = path.join(repoRoot, entry.path);
  if (!fs.existsSync(file)) {
    fail(`${name}: missing ${entry.path}`);
    continue;
  }
  const digest = sha256(file);
  if (digest !== entry.sha256) {
    fail(`${name}: ${digest} != ${entry.sha256}`);
  } else {
    ok(`${name}: ${entry.path}`);
  }
}

if (vendorDlkmImage) {
  if (!fs.existsSync(vendorDlkmImage)) {
    fail(`vendor_dlkm image missing: ${vendorDlkmImage}`);
  } else {
    const digest = sha256(vendorDlkmImage);
    if (digest !== lock.vendor_dlkm_image.sha256) {
      fail(`vendor_dlkm image: ${digest} != ${lock.vendor_dlkm_image.sha256}`);
    } else {
      ok(`vendor_dlkm image: ${vendorDlkmImage}`);
    }
  }
} else {
  console.log('SKIP vendor_dlkm image (pass --vendor-dlkm-image <vendor_dlkm_a_stock.img>)');
}

for (const file of lock.goodix_firmware) {
  if (!fs.existsSync(path.join(repoRoot, file))) fail(`missing firmware: ${file}`);
}
ok(`goodix firmware: ${lock.goodix_firmware.length} files`);

const kernelPath = path.join(repoRoot, lock.hashes.kernel.path);
if (fs.existsSync(kernelPath)) {
  const kernel = fs.readFileSync(kernelPath, 'latin1');
  if (!kernel.includes(lock.kernel.vermagic)) {
    fail(`kernel vermagic not found in ${lock.hashes.kernel.path}`);
  } else {
    ok('kernel vermagic string present');
  }
}

const moduleVermagic = [...new Set(rows.map((row) => row.vermagic))];
if (!moduleVermagic.includes(lock.kernel.vermagic)) {
  console.log(`WARN module vermagic (${moduleVermagic.length} values) does not equal the kernel vermagic; TWRP force-loads them (logcat: goodix modules loaded).`);
}

finish();
