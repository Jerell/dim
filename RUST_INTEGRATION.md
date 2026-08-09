# Using dim from Rust

`dim` exposes a structured C ABI intended for Rust and other FFI consumers.
The current surface is context-based; there are no legacy `dim_eval` or
process-global constant functions in the shipped library.

## Build the native library

```bash
zig build -Dtarget=native -Doptimize=ReleaseFast
```

This creates `zig-out/lib/libdim_c.a` (or the platform equivalent) and the
matching header at `dim.h`.

## Link from Cargo

Copy `libdim_c.a` and `dim.h` into a `vendor/` directory and add a build script:

```rust
use std::path::PathBuf;

fn main() {
    let vendor = PathBuf::from("vendor");
    println!("cargo:rustc-link-search=native={}", vendor.display());
    println!("cargo:rustc-link-lib=static=dim_c");
    println!("cargo:rerun-if-changed=vendor/libdim_c.a");
    println!("cargo:rerun-if-changed=vendor/dim.h");
}
```

Generate Rust declarations with `bindgen` using `vendor/dim.h` as the input.

## Context wrapper

The important operations are `dim_ctx_new`, `dim_ctx_define`, `dim_ctx_eval`,
the direct conversion/compatibility functions, and `dim_ctx_free`:

```rust
// These names are generated from dim.h by bindgen.
include!(concat!(env!("OUT_DIR"), "/bindings.rs"));

pub struct Context {
    raw: *mut DimContext,
}

#[derive(Debug)]
pub struct DimError(i32);

impl Context {
    pub fn new() -> Result<Self, DimError> {
        let raw = unsafe { dim_ctx_new() };
        if raw.is_null() {
            return Err(DimError(DIM_STATUS_OUT_OF_MEMORY));
        }
        Ok(Self { raw })
    }

    pub fn eval(&mut self, input: &[u8]) -> Result<DimEvalResult, DimError> {
        let mut result = unsafe { std::mem::zeroed::<DimEvalResult>() };
        let rc = unsafe {
            dim_ctx_eval(
                self.raw,
                input.as_ptr(),
                input.len(),
                &mut result,
            )
        };
        if rc != DIM_STATUS_OK {
            return Err(DimError(rc));
        }

        Ok(result)
    }

    pub fn reset_arena(&mut self) {
        unsafe { dim_ffi_reset() }
    }
}

impl Drop for Context {
    fn drop(&mut self) {
        unsafe { dim_ctx_free(self.raw) };
    }
}
```

The example shows the lifetime boundary, but a production wrapper should copy
`string_ptr` and `unit_ptr` into owned Rust `String`s before calling
`dim_ffi_reset`. `DimEvalResult` also carries exact rational dimension pairs,
so callers should not assume all exponents have denominator `1`.

For repeated workloads, prefer `dim_ctx_batch_convert_exprs` and
`dim_ctx_batch_convert_values`; each item returns a status alongside its
numeric output.

## Memory rules

- Input slices are borrowed only for the duration of the call.
- Result strings and unit symbols live in the calling thread's FFI arena.
- Copy result bytes before calling `dim_ffi_reset`.
- `dim_free` remains in the header for source compatibility but is a no-op in
  the arena-based ABI.
- A `DimContext` owns its constants and must be released with
  `dim_ctx_free`.

The context API is isolated by default. Do not share one context across
threads without external synchronization; create one context per concurrent
worker instead.
