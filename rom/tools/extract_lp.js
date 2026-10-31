#!/usr/bin/env node
'use strict';

const fs = require('fs');

const superPath = process.argv[2];
const partitionName = process.argv[3];
const outPath = process.argv[4];

if (!superPath) {
  console.error('usage: extract_lp.js <super.raw> --list | <partition> <out.img>');
  process.exit(2);
}

const fd = fs.openSync(superPath, 'r');
const head = Buffer.alloc(65536);
fs.readSync(fd, head, 0, head.length, 0);

const geomOff = 4096;
if (head.readUInt32LE(geomOff) !== 0x616c4467) throw new Error('no LP geometry');
const metadataMax = head.readUInt32LE(geomOff + 40);
const metadataSlotCount = head.readUInt32LE(geomOff + 44);
const logicalBlock = head.readUInt32LE(geomOff + 48);

// The first metadata slot starts after the reserved area + geometry + one
// geometry-sized gap; the magic scan below confirms the actual offset.
let metaOff = -1;
for (let off = 8192; off < 8192 + metadataMax; off += 4096) {
  if (head.readUInt32LE(off) === 0x414c5030) { metaOff = off; break; }
}
if (metaOff < 0) {
  for (let off = 0; off < head.length - 4; off++) {
    if (head.readUInt32LE(off) === 0x414c5030) { metaOff = off; break; }
  }
}
if (metaOff < 0) throw new Error('no LP metadata header');

const hdr = Buffer.alloc(256);
fs.readSync(fd, hdr, 0, 256, metaOff);
const headerSize = hdr.readUInt32LE(8);
const tablesSize = hdr.readUInt32LE(44);
const tables = Buffer.alloc(tablesSize);
fs.readSync(fd, tables, 0, tablesSize, metaOff + headerSize);

function desc(index) {
  const off = 80 + index * 12;
  return {
    offset: hdr.readUInt32LE(off),
    count: hdr.readUInt32LE(off + 4),
    size: hdr.readUInt32LE(off + 8),
  };
}

const pd = desc(0);
const ed = desc(1);
const partitions = [];
for (let i = 0; i < pd.count; i++) {
  const base = pd.offset + i * pd.size;
  const name = tables.subarray(base, base + 36).toString('utf8').replace(/\0.*$/, '');
  const firstExtent = tables.readUInt32LE(base + 40);
  const numExtents = tables.readUInt32LE(base + 44);
  const extents = [];
  let sectors = 0;
  for (let j = 0; j < numExtents; j++) {
    const eb = ed.offset + (firstExtent + j) * ed.size;
    const numSectors = Number(tables.readBigUInt64LE(eb));
    const targetType = tables.readUInt32LE(eb + 8);
    const targetData = Number(tables.readBigUInt64LE(eb + 12));
    extents.push({ numSectors, targetType, targetData });
    sectors += numSectors;
  }
  partitions.push({ name, sectors, extents, bytes: sectors * 512 });
}

if (!partitionName || partitionName === '--list') {
  for (const p of partitions) {
    console.log(p.name + ' ' + (p.bytes / 1024 / 1024).toFixed(1) + ' MB extents=' + p.extents.length);
  }
  fs.closeSync(fd);
  process.exit(0);
}

const target = partitions.find(p => p.name === partitionName);
if (!target) {
  console.error('partition not found: ' + partitionName);
  fs.closeSync(fd);
  process.exit(3);
}
if (!outPath) {
  console.error('missing output path');
  fs.closeSync(fd);
  process.exit(2);
}

const out = fs.openSync(outPath, 'w');
let outOffset = 0;
const chunkSize = 4 * 1024 * 1024;
for (const ext of target.extents) {
  const bytes = ext.numSectors * 512;
  if (ext.targetType === 1) {
    const zero = Buffer.alloc(Math.min(chunkSize, bytes));
    for (let p = 0; p < bytes; p += zero.length) {
      fs.writeSync(out, zero, 0, Math.min(zero.length, bytes - p), outOffset + p);
    }
  } else if (ext.targetType === 0) {
    let srcOffset = ext.targetData * 512;
    let left = bytes;
    const buf = Buffer.alloc(Math.min(chunkSize, bytes));
    while (left > 0) {
      const n = Math.min(buf.length, left);
      fs.readSync(fd, buf, 0, n, srcOffset);
      fs.writeSync(out, buf, 0, n, outOffset);
      srcOffset += n;
      outOffset += n;
      left -= n;
    }
    continue;
  } else {
    throw new Error('unknown extent target type ' + ext.targetType);
  }
  outOffset += bytes;
}
fs.ftruncateSync(out, target.bytes);
fs.closeSync(out);
fs.closeSync(fd);
console.log('extracted ' + partitionName + ' ' + (target.bytes / 1024 / 1024).toFixed(1) + ' MB -> ' + outPath);
