const WASI_ERRNO_NOTSUP = 58;

function unsupportedWasiOperation() {
  return WASI_ERRNO_NOTSUP;
}

function emptyWasiVectorGet() {
  return 0;
}

function createWasiImports(getMemory) {
  const wasi = {
      fd_write(_fd, iovPtr, iovCnt, nwrittenPtr) {
        const memory = getMemory();
        if (!memory) return unsupportedWasiOperation();
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
        if (!memory) return unsupportedWasiOperation();
        if (!globalThis.crypto?.getRandomValues) return unsupportedWasiOperation();
        const out = new Uint8Array(memory.buffer, bufPtr, bufLen);
        globalThis.crypto.getRandomValues(out);
        return 0;
      },
      fd_close: unsupportedWasiOperation,
      fd_sync: unsupportedWasiOperation,
      fd_seek: unsupportedWasiOperation,
      fd_read: unsupportedWasiOperation,
      fd_pread: unsupportedWasiOperation,
      fd_pwrite: unsupportedWasiOperation,
      fd_fdstat_get: unsupportedWasiOperation,
      fd_fdstat_set_flags: unsupportedWasiOperation,
      fd_filestat_get: unsupportedWasiOperation,
      fd_filestat_set_size: unsupportedWasiOperation,
      fd_filestat_set_times: unsupportedWasiOperation,
      fd_readdir: unsupportedWasiOperation,
      path_filestat_get: unsupportedWasiOperation,
      path_filestat_set_times: unsupportedWasiOperation,
      fd_prestat_get: unsupportedWasiOperation,
      fd_prestat_dir_name: unsupportedWasiOperation,
      path_open: unsupportedWasiOperation,
      path_link: unsupportedWasiOperation,
      path_readlink: unsupportedWasiOperation,
      path_symlink: unsupportedWasiOperation,
      path_rename: unsupportedWasiOperation,
      path_remove_directory: unsupportedWasiOperation,
      path_unlink_file: unsupportedWasiOperation,
      path_create_directory: unsupportedWasiOperation,
      environ_sizes_get(countPtr, bufSizePtr) {
        const memory = getMemory();
        if (!memory) return unsupportedWasiOperation();
        const dv = new DataView(memory.buffer);
        dv.setUint32(countPtr, 0, true);
        dv.setUint32(bufSizePtr, 0, true);
        return 0;
      },
      // Empty environment is a supported configuration after the size query
      // reports zero bytes.
      environ_get: emptyWasiVectorGet,
      args_sizes_get(argcPtr, argvBufSizePtr) {
        const memory = getMemory();
        if (!memory) return unsupportedWasiOperation();
        const dv = new DataView(memory.buffer);
        dv.setUint32(argcPtr, 0, true);
        dv.setUint32(argvBufSizePtr, 0, true);
        return 0;
      },
      args_get: emptyWasiVectorGet,
      clock_time_get: unsupportedWasiOperation,
      clock_res_get: unsupportedWasiOperation,
      poll_oneoff: unsupportedWasiOperation,
      proc_exit(code) {
        throw new Error(`WASI process exited with code ${code}`);
      },
  };

  return {
    // Keep the benchmark harness resilient to harmless additional WASI
    // imports emitted by future Zig versions.
    wasi_snapshot_preview1: new Proxy(wasi, {
      get(target, name) {
        return target[name] ?? unsupportedWasiOperation;
      },
    }),
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
