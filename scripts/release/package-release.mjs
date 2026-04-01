import { chmod, copyFile, mkdir, readdir, rm, stat, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

function parseArgs(argv) {
  const [kind, ...rest] = argv;
  if (!kind) {
    throw new Error('Usage: node scripts/release/package-release.mjs <native|wasm> [--version <semver>] [--platform <name>] [--arch <name>] [--out-dir <path>]');
  }

  const options = { kind };
  for (let index = 0; index < rest.length; index += 1) {
    const token = rest[index];
    if (!token.startsWith('--')) {
      throw new Error(`Unexpected argument: ${token}`);
    }
    const key = token.slice(2).replace(/-([a-z])/g, (_, letter) => letter.toUpperCase());
    const value = rest[index + 1];
    if (!value || value.startsWith('--')) {
      throw new Error(`Missing value for ${token}`);
    }
    options[key] = value;
    index += 1;
  }

  return options;
}

function requireOption(options, key) {
  const value = options[key];
  if (!value) {
    throw new Error(`Missing required option --${key.replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`)}`);
  }
  return value;
}

async function copyInto(filePath, outDir, renameTo) {
  const targetPath = join(outDir, renameTo ?? basename(filePath));
  await copyFile(filePath, targetPath);

  const sourceStat = await stat(filePath);
  if ((sourceStat.mode & 0o111) !== 0) {
    await chmod(targetPath, sourceStat.mode & 0o777);
  }
}

async function findMatchingFile(directory, pattern) {
  if (!existsSync(directory)) {
    return null;
  }

  const entries = await readdir(directory);
  const match = entries.find((entry) => pattern.test(entry));
  return match ? join(directory, match) : null;
}

async function stageNativeBundle({ repoRoot, version, platform, arch, outDir }) {
  const bundleName = `dim-v${version}-${platform}-${arch}`;
  const bundleDir = join(outDir, bundleName);
  await rm(bundleDir, { recursive: true, force: true });
  await mkdir(bundleDir, { recursive: true });

  const binDir = join(repoRoot, 'zig-out', 'bin');
  const libDir = join(repoRoot, 'zig-out', 'lib');
  const executablePath = await findMatchingFile(binDir, /^dim(?:\.exe)?$/);
  const dimLibPath = await findMatchingFile(libDir, /^(?:lib)?dim\.(?:a|lib)$/);
  const dimCLibPath = await findMatchingFile(libDir, /^(?:lib)?dim_c\.(?:a|lib)$/);

  if (!executablePath) {
    throw new Error(`Could not find native dim executable in ${binDir}`);
  }
  if (!dimLibPath) {
    throw new Error(`Could not find native dim library in ${libDir}`);
  }
  if (!dimCLibPath) {
    throw new Error(`Could not find native dim_c library in ${libDir}`);
  }

  await Promise.all([
    copyInto(executablePath, bundleDir),
    copyInto(dimLibPath, bundleDir),
    copyInto(dimCLibPath, bundleDir),
    copyInto(join(repoRoot, 'dim.h'), bundleDir),
    copyInto(join(repoRoot, 'README.md'), bundleDir),
    copyInto(join(repoRoot, 'LICENSE'), bundleDir),
  ]);

  await writeFile(
    join(bundleDir, 'BUILD_INFO.txt'),
    [
      `name=dim`,
      `version=${version}`,
      `kind=native`,
      `platform=${platform}`,
      `arch=${arch}`,
      `artifact=${bundleName}`,
    ].join('\n') + '\n',
    'utf8',
  );

  return bundleDir;
}

async function stageWasmBundle({ repoRoot, version, outDir }) {
  const bundleName = `dim-v${version}-wasm`;
  const bundleDir = join(outDir, bundleName);
  await rm(bundleDir, { recursive: true, force: true });
  await mkdir(bundleDir, { recursive: true });

  const wasmPath = resolve(repoRoot, 'zig-out', 'bin', 'dim_wasm.wasm');
  if (!existsSync(wasmPath)) {
    throw new Error(`Could not find wasm artifact at ${wasmPath}`);
  }

  await Promise.all([
    copyInto(wasmPath, bundleDir),
    copyInto(join(repoRoot, 'wasm', 'dim.ts'), bundleDir),
    copyInto(join(repoRoot, 'README.md'), bundleDir),
    copyInto(join(repoRoot, 'LICENSE'), bundleDir),
  ]);

  await writeFile(
    join(bundleDir, 'BUILD_INFO.txt'),
    [
      `name=dim`,
      `version=${version}`,
      `kind=wasm`,
      `artifact=${bundleName}`,
      `wrapper=dim.ts`,
    ].join('\n') + '\n',
    'utf8',
  );

  return bundleDir;
}

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, '..', '..');
const options = parseArgs(process.argv.slice(2));
const version = requireOption(options, 'version');
const outDir = resolve(options.outDir ?? join(repoRoot, 'dist', 'release'));
await mkdir(outDir, { recursive: true });

let bundleDir;
if (options.kind === 'native') {
  const platform = requireOption(options, 'platform');
  const arch = requireOption(options, 'arch');
  bundleDir = await stageNativeBundle({ repoRoot, version, platform, arch, outDir });
} else if (options.kind === 'wasm') {
  bundleDir = await stageWasmBundle({ repoRoot, version, outDir });
} else {
  throw new Error(`Unknown bundle kind: ${options.kind}`);
}

process.stdout.write(`${bundleDir}\n`);
