# Using dim in Rust

This guide explains how to use the dim library in a Rust application.

## Building the Library

First, build the C-compatible static library:

```bash
zig build -Dtarget=native -Doptimize=ReleaseFast
```

This will create `zig-out/lib/libdim_c.a` (the C-compatible library) and `zig-out/lib/libdim.a` (the Zig module library).

## Rust Integration

### Option 1: Using build.rs (Recommended)

1. Copy `libdim_c.a` and `dim.h` to your Rust project (e.g., in a `vendor/` directory).

2. Create a `build.rs` file in your Rust project root:

```rust
use std::env;
use std::path::PathBuf;

fn main() {
    // Tell cargo where to find the static library
    let lib_dir = PathBuf::from("vendor");
    println!("cargo:rustc-link-search=native={}", lib_dir.display());
    println!("cargo:rustc-link-lib=static=dim_c");

    // Tell cargo to invalidate the built crate whenever the library changes
    println!("cargo:rerun-if-changed=vendor/libdim_c.a");
    println!("cargo:rerun-if-changed=vendor/dim.h");
}
```

3. Generate Rust bindings using `bindgen`:

Add to your `Cargo.toml`:

```toml
[build-dependencies]
bindgen = "0.69"

[dependencies]
libc = "0.2"
```

Update your `build.rs`:

```rust
use std::env;
use std::path::PathBuf;

fn main() {
    // Tell cargo where to find the static library
    let lib_dir = PathBuf::from("vendor");
    println!("cargo:rustc-link-search=native={}", lib_dir.display());
    println!("cargo:rustc-link-lib=static=dim_c");

    // Generate bindings
    let bindings = bindgen::Builder::default()
        .header("vendor/dim.h")
        .parse_callbacks(Box::new(bindgen::CargoCallbacks))
        .generate()
        .expect("Unable to generate bindings");

    let out_path = PathBuf::from(env::var("OUT_DIR").unwrap());
    bindings
        .write_to_file(out_path.join("bindings.rs"))
        .expect("Couldn't write bindings!");

    println!("cargo:rerun-if-changed=vendor/libdim_c.a");
    println!("cargo:rerun-if-changed=vendor/dim.h");
}
```

4. Create a Rust wrapper module:

```rust
// src/dim.rs
#![allow(non_upper_case_globals)]
#![allow(non_camel_case_types)]
#![allow(non_snake_case)]

include!(concat!(env!("OUT_DIR"), "/bindings.rs"));

use std::ffi::CStr;
use std::os::raw::{c_char, c_uint};

pub struct DimError;

pub fn eval(input: &str) -> Result<String, DimError> {
    let input_bytes = input.as_bytes();
    let mut out_ptr: *mut u8 = std::ptr::null_mut();
    let mut out_len: usize = 0;

    let result = unsafe {
        dim_eval(
            input_bytes.as_ptr(),
            input_bytes.len(),
            &mut out_ptr,
            &mut out_len,
        )
    };

    if result != 0 {
        return Err(DimError);
    }

    unsafe {
        let slice = std::slice::from_raw_parts(out_ptr, out_len);
        let string = String::from_utf8_lossy(slice).to_string();
        dim_free(out_ptr, out_len);
        Ok(string)
    }
}

pub fn define(name: &str, expr: &str) -> Result<(), DimError> {
    let name_bytes = name.as_bytes();
    let expr_bytes = expr.as_bytes();

    let result = unsafe {
        dim_define(
            name_bytes.as_ptr(),
            name_bytes.len(),
            expr_bytes.as_ptr(),
            expr_bytes.len(),
        )
    };

    if result == 0 {
        Ok(())
    } else {
        Err(DimError)
    }
}

pub fn clear(name: &str) {
    let name_bytes = name.as_bytes();
    unsafe {
        dim_clear(name_bytes.as_ptr(), name_bytes.len());
    }
}

pub fn clear_all() {
    unsafe {
        dim_clear_all();
    }
}
```

5. Use it in your Rust code:

```rust
// src/main.rs
mod dim;

fn main() {
    match dim::eval("2 + 2") {
        Ok(result) => println!("Result: {}", result),
        Err(_) => println!("Error evaluating expression"),
    }

    dim::define("pi", "3.14159").unwrap();
    match dim::eval("pi * 2") {
        Ok(result) => println!("Result: {}", result),
        Err(_) => println!("Error evaluating expression"),
    }
}
```

### Option 2: Using a Cargo Build Script with System Library

If you install the library system-wide, you can use:

```rust
// build.rs
fn main() {
    println!("cargo:rustc-link-lib=static=dim_c");
}
```

## Notes

- The library uses `page_allocator` for memory returned by `dim_eval`, so you must call `dim_free` to avoid memory leaks.
- All string parameters are passed as byte slices with explicit lengths (no null terminators required).
- Error handling: functions return `0` on success, non-zero on failure.

