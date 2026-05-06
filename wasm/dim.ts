type DimExports = {
  memory: WebAssembly.Memory;
  dim_alloc: (n: number) => number;
  dim_free: (ptr: number, len: number) => void;
  dim_ffi_reset: () => void;
  dim_ctx_new: () => number;
  dim_ctx_free: (ctx: number) => void;
  dim_ctx_define: (
    ctx: number,
    namePtr: number,
    nameLen: number,
    exprPtr: number,
    exprLen: number,
  ) => number;
  dim_ctx_clear: (ctx: number, namePtr: number, nameLen: number) => void;
  dim_ctx_clear_all: (ctx: number) => void;
  dim_ctx_eval: (
    ctx: number,
    inPtr: number,
    inLen: number,
    outResultPtr: number,
  ) => number;
  dim_ctx_convert_expr: (
    ctx: number,
    exprPtr: number,
    exprLen: number,
    unitPtr: number,
    unitLen: number,
    outResultPtr: number,
  ) => number;
  dim_ctx_convert_value: (
    ctx: number,
    value: number,
    fromPtr: number,
    fromLen: number,
    toPtr: number,
    toLen: number,
    outValuePtr: number,
  ) => number;
  dim_ctx_is_compatible: (
    ctx: number,
    exprPtr: number,
    exprLen: number,
    unitPtr: number,
    unitLen: number,
    outBoolPtr: number,
  ) => number;
  dim_ctx_same_dimension: (
    ctx: number,
    lhsPtr: number,
    lhsLen: number,
    rhsPtr: number,
    rhsLen: number,
    outBoolPtr: number,
  ) => number;
  dim_ctx_batch_convert_exprs: (
    ctx: number,
    exprsPtr: number,
    unitsPtr: number,
    count: number,
    outValuesPtr: number,
    outStatusesPtr: number,
  ) => number;
  dim_ctx_batch_convert_values: (
    ctx: number,
    valuesPtr: number,
    fromUnitsPtr: number,
    toUnitsPtr: number,
    count: number,
    outValuesPtr: number,
    outStatusesPtr: number,
  ) => number;
};

// Source-of-truth TypeScript wrapper shipped alongside the release WASM bundle.

export type DimRational = {
  num: number;
  den: number;
};

export type DimDimension = {
  L: DimRational;
  M: DimRational;
  T: DimRational;
  I: DimRational;
  Th: DimRational;
  N: DimRational;
  J: DimRational;
};

export type DimFormatMode = "none" | "auto" | "scientific" | "engineering";

export type DimQuantityResult = {
  kind: "quantity";
  value: number;
  unit: string;
  dim: DimDimension;
  isDelta: boolean;
  mode: DimFormatMode;
};

export type DimEvalResult =
  | { kind: "number"; value: number }
  | { kind: "boolean"; value: boolean }
  | { kind: "string"; value: string }
  | DimQuantityResult
  | { kind: "nil" };

export type DimInitOptions = {
  wasmBytes?: ArrayBuffer | ArrayBufferView;
  wasmUrl?: string | URL;
  fetchOptions?: RequestInit;
};

type DimRuntime = DimExports & {
  ctx: number;
  enc: TextEncoder;
  dec: TextDecoder;
};

const EVAL_RESULT_SIZE = 104;
const QUANTITY_RESULT_SIZE = 80;
const DIM_SLICE_SIZE = 8;
const STATUS_OK = 0;
const KIND_NUMBER = 0;
const KIND_BOOLEAN = 1;
const KIND_STRING = 2;
const KIND_QUANTITY = 3;
const KIND_NIL = 4;
const MODES: DimFormatMode[] = ["none", "auto", "scientific", "engineering"];

let initPromise: Promise<void> | null = null;
let runtime: DimRuntime | null = null;
const readyListeners = new Set<(ready: boolean) => void>();

function toPtr(value: number): number {
  return value >>> 0;
}

