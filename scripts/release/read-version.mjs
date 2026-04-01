import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, '..', '..');
const zonPath = resolve(repoRoot, 'build.zig.zon');
const source = await readFile(zonPath, 'utf8');
const match = source.match(/\.version\s*=\s*"([^"]+)"/);

if (!match) {
  throw new Error(`Could not find .version in ${zonPath}`);
}

const version = match[1];
const semverPattern = /^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$/;
if (!semverPattern.test(version)) {
  throw new Error(`Version ${version} is not valid semver`);
}

process.stdout.write(version);
