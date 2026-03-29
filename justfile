# Install just: https://github.com/casey/just

default:
  @just --list

# Development
build-wasm:
  zig build wasm -Doptimize=ReleaseSmall

build-native:
  zig build -Dtarget=native -Doptimize=ReleaseFast