function alloc(rt: DimRuntime, size: number): number {
  const ptr = toPtr(rt.dim_alloc(size));
  if (!ptr) {
    throw new Error(`dim_alloc failed for ${size} bytes`);
  }
  return ptr;
}

function createWasiImports(
  getMemory: () => WebAssembly.Memory | null,
): WebAssembly.Imports {
  return {
    wasi_snapshot_preview1: {
      fd_write: (
        _fd: number,
        iovPtr: number,
        iovCnt: number,
        nwrittenPtr: number,
      ) => {
        const memory = getMemory();
        if (!memory) return 0;
        const dv = new DataView(memory.buffer);
        let total = 0;
        for (let i = 0; i < iovCnt; i += 1) {
          const base = iovPtr + i * 8;
          total += dv.getUint32(base + 4, true);
        }
        dv.setUint32(nwrittenPtr, total, true);
        return 0;
      },
      random_get: (bufPtr: number, bufLen: number) => {
        const memory = getMemory();
        if (!memory) return 0;
        const out = new Uint8Array(memory.buffer, bufPtr, bufLen);
        if (globalThis.crypto?.getRandomValues) {
          globalThis.crypto.getRandomValues(out);
        } else {
          out.fill(0);
        }
        return 0;
      },
      fd_close: () => 0,
      fd_seek: () => 0,
      fd_read: () => 0,
      fd_pread: () => 0,
      fd_pwrite: () => 0,
      fd_sync: () => 0,
      fd_fdstat_get: () => 0,
      fd_fdstat_set_flags: () => 0,
      fd_filestat_set_size: () => 0,
      fd_filestat_set_times: () => 0,
      fd_filestat_get: () => 0,
      path_filestat_get: () => 0,
      path_filestat_set_times: () => 0,
      fd_prestat_get: () => 0,
      fd_prestat_dir_name: () => 0,
      path_open: () => 0,
      path_link: () => 0,
      path_create_directory: () => 0,
      path_readlink: () => 0,
      path_symlink: () => 0,
      path_rename: () => 0,
      path_remove_directory: () => 0,
      path_unlink_file: () => 0,
      fd_readdir: () => 0,
      environ_sizes_get: (countPtr: number, bufSizePtr: number) => {
        const memory = getMemory();
        if (!memory) return 0;
        const dv = new DataView(memory.buffer);
        dv.setUint32(countPtr, 0, true);
        dv.setUint32(bufSizePtr, 0, true);
        return 0;
      },
      environ_get: () => 0,
      args_sizes_get: (argcPtr: number, argvBufSizePtr: number) => {
        const memory = getMemory();
        if (!memory) return 0;
        const dv = new DataView(memory.buffer);
        dv.setUint32(argcPtr, 0, true);
        dv.setUint32(argvBufSizePtr, 0, true);
        return 0;
      },
      args_get: () => 0,
      clock_res_get: () => 0,
      clock_time_get: () => 0,
      poll_oneoff: (
        _inPtr: number,
        _outPtr: number,
        _subscriptionCount: number,
        eventCountPtr: number,
      ) => {
        const memory = getMemory();
        if (!memory) return 0;
        new DataView(memory.buffer).setUint32(eventCountPtr, 0, true);
        return 0;
      },
      proc_exit: () => 0,
    },
  };
}

function emitReady(ready: boolean) {
  for (const listener of readyListeners) {
    listener(ready);
  }
}

export function subscribeDimReady(
  listener: (ready: boolean) => void,
): () => void {
  readyListeners.add(listener);
  listener(runtime !== null);
  return () => {
    readyListeners.delete(listener);
  };
}

function toArrayBuffer(value: ArrayBuffer | ArrayBufferView): ArrayBuffer {
  if (value instanceof ArrayBuffer) {
    return value;
  }

  return value.buffer.slice(
    value.byteOffset,
    value.byteOffset + value.byteLength,
  ) as ArrayBuffer;
}

