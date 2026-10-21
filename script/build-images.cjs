// Optional authoring tool; Node and sharp are not needed to run or deploy Rails.
// npm install --prefix tmp/image-tools sharp --no-audit --no-fund
// NODE_PATH="$PWD/tmp/image-tools/node_modules" node script/build-images.cjs
const sharp = require('sharp');
const fs = require('node:fs/promises');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const source = path.join(root, 'design-sources/night-sky.jpg');

async function build() {
  const directory = path.join(root, 'app/assets/images/background');
  await fs.mkdir(directory, { recursive: true });
  for (const width of [640, 960, 1440, 2560, 3200]) {
    const output = path.join(directory, `${width}.webp`);
    await sharp(source).resize({ width }).webp({ quality: 85, effort: 6 }).toFile(output);
    console.log(`${width}.webp: ${(await fs.stat(output)).size} bytes`);
  }
  // Error pages need a stable public URL without the Rails asset pipeline.
  await fs.copyFile(path.join(directory, '1440.webp'), path.join(root, 'public/error-background.webp'));
  await sharp(source)
    .resize(1200, 630, { fit: 'cover', position: 'centre' })
    .composite([{ input: path.join(root, 'design-sources/social-preview.svg') }])
    .jpeg({ quality: 88, mozjpeg: true })
    .toFile(path.join(root, 'public/social-preview.jpg'));
}
build().catch(error => { console.error(error); process.exitCode = 1; });
