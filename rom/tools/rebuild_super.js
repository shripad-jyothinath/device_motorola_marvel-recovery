#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const srcDir = process.argv[2];
const outPath = process.argv[3];
if (!srcDir || !outPath) {
  console.error('usage: rebuild_super.js <sparsechunk-dir> <out.raw>');
  process.exit(2);
}

const files = [];
for (let i = 0; i < 64; i++) {
  const f = path.join(srcDir, `super.img_sparsechunk.${i}`);
  if (fs.existsSync(f)) files.push(f);
}

const out = fs.openSync(outPath, 'w');
let totalBytes = 0;
let totalBlocks = 0;

for (const file of files) {
  const fd = fs.openSync(file, 'r');
  const hdr = Buffer.alloc(28);
  fs.readSync(fd, hdr, 0, 28, 0);
  const magic = hdr.readUInt32LE(0);
  if (magic !== 0xed26ff3a) throw new Error('bad sparse magic in ' + file);
  const blk = hdr.readUInt32LE(12);
  const blocks = hdr.readUInt32LE(16);
  const chunks = hdr.readUInt32LE(20);
  const fileHdr = hdr.readUInt16LE(8);
  const chunkHdr = hdr.readUInt16LE(10);
  let fileOff = fileHdr;
  let outBlock = 0;
  totalBlocks = blocks;

  for (let i = 0; i < chunks; i++) {
    const ch = Buffer.alloc(chunkHdr);
    fs.readSync(fd, ch, 0, chunkHdr, fileOff);
    const type = ch.readUInt16LE(0);
    const chunkBlocks = ch.readUInt32LE(4);
    const totalSize = ch.readUInt32LE(8);
    const outOffset = outBlock * blk;

    if (type === 0xcac1) {
      const data = Buffer.alloc(chunkBlocks * blk);
      fs.readSync(fd, data, 0, data.length, fileOff + chunkHdr);
      fs.writeSync(out, data, 0, data.length, outOffset);
      outBlock += chunkBlocks;
    } else if (type === 0xcac2) {
      const fill = ch.subarray(12, 16);
      const data = Buffer.alloc(chunkBlocks * blk);
      for (let p = 0; p < data.length; p += 4) fill.copy(data, p, 0, 4);
      fs.writeSync(out, data, 0, data.length, outOffset);
      outBlock += chunkBlocks;
    } else if (type === 0xcac3) {
      outBlock += chunkBlocks;
    } else if (type === 0xcac4) {
      // CRC chunk; no output blocks
    } else {
      throw new Error('unknown sparse chunk type 0x' + type.toString(16) + ' in ' + file);
    }

    fileOff += totalSize;
  }

  fs.closeSync(fd);
  if (outBlock !== blocks) {
    console.log(path.basename(file) + ': outBlocks=' + outBlock + ' expected=' + blocks);
  } else {
    console.log(path.basename(file) + ': ' + outBlock + ' blocks');
  }
}

totalBytes = totalBlocks * 4096;
fs.ftruncateSync(out, totalBytes);
fs.closeSync(out);
console.log('files=' + files.length + ' blocks=' + totalBlocks + ' bytes=' + totalBytes + ' GB=' + (totalBytes / 1e9).toFixed(2));
console.log('wrote ' + outPath);