async function responseToArrayBuffer(
  response: Response,
  source: string,
): Promise<ArrayBuffer> {
  if (!response.ok) {
    throw new Error(
      `Failed to load dim_wasm.wasm from ${source}: ${response.status} ${response.statusText}`,
    );
  }

  return response.arrayBuffer();
}

async function fetchWasmUrl(
  url: string | URL,
  fetchOptions: RequestInit | undefined,
): Promise<ArrayBuffer> {
  const response = await fetch(url, {
    cache: "no-cache",
    ...fetchOptions,
  });
  return responseToArrayBuffer(response, String(url));
}

async function findWasmBytes(
  options: DimInitOptions = {},
): Promise<ArrayBuffer> {
  if (options.wasmBytes) {
    return toArrayBuffer(options.wasmBytes);
  }

  if (options.wasmUrl) {
    return fetchWasmUrl(options.wasmUrl, options.fetchOptions);
  }

  const isNode =
    typeof process !== "undefined" &&
    process.versions != null &&
    process.versions.node != null;

  const moduleUrl = new URL("./dim_wasm.wasm", import.meta.url);

  if (isNode) {
    const { readFile } = await import("node:fs/promises");
    const { existsSync } = await import("node:fs");
    const { join, dirname } = await import("node:path");
    const { fileURLToPath } = await import("node:url");
    const __filename = fileURLToPath(import.meta.url);
    const thisDir = dirname(__filename);

    const candidates = [
      fileURLToPath(moduleUrl),
      join(thisDir, "dim_wasm.wasm"),
      join(thisDir, "..", "..", "..", "public", "dim", "dim_wasm.wasm"),
      join(process.cwd(), "dim", "wasm", "dim_wasm.wasm"),
      join(process.cwd(), "public", "dim", "dim_wasm.wasm"),
    ].filter((candidate, index, list) => list.indexOf(candidate) === index);

    const wasmPath = candidates.find((p) => existsSync(p));
    if (!wasmPath) {
      throw new Error(
        `Could not find dim_wasm.wasm. Searched:\n${candidates.join("\n")}`,
      );
    }

    const buf = await readFile(wasmPath);
    return buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength);
  } else {
    const sources: Array<string | URL> = [moduleUrl, "/dim/dim_wasm.wasm"];
    const failures: string[] = [];

    for (const source of sources) {
      try {
        return await fetchWasmUrl(source, options.fetchOptions);
      } catch (error) {
        failures.push(
          error instanceof Error ? error.message : `Failed to load ${source}`,
        );
      }
    }

    throw new Error(failures.join("\n"));
  }
}

export async function initDim(options: DimInitOptions = {}): Promise<void> {
  if (!initPromise) {
    emitReady(false);
    initPromise = (async () => {
      const bytes = await findWasmBytes(options);

      let currentMemory: WebAssembly.Memory | null = null;
      const { instance } = await WebAssembly.instantiate(
        bytes,
        createWasiImports(() => currentMemory),
      );
      const exports = instance.exports as unknown as DimExports;
      currentMemory = exports.memory;
      const required: Array<keyof DimExports> = [
        "memory",
        "dim_alloc",
        "dim_free",
        "dim_ffi_reset",
        "dim_ctx_new",
        "dim_ctx_free",
        "dim_ctx_define",
        "dim_ctx_clear",
        "dim_ctx_clear_all",
        "dim_ctx_eval",
        "dim_ctx_convert_expr",
        "dim_ctx_convert_value",
        "dim_ctx_is_compatible",
        "dim_ctx_same_dimension",
        "dim_ctx_batch_convert_exprs",
        "dim_ctx_batch_convert_values",
      ];

      for (const name of required) {
        if (!(name in exports)) {
          throw new Error(`dim wasm exports mismatch: missing ${String(name)}`);
        }
      }

      const ctx = toPtr(exports.dim_ctx_new());
      if (!ctx) {
        throw new Error("dim_ctx_new failed");
      }

      runtime = {
        ...exports,
        ctx,
        enc: new TextEncoder(),
        dec: new TextDecoder(),
      };
      emitReady(true);
    })().catch((error) => {
      if (runtime) {
        runtime.dim_ctx_free(runtime.ctx);
      }
      runtime = null;
      initPromise = null;
      emitReady(false);
      throw error;
    });
  }
  return initPromise;
}

