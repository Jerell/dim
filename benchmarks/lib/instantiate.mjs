function createWasiImports(getMemory) {
  return {
    wasi_snapshot_preview1: {
      fd_write(_fd, iovPtr, iovCnt, nwrittenPtr) {
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
      random_get(bufPtr, bufLen) {
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
      fd_fdstat_get: () => 0,
      fd_filestat_get: () => 0,
      path_filestat_get: () => 0,
      fd_prestat_get: () => 0,
      fd_prestat_dir_name: () => 0,
      path_open: () => 0,
      environ_sizes_get(countPtr, bufSizePtr) {
        const memory = getMemory();
        if (!memory) return 0;
        const dv = new DataView(memory.buffer);
        dv.setUint32(countPtr, 0, true);
        dv.setUint32(bufSizePtr, 0, true);
        return 0;
      },
      environ_get: () => 0,
      args_sizes_get(argcPtr, argvBufSizePtr) {
        const memory = getMemory();
        if (!memory) return 0;
        const dv = new DataView(memory.buffer);
        dv.setUint32(argcPtr, 0, true);
        dv.setUint32(argvBufSizePtr, 0, true);
        return 0;
      },
      args_get: () => 0,
      clock_time_get: () => 0,
      proc_exit: () => 0,
    },
  };
}

export function instantiateModuleWithWasi(module) {
  let currentMemory = null;
  const instance = new WebAssembly.Instance(
    module,
    createWasiImports(() => currentMemory),
  );
  currentMemory = instance.exports.memory;
  return instance;
}

export async function instantiateWithWasi(bytes) {
  const module = new WebAssembly.Module(bytes);
  return instantiateModuleWithWasi(module);
}
