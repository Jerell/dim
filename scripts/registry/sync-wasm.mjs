import { copyFile, mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, "..", "..");
const wasmPath = resolve(repoRoot, "zig-out", "bin", "dim_wasm.wasm");
const registryAssetPath = resolve(
  repoRoot,
  "registry",
  "assets",
  "dim_wasm.wasm.base64",
);
const publicAssetDir = resolve(repoRoot, "public", "dim");
const publicBase64Path = resolve(publicAssetDir, "dim_wasm.wasm.base64");
const publicWasmPath = resolve(publicAssetDir, "dim_wasm.wasm");

const wasm = await readFile(wasmPath);
const armored = `${wasm.toString("base64")}\n`;

await Promise.all([
  mkdir(dirname(registryAssetPath), { recursive: true }),
  mkdir(publicAssetDir, { recursive: true }),
]);
await Promise.all([
  writeFile(registryAssetPath, armored, "utf8"),
  writeFile(publicBase64Path, armored, "utf8"),
  copyFile(wasmPath, publicWasmPath),
]);

process.stdout.write(
  `Synced ${wasm.byteLength} WASM bytes to the registry and Storybook assets.\n`,
);