export async function recoverDim(options: DimInitOptions = {}): Promise<void> {
  if (runtime) {
    runtime.dim_ctx_free(runtime.ctx);
  }
  runtime = null;
  initPromise = null;
  emitReady(false);
  await initDim(options);
}

function requireRuntime(): DimRuntime {
  if (!runtime) {
    throw new Error("dim not initialized. Call initDim() first.");
  }
  return runtime;
}

function normalizeDimSyntax(value: string): string {
  return value
    .replaceAll("\u00b7", "*")
    .replaceAll("\u22c5", "*")
    .replaceAll("\u00b2", "^2")
    .replaceAll("\u00b3", "^3")
    .replace(
      /(^|[^\w.])([+-]?(?:\d+\.?\d*|\.\d+)[eE][+-]?\d+)(?=\s|$|[()*/+\-])/g,
      (_match, prefix, numeric) =>
        `${prefix}${expandScientificNotation(numeric)}`,
    );
}

function expandScientificNotation(value: string): string {
  const lower = value.toLowerCase();
  if (!lower.includes("e")) {
    return value;
  }

  const sign = lower.startsWith("-") ? "-" : "";
  const unsigned =
    lower.startsWith("-") || lower.startsWith("+") ? lower.slice(1) : lower;
  const [coefficient, exponentString] = unsigned.split("e");
  const exponent = Number.parseInt(exponentString, 10);
  if (!Number.isFinite(exponent)) {
    return value;
  }

  const [integerPart, fractionPart = ""] = coefficient.split(".");
  const digits = `${integerPart}${fractionPart}`.replace(/^0+/, "") || "0";
  const decimalIndex = integerPart.length + exponent;

  if (Math.abs(decimalIndex) > 4096) {
    return value;
  }

  if (digits === "0") {
    return "0";
  }

  if (decimalIndex <= 0) {
    return `${sign}0.${"0".repeat(Math.abs(decimalIndex))}${digits}`;
  }

  if (decimalIndex >= digits.length) {
    return `${sign}${digits}${"0".repeat(decimalIndex - digits.length)}`;
  }

  return `${sign}${digits.slice(0, decimalIndex)}.${digits.slice(decimalIndex)}`;
}

function writeUtf8(rt: DimRuntime, str: string) {
  const bytes = rt.enc.encode(normalizeDimSyntax(str));
  const ptr = alloc(rt, bytes.length);
  new Uint8Array(rt.memory.buffer, ptr, bytes.length).set(bytes);
  return { ptr, len: bytes.length };
}

function writeRawUtf8(rt: DimRuntime, str: string) {
  const bytes = rt.enc.encode(str);
  const ptr = alloc(rt, bytes.length);
  new Uint8Array(rt.memory.buffer, ptr, bytes.length).set(bytes);
  return { ptr, len: bytes.length };
}

function readUtf8(rt: DimRuntime, ptr: number, len: number): string {
  return rt.dec.decode(new Uint8Array(rt.memory.buffer, ptr, len));
}

function readRational(dv: DataView, offset: number): DimRational {
  return {
    num: dv.getInt32(offset, true),
    den: dv.getUint32(offset + 4, true),
  };
}

