# Install just: https://github.com/casey/just

default:
  @just --list

# Development
build-wasm:
  zig build -Dtarget=wasm32-wasi -Doptimize=ReleaseSmall

build-native:
  zig build -Dtarget=native -Doptimize=ReleaseFast