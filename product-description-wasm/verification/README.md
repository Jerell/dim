# Hand verification

These checklists compare the browser API documents with the TypeScript wrapper and the generated WASM artifact.

## What is here

| File | Covers |
| --- | --- |
| [browser-api.md](browser-api.md) | foundations, API calls, browser loading, and recovery |

## How to run a pass

1. From `/Users/jerell/Repos/dim`, run `npm run build:wasm`.
2. Run `node tests/wasm_wrapper.test.mjs` for the Node wrapper pass.
3. Confirm the source commit matches the feature footers (`811dcf0` for this draft snapshot).
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

A scripted pass ran on 2026-08-24: `npm run build:wasm` and `node tests/wasm_wrapper.test.mjs` passed and printed `27.77777777777778 m/s`. No browser harness has run, so no document is marked verified.
