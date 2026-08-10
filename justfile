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
    zig build test --fuzz={{ iterations }} -Doptimize=ReleaseSafe

# Install or refresh the React registry development dependencies.
react-install:
    npm install

# Start Storybook with hot reload for viewing and editing registry components.
storybook:
    npm run storybook

# Build the static Storybook site.
storybook-build:
    npm run storybook:build

# Run the React component tests once. Extra arguments are passed to Vitest.
test-components *args:
    npm run test:components -- {{ args }}

# Run the React component tests in watch mode while editing.
test-components-watch *args:
    npm run build:wasm
    npm run sync:wasm
    npx vitest {{ args }}

# Type-check the React registry, stories, and component tests.
typecheck-react:
    npm run typecheck

# Build the WASM asset and static shadcn registry JSON.
registry-build:
    npm run registry:build

# Validate the source registry and all of its items.
registry-validate:
    npm run registry:validate

# Print a built registry item's resolved install payload.
registry-view item="quantity-input": registry-build
    npx shadcn view ./public/r/{{ item }}.json

# Add one or more shadcn primitives for current or future components.
add-ui +components:
    npx shadcn add {{ components }}

# Run the complete React/registry verification suite.
check-react: typecheck-react test-components registry-validate storybook-build
