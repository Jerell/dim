import { readFile } from "node:fs/promises";
import {
  batchConvertValues,
  clearAllConsts,
  convertValue,
  evalStructured,
  formatEvalResult,
  initDim,
  isCompatible,
  recoverDim,
} from "../wasm/dim.ts";

const wasmBytes = await readFile("zig-out/bin/dim_wasm.wasm");
await initDim({ wasmBytes });

const quantity = evalStructured("100 km/h as m/s");
if (quantity.kind !== "quantity" || Math.abs(quantity.value - 27.7777777778) > 1e-9) {
  throw new Error(`unexpected structured result: ${JSON.stringify(quantity)}`);
}

if (convertValue(1, "bar", "Pa") !== 100000) {
  throw new Error("direct conversion failed");
}
if (!isCompatible("1 m", "km")) {
  throw new Error("compatibility check failed");
}

const batch = batchConvertValues([
  { value: 1, fromUnit: "bar", toUnit: "Pa" },
  { value: 2, fromUnit: "km", toUnit: "m" },
]);
if (batch[0] !== 100000 || batch[1] !== 2000) {
  throw new Error(`batch conversion failed: ${batch}`);
}

clearAllConsts();

const wasmBase64 = (
  await readFile("registry/assets/dim_wasm.wasm.base64", "utf8")
).trim();
await recoverDim({ wasmBase64 });
if (convertValue(1, "km", "m") !== 1000) {
  throw new Error("base64 WASM initialization failed");
}

console.log(formatEvalResult(quantity));
