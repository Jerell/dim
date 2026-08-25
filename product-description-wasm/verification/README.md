# Hand verification

These checklists compare the browser API documents with the TypeScript wrapper and the generated WASM artifact.

## What is here

| File | Covers |
| --- | --- |
| [browser-api.md](browser-api.md) | foundations, API calls, browser loading, and recovery |

## How to run a pass

1. From `/Users/jerell/Repos/dim`, run `npm run build:wasm`.
2. Run `node tests/wasm_wrapper.test.mjs` for the Node wrapper pass.
3. Confirm the source commit matches the feature footers (`5d9cf0d` for this revision).
4. Use a minimal browser harness for URL loading, browser-relative asset paths, page teardown, and worker behavior.
5. Record `pass`, `fail`, or `blocked`; do not mark browser documents verified from Node assertions alone.

## Devices and conditions

- **Node:** confirms wrapper values using explicit binary and base64 sources; it is not a browser fetch test.
- **Browser:** use a real browser with the WASM asset served over HTTP, not a `file:` URL.
- **Network:** use normal, missing, non-OK, and delayed asset responses.
- **Worker/page lifecycle:** use a dedicated worker or page reload for teardown/recovery claims.
- **Large batch:** use a controlled array size and record memory/latency observations.

## Driving the product from a script

The wrapper itself is the API surface. A script can inspect returned structured objects, booleans, formatted text, thrown status errors, and constants. It cannot establish browser URL resolution, page unload behavior, or how concurrent callers behave without a browser/worker harness.

## Results so far

An automated pass for this revision ran on 2026-08-25: `npm run build:wasm`, `node tests/wasm_wrapper.test.mjs`, `npm run test:components`, and `npm run typecheck` passed. The wrapper tests cover distinct parse and division-by-zero status errors. No browser harness has run, so no document is marked verified.
