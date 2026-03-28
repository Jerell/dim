import {
  compatibilityFixtures,
  convertExprFixtures,
  convertValueFixtures,
  sameDimensionFixtures,
} from "./fixtures.mjs";
import { createLegacyRuntime } from "./lib/legacy-runtime.mjs";
import { createV2Runtime } from "./lib/v2-runtime.mjs";

function assertApprox(actual, expected, label, epsilon = 1e-9) {
  if (Math.abs(actual - expected) > epsilon) {
    throw new Error(`${label}: expected ${expected}, got ${actual}`);
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!args["legacy-wasm"] || !args["candidate-wasm"]) {
    throw new Error("Usage: node benchmarks/compare-fixtures.mjs --legacy-wasm <path> --candidate-wasm <path>");
  }

  const legacy = await createLegacyRuntime(args["legacy-wasm"]);
  const candidate = await createV2Runtime(args["candidate-wasm"]);

  for (const fixture of compatibilityFixtures) {
    const legacyValue = legacy.isCompatible(fixture.expr, fixture.unit);
    const candidateValue = candidate.isCompatible(fixture.expr, fixture.unit);
    if (legacyValue !== fixture.expected || candidateValue !== fixture.expected) {
      throw new Error(`Compatibility mismatch for ${fixture.expr} -> ${fixture.unit}`);
    }
  }

  for (const fixture of sameDimensionFixtures) {
    const legacyValue = legacy.sameDimension(fixture.lhs, fixture.rhs);
    const candidateValue = candidate.sameDimension(fixture.lhs, fixture.rhs);
    if (legacyValue !== fixture.expected || candidateValue !== fixture.expected) {
      throw new Error(`Dimension mismatch for ${fixture.lhs} vs ${fixture.rhs}`);
    }
  }

  for (const fixture of convertValueFixtures) {
    assertApprox(
      legacy.convertValue(fixture.value, fixture.fromUnit, fixture.toUnit),
      fixture.expected,
      `Legacy convertValue ${fixture.fromUnit} -> ${fixture.toUnit}`,
    );
    assertApprox(
      candidate.convertValue(fixture.value, fixture.fromUnit, fixture.toUnit),
      fixture.expected,
      `V2 convertValue ${fixture.fromUnit} -> ${fixture.toUnit}`,
    );
  }

  for (const fixture of convertExprFixtures) {
    const legacyValue = legacy.convertExpr(fixture.expr, fixture.unit);
    const candidateValue = candidate.convertExpr(fixture.expr, fixture.unit);
    assertApprox(legacyValue.value, fixture.expectedValue, `Legacy convertExpr ${fixture.expr}`);
    assertApprox(candidateValue.value, fixture.expectedValue, `V2 convertExpr ${fixture.expr}`);
    if (legacyValue.unit !== fixture.expectedUnit || candidateValue.unit !== fixture.expectedUnit) {
      throw new Error(`Unit mismatch for ${fixture.expr} -> ${fixture.unit}`);
    }
  }

  candidate.dispose();
  console.log("All legacy vs V2 fixtures matched expected results.");
}

function parseArgs(argv) {
  const result = {};
  for (let i = 0; i < argv.length; i += 1) {
    const part = argv[i];
    if (!part.startsWith("--")) continue;
    result[part.slice(2)] = argv[i + 1];
    i += 1;
  }
  return result;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