function readDimensions(dv: DataView, offset: number): DimDimension {
  return {
    L: readRational(dv, offset + 0),
    M: readRational(dv, offset + 8),
    T: readRational(dv, offset + 16),
    I: readRational(dv, offset + 24),
    Th: readRational(dv, offset + 32),
    N: readRational(dv, offset + 40),
    J: readRational(dv, offset + 48),
  };
}

function expectStatus(rc: number, label: string) {
  if (rc !== STATUS_OK) {
    throw new Error(`${label} failed with status ${rc}`);
  }
}

function readEvalResult(rt: DimRuntime, ptr: number): DimEvalResult {
  const dv = new DataView(rt.memory.buffer, ptr, EVAL_RESULT_SIZE);
  const kind = dv.getUint32(0, true);
  const boolValue = dv.getUint32(4, true) === 1;
  const mode = MODES[dv.getUint32(8, true)] ?? "none";
  const isDelta = dv.getUint32(12, true) === 1;
  const numberValue = dv.getFloat64(16, true);
  const quantityValue = dv.getFloat64(24, true);
  const dim = readDimensions(dv, 32);
  const stringPtr = dv.getUint32(88, true);
  const stringLen = dv.getUint32(92, true);
  const unitPtr = dv.getUint32(96, true);
  const unitLen = dv.getUint32(100, true);

  switch (kind) {
    case KIND_NUMBER:
      return { kind: "number", value: numberValue };
    case KIND_BOOLEAN:
      return { kind: "boolean", value: boolValue };
    case KIND_STRING: {
      const value = readUtf8(rt, stringPtr, stringLen);
      return { kind: "string", value };
    }
    case KIND_QUANTITY: {
      const unit = readUtf8(rt, unitPtr, unitLen);
      return {
        kind: "quantity",
        value: quantityValue,
        unit,
        dim,
        isDelta,
        mode,
      };
    }
    case KIND_NIL:
    default:
      return { kind: "nil" };
  }
}

function readQuantityResult(rt: DimRuntime, ptr: number): DimQuantityResult {
  const dv = new DataView(rt.memory.buffer, ptr, QUANTITY_RESULT_SIZE);
  const mode = MODES[dv.getUint32(0, true)] ?? "none";
  const isDelta = dv.getUint32(4, true) === 1;
  const value = dv.getFloat64(8, true);
  const dim = readDimensions(dv, 16);
  const unitPtr = dv.getUint32(72, true);
  const unitLen = dv.getUint32(76, true);
  const unit = readUtf8(rt, unitPtr, unitLen);
  return { kind: "quantity", value, unit, dim, isDelta, mode };
}

function readBool(rt: DimRuntime, ptr: number): boolean {
  return new DataView(rt.memory.buffer, ptr, 4).getUint32(0, true) === 1;
}

function formatScientific(value: number): string {
  return value.toExponential(3).replace("e+", "e");
}

function mod(value: number, divisor: number): number {
  return ((value % divisor) + divisor) % divisor;
}

function isDimensionless(dim: DimDimension): boolean {
  return BASE_UNIT_COMPONENTS.every(({ key }) => dim[key].num === 0);
}

export function formatQuantity(result: DimQuantityResult): string {
  const prefix = result.isDelta ? "\u0394" : "";
  const showUnit = !isDimensionless(result.dim) || result.unit !== "1";
  const suffix = showUnit ? ` ${result.unit}` : "";
  switch (result.mode) {
    case "auto":
      return `${prefix}${result.value.toFixed(3)}${suffix}`;
    case "scientific":
      return `${prefix}${formatScientific(result.value)}${suffix}`;
    case "engineering": {
      if (result.value === 0) {
        return `${prefix}0.000${suffix}`;
      }
      const exponent = Math.floor(Math.log10(Math.abs(result.value)));
      const engineeringExponent = exponent - mod(exponent, 3);
      const scaled = result.value / 10 ** engineeringExponent;
      return `${prefix}${scaled.toFixed(3)}e${engineeringExponent}${suffix}`;
    }
    case "none":
    default:
      return `${prefix}${result.value}${suffix}`;
  }
}

