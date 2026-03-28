import { readFile } from "node:fs/promises";
import { normalizeDimSyntax } from "./normalize.mjs";
import { instantiateWithWasi } from "./instantiate.mjs";

const EVAL_RESULT_SIZE = 80;
const QUANTITY_RESULT_SIZE = 56;
const DIM_SLICE_SIZE = 8;

const STATUS_OK = 0;

const KIND_NUMBER = 0;
const KIND_BOOLEAN = 1;
const KIND_STRING = 2;
const KIND_QUANTITY = 3;
const KIND_NIL = 4;

const MODES = ["none", "auto", "scientific", "engineering"];
const toPtr = (value) => value >>> 0;

export async function createV2Runtime(wasmPath) {
  const bytes = await readFile(wasmPath);
  const instance = await instantiateWithWasi(bytes);
  const exports = instance.exports;
  const required = [
    "memory",
    "dim_alloc",
    "dim_free",
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
      throw new Error(`V2 wasm missing export: ${name}`);
    }
  }

  const ctx = toPtr(exports.dim_ctx_new());
  if (!ctx) {
    throw new Error("dim_ctx_new failed");
  }

  const enc = new TextEncoder();
  const dec = new TextDecoder();

  function alloc(size) {
    return toPtr(exports.dim_alloc(size));
  }

  function free(ptr, len) {
    if (len > 0 || ptr !== 0) {
      exports.dim_free(ptr, len);
    }
  }

  function writeUtf8(str) {
    const bytes = enc.encode(normalizeDimSyntax(str));
    const ptr = alloc(bytes.length);
    new Uint8Array(exports.memory.buffer, ptr, bytes.length).set(bytes);
    return { ptr, len: bytes.length };
  }

  function writeRawUtf8(str) {
    const bytes = enc.encode(str);
    const ptr = alloc(bytes.length);
    new Uint8Array(exports.memory.buffer, ptr, bytes.length).set(bytes);
    return { ptr, len: bytes.length };
  }

  function readString(ptr, len) {
    return dec.decode(new Uint8Array(exports.memory.buffer, ptr, len));
  }

  function readDims(dv, offset) {
    return {
      L: dv.getInt32(offset + 0, true),
      M: dv.getInt32(offset + 4, true),
      T: dv.getInt32(offset + 8, true),
      I: dv.getInt32(offset + 12, true),
      Th: dv.getInt32(offset + 16, true),
      N: dv.getInt32(offset + 20, true),
      J: dv.getInt32(offset + 24, true),
    };
  }

  function readEvalResult(ptr) {
    const dv = new DataView(exports.memory.buffer, ptr, EVAL_RESULT_SIZE);
    const kind = dv.getUint32(0, true);
    const boolValue = dv.getUint32(4, true);
    const mode = MODES[dv.getUint32(8, true)] ?? "none";
    const isDelta = dv.getUint32(12, true) === 1;
    const numberValue = dv.getFloat64(16, true);
    const quantityValue = dv.getFloat64(24, true);
    const dims = readDims(dv, 32);
    const stringPtr = dv.getUint32(60, true);
    const stringLen = dv.getUint32(64, true);
    const unitPtr = dv.getUint32(68, true);
    const unitLen = dv.getUint32(72, true);

    switch (kind) {
      case KIND_NUMBER:
        return { kind: "number", value: numberValue };
      case KIND_BOOLEAN:
        return { kind: "boolean", value: boolValue === 1 };
      case KIND_STRING: {
        const value = readString(stringPtr, stringLen);
        free(stringPtr, stringLen);
        return { kind: "string", value };
      }
      case KIND_QUANTITY: {
        const unit = readString(unitPtr, unitLen);
        free(unitPtr, unitLen);
        return {
          kind: "quantity",
          value: quantityValue,
          unit,
          dim: dims,
          isDelta,
          mode,
        };
      }
      case KIND_NIL:
      default:
        return { kind: "nil" };
    }
  }

  function readQuantityResult(ptr) {
    const dv = new DataView(exports.memory.buffer, ptr, QUANTITY_RESULT_SIZE);
    const mode = MODES[dv.getUint32(0, true)] ?? "none";
    const isDelta = dv.getUint32(4, true) === 1;
    const value = dv.getFloat64(8, true);
    const dim = readDims(dv, 16);
    const unitPtr = dv.getUint32(44, true);
    const unitLen = dv.getUint32(48, true);
    const unit = readString(unitPtr, unitLen);
    free(unitPtr, unitLen);
    return { value, unit, dim, isDelta, mode };
  }

  function callStatus(rc, label) {
    if (rc !== STATUS_OK) {
      throw new Error(`${label} failed with status ${rc}`);
    }
  }

  function evalStructured(expr) {
    const input = writeUtf8(expr);
    const outPtr = alloc(EVAL_RESULT_SIZE);
    const rc = exports.dim_ctx_eval(ctx, input.ptr, input.len, outPtr);
    free(input.ptr, input.len);
    callStatus(rc, "dim_ctx_eval");
    const result = readEvalResult(outPtr);
    free(outPtr, EVAL_RESULT_SIZE);
    return result;
  }

  function convertExpr(expr, unit) {
    const exprSlice = writeUtf8(expr);
    const unitSlice = writeUtf8(unit);
    const outPtr = alloc(QUANTITY_RESULT_SIZE);
    const rc = exports.dim_ctx_convert_expr(
      ctx,
      exprSlice.ptr,
      exprSlice.len,
      unitSlice.ptr,
      unitSlice.len,
      outPtr,
    );
    free(exprSlice.ptr, exprSlice.len);
    free(unitSlice.ptr, unitSlice.len);
    callStatus(rc, "dim_ctx_convert_expr");
    const result = readQuantityResult(outPtr);
    free(outPtr, QUANTITY_RESULT_SIZE);
    return result;
  }

  function convertValue(value, fromUnit, toUnit) {
    const fromSlice = writeUtf8(fromUnit);
    const toSlice = writeUtf8(toUnit);
    const outPtr = alloc(8);
    const rc = exports.dim_ctx_convert_value(
      ctx,
      value,
      fromSlice.ptr,
      fromSlice.len,
      toSlice.ptr,
      toSlice.len,
      outPtr,
    );
    free(fromSlice.ptr, fromSlice.len);
    free(toSlice.ptr, toSlice.len);
    callStatus(rc, "dim_ctx_convert_value");
    const result = new DataView(exports.memory.buffer, outPtr, 8).getFloat64(0, true);
    free(outPtr, 8);
    return result;
  }

  function readBool(outPtr) {
    return new DataView(exports.memory.buffer, outPtr, 4).getUint32(0, true) === 1;
  }

  function isCompatible(expr, unit) {
    const exprSlice = writeUtf8(expr);
    const unitSlice = writeUtf8(unit);
    const outPtr = alloc(4);
    const rc = exports.dim_ctx_is_compatible(
      ctx,
      exprSlice.ptr,
      exprSlice.len,
      unitSlice.ptr,
      unitSlice.len,
      outPtr,
    );
    free(exprSlice.ptr, exprSlice.len);
    free(unitSlice.ptr, unitSlice.len);
    callStatus(rc, "dim_ctx_is_compatible");
    const result = readBool(outPtr);
    free(outPtr, 4);
    return result;
  }

  function sameDimension(exprA, exprB) {
    const lhs = writeUtf8(exprA);
    const rhs = writeUtf8(exprB);
    const outPtr = alloc(4);
    const rc = exports.dim_ctx_same_dimension(
      ctx,
      lhs.ptr,
      lhs.len,
      rhs.ptr,
      rhs.len,
      outPtr,
    );
    free(lhs.ptr, lhs.len);
    free(rhs.ptr, rhs.len);
    callStatus(rc, "dim_ctx_same_dimension");
    const result = readBool(outPtr);
    free(outPtr, 4);
    return result;
  }

  function encodeSlices(strings, normalizer = normalizeDimSyntax) {
    const allocations = strings.map((value) => writeRawUtf8(normalizer(value)));
    const slicesPtr = alloc(strings.length * DIM_SLICE_SIZE);
    const dv = new DataView(exports.memory.buffer, slicesPtr, strings.length * DIM_SLICE_SIZE);
    allocations.forEach((entry, index) => {
      const base = index * DIM_SLICE_SIZE;
      dv.setUint32(base + 0, entry.ptr, true);
      dv.setUint32(base + 4, entry.len, true);
    });
    return { allocations, slicesPtr };
  }

  function batchConvertExprs(items) {
    const exprs = encodeSlices(items.map((item) => item.expr));
    const units = encodeSlices(items.map((item) => item.unit));
    const valuesPtr = alloc(items.length * 8);
    const statusesPtr = alloc(items.length * 4);
    const rc = exports.dim_ctx_batch_convert_exprs(
      ctx,
      exprs.slicesPtr,
      units.slicesPtr,
      items.length,
      valuesPtr,
      statusesPtr,
    );
    exprs.allocations.forEach(({ ptr, len }) => free(ptr, len));
    units.allocations.forEach(({ ptr, len }) => free(ptr, len));
    free(exprs.slicesPtr, items.length * DIM_SLICE_SIZE);
    free(units.slicesPtr, items.length * DIM_SLICE_SIZE);
    callStatus(rc, "dim_ctx_batch_convert_exprs");

    const valuesView = new DataView(exports.memory.buffer, valuesPtr, items.length * 8);
    const statusesView = new DataView(exports.memory.buffer, statusesPtr, items.length * 4);
    const values = [];
    for (let i = 0; i < items.length; i += 1) {
      const status = statusesView.getUint32(i * 4, true);
      if (status !== STATUS_OK) {
        free(valuesPtr, items.length * 8);
        free(statusesPtr, items.length * 4);
        throw new Error(`batch expr conversion failed at index ${i} with status ${status}`);
      }
      values.push(valuesView.getFloat64(i * 8, true));
    }
    free(valuesPtr, items.length * 8);
    free(statusesPtr, items.length * 4);
    return values;
  }

  function batchConvertValues(items) {
    const valuesPtr = alloc(items.length * 8);
    const valuesView = new DataView(exports.memory.buffer, valuesPtr, items.length * 8);
    items.forEach((item, index) => {
      valuesView.setFloat64(index * 8, item.value, true);
    });

    const fromUnits = encodeSlices(items.map((item) => item.fromUnit));
    const toUnits = encodeSlices(items.map((item) => item.toUnit));
    const outValuesPtr = alloc(items.length * 8);
    const statusesPtr = alloc(items.length * 4);
    const rc = exports.dim_ctx_batch_convert_values(
      ctx,
      valuesPtr,
      fromUnits.slicesPtr,
      toUnits.slicesPtr,
      items.length,
      outValuesPtr,
      statusesPtr,
    );
    free(valuesPtr, items.length * 8);
    fromUnits.allocations.forEach(({ ptr, len }) => free(ptr, len));
    toUnits.allocations.forEach(({ ptr, len }) => free(ptr, len));
    free(fromUnits.slicesPtr, items.length * DIM_SLICE_SIZE);
    free(toUnits.slicesPtr, items.length * DIM_SLICE_SIZE);
    callStatus(rc, "dim_ctx_batch_convert_values");

    const outValuesView = new DataView(exports.memory.buffer, outValuesPtr, items.length * 8);
    const statusesView = new DataView(exports.memory.buffer, statusesPtr, items.length * 4);
    const values = [];
    for (let i = 0; i < items.length; i += 1) {
      const status = statusesView.getUint32(i * 4, true);
      if (status !== STATUS_OK) {
        free(outValuesPtr, items.length * 8);
        free(statusesPtr, items.length * 4);
        throw new Error(`batch value conversion failed at index ${i} with status ${status}`);
      }
      values.push(outValuesView.getFloat64(i * 8, true));
    }
    free(outValuesPtr, items.length * 8);
    free(statusesPtr, items.length * 4);
    return values;
  }

  return {
    kind: "v2",
    evalStructured,
    convertExpr,
    convertValue,
    isCompatible,
    sameDimension,
    batchConvertExprs,
    batchConvertValues,
    defineConst(name, expr) {
      const nameSlice = writeRawUtf8(name);
      const exprSlice = writeUtf8(expr);
      const rc = exports.dim_ctx_define(
        ctx,
        nameSlice.ptr,
        nameSlice.len,
        exprSlice.ptr,
        exprSlice.len,
      );
      free(nameSlice.ptr, nameSlice.len);
      free(exprSlice.ptr, exprSlice.len);
      callStatus(rc, "dim_ctx_define");
    },
    clearConst(name) {
      const slice = writeRawUtf8(name);
      exports.dim_ctx_clear(ctx, slice.ptr, slice.len);
      free(slice.ptr, slice.len);
    },
    clearAllConsts() {
      exports.dim_ctx_clear_all(ctx);
    },
    dispose() {
      exports.dim_ctx_free(ctx);
    },
  };
}
