#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

function arg(name, fallback = null) {
  const i = process.argv.indexOf('--' + name);
  return i >= 0 ? process.argv[i + 1] : fallback;
}

const vendorRoot = path.resolve(arg('vendor', 'vendor/motorola/marvel'));
const stockVendor = path.resolve(arg('stock-vendor', ''));
const stockFw = path.resolve(arg('stock-fw', ''));
const donor = path.resolve(arg('donor', ''));
const outFile = path.resolve(arg('out', 'rom/audit/vendor-audit.json'));

function readText(file) {
  try { return fs.readFileSync(file, 'utf8'); } catch { return ''; }
}

function readFirst(file, count) {
  try {
    const fd = fs.openSync(file, 'r');
    const buf = Buffer.alloc(count);
    const n = fs.readSync(fd, buf, 0, count, 0);
    fs.closeSync(fd);
    return buf.subarray(0, n);
  } catch {
    return Buffer.alloc(0);
  }
}

function listFiles(dir, filter = null) {
  const out = [];
  try {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) out.push(...listFiles(full, filter));
      else if (!filter || filter(full)) out.push(full);
    }
  } catch {}
  return out;
}

function parseProps(text) {
  const map = new Map();
  for (const line of text.split(/\r?\n/)) {
    if (!line || /^\s*#/.test(line)) continue;
    const idx = line.indexOf('=');
    if (idx <= 0) continue;
    map.set(line.slice(0, idx).trim(), line.slice(idx + 1).trim());
  }
  return map;
}

function parseFstab(text) {
  const map = new Map();
  for (const line of text.split(/\r?\n/)) {
    if (!line || /^\s*#/.test(line)) continue;
    const cols = line.trim().split(/\s+/);
    if (cols.length < 3) continue;
    map.set(cols[1], { type: cols[2], options: cols[3] || '', flags: cols.slice(4).join(' ') });
  }
  return map;
}

function parseList(text, suffix = null) {
  const out = [];
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    let value = line.split(';')[0].trim();
    value = value.replace(/\|.*$/, '').trim();
    if (!value) continue;
    if (suffix && !value.endsWith(suffix)) continue;
    out.push(value);
  }
  return out;
}

const makefilePath = path.join(vendorRoot, 'marvel-vendor.mk');
const makefile = readText(makefilePath);
const lines = makefile.split(/\r?\n/);
const ruleRe = /^\s*(vendor\/motorola\/marvel\/proprietary\/[^:\s]+):(\$\(TARGET_COPY_OUT_[A-Z_]+\)\/[^\\\s]+)\s*\\?\s*$/;

const rules = [];
const malformed = [];
const destMap = new Map();
const exactMap = new Map();
const partitionCounts = {};

for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  if (/^\s*#/.test(line)) continue;
  if (!line.includes('proprietary/') || !line.includes('TARGET_COPY_OUT_')) continue;

  const m = line.match(ruleRe);
  if (!m) {
    malformed.push({ line: i + 1, text: line.trim() });
    continue;
  }

  const src = m[1];
  const dst = m[2];
  const rel = src.replace(/^vendor\/motorola\/marvel\//, '');
  const abs = path.join(vendorRoot, rel);
  let stat = null;
  let exists = false;
  let isSymlink = false;
  try {
    stat = fs.lstatSync(abs);
    exists = true;
    isSymlink = stat.isSymbolicLink();
  } catch {}

  const ext = path.extname(abs).toLowerCase();
  const elf = readFirst(abs, 20);
  const isElf = elf.length >= 20 && elf[0] === 0x7f && elf[1] === 0x45 && elf[2] === 0x4c && elf[3] === 0x46;
  const zipSig = readFirst(abs, 4);
  const isZip = zipSig.length >= 4 && zipSig[0] === 0x50 && zipSig[1] === 0x4b;

  const rule = {
    line: i + 1,
    src,
    dst,
    exists,
    size: exists ? stat.size : 0,
    symlink: isSymlink,
    ext,
    elf: isElf ? { class: elf[4], machine: elf.readUInt16LE(18) } : null,
    zip: isZip,
  };
  rules.push(rule);

  const partMatch = dst.match(/^\$\((TARGET_COPY_OUT_[A-Z_]+)\)/);
  if (partMatch) partitionCounts[partMatch[1]] = (partitionCounts[partMatch[1]] || 0) + 1;

  if (!destMap.has(dst)) destMap.set(dst, []);
  destMap.get(dst).push(rule);

  const exact = src + ' -> ' + dst;
  exactMap.set(exact, (exactMap.get(exact) || 0) + 1);
}

const duplicateDestinations = [...destMap.entries()]
  .filter(([, list]) => list.length > 1)
  .map(([dst, list]) => ({ dst, count: list.length, lines: list.map(r => r.line), sources: list.map(r => r.src) }));
const duplicateExact = [...exactMap.entries()]
  .filter(([, count]) => count > 1)
  .map(([pair, count]) => ({ pair, count }));

const missing = rules.filter(r => !r.exists);
const nonRegular = rules.filter(r => r.exists && r.symlink);
const elfRules = rules.filter(r => r.elf);
const elf64 = elfRules.filter(r => r.elf.class === 2);
const elfAarch64 = elfRules.filter(r => r.elf.machine === 183);
const zipRules = rules.filter(r => r.zip);
const apkRules = rules.filter(r => r.ext === '.apk');
const jarRules = rules.filter(r => r.ext === '.jar');
const xmlRules = rules.filter(r => r.ext === '.xml');

const srcSet = new Set(rules.map(r => r.src.replace(/^vendor\/motorola\/marvel\/proprietary\//, '')));
const donorListPath = path.join(donor, 'proprietary-files.txt');
const donorList = parseList(readText(donorListPath));
const donorSet = new Set(donorList);
const donorOnly = donorList.filter(x => !srcSet.has(x));
const vendorOnly = [...srcSet].filter(x => !donorSet.has(x)).sort();

const stockProp = parseProps(readText(path.join(stockVendor, 'build.prop')));
const donorProp = parseProps(readText(path.join(donor, 'vendor.prop')));
const propChanged = [];
const propMissingFromStock = [];
for (const [key, value] of donorProp) {
  if (!stockProp.has(key)) propMissingFromStock.push(key);
  else if (stockProp.get(key) !== value) propChanged.push({ key, donor: value, stock: stockProp.get(key) });
}

const stockFstabText = readText(path.join(stockFw, 'vendor_boot', 'ramdisk_ramdisk0', 'first_stage_ramdisk', 'fstab.qcom'));
const donorFstabText = readText(path.join(donor, 'rootdir', 'etc', 'fstab.qcom'));
const stockFstab = parseFstab(stockFstabText);
const donorFstab = parseFstab(donorFstabText);
const fstabDiff = [];
for (const [mount, entry] of donorFstab) {
  const stock = stockFstab.get(mount);
  if (!stock) fstabDiff.push({ mount, problem: 'not in stock', donorType: entry.type });
  else if (stock.type !== entry.type) fstabDiff.push({ mount, problem: 'type', donorType: entry.type, stockType: stock.type });
}

const stockModulesDir = path.join(stockFw, 'vendor_boot', 'ramdisk_ramdisk0', 'lib', 'modules');
const stockKo = listFiles(stockModulesDir, f => f.endsWith('.ko')).map(f => path.basename(f));
const donorModuleLoad = parseList(readText(path.join(donor, 'modules.load')), '.ko');
const stockModuleLoad = parseList(readText(path.join(stockModulesDir, 'modules.load')), '.ko');
const donorVendorBootLoad = parseList(readText(path.join(donor, 'modules.load.vendor_boot')), '.ko');
const donorModulesMissingFromVendorBoot = donorModuleLoad.filter(x => !stockKo.includes(x));
const stockLoadMissingFromDonor = stockModuleLoad.filter(x => !donorVendorBootLoad.includes(x));
const vendorKo = listFiles(path.join(vendorRoot, 'proprietary'), f => f.endsWith('.ko')).length;

const stockManifestDir = path.join(stockVendor, 'etc', 'vintf');
const vendorVintfDir = path.join(vendorRoot, 'proprietary', 'vendor', 'etc', 'vintf');
const vendorVintfTop = listFiles(vendorVintfDir, f => path.dirname(f) === vendorVintfDir);
const vendorFragments = listFiles(path.join(vendorVintfDir, 'manifest'), f => f.endsWith('.xml'));
const systemExtVintfDir = path.join(vendorRoot, 'proprietary', 'system_ext', 'etc', 'vintf');
const systemExtFragments = listFiles(systemExtVintfDir, f => f.endsWith('.xml'));
// The stock vendor has no top-level manifest.xml. Its primary manifest is
// manifest_volcano.xml and the rest of the HAL set is in the fragments under
// <vendor>/etc/vintf/manifest/. Collect both when comparing HAL coverage.
const stockManifestText = readText(path.join(stockManifestDir, 'manifest_volcano.xml'));
const stockManifestFragments = listFiles(path.join(stockManifestDir, 'manifest'), f => f.endsWith('.xml'));
const stockManifestHalNames = new Set();
for (const text of [stockManifestText, ...stockManifestFragments.map(readText)]) {
  for (const m of text.matchAll(/<name>([^<]+)<\/name>/g)) stockManifestHalNames.add(m[1]);
}
const vendorTopManifests = vendorVintfTop.filter(
  f => /^manifest.*\.xml$/.test(path.basename(f)));
const vendorHalNames = new Set();
for (const file of [...vendorTopManifests, ...vendorFragments, ...systemExtFragments]) {
  for (const m of readText(file).matchAll(/<name>([^<]+)<\/name>/g)) vendorHalNames.add(m[1]);
}

const summary = {
  generatedAt: new Date().toISOString(),
  vendorMakefile: 'vendor/motorola/marvel/marvel-vendor.mk',
  makefileLines: lines.length,
  copyRules: rules.length,
  malformedRuleLines: malformed.length,
  missingSources: missing.length,
  nonRegularSources: nonRegular.length,
  duplicateDestinationGroups: duplicateDestinations.length,
  duplicateExtraEntries: duplicateDestinations.reduce((n, d) => n + d.count - 1, 0),
  duplicateExactPairs: duplicateExact.length,
  partitionCounts,
  elfRules: elfRules.length,
  elf64: elf64.length,
  elfAarch64: elfAarch64.length,
  zipRules: zipRules.length,
  apkRules: apkRules.length,
  jarRules: jarRules.length,
  xmlRules: xmlRules.length,
  donorListEntries: donorList.length,
  donorOnlyEntries: donorOnly.length,
  vendorOnlyEntries: vendorOnly.length,
  stockPropCount: stockProp.size,
  donorPropCount: donorProp.size,
  donorPropChanged: propChanged.length,
  donorPropMissingFromStock: propMissingFromStock.length,
  stockFstabMounts: stockFstab.size,
  donorFstabMounts: donorFstab.size,
  fstabDiff: fstabDiff.length,
  stockVendorBootModules: stockKo.length,
  donorModulesListed: donorModuleLoad.length,
  donorModulesMissingFromVendorBoot: donorModulesMissingFromVendorBoot.length,
  stockLoadMissingFromDonor: stockLoadMissingFromDonor.length,
  vendorKo,
  vendorVintfTopLevelFiles: vendorVintfTop.length,
  vendorVintfFragments: vendorFragments.length,
  systemExtVintfFragments: systemExtFragments.length,
  stockManifestHalNames: stockManifestHalNames.size,
  vendorHalNames: vendorHalNames.size,
};

const result = {
  summary,
  duplicateDestinations,
  duplicateExact,
  missing,
  nonRegular,
  malformed,
  donorList: { donorOnly: donorOnly.slice(0, 50), vendorOnly: vendorOnly.slice(0, 50), donorOnlyCount: donorOnly.length, vendorOnlyCount: vendorOnly.length },
  props: { changed: propChanged.slice(0, 50), missingFromStock: propMissingFromStock.slice(0, 50), changedCount: propChanged.length, missingCount: propMissingFromStock.length },
  fstab: { differences: fstabDiff.slice(0, 50), differenceCount: fstabDiff.length },
  modules: {
    vendorBootCount: stockKo.length,
    donorListedCount: donorModuleLoad.length,
    missingFromVendorBoot: donorModulesMissingFromVendorBoot.slice(0, 100),
    missingFromVendorBootCount: donorModulesMissingFromVendorBoot.length,
    stockLoadMissingFromDonor: stockLoadMissingFromDonor.slice(0, 100),
    stockLoadMissingFromDonorCount: stockLoadMissingFromDonor.length,
    vendorRepoKoCount: vendorKo,
  },
  vintf: {
    topLevelFiles: vendorVintfTop.map(f => path.basename(f)),
    fragmentCount: vendorFragments.length,
    systemExtFragmentCount: systemExtFragments.length,
    stockManifestHalNames: [...stockManifestHalNames].sort(),
    vendorHalNames: [...vendorHalNames].sort(),
    missingTopLevelManifest: vendorVintfTop.length === 0,
  },
  rules,
};

fs.mkdirSync(path.dirname(outFile), { recursive: true });
fs.writeFileSync(outFile, JSON.stringify(result, null, 2));
console.log(JSON.stringify(summary, null, 2));
console.log('wrote ' + outFile);