export function formatEvalResult(result: DimEvalResult): string {
  switch (result.kind) {
    case "number":
      return `${result.value}`;
    case "boolean":
      return `${result.value}`;
    case "string":
      return result.value;
    case "quantity":
      return formatQuantity(result);
    case "nil":
    default:
      return "nil";
  }
}

export function evalStructured(expr: string): DimEvalResult {
  const rt = requireRuntime();
  try {
    const input = writeUtf8(rt, expr);
    const outPtr = alloc(rt, EVAL_RESULT_SIZE);
    const rc = rt.dim_ctx_eval(rt.ctx, input.ptr, input.len, outPtr);
    expectStatus(rc, "dim_ctx_eval");
    return readEvalResult(rt, outPtr);
  } finally {
    rt.dim_ffi_reset();
  }
}

export function convertExpr(expr: string, unit: string): DimQuantityResult {
  const rt = requireRuntime();
  try {
    const exprSlice = writeUtf8(rt, expr);
    const unitSlice = writeUtf8(rt, unit);
    const outPtr = alloc(rt, QUANTITY_RESULT_SIZE);
    const rc = rt.dim_ctx_convert_expr(
      rt.ctx,
      exprSlice.ptr,
      exprSlice.len,
      unitSlice.ptr,
      unitSlice.len,
      outPtr,
    );
    expectStatus(rc, "dim_ctx_convert_expr");
    return readQuantityResult(rt, outPtr);
  } finally {
    rt.dim_ffi_reset();
  }
}

export function convertValue(
  value: number,
  fromUnit: string,
  toUnit: string,
): number {
  const rt = requireRuntime();
  try {
    const fromSlice = writeUtf8(rt, fromUnit);
    const toSlice = writeUtf8(rt, toUnit);
    const outPtr = alloc(rt, 8);
    const rc = rt.dim_ctx_convert_value(
      rt.ctx,
      value,
      fromSlice.ptr,
      fromSlice.len,
      toSlice.ptr,
      toSlice.len,
      outPtr,
    );
    expectStatus(rc, "dim_ctx_convert_value");
    return new DataView(rt.memory.buffer, outPtr, 8).getFloat64(0, true);
  } finally {
    rt.dim_ffi_reset();
  }
}

export function isCompatible(expr: string, unit: string): boolean {
  const rt = requireRuntime();
  try {
    const exprSlice = writeUtf8(rt, expr);
    const unitSlice = writeUtf8(rt, unit);
    const outPtr = alloc(rt, 4);
    const rc = rt.dim_ctx_is_compatible(
      rt.ctx,
      exprSlice.ptr,
      exprSlice.len,
      unitSlice.ptr,
      unitSlice.len,
      outPtr,
    );
    if (rc !== STATUS_OK) {
      return false;
    }
    return readBool(rt, outPtr);
  } finally {
    rt.dim_ffi_reset();
  }
}

export function sameDimension(exprA: string, exprB: string): boolean {
  const rt = requireRuntime();
  try {
    const lhs = writeUtf8(rt, exprA);
    const rhs = writeUtf8(rt, exprB);
    const outPtr = alloc(rt, 4);
    const rc = rt.dim_ctx_same_dimension(
      rt.ctx,
      lhs.ptr,
      lhs.len,
      rhs.ptr,
      rhs.len,
      outPtr,
    );
    if (rc !== STATUS_OK) {
      return false;
    }
    return readBool(rt, outPtr);
  } finally {
    rt.dim_ffi_reset();
  }
}

