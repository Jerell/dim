# Hand verification

These checklists compare the QuantityInput documents with the running Storybook stories one observable claim at a time.

## What is here

| File | Covers |
| --- | --- |
| [quantity-input.md](quantity-input.md) | foundations, QuantityInput stories, and accessibility/layout |

## How to run a pass

1. From `/Users/jerell/Repos/dim`, run `npm run storybook`; open `http://localhost:6006`.
2. Confirm `git -C /Users/jerell/Repos/dim rev-parse --short HEAD` matches the document footer `c26ec6a`. If the source has moved, decide whether to update the source commit before recording results.
3. In Storybook, visit `dim/QuantityInput` and run Default, Invalid, and Spreadsheet from a fresh page load. Clear or reload between scenarios.
4. Work through P1 items first, then P2 and P3. Use a real keyboard and pointer for focus, editing, popover, and dismissal claims.
5. Record `pass`, `fail`, or `blocked` in the Result column. File every fail in `bug-triage.md`; a failure may mean the document is wrong rather than the product.
6. Mark a document `verified` only when every P1 and P2 item has passed or been filed.

## Devices and conditions

- **Desktop browser:** use the browser and viewport in which Storybook is running. Record browser name and viewport for visual or accessibility results.
- **Keyboard:** use Tab, Shift+Tab, Enter, Space, Escape, and text editing to check focus and activation. Synthetic test events are not a substitute for this pass.
- **Pointer:** use mouse clicks for the input, addon, info button, outside page, and table rows.
- **Fresh page:** reload Storybook between stories when checking provider loading; cached WASM can remove the visible loading interval.
- **Invalid value:** type `12 kg` into a `bar` field and wait for invalid state before opening the panel.
- **Controlled table:** use Spreadsheet to verify that editing one row does not change the other rows.

## Driving the product from a console or script

The browser console can inspect the rendered input, `aria-invalid`, `data-status`, and popup DOM, but it should not synthesize the gestures being checked. The source tests and Storybook build can confirm evaluation and rendering contracts, not visual timing, focus return, browser accessibility announcements, or the exact loading flash.

## Results so far

No hand-verification pass has been run. `npm run typecheck`, `npm run test:components`, and `npm run storybook:build` passed on 2026-08-24. Those automated checks cover four tests, type checking, and successful static build generation; they do not establish what a person sees in the browser or how keyboard focus and popover dismissal feel. No document is marked `verified`.
