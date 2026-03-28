import { performance } from "node:perf_hooks";
import { writeFile } from "node:fs/promises";
import {
  plotBatchCase,
  tableBatchCase,
  tooltipFanoutCase,
} from "./fixtures.mjs";
import { createLegacyRuntime } from "./lib/legacy-runtime.mjs";
import { createV2Runtime } from "./lib/v2-runtime.mjs";

const MEASURED_SAMPLES = 5;
const WARMUP_SAMPLES = 2;

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!args["legacy-wasm"] || !args["candidate-wasm"]) {
    throw new Error("Usage: node benchmarks/run.mjs --legacy-wasm <path> --candidate-wasm <path> [--json-out <path>] [--markdown-out <path>]");
  }

  const cases = buildCases();
  const results = [];
  for (const benchCase of cases) {
    const legacy = await createLegacyRuntime(args["legacy-wasm"]);
    const candidate = await createV2Runtime(args["candidate-wasm"]);
    const legacyMetrics = measure(() => benchCase.run(legacy), benchCase.iterations);
    const candidateMetrics = measure(() => benchCase.run(candidate), benchCase.iterations);
    candidate.dispose();
    results.push({
      name: benchCase.name,
      iterations: benchCase.iterations,
      legacy: legacyMetrics,
      candidate: candidateMetrics,
      speedup: legacyMetrics.medianMs / candidateMetrics.medianMs,
    });
  }

  const payload = {
    generatedAt: new Date().toISOString(),
    nodeVersion: process.version,
    legacyWasm: args["legacy-wasm"],
    candidateWasm: args["candidate-wasm"],
    results,
  };
  const markdown = renderMarkdown(payload);

  if (args["json-out"]) {
    await writeFile(args["json-out"], `${JSON.stringify(payload, null, 2)}\n`);
  }
  if (args["markdown-out"]) {
    await writeFile(args["markdown-out"], `${markdown}\n`);
  }

  console.log(markdown);
}

function buildCases() {
  return [
    {
      name: "compatibility-valid",
      iterations: 200,
      run(runtime) {
        for (let i = 0; i < 200; i += 1) {
          runtime.isCompatible("1 mm", "mi");
        }
      },
    },
    {
      name: "compatibility-invalid",
      iterations: 20,
      run(runtime) {
        for (let i = 0; i < 20; i += 1) {
          runtime.isCompatible("1 m", "C");
        }
      },
    },
    {
      name: "convert-value",
      iterations: 200,
      run(runtime) {
        for (let i = 0; i < 200; i += 1) {
          runtime.convertValue(1.43567576391605e-5, "Pa*s", "Pa*s");
        }
      },
    },
    {
      name: "convert-expr",
      iterations: 200,
      run(runtime) {
        for (let i = 0; i < 200; i += 1) {
          runtime.convertExpr("18 kJ / 3 kg", "kJ/kg");
        }
      },
    },
    {
      name: "tooltip-fanout",
      iterations: 50,
      run(runtime) {
        const items = tooltipFanoutCase.units.map((unit) => ({
          expr: tooltipFanoutCase.expression,
          unit,
        }));
        if (runtime.kind === "v2") {
          runtime.batchConvertExprs(items);
        } else {
          items.forEach((item) => runtime.convertExpr(item.expr, item.unit));
        }
      },
    },
    {
      name: "results-table-batch",
      iterations: 20,
      run(runtime) {
        if (runtime.kind === "v2") {
          runtime.batchConvertExprs(tableBatchCase);
        } else {
          tableBatchCase.forEach((item) => runtime.convertExpr(item.expr, item.unit));
        }
      },
    },
    {
      name: "plot-batch-values",
      iterations: 20,
      run(runtime) {
        if (runtime.kind === "v2") {
          runtime.batchConvertValues(plotBatchCase);
        } else {
          plotBatchCase.forEach((item) =>
            runtime.convertValue(item.value, item.fromUnit, item.toUnit),
          );
        }
      },
    },
  ];
}

function measure(runCase, iterations) {
  for (let i = 0; i < WARMUP_SAMPLES; i += 1) {
    runCase();
  }

  const samples = [];
  for (let i = 0; i < MEASURED_SAMPLES; i += 1) {
    const start = performance.now();
    runCase();
    const elapsedMs = performance.now() - start;
    samples.push(elapsedMs);
  }

  const sorted = [...samples].sort((a, b) => a - b);
  const medianMs = sorted[Math.floor(sorted.length / 2)];
  return {
    iterations,
    samplesMs: samples,
    medianMs,
    opsPerSecond: iterations / (medianMs / 1000),
  };
}

function renderMarkdown(payload) {
  const lines = [
    "# dim WASM benchmark report",
    "",
    `- Generated: ${payload.generatedAt}`,
    `- Node: ${payload.nodeVersion}`,
    `- Legacy artifact: ${payload.legacyWasm}`,
    `- Candidate artifact: ${payload.candidateWasm}`,
    "",
    "| Case | Iterations | Legacy median (ms) | Candidate median (ms) | Speedup |",
    "| --- | ---: | ---: | ---: | ---: |",
  ];

  for (const result of payload.results) {
    lines.push(
      `| ${result.name} | ${result.iterations} | ${result.legacy.medianMs.toFixed(3)} | ${result.candidate.medianMs.toFixed(3)} | ${result.speedup.toFixed(2)}x |`,
    );
  }

  return lines.join("\n");
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