function writeSlices(rt: DimRuntime, values: string[], normalize = true) {
  const allocations = values.map((value) =>
    normalize ? writeUtf8(rt, value) : writeRawUtf8(rt, value),
  );
  const slicesPtr = alloc(rt, values.length * DIM_SLICE_SIZE);
  const dv = new DataView(
    rt.memory.buffer,
    slicesPtr,
    values.length * DIM_SLICE_SIZE,
  );
  allocations.forEach((allocation, index) => {
    const base = index * DIM_SLICE_SIZE;
    dv.setUint32(base + 0, allocation.ptr, true);
    dv.setUint32(base + 4, allocation.len, true);
  });
  return { allocations, slicesPtr };
}

export function batchConvertExprs(
  items: Array<{ expr: string; unit: string }>,
): number[] {
  if (items.length === 0) {
    return [];
  }

  const rt = requireRuntime();
  try {
    const exprs = writeSlices(
      rt,
      items.map((item) => item.expr),
    );
    const units = writeSlices(
      rt,
      items.map((item) => item.unit),
    );
    const outValuesPtr = alloc(rt, items.length * 8);
    const outStatusesPtr = alloc(rt, items.length * 4);

    const rc = rt.dim_ctx_batch_convert_exprs(
      rt.ctx,
      exprs.slicesPtr,
      units.slicesPtr,
      items.length,
      outValuesPtr,
      outStatusesPtr,
    );
    expectStatus(rc, "dim_ctx_batch_convert_exprs");

    const valuesView = new DataView(
      rt.memory.buffer,
      outValuesPtr,
      items.length * 8,
    );
    const statusView = new DataView(
      rt.memory.buffer,
      outStatusesPtr,
      items.length * 4,
    );
    return items.map((_, index) => {
      const status = statusView.getUint32(index * 4, true);
      expectStatus(status, `dim_ctx_batch_convert_exprs[${index}]`);
      return valuesView.getFloat64(index * 8, true);
    });
  } finally {
    rt.dim_ffi_reset();
  }
}

export function batchConvertValues(
  items: Array<{ value: number; fromUnit: string; toUnit: string }>,
): number[] {
  if (items.length === 0) {
    return [];
  }

  const rt = requireRuntime();
  try {
    const valuesPtr = alloc(rt, items.length * 8);
    const valuesView = new DataView(
      rt.memory.buffer,
      valuesPtr,
      items.length * 8,
    );
    items.forEach((item, index) => {
      valuesView.setFloat64(index * 8, item.value, true);
    });
    const fromUnits = writeSlices(
      rt,
      items.map((item) => item.fromUnit),
    );
    const toUnits = writeSlices(
      rt,
      items.map((item) => item.toUnit),
    );
    const outValuesPtr = alloc(rt, items.length * 8);
    const outStatusesPtr = alloc(rt, items.length * 4);

    const rc = rt.dim_ctx_batch_convert_values(
      rt.ctx,
      valuesPtr,
      fromUnits.slicesPtr,
      toUnits.slicesPtr,
      items.length,
      outValuesPtr,
      outStatusesPtr,
    );
    expectStatus(rc, "dim_ctx_batch_convert_values");

    const outValuesView = new DataView(
      rt.memory.buffer,
      outValuesPtr,
      items.length * 8,
    );
    const statusView = new DataView(
      rt.memory.buffer,
      outStatusesPtr,
      items.length * 4,
    );
    return items.map((_, index) => {
      const status = statusView.getUint32(index * 4, true);
      expectStatus(status, `dim_ctx_batch_convert_values[${index}]`);
      return outValuesView.getFloat64(index * 8, true);
    });
  } finally {
    rt.dim_ffi_reset();
  }
}

export function defineConst(name: string, expr: string): void {
  const rt = requireRuntime();
  try {
    const nameSlice = writeRawUtf8(rt, name);
    const exprSlice = writeUtf8(rt, expr);
    const rc = rt.dim_ctx_define(
      rt.ctx,
      nameSlice.ptr,
      nameSlice.len,
      exprSlice.ptr,
      exprSlice.len,
    );
    expectStatus(rc, "dim_ctx_define");
  } finally {
    rt.dim_ffi_reset();
  }
}

