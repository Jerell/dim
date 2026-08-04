# Install just: https://github.com/casey/just

default:
  @just --list

# Development
build-wasm:
  zig build wasm -Doptimize=ReleaseSmall

build-native:
  zig build -Dtarget=native -Doptimize=ReleaseFast

# Run bounded built-in fuzz tests. Increase iterations for a longer run.
fuzz iterations="1000":
  zig build test --fuzz={{iterations}} -Doptimize=ReleaseSafe
