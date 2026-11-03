// Derive the Deploy variant from the existing vector brand, preserving Helper.
// Usage: node build-deploy-icon.cjs <absolute path to bundled sharp package>
const fs = require('fs');
const path = require('path');
const sharp = require(process.argv[2]);
const root = path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'flutter/assets/icon.svg'), 'utf8');
const svg = source.replace('SubnetDesk application icon', 'SubnetDesk Deploy application icon')
  .replace('</svg>', `<g stroke-linecap="round" stroke-linejoin="round">
    <circle cx="810" cy="226" r="148" fill="#F6B94A" stroke="#0B1F33" stroke-width="24"/>
    <path d="M810 139v119m-47-43 47 47 47-47M743 281v30h134v-30" fill="none" stroke="#0B1F33" stroke-width="25"/>
  </g></svg>`);
async function main() {
  fs.writeFileSync(path.join(root, 'flutter/assets/deploy_icon.svg'), svg);
  await sharp(Buffer.from(svg)).resize(256, 256).png().toFile(path.join(root, 'flutter/assets/deploy_icon.png'));
  const sizes = [16, 24, 32, 48, 64, 128, 256];
  const images = [];
  for (const size of sizes) images.push(await sharp(Buffer.from(svg)).resize(size, size).png().toBuffer());
  const header = Buffer.alloc(6 + sizes.length * 16);
  header.writeUInt16LE(1, 2); header.writeUInt16LE(sizes.length, 4);
  let offset = header.length;
  images.forEach((image, i) => {
    const entry = 6 + i * 16;
    header[entry] = sizes[i] % 256; header[entry + 1] = sizes[i] % 256;
    header.writeUInt16LE(1, entry + 4); header.writeUInt16LE(32, entry + 6);
    header.writeUInt32LE(image.length, entry + 8); header.writeUInt32LE(offset, entry + 12);
    offset += image.length;
  });
  fs.writeFileSync(path.join(root, 'flutter/windows/runner/resources/deploy_icon.ico'), Buffer.concat([header, ...images]));
}
main().catch(error => { console.error(error); process.exitCode = 1; });