export function clearConst(name: string): void {
  const rt = requireRuntime();
  try {
    const slice = writeRawUtf8(rt, name);
    rt.dim_ctx_clear(rt.ctx, slice.ptr, slice.len);
  } finally {
    rt.dim_ffi_reset();
  }
}

export function clearAllConsts(): void {
  const rt = requireRuntime();
  rt.dim_ctx_clear_all(rt.ctx);
}

export function evalDim(expr: string): string {
  return formatEvalResult(evalStructured(expr));
}

export function convertExprToUnit(expr: string, unit: string): string {
  return formatQuantity(convertExpr(expr, unit));
}

export function convertValueToUnit(
  value: number,
  fromUnit: string,
  toUnit: string,
): number {
  return convertValue(value, fromUnit, toUnit);
}

export function checkUnitCompatibility(expr: string, target: string): boolean {
  return isCompatible(expr, target);
}

export function checkDimensionalCompatibility(
  expr: string,
  target: string,
): boolean {
  return sameDimension(expr, target);
}

const BASE_UNIT_COMPONENTS: Array<{
  key: keyof DimDimension;
  symbol: string;
}> = [
  { key: "M", symbol: "kg" },
  { key: "L", symbol: "m" },
  { key: "T", symbol: "s" },
  { key: "I", symbol: "A" },
  { key: "Th", symbol: "K" },
  { key: "N", symbol: "mol" },
  { key: "J", symbol: "cd" },
];

function hasFractionalDimension(dim: DimDimension): boolean {
  return BASE_UNIT_COMPONENTS.some(({ key }) => dim[key].den !== 1);
}

function formatRationalExponent(value: DimRational): string {
  if (value.num === 1 && value.den === 1) {
    return "";
  }

  if (value.den === 1) {
    return value.num < 0 ? `^(${value.num})` : `^${value.num}`;
  }

  return `^(${value.num}/${value.den})`;
}

function formatIntegerPart(dim: DimDimension, sign: 1 | -1): string | null {
  const parts = BASE_UNIT_COMPONENTS.flatMap(({ key, symbol }) => {
    const exponent = dim[key].num * sign;

    if (exponent <= 0) {
      return [];
    }

    return exponent === 1 ? [symbol] : [`${symbol}^${exponent}`];
  });

  return parts.length > 0 ? parts.join("*") : null;
}

function formatCanonicalBaseUnit(dim: DimDimension): string {
  if (hasFractionalDimension(dim)) {
    const parts = BASE_UNIT_COMPONENTS.flatMap(({ key, symbol }) => {
      const exponent = dim[key];
      return exponent.num === 0
        ? []
        : [`${symbol}${formatRationalExponent(exponent)}`];
    });

    return parts.length > 0 ? parts.join("*") : "1";
  }

  const numerator = formatIntegerPart(dim, 1);
  const denominator = formatIntegerPart(dim, -1);

  if (!numerator && !denominator) {
    return "1";
  }

  if (!denominator) {
    return numerator!;
  }

  if (!numerator) {
    return `1/${denominator}`;
  }

  return `${numerator}/${denominator}`;
}

export function getBaseUnit(expr: string): string {
  const result = evalStructured(expr);
  return result.kind === "quantity" ? formatCanonicalBaseUnit(result.dim) : "";
}

const dim = {
  init: initDim,
  recover: recoverDim,
  eval: evalDim,
  evalStructured,
  formatEvalResult,
  formatQuantity,
  defineConst,
  clearConst,
  clearAllConsts,
  isCompatible,
  sameDimension,
  checkUnitCompatibility,
  checkDimensionalCompatibility,
  getBaseUnit,
  convertExpr,
  convert: convertExprToUnit,
  convertExprToUnit,
  convertValue,
  convertValueToUnit,
  batchConvertExprs,
  batchConvertValues,
};

export default dim;
