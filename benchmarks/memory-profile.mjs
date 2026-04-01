import { readFile, writeFile } from "node:fs/promises";
import {
  plotBatchCase,
  tableBatchCase,
  tooltipFanoutCase,
} from "./fixtures.mjs";
import { createV2Runtime } from "./lib/v2-runtime.mjs";

const ITERATIONS = 2000;
const SAMPLE_INTERVAL = 50;

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const wasmPath = args.wasm;
  if (!wasmPath) {
    console.error(
      "Usage: node benchmarks/memory-profile.mjs --wasm <path> [--iterations N] [--json-out <path>]",
    );
    process.exitCode = 1;
    return;
  }

  const iterations = args.iterations
    ? Number.parseInt(args.iterations, 10)
    : ITERATIONS;
  const sampleInterval = args["sample-interval"]
    ? Number.parseInt(args["sample-interval"], 10)
    : SAMPLE_INTERVAL;

  const bytes = await readFile(wasmPath);
  const { WebAssembly } = globalThis;
  const module = new WebAssembly.Module(bytes);

  // Instantiate with raw access to memory so we can track buffer size
  const { instantiateModuleWithWasi } = await import("./lib/instantiate.mjs");
  const instance = instantiateModuleWithWasi(module);
  const exports = instance.exports;
  const runtime = await createV2Runtime(wasmPath);

  const memory = exports.memory;
  const samples = [];

  function sample(iteration, phase) {
    samples.push({
      iteration,
      phase,
      memoryBytes: memory.buffer.byteLength,
      memoryPages: memory.buffer.byteLength / 65536,
    });
  }

  const workloads = [
    {
      name: "convertExpr",
      run: () => runtime.convertExpr("18 kJ / 3 kg", "kJ/kg"),
    },
    {
      name: "convertValue",
      run: () => runtime.convertValue(1.43567576391605e-5, "Pa*s", "Pa*s"),
    },
    {
      name: "isCompatible",
      run: () => runtime.isCompatible("1 mm", "mi"),
    },
    {
      name: "evalStructured",
      run: () => runtime.evalStructured("5 barg - 2 barg"),
    },
    {
      name: "tooltipFanout",
      run: () =>
        runtime.batchConvertExprs(
          tooltipFanoutCase.units.map((unit) => ({
            expr: tooltipFanoutCase.expression,
            unit,
          })),
        ),
    },
    {
      name: "tableBatch",
      run: () => runtime.batchConvertExprs(tableBatchCase),
    },
    {
      name: "plotBatch",
      run: () => runtime.batchConvertValues(plotBatchCase),
    },
  ];

  sample(0, "init");

  for (let i = 1; i <= iterations; i += 1) {
    // Cycle through all workloads each iteration
    for (const workload of workloads) {
      workload.run();
    }

    if (i % sampleInterval === 0 || i === 1 || i === iterations) {
      sample(i, "running");
    }
  }

  sample(iterations, "final");

  runtime.dispose();

  const initial = samples[0].memoryPages;
  const final = samples[samples.length - 1].memoryPages;
  const peak = Math.max(...samples.map((s) => s.memoryPages));

  const report = {
    generatedAt: new Date().toISOString(),
    nodeVersion: process.version,
    wasmPath,
    iterations,
    sampleInterval,
    workloadsPerIteration: workloads.map((w) => w.name),
    summary: {
      initialPages: initial,
      finalPages: final,
      peakPages: peak,
      initialBytes: initial * 65536,
      finalBytes: final * 65536,
      peakBytes: peak * 65536,
      growth: final - initial,
      stable: final <= initial + 1,
    },
    samples,
  };

  console.log(renderReport(report));

  if (args["json-out"]) {
    await writeFile(args["json-out"], `${JSON.stringify(report, null, 2)}\n`);
  }
}

function renderReport(report) {
  const s = report.summary;
  const lines = [
    "# dim WASM memory profile",
    "",
    `- Generated: ${report.generatedAt}`,
    `- Node: ${report.nodeVersion}`,
    `- WASM: ${report.wasmPath}`,
    `- Iterations: ${report.iterations} (${report.workloadsPerIteration.length} workloads each)`,
    "",
    "## Summary",
    "",
    `| Metric | Pages | Bytes |`,
    `| --- | ---: | ---: |`,
    `| Initial | ${s.initialPages} | ${formatBytes(s.initialBytes)} |`,
    `| Final | ${s.finalPages} | ${formatBytes(s.finalBytes)} |`,
    `| Peak | ${s.peakPages} | ${formatBytes(s.peakBytes)} |`,
    `| Growth | ${s.growth} | ${formatBytes(s.growth * 65536)} |`,
    "",
    `**Verdict: ${s.stable ? "STABLE - no unbounded growth detected" : "GROWING - memory increased by " + s.growth + " pages"}**`,
    "",
    "## Samples",
    "",
    "| Iteration | Pages | Bytes |",
    "| ---: | ---: | ---: |",
  ];

  for (const sample of report.samples) {
    lines.push(
      `| ${sample.iteration} | ${sample.memoryPages} | ${formatBytes(sample.memoryBytes)} |`,
    );
  }

  return lines.join("\n");
}

function formatBytes(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KiB`;
  return `${(bytes / (1024 * 1024)).toFixed(2)} MiB`;
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
