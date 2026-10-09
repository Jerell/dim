import { readFile } from "node:fs/promises";
import {
  batchConvertValues,
  clearAllConsts,
  convertValue,
  convertExpr,
  DIM_STATUS,
  DimWasmError,
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

// A quantity's value is in the unit it reports, as the native CLI prints it,
// not in SI base units under the typed unit's label.
for (const [expression, value, unit] of [
  ["5 bar", 5, "bar"],
  ["45 degC", 45, "degC"],
  ["500 ppm", 500, "ppm"],
  ["2 m + 30 cm", 2.3, "m"],
  ["45 degC as K", 318.15, "K"],
]) {
  const result = evalStructured(expression);
  if (
    result.kind !== "quantity" ||
    result.unit !== unit ||
    Math.abs(result.value - value) > 1e-9
  ) {
    throw new Error(`${expression}: unexpected result ${JSON.stringify(result)}`);
  }
  if (formatEvalResult(result) !== `${value} ${unit}`) {
    throw new Error(`${expression}: formatted as ${formatEvalResult(result)}`);
  }
}

for (const unit of ["um", "µm", "μm", "micrometer", "micrometre"]) {
  const expression = `45 ${unit}`;
  const authored = evalStructured(expression);
  if (authored.kind !== "quantity" || authored.unit !== unit || authored.value !== 45) {
    throw new Error(`${expression}: authored unit was lost`);
  }
  const converted = convertExpr(expression, "m");
  if (Math.abs(converted.value - 45e-6) > 1e-15 || !isCompatible(expression, "m")) {
    throw new Error(`${expression}: micrometre conversion failed`);
  }
  if (isCompatible(expression, "Pa")) {
    throw new Error(`${expression}: a length is not a pressure`);
  }
  if (Math.abs(convertValue(45e-6, "m", unit) - 45) > 1e-12) {
    throw new Error(`${expression}: conversion target failed`);
  }
}

for (const [unit, kelvin] of [["°C", 323.15], ["degC", 323.15], ["C", 323.15], ["°F", 283.15]]) {
  const expression = `50 ${unit}`;
  const authored = evalStructured(expression);
  if (authored.kind !== "quantity" || authored.unit !== unit || authored.value !== 50) {
    throw new Error(`${expression}: authored unit was lost`);
  }
  if (Math.abs(convertExpr(expression, "K").value - kelvin) > 1e-9) {
    throw new Error(`${expression}: absolute temperature conversion failed`);
  }
  if (Math.abs(convertValue(kelvin, "K", unit) - 50) > 1e-9) {
    throw new Error(`${expression}: conversion target failed`);
  }
}

if (convertValue(1, "bar", "Pa") !== 100000) {
  throw new Error("direct conversion failed");
}
if (!isCompatible("1 m", "km")) {
  throw new Error("compatibility check failed");
}

// The dimensionless unit is 1. Its compatibility probe used to be "1 1",
// which is not an expression, so no fraction was compatible with it.
for (const expression of ["0.5", "500 ppm", "5 percent", "5 %", "5%", "0.5 mol/mol"]) {
  if (!isCompatible(expression, "1")) {
    throw new Error(`${expression} should be compatible with 1`);
  }
}
if (isCompatible("3 m", "1")) {
  throw new Error("a length is not dimensionless");
}
if (Math.abs(convertValue(500, "ppm", "1") - 5e-4) > 1e-15) {
  throw new Error("ppm conversion to 1 failed");
}
if (Math.abs(convertValue(5, "percent", "ppm") - 5e4) > 1e-9) {
  throw new Error("percent conversion to ppm failed");
}
if (Math.abs(convertValue(5, "%", "1") - 0.05) > 1e-15) {
  throw new Error("% conversion to 1 failed");
}

for (const [expression, status] of [
  ["1 m trailing", DIM_STATUS.parseError],
  ["1 / 0", DIM_STATUS.divisionByZero],
]) {
  try {
    evalStructured(expression);
    throw new Error(`expected ${expression} to fail`);
  } catch (error) {
    if (!(error instanceof DimWasmError) || error.status !== status) {
      throw new Error(`unexpected status for ${expression}: ${error}`);
    }
  }
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
