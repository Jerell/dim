import { readFile } from "node:fs/promises";
import { normalizeDimSyntax } from "./normalize.mjs";
import { instantiateModuleWithWasi } from "./instantiate.mjs";

export async function createLegacyRuntime(wasmPath) {
  const bytes = await readFile(wasmPath);
  const wasmModule = new WebAssembly.Module(bytes);
  let exports = instantiateModuleWithWasi(wasmModule).exports;
  const required = [
    "memory",
    "dim_alloc",
    "dim_free",
    "dim_eval",
    "dim_define",
    "dim_clear",
    "dim_clear_all",
  ];
  for (const name of required) {
    if (!(name in exports)) {
      throw new Error(`Legacy wasm missing export: ${name}`);
    }
  }

  const enc = new TextEncoder();
  const dec = new TextDecoder();

  function loadInstance() {
    exports = instantiateModuleWithWasi(wasmModule).exports;
  }

  const alloc = (size) => exports.dim_alloc(size) >>> 0;

  function writeUtf8(str) {
    const bytes = enc.encode(str);
    const ptr = alloc(bytes.length);
    new Uint8Array(exports.memory.buffer, ptr, bytes.length).set(bytes);
    return { ptr, len: bytes.length };
  }

  function evalTextCore(expr) {
    const { ptr: inPtr, len: inLen } = writeUtf8(normalizeDimSyntax(expr));
    const scratch = alloc(8);
    const outPtrPtr = scratch;
    const outLenPtr = scratch + 4;
    const rc = exports.dim_eval(inPtr, inLen, outPtrPtr, outLenPtr);
    exports.dim_free(inPtr, inLen);
    if (rc !== 0) {
      exports.dim_free(scratch, 8);
      throw new Error("dim_eval failed");
    }

    const dv = new DataView(exports.memory.buffer);
    const outPtr = dv.getUint32(outPtrPtr, true);
    const outLen = dv.getUint32(outLenPtr, true);
    exports.dim_free(scratch, 8);

    const text = dec.decode(new Uint8Array(exports.memory.buffer, outPtr, outLen));
    exports.dim_free(outPtr, outLen);
    return text;
  }

  function runtimeLooksHealthy() {
    try {
      void evalTextCore("1 m as km");
      return true;
    } catch {
      return false;
    }
  }

  function maybeRecoverRuntime() {
    if (!runtimeLooksHealthy()) {
      loadInstance();
    }
  }

  function evalText(expr) {
    try {
      return evalTextCore(expr);
    } catch {
      maybeRecoverRuntime();
      return evalTextCore(expr);
    }
  }

  function defineConst(name, expr) {
    const n = writeUtf8(name);
    const v = writeUtf8(normalizeDimSyntax(expr));
    const rc = exports.dim_define(n.ptr, n.len, v.ptr, v.len);
    exports.dim_free(n.ptr, n.len);
    exports.dim_free(v.ptr, v.len);
    if (rc !== 0) {
      maybeRecoverRuntime();
      throw new Error("dim_define failed");
    }
  }

  function clearConst(name) {
    const slice = writeUtf8(name);
    exports.dim_clear(slice.ptr, slice.len);
    exports.dim_free(slice.ptr, slice.len);
  }

  function parseQuantity(text) {
    const trimmed = text.trim();
    if (trimmed.startsWith("Δ")) {
      const inner = parseQuantity(trimmed.slice(1));
      return { ...inner, isDelta: true };
    }

    const parts = trimmed.split(/\s+/);
    if (parts.length >= 2) {
      const value = Number.parseFloat(parts[0]);
      if (Number.isFinite(value)) {
        return {
          value,
          unit: parts.slice(1).join(" "),
          dim: null,
          isDelta: false,
          mode: "none",
        };
      }
    }

    throw new Error(`Unable to parse quantity result: ${text}`);
  }

  function evalStructured(expr) {
    const text = evalText(expr);
    if (text === "true" || text === "false") {
      return { kind: "boolean", value: text === "true" };
    }
    if (text === "nil") {
      return { kind: "nil" };
    }

    const numeric = Number(text);
    if (Number.isFinite(numeric) && !/\s/.test(text.trim())) {
      return { kind: "number", value: numeric };
    }

    try {
      return { kind: "quantity", ...parseQuantity(text) };
    } catch {
      return { kind: "string", value: text };
    }
  }

  return {
    kind: "legacy",
    evalStructured,
    convertExpr(expr, unit) {
      return parseQuantity(evalText(`${expr} as ${unit}`));
    },
    convertValue(value, fromUnit, toUnit) {
      return parseQuantity(evalText(`${value} ${fromUnit} as ${toUnit}`)).value;
    },
    isCompatible(expr, unit) {
      try {
        void evalText(`${expr} + 1 ${unit}`);
        return true;
      } catch {
        maybeRecoverRuntime();
        return false;
      }
    },
    sameDimension(exprA, exprB) {
      try {
        void evalText(`${exprA} + ${exprB}`);
        return true;
      } catch {
        maybeRecoverRuntime();
        return false;
      }
    },
    batchConvertExprs(items) {
      return items.map(({ expr, unit }) => this.convertExpr(expr, unit).value);
    },
    batchConvertValues(items) {
      return items.map(({ value, fromUnit, toUnit }) =>
        this.convertValue(value, fromUnit, toUnit),
      );
    },
    defineConst,
    clearConst,
    clearAllConsts() {
      exports.dim_clear_all();
    },
  };
}
